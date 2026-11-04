# One ephemeral preview: a dedicated ALB port + target group, so each PR gets
# its own URL (http://<alb>:<port>/) with no DNS. ECS service is deployed by CD.
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      app        = "jpmc-eventcatalog"
      managed_by = "harness-iacm"
      preview    = var.preview_id
      expires_at = timeadd(var.created_at, "${var.ttl_hours}h")
      owner      = var.owner
    }
  }
}

data "aws_lb" "base" { name = var.base_name }
data "aws_lb_target_group" "probe" { name = "${var.base_name}-blue" }

locals {
  # pr-43 -> 8143; anything else hashes into the preview port range. 8197-8199 are reserved for the long-lived
  # slots (staging test, dev, staging), hence % 97
  pr_number = tonumber(try(regex("^pr-(\\d+)$", var.preview_id)[0], -1))
  port      = var.port != 0 ? var.port : (local.pr_number >= 0 ? 8100 + (local.pr_number % 97) : 8100 + parseint(substr(sha1(var.preview_id), 0, 2), 16) % 97)
  tg_name   = substr("jec-${var.preview_id}", 0, 32)
}

resource "aws_lb_target_group" "preview" {
  name                 = local.tg_name
  port                 = 80
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = data.aws_lb_target_group.probe.vpc_id
  deregistration_delay = 5
  health_check {
    path              = "/healthz"
    interval          = 10
    healthy_threshold = 2
  }
}

resource "aws_lb_listener" "preview" {
  load_balancer_arn = data.aws_lb.base.arn
  port              = local.port
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.preview.arn
  }
  # on a blue/green slot CD owns which colour this forwards to
  lifecycle { ignore_changes = [default_action] }
}

# blue/green slots: the second colour behind a test listener
resource "aws_lb_target_group" "green" {
  count                = var.test_port != 0 ? 1 : 0
  name                 = substr("jec-${var.preview_id}-green", 0, 32)
  port                 = 80
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = data.aws_lb_target_group.probe.vpc_id
  deregistration_delay = 5
  health_check {
    path              = "/healthz"
    interval          = 10
    healthy_threshold = 2
  }
}

resource "aws_lb_listener" "test" {
  count             = var.test_port != 0 ? 1 : 0
  load_balancer_arn = data.aws_lb.base.arn
  port              = var.test_port
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.green[0].arn
  }
  lifecycle { ignore_changes = [default_action] }
}
