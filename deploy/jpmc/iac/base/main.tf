# Shared, long-lived infrastructure for the JPMC EventCatalog demo.
# Previews (../preview) attach per-PR listeners to the ALB created here.
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = { app = "jpmc-eventcatalog", managed_by = "harness-iacm", owner = var.owner }
  }
}

data "aws_caller_identity" "current" {}

resource "aws_ecr_repository" "app" {
  name                 = var.name
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true
  image_scanning_configuration { scan_on_push = true }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name
  policy = jsonencode({ rules = [{
    rulePriority = 1, description = "expire untagged and preview images after 7 days"
    selection    = { tagStatus = "tagged", tagPrefixList = ["pr-"], countType = "sinceImagePushed", countUnit = "days", countNumber = 7 }
    action       = { type = "expire" }
  }] })
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/jpmc/${var.name}"
  retention_in_days = 7
}

resource "aws_security_group" "alb" {
  name        = "${var.name}-alb"
  description = "JPMC EventCatalog ALB: prod 80, test 8080, previews ${var.preview_port_min}-${var.preview_port_max}"
  vpc_id      = var.vpc_id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.ingress_cidrs
  }
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.preview_ingress_cidrs
  }
  ingress {
    from_port   = var.preview_port_min
    to_port     = var.preview_port_max
    protocol    = "tcp"
    cidr_blocks = var.preview_ingress_cidrs
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "tasks" {
  name        = "${var.name}-tasks"
  description = "JPMC EventCatalog Fargate tasks: port 80 from the ALB only"
  vpc_id      = var.vpc_id
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "app" {
  name               = var.name
  load_balancer_type = "application"
  subnets            = var.subnet_ids
  security_groups    = [aws_security_group.alb.id]
}

# blue = live, green = candidate (ECS blue/green swaps the listener between them)
resource "aws_lb_target_group" "app" {
  for_each             = toset(["blue", "green"])
  name                 = "${var.name}-${each.key}"
  port                 = 80
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = var.vpc_id
  deregistration_delay = 15
  health_check {
    path              = "/healthz"
    interval          = 10
    healthy_threshold = 2
  }
}

resource "aws_lb_listener" "prod" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app["blue"].arn
  }
  lifecycle { ignore_changes = [default_action] } # owned by CD once blue/green is live
}

resource "aws_lb_listener" "test" {
  load_balancer_arn = aws_lb.app.arn
  port              = 8080
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app["green"].arn
  }
  lifecycle { ignore_changes = [default_action] }
}
