output "queue_url" {
  value = aws_sqs_queue.orders.id
}

output "queue_arn" {
  value = aws_sqs_queue.orders.arn
}
