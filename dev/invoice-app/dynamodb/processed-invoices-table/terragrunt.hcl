terraform {
  source = "${dirname(find_in_parent_folders())}/modules/dynamodb"
}

include "terragrunt_config" {
  path = find_in_parent_folders("terragrunt.hcl")
}

include "common_vars" {
  path = find_in_parent_folders("common_vars.hcl")
}

locals {
  common_vars = read_terragrunt_config(find_in_parent_folders("common_vars.hcl"))
  environment = local.common_vars.locals.environment
  tags        = local.common_vars.locals.tags
}

inputs = {
  table_name     = "processed-invoices-${local.environment}"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "InvoiceID"
  tags           = local.tags
  stream_enabled   = false
  create_gsi = false
}
