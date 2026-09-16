variable "project" {
  type = string
}

variable "region" {
  type = string
}

variable "account_id" {
  type = string
}

variable "products_table_name" {
  type = string
}

variable "products_table_arn" {
  type = string
}

variable "orders_queue_url" {
  type = string
}

variable "orders_queue_arn" {
  type = string
}

variable "get_products_src_dir" {
  description = "Path to the get_products Lambda source directory"
  type        = string
}

variable "post_order_src_dir" {
  type = string
}


