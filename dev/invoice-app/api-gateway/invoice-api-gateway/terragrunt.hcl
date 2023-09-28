terraform {
  source = "${dirname(find_in_parent_folders())}/modules/api-gateway"
}

dependency "list_invoices_lambda" {
  config_path = "../../lambda/list-invoices-lambda"
}

dependency "insert_invoice_lambda" {
  config_path = "../../lambda/insert-invoice-lambda"
}

dependency "download_pdf_lambda" {
  config_path = "../../lambda/download-pdf-lambda"
}

locals {
  common_vars     = read_terragrunt_config(find_in_parent_folders("common_vars.hcl"))
  environment     = local.common_vars.locals.environment
  tags            = local.common_vars.locals.tags
  api_name        = "invoice-api-gateway-${local.environment}"
  api_description = "Invoice api for ${local.environment}"
}

inputs = {
  api_name        = local.api_name
  api_description = local.api_description
  endpoint_types  = ["EDGE"]
  # Used for creating parametric lambda integrations
  lambda_arn_map  = merge(
    jsondecode("{ \"${dependency.list_invoices_lambda.outputs.lambda_name}\": \"${dependency.list_invoices_lambda.outputs.lambda_arn}\" }"),
    jsondecode("{ \"${dependency.insert_invoice_lambda.outputs.lambda_name}\": \"${dependency.insert_invoice_lambda.outputs.lambda_arn}\" }"),
    jsondecode("{ \"${dependency.download_pdf_lambda.outputs.lambda_name}\": \"${dependency.download_pdf_lambda.outputs.lambda_arn}\" }")
  )

  api_details = [
    {
      lambda_name  = dependency.list_invoices_lambda.outputs.lambda_name
      http_method  = "GET"
      path_part    = "list-invoices"  
    },
    {
      lambda_name  = dependency.insert_invoice_lambda.outputs.lambda_name
      http_method  = "POST"
      path_part    = "insert-invoice"
    },
    {
      lambda_name  = dependency.download_pdf_lambda.outputs.lambda_name
      http_method  = "GET"
      path_part    = "download-invoice"
    }
  ]

  stage_name             = "v1"
  api_key_name           = "${local.api_name}-api-key"
  api_key_description    = "API key for ${local.api_name}"
  usage_plan_name        = "${local.api_name}-usage-plan"
  usage_plan_description = "Usage plan for ${local.api_name}"
}
