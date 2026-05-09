# 1. Generálunk egy random 4 karakteres kódot. 
# Miért? Mert az S3 vödrök nevének GLOBÁLISAN egyedinek kell lennie az egész világon!
resource "random_id" "bucket_id" {
  byte_length = 4
}

# 2. Létrehozzuk magát az S3 vödröt
resource "aws_s3_bucket" "frontend_bucket" {
  bucket = "serverless-chat-frontend-${random_id.bucket_id.hex}"
}

# 3. Bekapcsoljuk rajta a Weboldal Hosztolás funkciót
resource "aws_s3_bucket_website_configuration" "frontend_config" {
  bucket = aws_s3_bucket.frontend_bucket.id

  index_document {
    suffix = "index.html"
  }
}

# 4. Kikapcsoljuk az AWS gyári védelmét, ami blokkolja a publikus hozzáférést (hiszen ez egy weboldal lesz)
resource "aws_s3_bucket_public_access_block" "frontend_access" {
  bucket = aws_s3_bucket.frontend_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# 5. Létrehozunk egy szabályt (Policy), ami kimondja: "Bárki az interneten olvashatja a fájlokat ebből a vödörből"
resource "aws_s3_bucket_policy" "public_read" {
  bucket = aws_s3_bucket.frontend_bucket.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.frontend_bucket.arn}/*"
      }
    ]
  })
  
  depends_on = [aws_s3_bucket_public_access_block.frontend_access]
}

# 6. A Terraform automatikusan feltölti az index.html-t a gépedről a felhőbe!
resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.frontend_bucket.id
  key          = "index.html"
  source       = "${path.module}/../index.html" # Itt keresi a fájlt a terraform mappán KÍVÜL
  content_type = "text/html"                    # Ebből tudja a böngésző, hogy ez egy weboldal
  etag         = filemd5("${path.module}/../index.html") # Ha módosítod az index.html-t, a TF tudni fogja, hogy frissíteni kell
}

# 7. OUTPUT: A kész weboldalad publikus linkje!
output "website_url" {
  value       = "http://${aws_s3_bucket_website_configuration.frontend_config.website_endpoint}"
  description = "Ezt a linket küldd el a barátaidnak!"
}