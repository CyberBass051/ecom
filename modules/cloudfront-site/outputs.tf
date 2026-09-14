output "site_bucket" {
  value = aws_s3_bucket.site.bucket
}

output "distribution_domain" {
  value = aws_cloudfront_distribution.this.domain_name
}
