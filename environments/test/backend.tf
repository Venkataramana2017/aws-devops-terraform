terraform {
  backend "s3" {
    bucket       = "bucket-backend-terraform-313932316713-us-east-1"
    region       = "us-east-1"
    key          = "aws-devops/test/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}