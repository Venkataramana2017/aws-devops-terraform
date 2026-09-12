variable "aws_region" {
  description = "AWS region with at least two available AZs."
  type        = string
  default     = "us-east-1"
}
variable "name" {
  description = "Resource name prefix."
  type        = string
  default     = "devops-pre"
}
variable "environment" {
  description = "Environment tag."
  type        = string
  default     = "pre"
}
variable "bucket_name" {
  description = "Unique name for a NEW bucket, distinct from the existing root deployment."
  type        = string
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
  default     = { min = 2, desired = 2, max = 4 }
}

variable "vpc_cidr" {
  description = "Environment VPC IPv4 /16; subnet /24s are derived automatically."
  type        = string
  default     = "10.50.0.0/16"
  validation {
    condition     = can(cidrnetmask(var.vpc_cidr)) && can(regex("/16$", var.vpc_cidr))
    error_message = "Supply a valid IPv4 /16 CIDR."
  }
}
variable "instance_type" {
  description = "Instance type for standalone and Auto Scaling compute; match the AMI architecture."
  type        = string
  default     = "t3.micro"
}