variable "region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "prod-v4"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}