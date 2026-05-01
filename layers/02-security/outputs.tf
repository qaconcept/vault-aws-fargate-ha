output "kms_key_arn" {
  value = aws_kms_key.vault_unseal.arn
}

output "vault_task_role_arn" {
  value = aws_iam_role.vault_task_role.arn
}

output "vault_execution_role_arn" {
  value = aws_iam_role.vault_execution_role.arn
}