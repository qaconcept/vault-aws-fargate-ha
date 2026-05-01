provider "aws" {
  region = "us-east-1"
}

# ---------------------------------------------------------
# 1. Dynamic Networking (Link to Layer 01)
# ---------------------------------------------------------
data "terraform_remote_state" "network" {
  backend = "local"
  config = {
    path = "../01-network/terraform.tfstate"
  }
}

locals {
  vpc_id          = data.terraform_remote_state.network.outputs.vpc_id 
  storage_subnets = data.terraform_remote_state.network.outputs.private_subnets 
  vpc_cidr        = data.terraform_remote_state.network.outputs.vpc_cidr 
}

# ---------------------------------------------------------
# 2. Security Group for EFS
# ---------------------------------------------------------
resource "aws_security_group" "efs_sg" {
  name        = "vault-efs-sg"
  description = "Allow inbound traffic from Vault tasks to EFS" 
  vpc_id      = local.vpc_id # Dynamically pulled from network layer 

  ingress {
    from_port   = 2049 
    to_port     = 2049 
    protocol    = "tcp" 
    cidr_blocks = [local.vpc_cidr] # Dynamically pulled from network layer 
  }

  egress {
    from_port   = 0 
    to_port     = 0 
    protocol    = "-1" 
    cidr_blocks = ["0.0.0.0/0"] 
  }
}

# ---------------------------------------------------------
# 3. EFS File System
# ---------------------------------------------------------
resource "aws_efs_file_system" "vault" {
  creation_token = "vault-raft-data" 
  encrypted      = true 

  tags = {
    Name = "vault-storage" 
  }
}

# Dynamic Mount Targets (Creates one for each private subnet found in Phase 1)
resource "aws_efs_mount_target" "vault" {
  count           = length(local.storage_subnets) 
  file_system_id  = aws_efs_file_system.vault.id 
  subnet_id       = local.storage_subnets[count.index] # Dynamically pulled from network layer 
  security_groups = [aws_security_group.efs_sg.id] 
}

# ---------------------------------------------------------
# 4. EFS Access Point (Ensures consistent POSIX permissions)
# ---------------------------------------------------------
resource "aws_efs_access_point" "vault" {
  file_system_id = aws_efs_file_system.vault.id 

  posix_user {
    gid = 1000 
    uid = 1000 # Updated to 1000 to align with standard Vault container users 
  }

  root_directory {
    path = "/vault/data" 
    creation_info {
      owner_gid   = 1000 
      owner_uid   = 1000 # Updated to 1000 for consistency 
      permissions = "755" 
    }
  }
}