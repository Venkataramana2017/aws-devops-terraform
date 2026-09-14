output "bucket_name" {
  value = aws_s3_bucket.this.id
}

output "bucket_arn" {
  value = aws_s3_bucket.this.arn
}

output "region" {
  value = var.aws_region
}

output "environment_state_keys" {
  value = { for target in ["dev", "test", "pre", "prod"] : target => "aws-devops/${target}/terraform.tfstate" }
}
