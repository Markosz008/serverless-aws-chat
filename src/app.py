# src/app.py
import json
import boto3
import os

# Kapcsolódás a DynamoDB-hez
dynamodb = boto3.client('dynamodb')
TABLE_NAME = os.environ.get('TABLE_NAME', 'websocket-connections')

def lambda_handler(event, context):
    # Az API Gateway elküldi nekünk, hogy milyen esemény történt, és ki az
    route_key = event.get('requestContext', {}).get('routeKey')
    connection_id = event.get('requestContext', {}).get('connectionId')

    # 1. Valaki megnyitotta a weboldalt ($connect)
    if route_key == '$connect':
        dynamodb.put_item(
            TableName=TABLE_NAME, 
            Item={'connectionId': {'S': connection_id}}
        )
        return {'statusCode': 200, 'body': 'Connected'}

    # 2. Valaki bezárta a weboldalt ($disconnect)
    elif route_key == '$disconnect':
        dynamodb.delete_item(
            TableName=TABLE_NAME, 
            Key={'connectionId': {'S': connection_id}}
        )
        return {'statusCode': 200, 'body': 'Disconnected'}

    # 3. Valaki küldött egy üzenetet a chatbe (sendMessage)
    elif route_key == 'sendMessage':
        domain = event.get('requestContext', {}).get('domainName')
        stage = event.get('requestContext', {}).get('stage')
        apigw_management = boto3.client('apigatewaymanagementapi', endpoint_url=f'https://{domain}/{stage}')

        body = json.loads(event.get('body', '{}'))
        message = body.get('message', 'Üres üzenet')
        
        # ÚJ: Megnézzük, küldött-e a felhasználó saját nevet. Ha nem, marad a generált.
        username = body.get('username', f"User_{connection_id[-6:]}")

        response = dynamodb.scan(TableName=TABLE_NAME)
        
        for item in response.get('Items', []):
            conn_id = item['connectionId']['S']
            try:
                # A payload már tartalmazza az egyedi nevet is!
                payload = {
                    'sender': username,
                    'message': message
                }
                apigw_management.post_to_connection(
                    ConnectionId=conn_id, 
                    Data=json.dumps(payload).encode('utf-8')
                )
            except Exception as e:
                dynamodb.delete_item(TableName=TABLE_NAME, Key={'connectionId': {'S': conn_id}})

        return {'statusCode': 200, 'body': 'Message broadcasted'}

    # Ha valami ismeretlen kérés jön
    return {'statusCode': 400, 'body': 'Unknown route'}