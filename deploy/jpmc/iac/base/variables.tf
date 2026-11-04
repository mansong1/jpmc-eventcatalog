variable "name" {
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
variable "vpc_id" {
  type    = string
  default = "vpc-307f234b"
}
variable "subnet_ids" {
  type    = list(string)
  default = ["subnet-7db33072", "subnet-35b30f7f", "subnet-e7bc4480"]
}
variable "ingress_cidrs" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "Who can reach the released site on port 80"
}
variable "preview_ingress_cidrs" {
  type        = list(string)
  description = "Who can reach unreleased builds: test listener 8080 and preview ports (corporate/VPN ranges, never 0.0.0.0/0)"
  validation {
    condition     = length(var.preview_ingress_cidrs) > 0 && !contains(var.preview_ingress_cidrs, "0.0.0.0/0")
    error_message = "preview_ingress_cidrs must be a non-empty list of restricted CIDRs."
  }
}
variable "preview_port_min" {
  type    = number
  default = 8100
}
variable "preview_port_max" {
  type    = number
  default = 8199
}
