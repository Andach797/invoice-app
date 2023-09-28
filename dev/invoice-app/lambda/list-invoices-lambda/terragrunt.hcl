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

locals {
  common_vars = read_terragrunt_config(find_in_parent_folders("common_vars.hcl"))
  environment = local.common_vars.locals.environment
  tags        = local.common_vars.locals.tags
  function_name = "list-invoices-function-${local.environment}"
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
  global_secondary_index_name = dependency.dynamodb.outputs.global_secondary_index_name,
  global_secondary_index_hash_key = dependency.dynamodb.outputs.global_secondary_index_hash_key }
  enable_cloudwatch_logs = local.enable_cloudwatch_logs
  tags = local.tags
  inline_policies = {
    "DynamoDBWriteOnlyPolicy" = jsonencode({
      Version = "2012-10-17",
      Statement = [
        {
          Action = [
            "dynamodb:Query"
          ],
          Effect = "Allow",
          Resource = [
            "arn:aws:dynamodb:${local.region}:${local.account_id}:table/${dependency.dynamodb.outputs.dynamodb_table_name}",
            "arn:aws:dynamodb:${local.region}:${local.account_id}:table/${dependency.dynamodb.outputs.dynamodb_table_name}/index/${dependency.dynamodb.outputs.global_secondary_index_name}"
          ]
        }
      ]
    })
  }
}
