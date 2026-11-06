# EventCatalog on ECS Fargate, deployed end-to-end by Terraform (no Harness CD).
# Unlike ../base + ../preview (shared ALB, service deployed by CD), this stack owns
# its whole path: ECS cluster, service, task definition, ALB, security groups and
# logs. It references only the existing ECR repo and task execution role, so it is
# safe to run alongside the demo - nothing here changes those resources.
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = { app = "jpmc-eventcatalog", managed_by = "harness-iacm", owner = var.owner, stack = "ecs-app" }
  }
}

data "aws_caller_identity" "current" {}

# Same default VPC / public subnets the existing demo uses; public IPs mean no NAT.
data "aws_vpc" "default" { default = true }

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Existing repo from ../base - this stack pulls images, it does not manage the repo.
data "aws_ecr_repository" "app" { name = var.ecr_repository_name }

locals {
  image = "${data.aws_ecr_repository.app.repository_url}:${var.image_tag}"
}

resource "aws_ecs_cluster" "app" {
  name = var.name
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/jpmc/${var.name}"
  retention_in_days = 7
}

resource "aws_security_group" "alb" {
  name        = "${var.name}-alb"
  description = "Terraform-managed EventCatalog ALB: port 80"
  vpc_id      = data.aws_vpc.default.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.ingress_cidrs
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
  description = "Terraform-managed EventCatalog Fargate tasks: port 80 from its ALB only"
  vpc_id      = data.aws_vpc.default.id
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
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.alb.id]
}

resource "aws_lb_target_group" "app" {
  name                 = "${var.name}-app"
  port                 = 80
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = data.aws_vpc.default.id
  deregistration_delay = 15
  health_check {
    path              = "/healthz"
    interval          = 10
    healthy_threshold = 2
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_ecs_task_definition" "app" {
  family                   = var.name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  # Existing role used by the CD taskdefs - no new IAM.
  execution_role_arn = var.task_execution_role_arn
  container_definitions = jsonencode([{
    name      = "eventcatalog"
    image     = local.image
    essential = true
    portMappings = [{ containerPort = 80, protocol = "tcp" }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.app.name
        awslogs-region        = var.region
        awslogs-stream-prefix = "ecs"
      }
    }
    healthCheck = {
      command     = ["CMD-SHELL", "wget -qO- http://localhost/healthz || exit 1"]
      interval    = 15
      retries     = 3
      startPeriod = 10
    }
  }])
}

resource "aws_ecs_service" "app" {
  name            = var.name
  cluster         = aws_ecs_cluster.app.id
  task_definition = aws_ecs_task_definition.app.arn
  launch_type     = "FARGATE"
  desired_count   = var.desired_count

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  health_check_grace_period_seconds = 30

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "eventcatalog"
    container_port   = 80
  }

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.tasks.id]
    assign_public_ip = true
  }

  depends_on = [aws_lb_listener.http]
}
