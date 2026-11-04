variable "preview_id" {
  type        = string
  description = "Preview name, e.g. pr-42"
  validation {
    condition     = can(regex("^[a-z0-9-]{1,28}$", var.preview_id))
    error_message = "preview_id must be lowercase alphanumerics and dashes, max 28 chars."
  }
}
variable "port" {
  type        = number
  default     = 0
  description = "Override the ALB port (0 = derive from preview_id)"
}
variable "ttl_hours" {
  type    = number
  default = 24
}
variable "created_at" {
  type        = string
  description = "RFC3339 creation time (pass <+pipeline.startTs> formatted, or timestamp())"
  default     = "2026-01-01T00:00:00Z"
}
variable "base_name" {
  type    = string
  default = "jpmc-eventcatalog"
}
variable "region" {
  type    = string
  default = "us-east-1"
}
variable "owner" {
  type    = string
  default = "jpmc-workshop"
}
