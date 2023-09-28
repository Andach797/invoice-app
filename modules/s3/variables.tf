variable "bucket_name" {
  description = "The name of the bucket"
  type        = string

  validation {
    condition     = length(var.bucket_name) > 2 && length(var.bucket_name) < 64
    error_message = "The bucket name must be between 3 and 63 characters."
  }
}

variable "bucket_acl" {
  description = "The access control list of the bucket"
  type        = string
  default     = "private"

  validation {
    condition     = contains(["private", "public-read", "public-read-write", "authenticated-read", "log-delivery-write", "aws-exec-read", "bucket-owner-read", "bucket-owner-full-control"], var.bucket_acl)
    error_message = "Invalid ACL type. Must be one of: private, public-read, public-read-write, authenticated-read, log-delivery-write, aws-exec-read, bucket-owner-read, bucket-owner-full-control."
  }
}


variable "versioning" {
  description = "Map containing versioning configuration"
  type        = string
  default     = "Enabled"

  validation {
    condition     = contains(["Enabled", "Disabled"], var.versioning)
    error_message = "Versioning must be 'Enabled' or 'Disabled'."
  }
}

variable "tags" {
  description = "Tags to attach to the bucket"
  type        = map(string)
  default     = {}
}
