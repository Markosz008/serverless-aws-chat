resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    # Itt az S3 vödrünk publikus weboldal linkjére mutatunk
    domain_name = aws_s3_bucket_website_configuration.frontend_config.website_endpoint
    origin_id   = "S3-Website-${aws_s3_bucket.frontend_bucket.id}"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only" # Mivel az S3 maga csak HTTP-t tud
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-Website-${aws_s3_bucket.frontend_bucket.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    # EZ A LÉNYEG: Mindenkit átdobunk HTTPS-re!
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    # Ingyenes, gyári AWS SSL tanúsítvány a cloudfront.net domainhez
    cloudfront_default_certificate = true
  }
}

output "https_secure_url" {
  value       = "https://${aws_cloudfront_distribution.s3_distribution.domain_name}"
  description = "A BIZTONSÁGOS (HTTPS) linked!"
}