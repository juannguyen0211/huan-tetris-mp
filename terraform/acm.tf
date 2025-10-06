data "aws_acm_certificate" "cloudflare_cert" {
  domain   = "mock-game.jn7n-vn.com"
  statuses = ["ISSUED"]
  most_recent = true
}

output "cloudflare_cert_arn" {
  value = data.aws_acm_certificate.cloudflare_cert.arn
}
