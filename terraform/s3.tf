# --- FRONTEND BUCKET (A weboldal kiszolgálása) ---

resource "random_id" "bucket_id" {
  byte_length = 4
}

resource "aws_s3_bucket" "frontend_bucket" {
  bucket = "serverless-chat-frontend-${random_id.bucket_id.hex}"
}

resource "aws_s3_bucket_website_configuration" "frontend_config" {
  bucket = aws_s3_bucket.frontend_bucket.id
  index_document { suffix = "index.html" }
}

resource "aws_s3_bucket_public_access_block" "frontend_access" {
  bucket = aws_s3_bucket.frontend_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "public_read" {
  bucket = aws_s3_bucket.frontend_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicReadGetObject"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.frontend_bucket.arn}/*"
    }]
  })
  depends_on = [aws_s3_bucket_public_access_block.frontend_access]
}

resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.frontend_bucket.id
  key          = "index.html"
  content_type = "text/html"
  content = templatefile("${path.module}/../index.html.tpl", {
    websocket_url = "${aws_apigatewayv2_api.websocket_api.api_endpoint}/${aws_apigatewayv2_stage.prod.name}"
  })
  etag = md5(templatefile("${path.module}/../index.html.tpl", {
    websocket_url = "${aws_apigatewayv2_api.websocket_api.api_endpoint}/${aws_apigatewayv2_stage.prod.name}"
  }))
}

# --- IMAGE STORAGE BUCKET (A fotóknak) ---

resource "aws_s3_bucket" "chat_images" {
  bucket_prefix = "chat-images-"
  force_destroy = true
}

resource "aws_s3_bucket_ownership_controls" "image_ownership" {
  bucket = aws_s3_bucket.chat_images.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "image_access" {
  bucket = aws_s3_bucket.chat_images.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "image_acl" {
  depends_on = [
    aws_s3_bucket_ownership_controls.image_ownership,
    aws_s3_bucket_public_access_block.image_access,
  ]
  bucket = aws_s3_bucket.chat_images.id
  acl    = "public-read"
}

resource "aws_s3_bucket_lifecycle_configuration" "expire_images" {
  bucket = aws_s3_bucket.chat_images.id
  rule {
    id     = "delete-after-24h"
    status = "Enabled"
    expiration { days = 1 }
  }
}

# CORS - JAVÍTVA: OPTIONS eltávolítva az érvényes metódusok közül
resource "aws_s3_bucket_cors_configuration" "chat_cors" {
  bucket = aws_s3_bucket.chat_images.id
  cors_rule {
    allowed_headers = ["*"]
    # Az S3-nál a PUT/POST engedélyezése automatikusan kezeli a preflight OPTIONS kérést.
    allowed_methods = ["GET", "PUT", "POST", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag", "Location", "Access-Control-Allow-Origin"]
    max_age_seconds = 3600
  }
}

resource "aws_s3_bucket_policy" "image_public_read" {
  bucket = aws_s3_bucket.chat_images.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicReadAndPut"
      Effect    = "Allow"
      Principal = "*"
      Action    = ["s3:GetObject", "s3:PutObject", "s3:PutObjectAcl"]
      Resource  = "${aws_s3_bucket.chat_images.arn}/*"
    }]
  })
  depends_on = [aws_s3_bucket_public_access_block.image_access]
}

# OUTPUTOK
output "website_url" {
  value = "http://${aws_s3_bucket_website_configuration.frontend_config.website_endpoint}"
}

output "image_bucket_name" {
  value = aws_s3_bucket.chat_images.id
}