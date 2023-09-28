data "aws_region" "current" {}

data "aws_caller_identity" "current" {}


resource "aws_lambda_function" "this" {
  function_name = var.function_name
  handler       = var.handler
  role          = aws_iam_role.iam_for_lambda.arn
  runtime       = var.runtime
  publish       = true
  s3_bucket     = var.s3_bucket
  s3_key        = var.s3_key
  memory_size   = var.memory_size  
  timeout       = var.timeout 
  environment {
    variables = var.environment_variables
  }
  tags          = var.tags
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "${var.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}
resource "aws_iam_role_policy" "inline_policies" {
  for_each = var.inline_policies

  name = each.key
  role = aws_iam_role.iam_for_lambda.name

  policy = each.value
}

resource "aws_lambda_event_source_mapping" "dynamodb_stream_mapping" {
  count              = var.enable_dynamodb_trigger ? 1 : 0
  event_source_arn   = var.dynamodb_table_stream_arn
  function_name      = aws_lambda_function.this.function_name
  starting_position  = "LATEST"
}

resource "aws_iam_policy" "lambda_cloudwatch_logs" {
  count       = var.enable_cloudwatch_logs ? 1 : 0
  name        = "${var.function_name}-LambdaCloudWatchLogsPolicy"
  description = "Allows ${var.function_name} Lambda function to write logs to CloudWatch Logs."

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "logs:CreateLogGroup",
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.function_name}:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_cloudwatch_logs_attach" {
  count      = var.enable_cloudwatch_logs ? 1 : 0
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_cloudwatch_logs[0].arn
}

resource "aws_lambda_alias" "prod_alias" {
  name             = var.alias_name
  function_name    = aws_lambda_function.this.function_name
  function_version = aws_lambda_function.this.version
}