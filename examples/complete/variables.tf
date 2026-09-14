variable "aws_region" {
  description = "AWS region with at least two available AZs."
  type        = string
  default     = "us-east-1"
}
variable "name" {
  description = "Resource name prefix."
  type        = string
  default     = "devops-demo"
}
variable "environment" {
  description = "Environment tag."
  type        = string
  default     = "dev"
}
variable "ami_id" {
  description = "Optional pinned Amazon Linux compatible x86_64 AMI; otherwise use latest AL2023."
  type        = string
  default     = null
}
variable "enable_nat_gateway" {
  description = "Enable charged private internet egress."
  type        = bool
  default     = false
}
variable "single_nat_gateway" {
  description = "Use one shared NAT instead of one per AZ when enabled."
  type        = bool
  default     = false
}
variable "iam_instance_profile" {
  description = "Existing instance profile, for example one granting SSM access."
  type        = string
  default     = null
}
variable "capacity" {
  description = "Auto Scaling capacity, in addition to the standalone EC2 instance."
  type        = object({ min = number, desired = number, max = number })
  default     = { min = 1, desired = 1, max = 3 }
}
