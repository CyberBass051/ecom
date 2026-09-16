terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4"
    }
  }
  backend "s3" {}
}

provider "aws" {
  region = "us-east-1"
}


data "aws_caller_identity" "current" {}

locals {
  project = "ecom-project"
  region  = "us-east-1"
  owner   = "Pietro"
}

#trivy:ignore:AVD-AWS-0025
module "dynamodb" {
  source = "../../modules/dynamodb"

  project = local.project
  owner   = local.owner
}

module "orders_pipeline" {
  source = "../../modules/orders-pipeline"

  project           = local.project
  region            = local.region
  account_id        = data.aws_caller_identity.current.account_id
  orders_table_name = module.dynamodb.orders_table_name
  orders_table_arn  = module.dynamodb.orders_table_arn
  src_dir           = "${path.module}/../../src/order_consumer"
  alert_email       = "pietrocorp051@gmail.com"
}

module "api" {
  source = "../../modules/api"

  project                 = local.project
  region                  = local.region
  account_id              = data.aws_caller_identity.current.account_id
  products_table_name     = module.dynamodb.products_table_name
  products_table_arn      = module.dynamodb.products_table_arn
  orders_queue_url        = module.orders_pipeline.queue_url
  orders_queue_arn        = module.orders_pipeline.queue_arn
  get_products_src_dir    = "${path.module}/../../src/get_products"
  post_order_src_dir      = "${path.module}/../../src/post_order"
}

module "site" {
  source = "../../modules/cloudfront-site"

  project         = local.project
  api_domain_name = replace(module.api.api_endpoint, "https://", "")
  account_id      = data.aws_caller_identity.current.account_id
}

resource "aws_s3_object" "index" {
  bucket       = module.site.site_bucket
  key          = "index.html"
  source       = "${path.module}/../../site/index.html"
  etag         = filemd5("${path.module}/../../site/index.html")
  content_type = "text/html"
}

output "api_endpoint" {
  value = module.api.api_endpoint
}

output "products_url" {
  value = "${module.api.api_endpoint}/products"
}

output "orders_url" {
  value = "${module.api.api_endpoint}/orders"
}

output "site_url" {
  value = "https://${module.site.distribution_domain}"
}


