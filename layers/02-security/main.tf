provider "aws" {
  region = var.region
}

# ---------------------------------------------------------
# 1. KMS Key for Auto-Unseal
# ---------------------------------------------------------
resource "aws_kms_key" "vault_unseal" {
  description             = "Vault unseal key prod-v4"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  # Add the KMS Key Policy here to allow the task role
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::581781313195:root" # Update with your AWS Account ID
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowVaultTaskRoleToUseKey"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.vault_task_role.arn
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "vault-unseal-key"
  }
}

resource "aws_kms_alias" "vault_unseal" {
  name          = "alias/prod-v5-vault-key" # Updated to avoid collision
  target_key_id = aws_kms_key.vault_unseal.key_id
}

# ---------------------------------------------------------
# 2. IAM Roles for ECS Fargate
# ---------------------------------------------------------

# The Task Execution Role (Allows ECS to pull images from ECR)
resource "aws_iam_role" "vault_execution_role" { #
  name = "vault-execution-role-v4"

  assume_role_policy = jsonencode({
    Version = "2012-10-17" #
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "execution_role_policy" {
  role       = aws_iam_role.vault_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# The Task Role (What Vault actually "is" — allowed to use KMS)
resource "aws_iam_role" "vault_task_role" {
  name = "vault-task-role-v4"

  assume_role_policy = jsonencode({
    Version = "2012-10-17" #
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "vault_kms_access" {
  name = "vault-kms-access"
  role = aws_iam_role.vault_task_role.id

  policy = jsonencode({
    Version = "2012-10-17" #
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:DescribeKey" #
        ]
        Resource = [aws_kms_key.vault_unseal.arn]
      }
    ]
  })
}