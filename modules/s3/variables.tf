variable "bucket_name" {
  description = "Globally unique S3 bucket name."
  type        = string
}
variable "force_destroy" {
  description = "Allow deletion of a nonempty bucket."
  type        = bool
  default     = false
}
variable "versioning_enabled" {
  description = "Enable object versioning."
  type        = bool
  default     = true
}
variable "kms_key_arn" {
  description = "Optional customer managed KMS key ARN."
  type        = string
  default     = null
}
variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}
