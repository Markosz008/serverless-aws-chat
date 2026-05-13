# 1. Az API Gateway (WebSocket típus)
resource "aws_apigatewayv2_api" "websocket_api" {
  name          = "serverless-chat-api"
  protocol_type = "WEBSOCKET"
  # JSON-ben az 'action' mező fogja eldönteni a route-ot
  route_selection_expression = "$request.body.action"
}

# 2. Integráció: Összekötjük az API Gateway-t a Lambdával
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.websocket_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.websocket_handler.invoke_arn
}

# 3. Route-ok (Útvonalak)

# Kapcsolódás
resource "aws_apigatewayv2_route" "connect" {
  api_id    = aws_apigatewayv2_api.websocket_api.id
  route_key = "$connect"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# Szétkapcsolás
resource "aws_apigatewayv2_route" "disconnect" {
  api_id    = aws_apigatewayv2_api.websocket_api.id
  route_key = "$disconnect"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# Üzenetküldés
resource "aws_apigatewayv2_route" "send_message" {
  api_id    = aws_apigatewayv2_api.websocket_api.id
  route_key = "sendMessage"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# Név megadása / Belépés
resource "aws_apigatewayv2_route" "join" {
  api_id    = aws_apigatewayv2_api.websocket_api.id
  route_key = "join"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# JAVÍTÁS: ÚJ ROUTE a képfeltöltési link igényléséhez
resource "aws_apigatewayv2_route" "get_upload_url" {
  api_id    = aws_apigatewayv2_api.websocket_api.id
  route_key = "getUploadUrl"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# JAVÍTÁS: BIZTONSÁGI ROUTE minden egyéb üzenethez
resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.websocket_api.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# 4. Stage (Auto-deploy bekapcsolva)
resource "aws_apigatewayv2_stage" "prod" {
  api_id      = aws_apigatewayv2_api.websocket_api.id
  name        = "production"
  auto_deploy = true
}

# 5. Engedély: Az API Gateway lefuttathatja a Lambdánkat
resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.websocket_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.websocket_api.execution_arn}/*/*"
}

# 6. OUTPUT: A WSS link
output "websocket_url" {
  value       = "${aws_apigatewayv2_api.websocket_api.api_endpoint}/${aws_apigatewayv2_stage.prod.name}"
  description = "WebSocket API URL"
}