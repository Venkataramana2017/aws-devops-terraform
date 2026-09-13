terraform {
  backend "s3" {
    key          = "aws-devops/pre/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
    # Supply bucket and region with -backend-config during terraform init.
  }
}