output "api_id" {
  description = "The API Gateway REST API ID"
  value       = aws_api_gateway_rest_api.api_gateway.id
}

output "api_execution_url" {
  description = "The API Gateway REST API execution ARN"
  value       = aws_api_gateway_rest_api.api_gateway.execution_arn
}
output "lambda_uris" {
  description = "URIs for the Lambda integrations"
  value       = { for key, value in aws_api_gateway_integration.lambda_integration : key => value.uri }
}