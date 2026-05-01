HashiCorp Vault on AWS ECS Fargate Deployment Guide
This document contains the complete end-to-end instructions, prerequisites, and validation commands to deploy, initialize, and test a highly available (HA) HashiCorp Vault cluster on AWS ECS using AWS KMS auto-unseal and EFS for persistent Raft storage.

Prerequisites
Before starting the deployment, ensure you have the following tools and resources provisioned and configured in your environment:

AWS Account: An active AWS account with appropriate permissions to create IAM roles, KMS keys, EFS, and ECS resources.

AWS CLI: Installed and authenticated locally using your credentials (run aws configure or set your environment variables).

Route 53 Hosted Zone: A hosted zone for sreconcepts.com already created in your AWS account containing the default NS and SOA records.

Terraform: Installed (version 1.5+ recommended) to manage infrastructure as code.

Vault CLI: Installed locally on your workstation to interact with the Vault server after deployment.

Docker: Installed locally on your machine (useful for inspecting or pulling container base images).

Architecture Overview
Orchestration: AWS ECS Fargate

Storage Backend: AWS EFS (using Raft storage engine)

Auto-Unseal: AWS KMS Key (alias/prod-v5-vault-key)

Load Balancing: AWS Application Load Balancer (ALB) with ACM SSL/TLS Certificate

Step-by-Step Implementation
Layer 01: Networking
Create your VPC, public subnets, and private subnets.

Initialize and apply the network state.

Bash
cd 01-network
terraform init
terraform apply -auto-approve
Layer 02: Security
Create the AWS KMS key for auto-unseal, IAM roles for ECS tasks, and EFS security groups.

Ensure the key alias matches alias/prod-v5-vault-key.

Bash
cd ../02-security
terraform init
terraform apply -auto-approve
Layer 03: Storage
Provision the Amazon EFS file system, access point, and security groups.

Bash
cd ../03-storage
terraform init
terraform apply -auto-approve
Layer 04: Application (ECS, ALB, and ACM)
Verify that 04-app/main.tf is properly configured, and any redundant local files have been deleted.

Initialize and apply the final infrastructure layer:

Bash
cd ../04-app
terraform init
terraform apply -auto-approve
Infrastructure Validation
Verify that the ECS tasks and target groups are healthy and running:

1. Verify Task Status
Bash
TASK_ARN=$(aws ecs list-tasks --cluster vault-cluster --service-name vault-service --query 'taskArns[0]' --output text)
aws ecs describe-tasks --cluster vault-cluster --tasks $TASK_ARN --query 'tasks[0].lastStatus' --output text
Expected Output: RUNNING

2. Verify Target Health
Bash
TG_ARN=$(aws elbv2 describe-target-groups --names vault-tg --query 'TargetGroups[0].TargetGroupArn' --output text)
aws elbv2 describe-target-health --target-group-arn $TG_ARN --query 'TargetHealthDescriptions[*].TargetHealth.State' --output text
Expected Output: healthy

3. Check Health Status via cURL
Bash
curl -I https://vault.sreconcepts.com/v1/sys/health
Expected Output: 501 Not Implemented (This indicates an uninitialized state, which is expected before Vault setup).

Vault Initial Setup
Open your web browser and navigate to: https://vault.sreconcepts.com/

You will see the Vault Initial Setup screen.

Configure the Key shares and Key threshold:

Key shares: 3

Key threshold: 2

Click Initialize.

CRITICAL STEP: Download and securely store the generated Unseal Keys and Initial Root Token.

Testing the Vault Cluster
Configure your environment and verify operations using the Vault CLI:

1. Set the Address and Log In
Bash
export VAULT_ADDR="https://vault.sreconcepts.com"
vault login
Provide the root token when prompted.

Expected Output:
Plaintext
Success! You are now authenticated. The token information displayed below
is already stored in the token helper. You do NOT need to run "vault login"
again. Future Vault requests will automatically use this token.

Key                  Value
---                  -----
token                hvs.xxxxxxxxxxxxxxxxxxxxxxxx
token_accessor       46WIYkcaITgfNG55isXPKcZC
token_duration       ∞
token_renewable      false
token_policies       ["root"]
identity_policies    []
policies             ["root"]
2. Enable the KV v2 Secrets Engine
Bash
vault secrets enable -path=secret kv-v2
Expected Output:
Plaintext
Success! Enabled the kv-v2 secrets engine at: secret/
3. Write Your Test Secret
Bash
vault kv put secret/hello foo=world
Expected Output:
Plaintext
== Secret Path ==
secret/data/hello

======= Metadata =======
Key                Value
---                -----
created_time       2026-05-01T08:22:39.231758143Z
custom_metadata    <nil>
deletion_time      n/a
destroyed          false
version            1
4. Verify the Secret
Bash
vault kv get secret/hello
Expected Output:
Plaintext
== Secret Path ==
secret/data/hello

======= Metadata =======
Key                Value
---                -----
created_time       2026-05-01T08:22:39.231758143Z
custom_metadata    <nil>
deletion_time      n/a
destroyed          false
version            1

=== Data ===
Key    Value
---    -----
foo    world