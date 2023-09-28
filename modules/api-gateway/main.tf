data "aws_region" "current" {}

locals {
  api_details_map = { for api in var.api_details : api.lambda_name => api }
}

resource "aws_api_gateway_rest_api" "api_gateway" {
  name        = var.api_name
  description = var.api_description
  endpoint_configuration {
    types = var.endpoint_types
  }
}

resource "aws_api_gateway_resource" "api_resource" {
  for_each    = local.api_details_map
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_rest_api.api_gateway.root_resource_id
  path_part   = each.value.path_part
}

resource "aws_api_gateway_method" "api_method" {
  for_each      = local.api_details_map
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.api_resource[each.key].id
  http_method   = each.value.http_method
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  for_each      = local.api_details_map
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.api_resource[each.key].id
  http_method   = aws_api_gateway_method.api_method[each.key].http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:lambda:path/2015-03-31/functions/${var.lambda_arn_map[each.key]}/invocations"
}

resource "aws_lambda_permission" "api_gateway_lambda_permission" {
  for_each      = local.api_details_map
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = each.value.lambda_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.api_gateway.execution_arn}/*/${aws_api_gateway_method.api_method[each.key].http_method}${aws_api_gateway_resource.api_resource[each.key].path}"
}

resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on  = [aws_api_gateway_integration.lambda_integration]
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id

  triggers = {
    redeployment = sha256(jsonencode(aws_api_gateway_rest_api.api_gateway.body))
  }

  lifecycle {
    ignore_changes = [
      stage_name,
    ]
  }
}

resource "aws_api_gateway_stage" "api_stage" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  stage_name    = var.stage_name

  lifecycle {
    ignore_changes = [
      deployment_id,
    ]
  }

  dynamic "access_log_settings" {
    for_each = var.enable_logging ? [1] : []
    content {
      destination_arn = aws_cloudwatch_log_group.api_gateway_logs[0].arn
      format = "$context.identity.sourceIp - - [$context.requestTime] \"$context.httpMethod $context.resourcePath $context.protocol\" $context.status $context.responseLength $context.requestId"
    }
  }
}

resource "aws_api_gateway_api_key" "api_key" {
  name        = var.api_key_name
  description = var.api_key_description
  enabled     = true
}

resource "aws_api_gateway_usage_plan" "usage_plan" {
  name        = var.usage_plan_name
  description = var.usage_plan_description
  api_stages {
    api_id = aws_api_gateway_rest_api.api_gateway.id
    stage  = aws_api_gateway_stage.api_stage.stage_name
  }
}

resource "aws_api_gateway_usage_plan_key" "usage_plan_key" {
  key_id        = aws_api_gateway_api_key.api_key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.usage_plan.id
}

resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  count = var.enable_logging ? 1 : 0 
  name = "/aws/apigateway/${var.api_name}"

  tags = {
    Name = "${var.api_name} API Gateway Logs"
  }
  retention_in_days = 14
}

