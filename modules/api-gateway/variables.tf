variable "api_name" {
  description = "The name of the REST API"
  type        = string
  validation {
    condition     = length(var.api_name) > 0 && length(var.api_name) <= 128
    error_message = "The api_name must be between 1 and 128 characters."
  }
}

variable "api_description" {
  description = "The description of the REST API"
  type        = string
  default     = ""
  validation {
    condition     = length(var.api_description) <= 256
    error_message = "The api_description can be up to 256 characters."
  }
}

variable "endpoint_types" {
  description = "The endpoint types of the API Gateway"
  type        = list(string)
  default     = ["EDGE"]
  validation {
    condition     = alltrue([for type in var.endpoint_types : contains(["EDGE", "REGIONAL", "PRIVATE"], type)])
    error_message = "The endpoint_types can only contain EDGE, REGIONAL, or PRIVATE."
  }
}

variable "api_details" {
  description = "Details for the API endpoints"
  type = list(object({
    lambda_name  = string
    http_method  = string
    path_part    = string
  }))
  validation {
condition     = alltrue([for detail in var.api_details : contains(["GET", "POST", "PUT", "DELETE", "PATCH"], detail.http_method)])
    error_message = "The http_method can only be one of the standard HTTP methods."
  }
}

variable "lambda_arn_map" {
  description = "Map of Lambda function ARNs keyed by Lambda function name"
  type        = map(string)
  default     = {}
}

variable "stage_name" {
  description = "Name of the stage for API Gateway deployment."
  type        = string
}

variable "api_key_name" {
  description = "Name of the API key for the API Gateway."
  type        = string
}

variable "api_key_description" {
  description = "Description of the API key for the API Gateway."
  type        = string
  default     = ""
}

variable "usage_plan_name" {
  description = "Name of the usage plan for the API Gateway."
  type        = string
}

variable "usage_plan_description" {
  description = "Description of the usage plan for the API Gateway."
  type        = string
  default     = ""
}

variable "enable_logging" {
  description = "Enable API Gateway logging to CloudWatch Logs"
  type        = bool
  default     = true
}

