variable "table_name" {
  description = "The name of the DynamoDB table."
  type        = string
  validation {
    condition     = length(var.table_name) > 0
    error_message = "Table name must not be empty."
  }
}

variable "read_capacity" {
  description = "The read capacity for the DynamoDB table."
  type        = number
  default     = 5
  validation {
    condition     = var.read_capacity > 0
    error_message = "Read capacity must be a positive number."
  }
}

variable "write_capacity" {
  description = "The write capacity for the DynamoDB table."
  type        = number
  default     = 5
  validation {
    condition     = var.write_capacity > 0
    error_message = "Write capacity must be a positive number."
  }
}

variable "hash_key" {
  description = "The hash key for the DynamoDB table."
  type        = string
  validation {
    condition     = length(var.hash_key) > 0
    error_message = "Hash key must not be empty."
  }
}

variable "range_key" {
  description = "The range key for the DynamoDB table"
  type        = string
  default     = null
}

variable "read_max_capacity" {
  description = "The maximum read capacity for autoscaling."
  type        = number
  default     = 20
}

variable "read_min_capacity" {
  description = "The minimum read capacity for autoscaling."
  type        = number
  default     = 5
}

variable "write_max_capacity" {
  description = "The maximum write capacity for autoscaling."
  type        = number
  default     = 20
}

variable "write_min_capacity" {
  description = "The minimum write capacity for autoscaling."
  type        = number
  default     = 5
}

variable "target_value" {
  description = "The target value for autoscaling."
  type        = number
  default     = 70
  validation {
    condition     = var.target_value > 0 && var.target_value <= 100
    error_message = "Target value must be between 0 and 100."
  }
}

variable "environment" {
  description = "Environment tag."
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Tags to apply to resources created"
  type        = map(string)
  default     = {}
}

variable "stream_enabled" {
  description = "Determines if the stream is enabled or not on the DynamoDB table."
  default     = false
  type        = bool
}

variable "stream_view_type" {
  description = "Determines how the stream is viewed. Valid values are KEYS_ONLY, NEW_IMAGE, OLD_IMAGE, NEW_AND_OLD_IMAGES."
  default     = "NEW_IMAGE"
  type        = string
  validation {
    condition     = var.stream_view_type == "KEYS_ONLY" || var.stream_view_type == "NEW_IMAGE" || var.stream_view_type == "OLD_IMAGE" || var.stream_view_type == "NEW_AND_OLD_IMAGES"
    error_message = "Invalid stream view type. Allowed values are KEYS_ONLY, NEW_IMAGE, OLD_IMAGE, NEW_AND_OLD_IMAGES."
  }
}

variable "create_gsi" {
  description = "Boolean to determine if a GSI should be created"
  type        = bool
  default = false
}

variable "hash_key_type" {
  description = "The data type of the hash key. Valid values are S (string), N (number), or B (binary)."
  type        = string
  default     = "S"
  validation {
    condition     = var.hash_key_type == "S" || var.hash_key_type == "N" || var.hash_key_type == "B"
    error_message = "Invalid hash key type. Allowed values are S, N, B."
  }
}

variable "range_key_type" {
  description = "The data type of the range key if it's used. Valid values are S (string), N (number), or B (binary)."
  type        = string
  default     = "S"
  validation {
    condition     = var.range_key_type == "S" || var.range_key_type == "N" || var.range_key_type == "B"
    error_message = "Invalid range key type. Allowed values are S, N, B."
  }
}
