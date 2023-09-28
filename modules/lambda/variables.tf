variable "function_name" {
  description = "The name of the lambda function"
  type        = string
  validation {
    condition     = length(var.function_name) > 0
    error_message = "The function name must not be empty."
  }
}

variable "handler" {
  description = "The handler for the lambda function"
  type        = string
  validation {
    condition     = length(var.handler) > 0
    error_message = "The handler must not be empty."
  }
}

variable "runtime" {
  description = "The runtime for the lambda function"
  type        = string
  validation {
    condition     = can(regex("^python|nodejs|ruby|java|go|dotnet|custom$", var.runtime))
    error_message = "The provided runtime is not valid."
  }
}

variable "s3_bucket" {
  description = "The S3 bucket where the lambda function code is stored"
  type        = string
  validation {
    condition     = length(var.s3_bucket) > 0
    error_message = "The S3 bucket name must not be empty."
  }
}

variable "s3_key" {
  description = "The S3 key where the lambda function code is stored"
  type        = string
  validation {
    condition     = length(var.s3_key) > 0
    error_message = "The S3 key must not be empty."
  }
}

variable "environment_variables" {
  description = "Environment variables to set for the lambda function"
  type        = map(string)
  default     = {}
}

variable "inline_policies" {
  description = "Inline IAM policies to attach to the IAM role for the lambda function"
  type        = map(string)
  default     = {}
}

variable "enable_dynamodb_trigger" {
  description = "Flag to enable DynamoDB Stream trigger for Lambda"
  type        = bool
  default     = false
}

variable "dynamodb_table_stream_arn" {
  description = "The ARN of the DynamoDB table stream."
  type        = string
  default     = ""

}

variable "enable_cloudwatch_logs" {
  description = "Flag to enable CloudWatch logs for the Lambda function"
  type        = bool
  default     = false
}

variable "alias_name" {
  description = "The alias name for the Lambda function version"
  type        = string
  default     = "latest"
}

variable "memory_size" {
  description = "Memory allocation for the Lambda function (in MB)"
  type        = number
  default     = 256
  validation {
    condition     = var.memory_size > 0 && var.memory_size <= 3008 && var.memory_size % 64 == 0
    error_message = "Memory size must be between 128 and 3008 inclusive and in multiples of 64."
  }
}

variable "timeout" {
  description = "Timeout for the Lambda function (in seconds)"
  type        = number
  default     = 10
  validation {
    condition     = var.timeout > 0 && var.timeout <= 900
    error_message = "Timeout must be between 1 and 900 seconds inclusive."
  }
}

variable "tags" {
  description = "Tags to attach to the bucket"
  type        = map(string)
  default     = {}
}
