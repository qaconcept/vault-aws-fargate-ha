# 1. Request the Certificate
resource "aws_acm_certificate" "vault" {
  domain_name       = "sreconcepts.com"
  validation_method = "DNS"
  subject_alternative_names = ["*.sreconcepts.com"]

  lifecycle {
    create_before_destroy = true
  }
}

# 2. Get your existing Route53 Zone
data "aws_route53_zone" "main" {
  name         = "sreconcepts.com"
  private_zone = false
}

# 3. Create the DNS Record for Validation
resource "aws_route53_record" "vault_validation" {
  for_each = {
    for dvo in aws_acm_certificate.vault.domain_validation_options : dvo.domain_name => {
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

# 4. The "Waiter" - tells Terraform to stop here until the cert is actually ready
resource "aws_acm_certificate_validation" "vault" {
  certificate_arn         = aws_acm_certificate.vault.arn
  validation_record_fqdns = [for record in aws_route53_record.vault_validation : record.fqdn]
}