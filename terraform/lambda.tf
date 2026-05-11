# Adatforrások a pontos azonosítókhoz
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# 1. Automatikusan becsomagoljuk a Python kódunkat egy ZIP fájlba
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../src/app.py"
  output_path = "${path.module}/lambda_function.zip"
}

# 2. IAM Role: Megengedjük a Lambdának, hogy felvegye ezt a szerepkört
resource "aws_iam_role" "lambda_exec" {
  name = "websocket_lambda_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# 3. IAM Policy: Minden szükséges jogosultság összefésülve
resource "aws_iam_role_policy" "lambda_policy" {
  name = "websocket_lambda_policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # CloudWatch Logs: Hogy lássuk a hibákat a naplóban
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        # DynamoDB: A felhasználók és kapcsolatok kezeléséhez
        Effect = "Allow"
        Action = ["dynamodb:PutItem", "dynamodb:DeleteItem", "dynamodb:Scan", "dynamodb:UpdateItem"]
        Resource = aws_dynamodb_table.websocket_connections.arn
      },
      {
        # API Gateway: Üzenetek visszaküldése a klienseknek (JAVÍTVA)
        Effect = "Allow"
        Action = ["execute-api:ManageConnections"]
        Resource = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*/*"
      },
      {
        # S3: Képfeltöltési linkek és fájlok kezelése (JAVÍTVA)
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = [
          "${aws_s3_bucket.chat_images.arn}",
          "${aws_s3_bucket.chat_images.arn}/*"
        ]
      }
    ]
  })
}

# 4. Maga a Lambda függvény a szükséges környezeti változókkal
resource "aws_lambda_function" "websocket_handler" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "WebSocketChatHandler"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "app.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.9"

  environment {
    variables = {
      TABLE_NAME   = aws_dynamodb_table.websocket_connections.name
      IMAGE_BUCKET = aws_s3_bucket.chat_images.id
    }
  }
}