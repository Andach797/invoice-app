terraform {
  source = "${dirname(find_in_parent_folders())}/modules/lambda"

# Hook for building, zipping, and uploading Go code to S3
before_hook "chmod_script" {
  commands     = ["apply", "plan"]
  execute      = ["chmod", "+x", "../../../../scripts/build-script.sh"]
  run_on_error = false
}

before_hook "execute_before_hooks" {
  commands     = ["apply", "plan"]
  execute      = ["../../../../scripts/build-script.sh", "${local.function_name}", "${dependency.s3_artifacts.outputs.s3_bucket_name}", "${local.s3_key}"]
  run_on_error = false
}

after_hook "delete_terragrunt_cache" {
  commands = ["destroy"]
  execute  = ["sh", "-c", "find .. -maxdepth 4 -name '.terragrunt-cache' -type d -exec rm -rf {} +"]
}

after_hook "delete_s3_artifact" {
  commands = ["destroy"]
  execute  = ["sh", "-c", "aws s3 rm s3://${dependency.s3_artifacts.outputs.s3_bucket_name}/${local.s3_key}"]
}
}

include "terragrunt_config" {
  path = find_in_parent_folders("terragrunt.hcl")
}

include "common_vars" {
  path = find_in_parent_folders("common_vars.hcl")
}

dependency "s3_artifacts" {
  config_path = "../../s3/artifacts-bucket"
}

dependency "s3_pdf" {
  config_path = "../../s3/pdf-bucket"
}

dependency "dynamodb_pdf_table" {
  config_path = "../../dynamodb/processed-invoices-table"
}

locals {
  common_vars = read_terragrunt_config(find_in_parent_folders("common_vars.hcl"))
  environment = local.common_vars.locals.environment
  tags        = local.common_vars.locals.tags
  function_name = "download-pdf-function-${local.environment}"
  account_id     = run_cmd("aws", "sts", "get-caller-identity", "--query", "Account", "--output", "text")
  region         = run_cmd("aws", "configure", "get", "region")
  s3_key         = "${local.environment}/${local.function_name}.zip"
  enable_cloudwatch_logs = true
  
}

inputs = {
  function_name         = local.function_name
  handler               = "main"
  runtime               = "go1.x"
  enable_dynamodb_trigger   = false
  s3_bucket             = dependency.s3_artifacts.outputs.s3_bucket_name
  s3_key                = local.s3_key
  enable_cloudwatch_logs = local.enable_cloudwatch_logs
  tags = local.tags
  environment_variables = {
    S3_BUCKET_NAME  = dependency.s3_pdf.outputs.s3_bucket_name,
    DYNAMODB_TABLE_NAME = dependency.dynamodb_pdf_table.outputs.dynamodb_table_name
  }
  inline_policies = {
    "S3PdfBucketReadPolicy" = jsonencode({
      Version = "2012-10-17",
      Statement = [
        {
          Action = "s3:GetObject",
          Effect = "Allow",
          Resource = "${dependency.s3_pdf.outputs.s3_bucket_arn}/*"
        }
      ]
    }),
    "DynamoDBReadPolicy" = jsonencode({
      Version = "2012-10-17",
      Statement = [
        {
          Action = "dynamodb:GetItem",
          Effect = "Allow",
          Resource = dependency.dynamodb_pdf_table.outputs.dynamodb_table_arn
        }
      ]
    })
  }
}