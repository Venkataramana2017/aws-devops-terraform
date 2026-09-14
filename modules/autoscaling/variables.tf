variable "name" {
  description = "Resource name prefix."
  type        = string
}
variable "ami_id" {
  description = "Region-specific AMI compatible with the instance type."
  type        = string
}
variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.micro"
}
variable "security_group_ids" {
  description = "VPC security groups to attach."
  type        = list(string)
}
variable "key_name" {
  description = "Optional existing EC2 key pair name."
  type        = string
  default     = null
}
variable "iam_instance_profile" {
  description = "Optional existing IAM instance profile name."
  type        = string
  default     = null
}
variable "user_data" {
  description = "Plain-text boot script; do not put secrets here."
  type        = string
  default     = null
}
variable "root_volume_size" {
  description = "Encrypted gp3 root disk size in GiB; must accommodate the AMI."
  type        = number
  default     = 20
}
variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}
variable "root_device_name" {
  description = "Root device name from the AMI block device mapping."
  type        = string
  default     = "/dev/xvda"
}

variable "subnet_ids" {
  description = "Subnets across availability zones for the group."
  type        = list(string)
  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "At least one subnet is required."
  }
}
variable "capacity" {
  description = "Minimum, initial desired, and maximum instance counts."
  type        = object({ min = number, desired = number, max = number })
  default     = { min = 1, desired = 1, max = 3 }
  validation {
    condition     = var.capacity.min >= 0 && var.capacity.min <= var.capacity.desired && var.capacity.desired <= var.capacity.max && var.capacity.max > 0 && alltrue([for n in [var.capacity.min, var.capacity.desired, var.capacity.max] : floor(n) == n])
    error_message = "Capacity must contain integers satisfying 0 <= min <= desired <= max, with max > 0."
  }
}
variable "target_cpu_utilization" {
  description = "CPU percentage for target tracking scaling."
  type        = number
  default     = 60
  validation {
    condition     = var.target_cpu_utilization > 0 && var.target_cpu_utilization <= 100
    error_message = "CPU target must be above 0 and at most 100."
  }
}
variable "target_group_arns" {
  description = "Optional existing load balancer target groups."
  type        = list(string)
  default     = []
}
variable "health_check_type" {
  description = "EC2, or ELB when attached to a load balancer."
  type        = string
  default     = "EC2"
  validation {
    condition     = contains(["EC2", "ELB"], var.health_check_type)
    error_message = "Use EC2 or ELB."
  }
}
