variable "name" {
  description = "Security group name prefix."
  type        = string
}
variable "description" {
  description = "Security group description."
  type        = string
  default     = "Managed by Terraform"
}
variable "vpc_id" {
  description = "VPC containing this security group."
  type        = string
}
variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}
variable "ingress_rules" {
  description = "Named rules. Specify exactly one IPv4 CIDR or peer security group per rule. Empty denies all traffic in this direction."
  type = map(object({
    description              = optional(string)
    ip_protocol              = optional(string, "tcp")
    from_port                = optional(number)
    to_port                  = optional(number)
    cidr_ipv4                = optional(string)
    source_security_group_id = optional(string)
  }))
  default = {}
  validation {
    condition = alltrue([for r in var.ingress_rules :
      (r.cidr_ipv4 != null) != (r.source_security_group_id != null)
    ])
    error_message = "Each rule needs exactly one CIDR or security group ID."
  }
}
variable "egress_rules" {
  description = "Named rules. Specify exactly one IPv4 CIDR or peer security group per rule. Empty denies all traffic in this direction."
  type = map(object({
    description              = optional(string)
    ip_protocol              = optional(string, "tcp")
    from_port                = optional(number)
    to_port                  = optional(number)
    cidr_ipv4                = optional(string)
    source_security_group_id = optional(string)
  }))
  default = {}
  validation {
    condition = alltrue([for r in var.egress_rules :
      (r.cidr_ipv4 != null) != (r.source_security_group_id != null)
    ])
    error_message = "Each rule needs exactly one CIDR or security group ID."
  }
}
