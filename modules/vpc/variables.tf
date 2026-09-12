variable "name" {
  description = "Network name prefix."
  type        = string
}
variable "cidr_block" {
  description = "VPC IPv4 CIDR."
  type        = string
  validation {
    condition     = can(cidrnetmask(var.cidr_block))
    error_message = "Provide a valid IPv4 CIDR."
  }
}
variable "subnets" {
  description = "Stable keys mapping to an AZ and a public/private subnet pair; CIDRs must be disjoint and inside the VPC."
  type = map(object({
    availability_zone = string
    public_cidr       = string
    private_cidr      = string
  }))
  validation {
    condition     = length(var.subnets) > 0 && alltrue([for s in var.subnets : can(cidrnetmask(s.public_cidr)) && can(cidrnetmask(s.private_cidr))])
    error_message = "Supply at least one subnet pair with valid IPv4 CIDRs."
  }
}
variable "enable_nat_gateway" {
  description = "Create NAT gateways for private internet egress; incurs AWS charges."
  type        = bool
  default     = false
}
variable "single_nat_gateway" {
  description = "Share one NAT gateway; false creates one per subnet pair."
  type        = bool
  default     = false
}
variable "enable_s3_endpoint" {
  description = "Create a gateway endpoint for regional S3 access."
  type        = bool
  default     = true
}
variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}
