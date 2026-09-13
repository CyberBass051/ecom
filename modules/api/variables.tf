variable "project" {
  type = string
}

variable "region" {
  type = string
}

variable "account_id" {
  type = string
}

variable "table_name" {
  type = string
}

variable "table_arn" {
  type = string
}

variable "src_dir" {
  description = "Path to the get_products Lambda source directory"
  type        = string
}


