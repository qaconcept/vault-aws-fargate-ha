variable "region" {
  type    = string
  default = "us-east-1"
}

variable "kms_key_id" {
  type    = string
  default = "alias/prod-v1-vault-key" # Updated to avoid collision
}

variable "aws_account_id" {
  type        = string
  description = "The 12-digit AWS Account ID"
  default     = "581781313195" # Update to your actual AWS Account ID
}