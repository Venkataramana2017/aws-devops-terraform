variable "aws_region" {
  description = "Region for the dedicated Terraform state bucket."
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Terraform state bucket name used by the environment backends."
  type        = string
  default     = "bucket-backend-terraform-313932316713-us-east-1"
}
