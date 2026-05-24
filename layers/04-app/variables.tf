variable "domain_name" {
  description = "The root domain name (e.g., sreconcepts.com)"
  type        = string
  default     = "sreconcepts.com"
}

variable "subdomain" {
  description = "The subdomain for Vault (e.g., vault)"
  type        = string
  default     = "vault"
}

variable "region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "kms_key_id" {
  type    = string
  default = "alias/prod-v1-vault-key" # Updated to avoid collision, also if updated ensure it matches 02-security/variables.tf
}