terraform {
  backend "s3" {
    key          = "aws-devops/prod/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
    # Supply bucket and region with -backend-config during terraform init.
  }
}