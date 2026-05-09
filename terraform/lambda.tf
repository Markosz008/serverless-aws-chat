# 1. Automatikusan becsomagoljuk a Python kódunkat egy ZIP fájlba
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../src/app.py" # Megkeresi a kódot a src mappában
  output_path = "${path.module}/lambda_function.zip"
}

# 2. IAM Role: Megengedjük a Lambdának, hogy fusson
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

# 3. IAM Policy: Jogosultságok (Logolás + DynamoDB + API Gateway üzenetküldés)
resource "aws_iam_role_policy" "lambda_policy" {
  name = "websocket_lambda_policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = ["dynamodb:PutItem", "dynamodb:DeleteItem", "dynamodb:Scan"]
        Resource = aws_dynamodb_table.websocket_connections.arn
      },
      {
        # EZ A VARÁZSLAT: Ezzel tud a Lambda visszaszólni a WebSocket klienseknek!
        Effect = "Allow"
        Action = ["execute-api:ManageConnections"]
        Resource = "arn:aws:execute-api:*:*:**/@connections/*"
      }
    ]
  })
}

# 4. Maga a Lambda függvény
resource "aws_lambda_function" "websocket_handler" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "WebSocketChatHandler"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "app.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.9"

  # Átadjuk neki a DynamoDB tábla nevét környezeti változóként
  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.websocket_connections.name
    }
  }
}