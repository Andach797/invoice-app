terraform {
  source = "${dirname(find_in_parent_folders())}/modules/s3"

  before_hook "before_destroy_delete_objects" {
  commands = ["destroy"]
  execute  = ["sh", "../../../../scripts/delete-all-files-and-versions.sh", "${local.region}", "${local.bucket_name}"]
}
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
  bucket_name = "andac-bucket-for-pdf-${local.environment}"
  region         = run_cmd("aws", "configure", "get", "region")
  versioning  = "Enabled"
}

inputs = {
  bucket_name       = local.bucket_name
  tags              = local.tags
  versioning        = local.versioning
}
