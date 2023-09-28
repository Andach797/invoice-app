terraform {
  source = "${dirname(find_in_parent_folders())}/modules/lambda"

# Hooks for building, zipping, and uploading Go code to S3
before_hook "chmod_script" {
  commands     = ["apply", "plan"]
  execute      = ["chmod", "+x", "../../../../scripts/build-script.sh"]
  run_on_error = false
}

before_hook "execute_before_hooks" {
  commands     = ["apply", "plan"]
  execute      = ["../../../../scripts/build-script.sh", "${local.function_name}", "${dependency.s3.outputs.s3_bucket_name}", "${local.s3_key}"]
  run_on_error = false
}


after_hook "delete_terragrunt_cache" {
  commands = ["destroy"]
  execute  = ["sh", "-c", "find .. -maxdepth 4 -name '.terragrunt-cache' -type d -exec rm -rf {} +"]
}

after_hook "delete_s3_artifact" {
  commands = ["destroy"]
  execute  = ["sh", "-c", "aws s3 rm s3://${dependency.s3.outputs.s3_bucket_name}/${local.s3_key}"]
}

# Checks dynamodb for mock items. If mock item doesn't exist, it will insert data by invoking the lambda function
after_hook "invoke_lambda_if_no_mock_data" {
  commands = ["apply"]
  execute = ["sh", "-c", "if ! aws dynamodb get-item --table-name ${dependency.dynamodb.outputs.dynamodb_table_name} --key '{\"InvoiceID\": {\"S\": \"INV81\"}}' | grep -q 'InvoiceID'; then aws lambda invoke --function-name ${local.function_name} /dev/null; fi"]
}
}

include "terragrunt_config" {
  path = find_in_parent_folders("terragrunt.hcl")
}

include "common_vars" {
  path = find_in_parent_folders("common_vars.hcl")
}

dependency "s3" {
  config_path = "../../s3/artifacts-bucket"
}

dependency "dynamodb" {
  config_path = "../../dynamodb/invoices-table"
}
# This dependency added so this lambda can be run last to create mock data and test flow.
dependency "api_gateway" {
  config_path = "../../api-gateway/invoice-api-gateway"
}

locals {
  common_vars = read_terragrunt_config(find_in_parent_folders("common_vars.hcl"))
  environment = local.common_vars.locals.environment
  tags        = local.common_vars.locals.tags
  function_name = "insert-mock-function-${local.environment}"
  account_id     = run_cmd("aws", "sts", "get-caller-identity", "--query", "Account", "--output", "text")
  region         = run_cmd("aws", "configure", "get", "region")
  s3_key         = "${local.environment}/${local.function_name}.zip"
  enable_cloudwatch_logs = true

}

inputs = {
  function_name         = local.function_name
  handler               = "main"
  runtime               = "go1.x"
  s3_bucket             = dependency.s3.outputs.s3_bucket_name
  s3_key                = local.s3_key
  environment_variables = { dynamodb_table_name = dependency.dynamodb.outputs.dynamodb_table_name,
  s3_bucket_name = dependency.s3.outputs.s3_bucket_name }
  enable_cloudwatch_logs = local.enable_cloudwatch_logs
  tags = local.tags
  inline_policies = {
    "DynamoDBWriteOnlyPolicy" = jsonencode({
      Version = "2012-10-17",
      Statement = [
        {
          Action = [
            "dynamodb:PutItem"
          ],
          Effect = "Allow",
          Resource = "arn:aws:dynamodb:${local.region}:${local.account_id}:table/${dependency.dynamodb.outputs.dynamodb_table_name}"
        }
      ]
    })
  }
}
