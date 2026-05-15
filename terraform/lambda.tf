# Adatforrások a pontos azonosítókhoz
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# --- ÚJ: Beolvassuk a titkosított VAPID kulcsot az AWS SSM Parameter Store-ból ---
data "aws_ssm_parameter" "vapid_private_key" {
  name            = "/chat/prod/vapid_private_key"
  with_decryption = true
}

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
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
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
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "transcribe:StartTranscriptionJob",
          "transcribe:GetTranscriptionJob"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["polly:SynthesizeSpeech"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:DeleteItem",
          "dynamodb:Scan",
          "dynamodb:UpdateItem",
          "dynamodb:Query"
        ]
        Resource = [
          aws_dynamodb_table.websocket_connections.arn,
          aws_dynamodb_table.messages_table.arn,
          aws_dynamodb_table.rooms_table.arn,
          aws_dynamodb_table.push_subscriptions.arn
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["execute-api:ManageConnections"]
        Resource = "arn:aws:execute-api:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:*/*"
      },
      {
        Effect = "Allow"
        Action = ["s3:PutObject", "s3:PutObjectAcl", "s3:GetObject", "s3:ListBucket"]
        Resource = [
          "${aws_s3_bucket.chat_images.arn}",
          "${aws_s3_bucket.chat_images.arn}/*",
          "${aws_s3_bucket.avatar_bucket.arn}",
          "${aws_s3_bucket.avatar_bucket.arn}/*"
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
  runtime          = "python3.12"

  timeout     = 30
  
  # --- ÚJ: Memória megemelése 512MB-ra a gyorsabb betöltéshez ---
  memory_size = 512

  layers = [aws_lambda_layer_version.webpush_layer.arn]

  environment {
    variables = {
      CONNECTIONS_TABLE   = aws_dynamodb_table.websocket_connections.name
      MESSAGES_TABLE      = aws_dynamodb_table.messages_table.name
      ROOMS_TABLE         = aws_dynamodb_table.rooms_table.name
      IMAGE_BUCKET        = aws_s3_bucket.chat_images.id
      AVATAR_BUCKET       = aws_s3_bucket.avatar_bucket.id
      SUBSCRIPTIONS_TABLE = aws_dynamodb_table.push_subscriptions.name
      
      # --- ÚJ: Biztonságos hivatkozás a Parameter Store-ra ---
      VAPID_PRIVATE_KEY   = data.aws_ssm_parameter.vapid_private_key.value
      VAPID_CONTACT_EMAIL = "mailto:admin@sajat-domained.hu" 
    }
  }
}