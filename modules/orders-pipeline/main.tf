data "archive_file" "order_consumer" {
  type        = "zip"
  source_dir  = var.src_dir
  output_path = "${path.module}/../../.build/order_consumer.zip"
}

# ------- DLQ --------------
resource "aws_sqs_queue" "orders_dlq" {
  name                      = "${var.project}-orders-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true
}

resource "aws_sqs_queue" "orders" {
  name                       = "${var.project}-orders"
  visibility_timeout_seconds = 90
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.orders_dlq.arn
    maxReceiveCount     = 5
  })
}

resource "aws_sqs_queue_redrive_allow_policy" "orders_dlq" {
  queue_url = aws_sqs_queue.orders_dlq.id
  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.orders.arn]
  })
}

# --------- Alarm --------------
resource "aws_sns_topic" "orders_dlq_alerts" {
  name              = "${var.project}-orders-dlq-alerts"
  kms_master_key_id = "alias/aws/sns"
}

resource "aws_sns_topic_subscription" "orders_dlq_alerts_email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.orders_dlq_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "dlq_not_empty" {
  alarm_name          = "${var.project}-orders-dlq-not-empty"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  dimensions          = { QueueName = aws_sqs_queue.orders_dlq.name }
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  alarm_description   = "One or more orders landed in the DLQ - investigate before they age out at 14 days"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.orders_dlq_alerts.arn]
  ok_actions          = [aws_sns_topic.orders_dlq_alerts.arn]
}

# ----- Consumer Lambda -------
resource "aws_iam_role" "order_consumer_exec" {
  name = "${var.project}-order-consumer-exec"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.comn" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "order_consumer_exec" {
  name = "${var.project}-order-consumer-exec-policy"
  role = aws_iam_role.order_consumer_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "WriteOrders"
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem"]
        Resource = var.orders_table_arn
      },
      {
        Sid      = "ConsumeQueue"
        Effect   = "Allow"
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
        Resource = aws_sqs_queue.orders.arn
      },
      {
        Sid      = "Logs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${var.region}:${var.account_id}:log-group:/aws/lambda/${var.project}-order-consumer"
      }
    ]
  })
}

resource "aws_lambda_function" "order_consumer" {
  function_name    = "${var.project}-order-consumer"
  role             = aws_iam_role.order_consumer_exec.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.order_consumer.output_path
  source_code_hash = data.archive_file.order_consumer.output_base64sha256
  timeout          = 15

  environment {
    variables = {
      ORDERS_TABLE_NAME = var.orders_table_name
    }
  }
  
  tracing_config {
    mode = "Active"
  }

  reserved_concurrent_executions = 5
}

resource "aws_lambda_event_source_mapping" "orders" {
  event_source_arn = aws_sqs_queue.orders.arn
  function_name    = aws_lambda_function.order_consumer.arn
  batch_size       = 10
}


