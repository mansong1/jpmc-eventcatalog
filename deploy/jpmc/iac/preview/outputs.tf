output "name" { value = var.preview_id }
output "port" { value = local.port }
output "url" { value = "http://${data.aws_lb.base.dns_name}:${local.port}" }
output "target_group_arn" { value = aws_lb_target_group.preview.arn }
output "expires_at" { value = timeadd(var.created_at, "${var.ttl_hours}h") }
