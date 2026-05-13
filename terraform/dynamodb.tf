# terraform/dynamodb.tf

resource "aws_dynamodb_table" "websocket_connections" {
  name         = "websocket-connections"
  billing_mode = "PAY_PER_REQUEST" # Nem foglalunk le kapacitást előre, csak a kérésekért fizetünk (ingyenes tierbe bőven belefér)
  hash_key     = "connectionId"    # Ez lesz a tábla elsődleges kulcsa

  attribute {
    name = "connectionId"
    type = "S" # "S" mint String (szöveg)
  }

  tags = {
    Name = "Serverless-WebSocket-Table"
  }
}

resource "aws_dynamodb_table" "messages_table" {
  name         = "chat-messages"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "room"      # Partition key: Szoba azonosítója (pl. 'main')
  range_key    = "timestamp" # Sort key: Időrendi sorrendhez

  attribute {
    name = "room"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N" # Szám típus az időbélyegnek
  }

  tags = {
    Name = "Chat-Messages-History"
  }

  ttl {
    attribute_name = "expiresAt"
    enabled        = true
  }
}

resource "aws_dynamodb_table" "rooms_table" {
  name         = "chat-rooms"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "roomName"

  attribute {
    name = "roomName"
    type = "S"
  }

  tags = {
    Name = "Chat-Rooms-Passwords"
  }

  ttl {
    attribute_name = "expiresAt"
    enabled        = true
  }
}