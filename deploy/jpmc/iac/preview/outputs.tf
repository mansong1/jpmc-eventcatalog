output "name" { value = var.preview_id }
output "port" { value = local.port }
output "url" { value = "http://${data.aws_lb.base.dns_name}:${local.port}" }
output "target_group_arn" { value = aws_lb_target_group.preview.arn }
output "expires_at" { value = timeadd(var.created_at, "${var.ttl_hours}h") }
output "listener_arn" { value = aws_lb_listener.preview.arn }
output "test_listener_arn" { value = one(aws_lb_listener.test[*].arn) }
output "test_url" { value = var.test_port != 0 ? "http://${data.aws_lb.base.dns_name}:${var.test_port}" : null }
