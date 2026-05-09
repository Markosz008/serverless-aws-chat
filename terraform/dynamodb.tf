# terraform/dynamodb.tf

resource "aws_dynamodb_table" "websocket_connections" {
  name           = "websocket-connections"
  billing_mode   = "PAY_PER_REQUEST" # Nem foglalunk le kapacitást előre, csak a kérésekért fizetünk (ingyenes tierbe bőven belefér)
  hash_key       = "connectionId"    # Ez lesz a tábla elsődleges kulcsa

  attribute {
    name = "connectionId"
    type = "S" # "S" mint String (szöveg)
  }

  tags = {
    Name = "Serverless-WebSocket-Table"
  }
}