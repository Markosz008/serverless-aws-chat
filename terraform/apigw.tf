# 1. Az API Gateway (WebSocket típus)
resource "aws_apigatewayv2_api" "websocket_api" {
  name                       = "serverless-chat-api"
  protocol_type              = "WEBSOCKET"
  # JSON-ben az 'action' mező fogja eldönteni a route-ot (pl. {"action": "sendMessage", "message": "Szia"})
  route_selection_expression = "$request.body.action" 
}

# 2. Integráció: Összekötjük az API Gateway-t a Lambdával
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.websocket_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.websocket_handler.invoke_arn
}

# 3. Route-ok (Útvonalak)
resource "aws_apigatewayv2_route" "connect" {
  api_id    = aws_apigatewayv2_api.websocket_api.id
  route_key = "$connect"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_route" "disconnect" {
  api_id    = aws_apigatewayv2_api.websocket_api.id
  route_key = "$disconnect"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_route" "send_message" {
  api_id    = aws_apigatewayv2_api.websocket_api.id
  route_key = "sendMessage"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# 4. Deployment és Stage (Hogy kapjunk egy élő linket)
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

# 6. OUTPUT: Ezt a WSS linket fogjuk használni a teszteléshez!
output "websocket_url" {
  value       = "${aws_apigatewayv2_api.websocket_api.api_endpoint}/${aws_apigatewayv2_stage.prod.name}"
  description = "Ezt a linket használd a csatlakozáshoz (pl. wscat -c WSS_LINK)"
}