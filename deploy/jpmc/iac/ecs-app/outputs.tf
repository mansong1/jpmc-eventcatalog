output "url" { value = "http://${aws_lb.app.dns_name}" }
output "alb_dns" { value = aws_lb.app.dns_name }
output "cluster_name" { value = aws_ecs_cluster.app.name }
output "cluster_arn" { value = aws_ecs_cluster.app.arn }
output "service_name" { value = aws_ecs_service.app.name }
output "task_definition_arn" { value = aws_ecs_task_definition.app.arn }
output "image" { value = local.image }
output "log_group" { value = aws_cloudwatch_log_group.app.name }
