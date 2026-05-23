# =============================================
# ACM Certificate (Smart: Use existing or create new)
# =============================================

# Try to find an existing certificate for the domain
data "aws_acm_certificate" "existing" {
  domain      = var.domain_name
  most_recent = true
}

# Create new certificate only if one doesn't exist
resource "aws_acm_certificate" "vault" {
  count = data.aws_acm_certificate.existing.id == "" ? 1 : 0

  domain_name               = var.domain_name
  validation_method         = "DNS"
  subject_alternative_names = ["*.${var.domain_name}"]

  lifecycle {
    create_before_destroy = true
  }
}

# Get Route53 Zone
data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

# DNS Validation Records (only if creating new cert)
resource "aws_route53_record" "vault_validation" {
  for_each = {
    for dvo in try(aws_acm_certificate.vault[0].domain_validation_options, []) : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main.zone_id
}

# Certificate Validation (only if we created a new cert)
resource "aws_acm_certificate_validation" "vault" {
  count = data.aws_acm_certificate.existing.id == "" ? 1 : 0

  certificate_arn         = aws_acm_certificate.vault[0].arn
  validation_record_fqdns = [for record in aws_route53_record.vault_validation : record.fqdn]
}

# =============================================
# Final Certificate ARN Logic (Fixed)
# =============================================
locals {
  certificate_arn = coalesce(
    try(data.aws_acm_certificate.existing.arn, ""),
    try(aws_acm_certificate_validation.vault[0].certificate_arn, "")
  )
}