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
  table_name     = "invoices-table-${local.environment}"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "InvoiceID"
  range_key      = "CustomerID"
  tags           = local.tags
  stream_enabled   = true
  stream_view_type = "NEW_IMAGE"
  create_gsi = true
}
