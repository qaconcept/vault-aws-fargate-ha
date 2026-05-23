# =============================================
# Important Outputs
# =============================================

output "vault_url" {
  description = "The full HTTPS URL to access Vault"
  value       = "https://${local.vault_fqdn}"
}

output "vault_fqdn" {
  description = "The fully qualified domain name for Vault"
  value       = local.vault_fqdn
}

output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = aws_lb.vault.dns_name
}

output "alb_zone_id" {
  description = "The Zone ID of the Application Load Balancer"
  value       = aws_lb.vault.zone_id
}

output "certificate_arn" {
  description = "The ARN of the ACM certificate used (existing or newly created)"
  value       = local.certificate_arn
}

output "ecs_cluster_name" {
  description = "Name of the ECS Cluster"
  value       = aws_ecs_cluster.vault.name
}

output "ecs_service_name" {
  description = "Name of the ECS Service"
  value       = aws_ecs_service.vault.name
}

output "target_group_arn" {
  description = "ARN of the Target Group"
  value       = aws_lb_target_group.vault.arn
}

output "vault_task_definition_arn" {
  description = "ARN of the Vault ECS Task Definition"
  value       = aws_ecs_task_definition.vault.arn
}

# Optional: Full Vault access info
output "vault_access_info" {
  description = "Summary of how to access Vault"
  value = {
    url         = "https://${local.vault_fqdn}"
    alb_dns     = aws_lb.vault.dns_name
    region      = var.region
    domain_name = var.domain_name
  }
}