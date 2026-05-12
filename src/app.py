import json
import boto3
import os
import uuid
import time
import re
import urllib.request
import urllib.parse
import base64
from botocore.config import Config

s3_config = Config(signature_version='s3v4')
dynamodb = boto3.client('dynamodb')
s3_client = boto3.client('s3', config=s3_config)

CONNECTIONS_TABLE = os.environ.get('CONNECTIONS_TABLE', 'websocket-connections')
MESSAGES_TABLE = os.environ.get('MESSAGES_TABLE', 'chat-messages')
ROOMS_TABLE = os.environ.get('ROOMS_TABLE', 'chat-rooms')
IMAGE_BUCKET = os.environ.get('IMAGE_BUCKET')

def get_meta_content(html, property_name):
    patterns = [
        f'<meta[^>]+property=["\']{property_name}["\'][^>]+content=["\'](.*?)["\']',
        f'<meta[^>]+content=["\'](.*?)["\'][^>]+property=["\']{property_name}["\']',
        f'<meta[^>]+name=["\']{property_name}["\'][^>]+content=["\'](.*?)["\']',
        f'<meta[^>]+content=["\'](.*?)["\'][^>]+name=["\']{property_name}["\']'
    ]
    for pattern in patterns:
        match = re.search(pattern, html, re.IGNORECASE | re.DOTALL)
        if match: return match.group(1)
    return None

def lambda_handler(event, context):
    route_key = event.get('requestContext', {}).get('routeKey')
    connection_id = event.get('requestContext', {}).get('connectionId')
    domain = event.get('requestContext', {}).get('domainName')
    stage = event.get('requestContext', {}).get('stage')
    
    apigw_management = None
    if domain and stage:
        apigw_management = boto3.client('apigatewaymanagementapi', endpoint_url=f'https://{domain}/{stage}')

    if route_key == '$connect':
        dynamodb.put_item(TableName=CONNECTIONS_TABLE, Item={'connectionId': {'S': connection_id}, 'username': {'S': 'Ismeretlen'}, 'room': {'S': 'main'}})
        return {'statusCode': 200}

    elif route_key == '$disconnect':
        old_item = dynamodb.get_item(TableName=CONNECTIONS_TABLE, Key={'connectionId': {'S': connection_id}}).get('Item', {})
        old_room = old_item.get('room', {}).get('S', 'main')
        dynamodb.delete_item(TableName=CONNECTIONS_TABLE, Key={'connectionId': {'S': connection_id}})
        if apigw_management: broadcast_user_list(apigw_management, old_room)
        return {'statusCode': 200}

    if event.get('body'):
        body = json.loads(event.get('body', '{}'))
        action = body.get('action')

        if action == 'join':
            username = body.get('username', 'Anonim')
            target_room = body.get('room', 'main')
            password = body.get('password', '')

            if target_room != 'main':
                room_item = dynamodb.get_item(TableName=ROOMS_TABLE, Key={'roomName': {'S': target_room}}).get('Item')
                if room_item:
                    if room_item.get('password', {}).get('S', '') != password:
                        if apigw_management: apigw_management.post_to_connection(ConnectionId=connection_id, Data=json.dumps({'type': 'error', 'message': 'Hibás jelszó a szobához!'}).encode('utf-8'))
                        return {'statusCode': 200}
                else:
                    dynamodb.put_item(TableName=ROOMS_TABLE, Item={'roomName': {'S': target_room}, 'password': {'S': password}})

            dynamodb.update_item(TableName=CONNECTIONS_TABLE, Key={'connectionId': {'S': connection_id}}, UpdateExpression="SET username = :u, room = :r", ExpressionAttributeValues={':u': {'S': username}, ':r': {'S': target_room}})

            if apigw_management: 
                apigw_management.post_to_connection(ConnectionId=connection_id, Data=json.dumps({'type': 'roomJoined', 'room': target_room}).encode('utf-8'))
                broadcast_user_list(apigw_management, target_room)
                try:
                    res = dynamodb.query(TableName=MESSAGES_TABLE, KeyConditionExpression="room = :r", ExpressionAttributeValues={":r": {"S": target_room}}, ScanIndexForward=False, Limit=100)
                    history = []
                    for item in res.get('Items', []):
                        m = {
                            'msgId': item.get('msgId', {}).get('S'),
                            'sender': item.get('sender', {}).get('S'),
                            'deviceId': item.get('deviceId', {}).get('S', 'unknown'),
                            'message': item.get('message', {}).get('S'),
                            'timestamp': int(item.get('timestamp', {}).get('N', 0)),
                            'isRead': item.get('isRead', {}).get('BOOL', False)
                        }
                        if item.get('replyTo'): m['replyTo'] = {'sender': item['replyTo']['M']['sender']['S'], 'message': item['replyTo']['M']['message']['S']}
                        if item.get('linkPreview'): m['linkPreview'] = json.loads(item['linkPreview']['S'])
                        if item.get('reactions'): m['reactions'] = json.loads(item['reactions']['S'])
                        history.append(m)
                    history.reverse()
                    if history: apigw_management.post_to_connection(ConnectionId=connection_id, Data=json.dumps({'type': 'history', 'messages': history}).encode('utf-8'))
                except Exception as e: print(f"History hiba: {e}")

        elif action == 'sendMessage':
            msg_id = str(uuid.uuid4())
            sender = body.get('username', 'Anonim')
            message = body.get('message', '')
            device_id = body.get('deviceId', 'unknown')
            reply_to = body.get('replyTo') 
            room = body.get('room', 'main') 
            temp_id = body.get('tempId') 
            timestamp = int(time.time() * 1000)
            expires_at = int(time.time()) + (30 * 24 * 60 * 60)

            link_preview = None
            urls = re.findall(r'(https?://[^\s]+)', message)
            if urls and not message.startswith('https://s3.'):
                target_url = urls[0]
                try:
                    if 'youtube.com' in target_url or 'youtu.be' in target_url:
                        oembed_url = f"https://www.youtube.com/oembed?url={urllib.parse.quote(target_url)}&format=json"
                        req = urllib.request.Request(oembed_url, headers={'User-Agent': 'Mozilla/5.0'})
                        with urllib.request.urlopen(req, timeout=1.5) as response:
                            yt_data = json.loads(response.read().decode('utf-8'))
                            link_preview = {'url': target_url, 'title': yt_data.get('title', '')[:100], 'image': yt_data.get('thumbnail_url', ''), 'description': yt_data.get('author_name', '')}
                    else:
                        req = urllib.request.Request(target_url, headers={'User-Agent': 'Mozilla/5.0'})
                        with urllib.request.urlopen(req, timeout=1.5) as response:
                            html = response.read(50000).decode('utf-8', errors='ignore')
                            title_match = re.search(r'<title>(.*?)</title>', html, re.I | re.DOTALL)
                            title = title_match.group(1).strip() if title_match else target_url
                            image = get_meta_content(html, 'og:image') or get_meta_content(html, 'twitter:image')
                            desc = get_meta_content(html, 'og:description') or get_meta_content(html, 'description')
                            if title or image: link_preview = {'url': target_url, 'title': title[:100], 'image': image, 'description': desc[:150] if desc else None}
                except: pass

            item_to_put = {
                'room': {'S': room}, 'timestamp': {'N': str(timestamp)}, 'msgId': {'S': msg_id},
                'sender': {'S': sender}, 'deviceId': {'S': device_id}, 'message': {'S': message}, 
                'expiresAt': {'N': str(expires_at)}, 'isRead': {'BOOL': False}
            }
            if reply_to: item_to_put['replyTo'] = {'M': {'sender': {'S': str(reply_to.get('sender', ''))}, 'message': {'S': str(reply_to.get('message', ''))}}}
            if link_preview: item_to_put['linkPreview'] = {'S': json.dumps(link_preview)}

            try:
                dynamodb.put_item(TableName=MESSAGES_TABLE, Item=item_to_put)
                if room != 'main': dynamodb.update_item(TableName=ROOMS_TABLE, Key={'roomName': {'S': room}}, UpdateExpression="SET expiresAt = :e", ExpressionAttributeValues={':e': {'N': str(expires_at)}})
            except: pass

            payload = {'type': 'chat', 'msgId': msg_id, 'sender': sender, 'deviceId': device_id, 'message': message, 'timestamp': timestamp}
            if temp_id: payload['tempId'] = temp_id 
            if link_preview: payload['linkPreview'] = link_preview
            if reply_to: payload['replyTo'] = reply_to
            if apigw_management: broadcast(apigw_management, payload, room)

            if message.strip().startswith('/kaland'):
                prompt = message.replace('/kaland', '').strip()
                ai_message = ""
                try:
                    bedrock = boto3.client('bedrock-runtime', region_name='eu-central-1')
                    model_arn = 'arn:aws:bedrock:eu-central-1:682356774927:inference-profile/eu.anthropic.claude-haiku-4-5-20251001-v1:0'
                    messages_payload = [{"role": "user", "content": [{"text": f"Te egy magyar nyelvű humoros, titokzatos Kalandmester (Dungeon Master) vagy. Egy játékos ezt lépi a kalandban: '{prompt}'. Reagálj rá izgalmasan, fantázia stílusban maximum 3 mondatban, és tegyél fel neki egy újabb kérdést vagy kihívást!"}]}]
                    resp = bedrock.converse(modelId=model_arn, messages=messages_payload, inferenceConfig={"maxTokens": 400})
                    ai_message = resp['output']['message']['content'][0]['text']
                except Exception as e:
                    print(f"BEDROCK HIBA: {str(e)}")
                    ai_message = f"🧙‍♂️ Rendszerhiba a Kalandmesternél... Hiba: {str(e)[:50]}"
                
                ai_msg_id = str(uuid.uuid4())
                ai_timestamp = timestamp + 1
                ai_sender = "🧙‍♂️ Kalandmester|ai"
                ai_item = {
                    'room': {'S': room}, 'timestamp': {'N': str(ai_timestamp)}, 'msgId': {'S': ai_msg_id},
                    'sender': {'S': ai_sender}, 'deviceId': {'S': 'AI_BOT'}, 'message': {'S': ai_message}, 
                    'expiresAt': {'N': str(expires_at)}, 'isRead': {'BOOL': False}
                }
                dynamodb.put_item(TableName=MESSAGES_TABLE, Item=ai_item)
                if apigw_management: broadcast(apigw_management, {'type': 'chat', 'msgId': ai_msg_id, 'sender': ai_sender, 'deviceId': 'AI_BOT', 'message': ai_message, 'timestamp': ai_timestamp}, room)

            elif message.strip().startswith('/kep'):
                raw_prompt = message.replace('/kep', '').strip()
                ai_message = ""
                try:
                    bedrock_translate = boto3.client('bedrock-runtime', region_name='eu-central-1')
                    translate_arn = 'arn:aws:bedrock:eu-central-1:682356774927:inference-profile/eu.anthropic.claude-haiku-4-5-20251001-v1:0'
                    translate_payload = [{"role": "user", "content": [{"text": f"Translate the following image generation prompt to English. Return ONLY the English translation, without any quotes or extra words: {raw_prompt}"}]}]
                    trans_resp = bedrock_translate.converse(modelId=translate_arn, messages=translate_payload, inferenceConfig={"maxTokens": 100})
                    english_prompt = trans_resp['output']['message']['content'][0]['text'].strip()
                    
                    bedrock_img = boto3.client('bedrock-runtime', region_name='us-west-2')
                    req_body = json.dumps({
                        "prompt": english_prompt,
                        "mode": "text-to-image",
                        "aspect_ratio": "1:1",
                        "output_format": "jpeg"
                    })
                    res = bedrock_img.invoke_model(
                        modelId='stability.stable-image-core-v1:1',
                        body=req_body,
                        accept='application/json',
                        contentType='application/json'
                    )
                    
                    res_body = json.loads(res['body'].read().decode('utf-8'))
                    if 'images' in res_body: base64_img = res_body['images'][0]
                    elif 'artifacts' in res_body: base64_img = res_body['artifacts'][0]['base64']
                    else: raise ValueError("Nem található képadat.")
                        
                    img_bytes = base64.b64decode(base64_img)
                    safe_name = f"aigenerated_{uuid.uuid4()}.jpg"
                    s3_client.put_object(Bucket=IMAGE_BUCKET, Key=safe_name, Body=img_bytes, ContentType='image/jpeg')
                    ai_message = f"https://s3.eu-central-1.amazonaws.com/{IMAGE_BUCKET}/{safe_name}"
                    
                except Exception as e:
                    print(f"BEDROCK IMAGE HIBA: {str(e)}")
                    ai_message = f"🎨 Hiba a képgenerálás során... Hiba: {str(e)[:50]}"
                
                ai_msg_id = str(uuid.uuid4())
                ai_timestamp = timestamp + 1
                ai_sender = "🎨 AI Művész|ai"
                ai_item = {
                    'room': {'S': room}, 'timestamp': {'N': str(ai_timestamp)}, 'msgId': {'S': ai_msg_id},
                    'sender': {'S': ai_sender}, 'deviceId': {'S': 'AI_BOT'}, 'message': {'S': ai_message}, 
                    'expiresAt': {'N': str(expires_at)}, 'isRead': {'BOOL': False}
                }
                dynamodb.put_item(TableName=MESSAGES_TABLE, Item=ai_item)
                if apigw_management: broadcast(apigw_management, {'type': 'chat', 'msgId': ai_msg_id, 'sender': ai_sender, 'deviceId': 'AI_BOT', 'message': ai_message, 'timestamp': ai_timestamp}, room)

        elif action == 'draw':
            room = body.get('room', 'main')
            payload = {'type': 'draw', 'sender': body.get('username'), 'x': body.get('x'), 'y': body.get('y'), 'color': body.get('color'), 'drawType': body.get('drawType')}
            if apigw_management: broadcast(apigw_management, payload, room)

        elif action == 'webrtcSignal':
            target_user = body.get('targetUser')
            sender = body.get('username')
            room = body.get('room', 'main')
            payload = {'type': 'webrtcSignal', 'sender': sender, 'deviceId': body.get('deviceId'), 'signal': body.get('signal')}
            if apigw_management:
                conns = dynamodb.scan(TableName=CONNECTIONS_TABLE).get('Items', [])
                for c in conns:
                    if c.get('username', {}).get('S') == target_user and c.get('room', {}).get('S', 'main') == room:
                        try: apigw_management.post_to_connection(ConnectionId=c['connectionId']['S'], Data=json.dumps(payload).encode('utf-8'))
                        except: pass

        elif action == 'markRead':
            msg_id = body.get('msgId')
            ts = body.get('timestamp')
            room = body.get('room', 'main')
            if msg_id and ts:
                try: dynamodb.update_item(TableName=MESSAGES_TABLE, Key={'room': {'S': room}, 'timestamp': {'N': str(ts)}}, UpdateExpression="SET isRead = :r", ExpressionAttributeValues={':r': {'BOOL': True}})
                except: pass
            if apigw_management: broadcast(apigw_management, {'type': 'msgRead', 'msgId': msg_id}, room)

        elif action == 'typing':
            if apigw_management: broadcast(apigw_management, {'type': 'typing', 'sender': body.get('username'), 'typing': body.get('typing')}, body.get('room', 'main'))

        elif action == 'sendReaction':
            msg_id = body.get('msgId')
            ts = body.get('timestamp')
            emoji = body.get('emoji')
            is_add = body.get('isAdd')
            room = body.get('room', 'main')
            username = body.get('username')
            
            if msg_id and ts and username:
                try:
                    item_resp = dynamodb.get_item(TableName=MESSAGES_TABLE, Key={'room': {'S': room}, 'timestamp': {'N': str(ts)}})
                    item = item_resp.get('Item')
                    if item:
                        reactions_str = item.get('reactions', {}).get('S', '{}')
                        reactions_data = json.loads(reactions_str)
                        if emoji not in reactions_data: reactions_data[emoji] = []
                        if is_add and username not in reactions_data[emoji]: reactions_data[emoji].append(username)
                        elif not is_add and username in reactions_data[emoji]: reactions_data[emoji].remove(username)
                        if not reactions_data[emoji]: del reactions_data[emoji]
                        dynamodb.update_item(TableName=MESSAGES_TABLE, Key={'room': {'S': room}, 'timestamp': {'N': str(ts)}}, UpdateExpression="SET reactions = :r", ExpressionAttributeValues={':r': {'S': json.dumps(reactions_data)}})
                except Exception as e: print("Reaction save error:", str(e))
            
            if apigw_management: broadcast(apigw_management, {'type': 'reaction', 'msgId': msg_id, 'emoji': emoji, 'isAdd': is_add, 'username': username}, room)

        elif action == 'getUploadUrl':
            try:
                safe_name = f"{uuid.uuid4()}_{body.get('fileName', 'file')}"
                url = boto3.client('s3', region_name='eu-central-1', config=Config(signature_version='s3v4', s3={'addressing_style': 'path'})).generate_presigned_url('put_object', Params={'Bucket': IMAGE_BUCKET, 'Key': safe_name, 'ContentType': body.get('contentType', 'application/octet-stream')}, ExpiresIn=300)
                if apigw_management: apigw_management.post_to_connection(ConnectionId=connection_id, Data=json.dumps({'uploadUrl': url, 'fileUrl': f"https://s3.eu-central-1.amazonaws.com/{IMAGE_BUCKET}/{safe_name}"}))
            except Exception as e: print(f"S3 Hiba: {str(e)}")

        return {'statusCode': 200}
    return {'statusCode': 400}

def broadcast(apigw_management, payload, target_room):
    for item in dynamodb.scan(TableName=CONNECTIONS_TABLE).get('Items', []):
        if item.get('room', {}).get('S', 'main') == target_room:
            try: apigw_management.post_to_connection(ConnectionId=item['connectionId']['S'], Data=json.dumps(payload).encode('utf-8'))
            except: dynamodb.delete_item(TableName=CONNECTIONS_TABLE, Key={'connectionId': item['connectionId']})

def broadcast_user_list(apigw_management, target_room):
    users = list(set([i['username']['S'] for i in dynamodb.scan(TableName=CONNECTIONS_TABLE).get('Items', []) if i.get('room', {}).get('S', 'main') == target_room and i['username']['S'] != 'Ismeretlen']))
    broadcast(apigw_management, {'type': 'userList', 'users': users}, target_room)