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

# --- ÚJ FÁJLOK: CSS és JS feltöltése a bontáshoz ---

resource "aws_s3_object" "frontend_css_files" {
  for_each = fileset("${path.module}/../frontend/css", "**/*.css")

  bucket       = aws_s3_bucket.frontend_bucket.id
  key          = "css/${each.value}"
  source       = "${path.module}/../frontend/css/${each.value}"
  content_type = "text/css"
  etag         = filemd5("${path.module}/../frontend/css/${each.value}")
}

# --- DINAMIKUS CIKLUS: Az összes JS fájl feltöltése a frontend/js mappából ---
resource "aws_s3_object" "frontend_js_files" {
  for_each = fileset("${path.module}/../frontend/js", "**/*.js")

  bucket       = aws_s3_bucket.frontend_bucket.id
  key          = "js/${each.value}"
  source       = "${path.module}/../frontend/js/${each.value}"
  content_type = "application/javascript"
  etag         = filemd5("${path.module}/../frontend/js/${each.value}")
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
    allowed_methods = ["GET", "PUT", "POST", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag", "Accept-Ranges", "Content-Range", "Content-Encoding", "Content-Length"]
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

resource "aws_s3_object" "manifest_json" {
  bucket       = aws_s3_bucket.frontend_bucket.id
  key          = "manifest.json"
  source       = "${path.module}/../frontend/manifest.json"
  content_type = "application/json"
  etag         = filemd5("${path.module}/../frontend/manifest.json")
}

resource "aws_s3_object" "service_worker" {
  bucket       = aws_s3_bucket.frontend_bucket.id
  key          = "sw.js"
  source       = "${path.module}/../frontend/sw.js"
  content_type = "application/javascript"
  etag         = filemd5("${path.module}/../frontend/sw.js")
}

resource "null_resource" "cloudfront_invalidation" {
  triggers = {
    # Új HTML-t és a CSS-t
    html_hash  = filemd5("${path.module}/../index.html.tpl")
    css_hash   = filemd5("${path.module}/../frontend/css/style.css")
    
    #ÚJ, szétdarabolt JS modulokat
    js_state   = filemd5("${path.module}/../frontend/js/state.js")
    js_ui      = filemd5("${path.module}/../frontend/js/ui.js")
    js_network = filemd5("${path.module}/../frontend/js/network.js")
    js_media   = filemd5("${path.module}/../frontend/js/media.js")
    js_app     = filemd5("${path.module}/../frontend/js/app.js")
  }

  provisioner "local-exec" {
  
    command = "aws cloudfront create-invalidation --distribution-id ESV32IXWM4EHZ --paths '/*'"
  }
}
# --- AVATAR BUCKET (Profilképek tárolása) ---

resource "aws_s3_bucket" "avatar_bucket" {
  bucket_prefix = "chat-avatars-"
  force_destroy = true
}

resource "aws_s3_bucket_ownership_controls" "avatar_ownership" {
  bucket = aws_s3_bucket.avatar_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "avatar_access" {
  bucket                  = aws_s3_bucket.avatar_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "avatar_acl" {
  depends_on = [
    aws_s3_bucket_ownership_controls.avatar_ownership,
    aws_s3_bucket_public_access_block.avatar_access,
  ]
  bucket = aws_s3_bucket.avatar_bucket.id
  acl    = "public-read"
}

# Avatarokat NEM töröljük naponta — maradnak amíg a user nem cseréli
resource "aws_s3_bucket_lifecycle_configuration" "avatar_lifecycle" {
  bucket = aws_s3_bucket.avatar_bucket.id
  rule {
    id     = "delete-old-avatars"
    status = "Enabled"
    # Régi feltöltött avatarokat 90 nap után töröljük
    expiration { days = 90 }
  }
}

resource "aws_s3_bucket_cors_configuration" "avatar_cors" {
  bucket = aws_s3_bucket.avatar_bucket.id
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag", "Content-Length"]
    max_age_seconds = 3600
  }
}

resource "aws_s3_bucket_policy" "avatar_public_read" {
  bucket = aws_s3_bucket.avatar_bucket.id
  depends_on = [aws_s3_bucket_public_access_block.avatar_access]
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicReadAndPut"
      Effect    = "Allow"
      Principal = "*"
      Action    = ["s3:GetObject", "s3:PutObject", "s3:PutObjectAcl"]
      Resource  = "${aws_s3_bucket.avatar_bucket.arn}/*"
    }]
  })
}

output "avatar_bucket_name" {
  value = aws_s3_bucket.avatar_bucket.id
}
