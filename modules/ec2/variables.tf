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
variable "subnet_id" {
  description = "Subnet for the instance."
  type        = string
}
variable "associate_public_ip_address" {
  description = "Assign a public IP; requires a public subnet for internet connectivity."
  type        = bool
  default     = false
}
