provider "cloudflare" {
  email   = var.cloudflare_email
  api_key = var.cloudflare_api_key
}

resource "cloudflare_record" "tetris_dns" {
  zone_id = var.cloudflare_zone_id
  name    = "mock-game"
  value   = aws_lb.ingress.dns_name
  type    = "CNAME"
  ttl     = 300
  proxied = true
}
