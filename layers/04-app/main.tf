provider "aws" {
  region = var.region
}

# ---------------------------------------------------------
# 1. Networking & State Configuration
# ---------------------------------------------------------
data "terraform_remote_state" "network" {
  backend = "local"
  config = {
    path = "../01-network/terraform.tfstate"
  }
}

data "terraform_remote_state" "security" {
  backend = "local"
  config = {
    path = "../02-security/terraform.tfstate"
  }
}

data "terraform_remote_state" "storage" {
  backend = "local"
  config = {
    path = "../03-storage/terraform.tfstate"
  }
}

locals {
  vpc_id                   = data.terraform_remote_state.network.outputs.vpc_id
  public_subnets           = data.terraform_remote_state.network.outputs.public_subnets
  kms_key_arn              = data.terraform_remote_state.security.outputs.kms_key_arn
  vault_task_role_arn      = data.terraform_remote_state.security.outputs.vault_task_role_arn
  vault_execution_role_arn = data.terraform_remote_state.security.outputs.vault_execution_role_arn
  efs_id                   = data.terraform_remote_state.storage.outputs.efs_id
  efs_access_point_id      = data.terraform_remote_state.storage.outputs.efs_access_point_id
  efs_sg_id                = data.terraform_remote_state.storage.outputs.efs_sg_id

  # Full domain name for Vault
  vault_fqdn = "${var.subdomain}.${var.domain_name}"
}

# ---------------------------------------------------------
# 2. ECS Cluster & CloudWatch Logs
# ---------------------------------------------------------
resource "aws_ecs_cluster" "vault" {
  name = "vault-cluster"
}

resource "aws_cloudwatch_log_group" "vault" {
  name              = "/ecs/vault"
  retention_in_days = 7
}

# ---------------------------------------------------------
# 3. Security Groups
# ---------------------------------------------------------
resource "aws_security_group" "alb_sg" {
  name   = "vault-alb-sg"
  vpc_id = local.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "vault_task_sg" {
  name   = "vault-task-sg"
  vpc_id = local.vpc_id

  ingress {
    from_port       = 8200
    to_port         = 8200
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------------------------------------------------------
# 4. Load Balancer & SSL
# ---------------------------------------------------------
resource "aws_lb" "vault" {
  name               = "vault-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = local.public_subnets
}

resource "aws_lb_target_group" "vault" {
  name        = "vault-tg"
  port        = 8200
  protocol    = "HTTP"
  vpc_id      = local.vpc_id
  target_type = "ip"

  health_check {
    path                = "/v1/sys/health?uninitcode=200&sealedcode=200"
    protocol            = "HTTP"
    port                = "8200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
    matcher             = "200"
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.vault.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = local.certificate_arn   # ← Now using the smart local from acm.tf

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.vault.arn
  }
}

# ---------------------------------------------------------
# 5. ECS Task Definition
# ---------------------------------------------------------
resource "aws_ecs_task_definition" "vault" {
  family                   = "vault"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = local.vault_execution_role_arn
  task_role_arn            = local.vault_task_role_arn

  container_definitions = jsonencode([{
    name    = "vault"
    image   = "hashicorp/vault:1.15.6"
    user    = "0"
    command = ["server"]

    portMappings = [{ containerPort = 8200, hostPort = 8200 }]
    mountPoints  = [{ sourceVolume = "vault-data", containerPath = "/vault/data", readOnly = false }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/vault"
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "vault"
      }
    }

    environment = [
      {
        name = "VAULT_LOCAL_CONFIG"
        value = jsonencode({
          storage = {
            raft = {
              path     = "/vault/data"
              node_id  = "node1"
            }
          }
          seal = {
            awskms = {
              region     = var.region
              kms_key_id = "alias/prod-v5-vault-key"   # Consider making this a variable too later
            }
          }
          listener = {
            tcp = {
              address     = "0.0.0.0:8200"
              tls_disable = "true"
            }
          }
          cluster_addr = "http://127.0.0.1:8201"
          api_addr     = "https://${local.vault_fqdn}"   # ← Now dynamic
          ui           = true
          disable_mlock = true
        })
      },
      { name = "VAULT_LOG_LEVEL", value = "debug" }
    ]
  }])

  volume {
    name = "vault-data"
    efs_volume_configuration {
      file_system_id     = local.efs_id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = local.efs_access_point_id
      }
    }
  }
}

# ---------------------------------------------------------
# 6. ECS Service & DNS
# ---------------------------------------------------------
resource "aws_ecs_service" "vault" {
  name            = "vault-service"
  cluster         = aws_ecs_cluster.vault.id
  task_definition = aws_ecs_task_definition.vault.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = local.public_subnets
    security_groups  = [aws_security_group.vault_task_sg.id, local.efs_sg_id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.vault.arn
    container_name   = "vault"
    container_port   = 8200
  }
}

resource "aws_route53_record" "vault" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = local.vault_fqdn          # ← Now dynamic using variables
  type    = "A"

  alias {
    name                   = aws_lb.vault.dns_name
    zone_id                = aws_lb.vault.zone_id
    evaluate_target_health = true
  }
}