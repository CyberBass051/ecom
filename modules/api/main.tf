data "archive_file" "get_products" {
  type        = "zip"
  source_dir  = var.get_products_src_dir
  output_path = "${path.module}/../../.build/get_products.zip"
}

data "archive_file" "post_order" {
  type        = "zip"
  source_dir  = var.post_order_src_dir
  output_path = "${path.module}/../../.build/post_order.zip"
}

# ------------- Lambda Exec Role ---------------
resource "aws_iam_role" "get_products_exec" {
  name = "${var.project}-get-products-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "get_products_exec" {
  role = aws_iam_role.get_products_exec.id
  name = "${var.project}-get-product-exec-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadProducts"
        Effect   = "Allow"
        Action   = ["dynamodb:Scan", "dynamodb:GetItem", "dynamodb:Query"]
        Resource = var.products_table_arn
      },
      {
        Sid      = "Logs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = var.products_table_arn
      }
    ]
  })
}

resource "aws_lambda_function" "get_products" {
  function_name    = "${var.project}-get-products"
  role             = aws_iam_role.get_products_exec.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.get_products.output_path
  source_code_hash = data.archive_file.get_products.output_base64sha256
  timeout          = 10

  environment {
    variables = {
      TABLE_NAME = var.products_table_name
    }
  }

  tracing_config {
    mode = "Active"
  }

  reserved_concurrent_executions = 5
}

# ----------- Post Order ---------
resource "aws_iam_role" "post_order_exec" {
  name = "${var.project}-post-order-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "post_order_exec" {
  name = "post-order-exec"
  role = aws_iam_role.post_order_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadProductPrices"
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem"]
        Resource = var.products_table_arn
      },
      {
        Sid      = "SendToOrdersQueue"
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = var.orders_queue_arn
      },
      {
        Sid      = "Logs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${var.region}:${var.account_id}:log-group:/aws/lambda/${var.project}-post-order*"
      }
    ]
  })
}

resource "aws_lambda_function" "post_order" {
  function_name    = "${var.project}-post-order"
  role             = aws_iam_role.post_order_exec.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.post_order.output_path
  source_code_hash = data.archive_file.post_order.output_base64sha256
  timeout          = 10

  environment {
    variables = {
      PRODUCTS_TABLE_NAME = var.products_table_name
      ORDERS_QUEUE_URL    = var.orders_queue_url
    }
  }

  tracing_config {
    mode = "Active"
  }

  reserved_concurrent_executions = 5
}


# -------------- HTTP API --------------------
resource "aws_apigatewayv2_api" "this" {
  name          = "${var.project}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST"]
  }
}

resource "aws_apigatewayv2_integration" "get_products" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.get_products.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get_products" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "GET /products"
  target    = "integrations/${aws_apigatewayv2_integration.get_products.id}"
}

resource "aws_apigatewayv2_integration" "post_order" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.post_order.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "post_order" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "POST /orders"
  target    = "integrations/${aws_apigatewayv2_integration.post_order.id}"
}

resource "aws_cloudwatch_log_group" "api_access" {
  name              = "/aws/apigateway/${var.project}-api"
  retention_in_days = 365
}

resource "aws_apigatewayv2_stage" "dev" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_access.arn
    format = jsonencode({
      requestId        = "$context.requestId"
      routeKey         = "$context.routeKey"
      status           = "$context.status"
      integrationError = "$context.integrationErrorMessage"
      responseLatency  = "$context.responseLatency"
    })
  }
}

resource "aws_lambda_permission" "apigw_get_products" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_products.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_post_order" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.post_order.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}
