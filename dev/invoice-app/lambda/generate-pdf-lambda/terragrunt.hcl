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

dependency "dynamodb_invoice_table" {
  config_path = "../../dynamodb/invoices-table"
}

locals {
  common_vars = read_terragrunt_config(find_in_parent_folders("common_vars.hcl"))
  environment = local.common_vars.locals.environment
  tags        = local.common_vars.locals.tags
  function_name = "generate-pdf-function-${local.environment}"
  account_id     = run_cmd("aws", "sts", "get-caller-identity", "--query", "Account", "--output", "text")
  region         = run_cmd("aws", "configure", "get", "region")
  s3_key         = "${local.environment}/${local.function_name}.zip"
  enable_cloudwatch_logs = true

}

inputs = {
  function_name         = local.function_name
  handler               = "main"
  runtime               = "go1.x"
  enable_dynamodb_trigger   = true
  dynamodb_table_stream_arn = dependency.dynamodb_invoice_table.outputs.dynamodb_table_stream_arn
  s3_bucket             = dependency.s3_artifacts.outputs.s3_bucket_name
  s3_key                = local.s3_key
  enable_cloudwatch_logs = local.enable_cloudwatch_logs

  environment_variables = {
    INVOICE_DYNAMODB_TABLE = dependency.dynamodb_invoice_table.outputs.dynamodb_table_name,
    S3_BUCKET  = dependency.s3_pdf.outputs.s3_bucket_name,
    PDF_DYNAMODB_TABLE = dependency.dynamodb_pdf_table.outputs.dynamodb_table_name
  }
  inline_policies = {
    "DynamoDBStreamReadOnlyPolicy" = jsonencode({
      Version = "2012-10-17",
      Statement = [
        {
          Action = [
            "dynamodb:GetRecords",
            "dynamodb:GetShardIterator",
            "dynamodb:DescribeStream",
            "dynamodb:ListStreams"
          ],
          Effect   = "Allow",
          Resource = dependency.dynamodb_invoice_table.outputs.dynamodb_table_stream_arn
        }
      ]
    }),
    "S3PdfBucketWritePolicy" = jsonencode({
      Version = "2012-10-17",
      Statement = [
        {
          Action = [
            "s3:PutObject",
            "s3:PutObjectAcl"
          ],
          Effect   = "Allow",
          Resource = "arn:aws:s3:::${dependency.s3_pdf.outputs.s3_bucket_name}/*"
        }
      ]
    }),
    "DynamoDBProcessedInvoiceWritePolicy" = jsonencode({
        Version = "2012-10-17",
        Statement = [
          {
            Action = [
              "dynamodb:PutItem",
              "dynamodb:UpdateItem"
            ],
            Effect   = "Allow",
            Resource = dependency.dynamodb_pdf_table.outputs.dynamodb_table_arn
    }
  ]
})
  }
}
