output "efs_id" {
  value = aws_efs_file_system.vault.id
}

output "efs_access_point_id" {
  value = aws_efs_access_point.vault.id
}

output "efs_sg_id" {
  value = aws_security_group.efs_sg.id
}