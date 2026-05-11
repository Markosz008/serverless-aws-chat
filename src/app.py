import json
import boto3
import os
import uuid
from botocore.config import Config

# FONTOS: S3v4 aláírás kényszerítése
s3_config = Config(signature_version='s3v4')
dynamodb = boto3.client('dynamodb')
s3_client = boto3.client('s3', config=s3_config)

TABLE_NAME = os.environ.get('TABLE_NAME', 'websocket-connections')
IMAGE_BUCKET = os.environ.get('IMAGE_BUCKET')

def lambda_handler(event, context):
    route_key = event.get('requestContext', {}).get('routeKey')
    connection_id = event.get('requestContext', {}).get('connectionId')
    domain = event.get('requestContext', {}).get('domainName')
    stage = event.get('requestContext', {}).get('stage')
    
    apigw_management = None
    if domain and stage:
        apigw_management = boto3.client('apigatewaymanagementapi', endpoint_url=f'https://{domain}/{stage}')

    if route_key == '$connect':
        dynamodb.put_item(TableName=TABLE_NAME, Item={'connectionId': {'S': connection_id}, 'username': {'S': 'Ismeretlen'}})
        return {'statusCode': 200}

    elif route_key == '$disconnect':
        dynamodb.delete_item(TableName=TABLE_NAME, Key={'connectionId': {'S': connection_id}})
        if apigw_management: broadcast_user_list(apigw_management)
        return {'statusCode': 200}

    if event.get('body'):
        body = json.loads(event.get('body', '{}'))
        action = body.get('action')

        if action == 'join':
            username = body.get('username', 'Anonim')
            dynamodb.update_item(
                TableName=TABLE_NAME,
                Key={'connectionId': {'S': connection_id}},
                UpdateExpression="SET username = :u",
                ExpressionAttributeValues={':u': {'S': username}}
            )
            if apigw_management: broadcast_user_list(apigw_management)

        elif action == 'sendMessage':
            payload = {
                'type': 'chat',
                'msgId': str(uuid.uuid4()), # Egyedi ID minden üzenetnek
                'sender': body.get('username', 'Anonim'),
                'message': body.get('message', ''),
                'msgType': 'text'
            }
            if apigw_management: broadcast(apigw_management, payload)

        elif action == 'sendReaction':
            # ITT A JAVÍTÁS: Továbbadjuk az "isAdd" paramétert, hogy tudja, ha levontál egyet
            payload = {
                'type': 'reaction',
                'msgId': body.get('msgId'),
                'emoji': body.get('emoji'),
                'isAdd': body.get('isAdd', True) 
            }
            if apigw_management: broadcast(apigw_management, payload)

        elif action == 'getUploadUrl':
            try:
                file_name = f"{uuid.uuid4()}.jpg"
                s3_client_simple = boto3.client('s3', 
                    region_name='eu-central-1',
                    config=Config(signature_version='s3v4', s3={'addressing_style': 'path'})
                )
                
                presigned_url = s3_client_simple.generate_presigned_url(
                    ClientMethod='put_object',
                    Params={'Bucket': IMAGE_BUCKET, 'Key': file_name}, 
                    ExpiresIn=300
                )

                if apigw_management:
                    apigw_management.post_to_connection(
                        ConnectionId=connection_id,
                        Data=json.dumps({
                            'uploadUrl': presigned_url,
                            'fileUrl': f"https://s3.eu-central-1.amazonaws.com/{IMAGE_BUCKET}/{file_name}"
                        })
                    )
            except Exception as e:
                print(f"HIBA tortent az S3-nal: {str(e)}")

        return {'statusCode': 200}

    return {'statusCode': 400}

def broadcast(apigw_management, payload):
    response = dynamodb.scan(TableName=TABLE_NAME)
    for item in response.get('Items', []):
        conn_id = item['connectionId']['S']
        try:
            apigw_management.post_to_connection(ConnectionId=conn_id, Data=json.dumps(payload).encode('utf-8'))
        except:
            dynamodb.delete_item(TableName=TABLE_NAME, Key={'connectionId': {'S': conn_id}})

def broadcast_user_list(apigw_management):
    response = dynamodb.scan(TableName=TABLE_NAME)
    users = list(set([item.get('username', {}).get('S', 'Ismeretlen') for item in response.get('Items', []) if item.get('username', {}).get('S') != 'Ismeretlen']))
    broadcast(apigw_management, {'type': 'userList', 'users': users})