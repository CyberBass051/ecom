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

module "api" {
  source = "../../modules/api"

  project    = local.project
  region     = local.region
  account_id = data.aws_caller_identity.current.account_id
  table_name = module.dynamodb.table_name
  table_arn  = module.dynamodb.table_arn
  src_dir    = "${path.module}/../../src/get_products"
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

output "site_url" {
  value = "https://${module.site.distribution_domain}"
}


