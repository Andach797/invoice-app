output "dynamodb_table_arn" {
  value = aws_dynamodb_table.this.arn
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.this.name
}

output "global_secondary_index_name" {
  description = "The name of the global secondary index"
  value       = var.range_key != null ? "${var.range_key}-Index" : null
}

output "global_secondary_index_hash_key" {
  description = "The hash key of the Global Secondary Index"
  value       = var.range_key != null ? var.range_key  : null
}

output "dynamodb_table_stream_arn" {
  description = "The ARN of the DynamoDB Stream associated with the table"
  value       = aws_dynamodb_table.this.stream_arn
}