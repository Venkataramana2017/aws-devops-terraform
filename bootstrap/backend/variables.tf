variable "aws_region" {
  description = "Region for the dedicated Terraform state bucket."
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Optional unique bucket name; default includes the authenticated AWS account ID and region."
  type        = string
  default     = null
}
