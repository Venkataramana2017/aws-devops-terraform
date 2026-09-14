provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

locals {
  bucket_name = var.bucket_name != null ? var.bucket_name : "aws-devops-tfstate-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
  tags = {
    Name      = "Terraform state backend"
    ManagedBy = "Terraform"
    Purpose   = "TerraformState"
  }
}
