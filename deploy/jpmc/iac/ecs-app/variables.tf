variable "name" {
  type        = string
  default     = "jpmc-eventcatalog-tf"
  description = "Name for the ECS cluster, service, ALB and log group (must not collide with the CD-managed demo resources)."
  validation {
    condition     = can(regex("^[a-z0-9-]{1,28}$", var.name))
    error_message = "name must be lowercase alphanumerics and dashes, max 28 chars."
  }
}
variable "region" {
  type    = string
  default = "us-east-1"
}
variable "owner" {
  type    = string
  default = "jpmc-workshop"
}
variable "ecr_repository_name" {
  type        = string
  default     = "jpmc-eventcatalog"
  description = "Existing ECR repo built by the workshop CI (from ../base)."
}
variable "image_tag" {
  type        = string
  default     = "latest"
  description = "Image tag to deploy. Must exist in the ECR repo; pr-* tags expire after 7 days per the repo lifecycle policy."
}
variable "desired_count" {
  type    = number
  default = 1
}
variable "ingress_cidrs" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "Who can reach the site on port 80."
}
variable "task_execution_role_arn" {
  type        = string
  default     = "arn:aws:iam::759984737373:role/cicd-demo-ecs-task-execution"
  description = "Existing ECS task execution role (ECR pull + logs). Referenced, not created, so this stack adds no IAM."
}
