output "s3_bucket_arn" {
  description = "The ARN of the S3 bucket"
  value       = aws_s3_bucket.this.arn
}

output "s3_bucket_name" {
  description = "The ARN of the S3 bucket"
  value       = aws_s3_bucket.this.bucket
}