variable "project" {
  type = string
}

variable "region" {
  type = string
}

variable "account_id" {
  type = string
}

variable "orders_table_name" {
  type = string
}

variable "orders_table_arn" {
  type = string
}

variable "src_dir" {
  description = "Path to the order_consmer Lambda source directory"
  type        = string
}

variable "alert_email" {
  description = "Email to notify when the orders DLQ alarm fires."
  type        = string
  default     = ""
} 
