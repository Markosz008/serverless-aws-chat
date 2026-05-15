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

# --- ÚJ: Importáljuk a webpush könyvtárat a Layerből ---
from pywebpush import webpush, WebPushException

s3_config = Config(signature_version='s3v4')
dynamodb = boto3.client('dynamodb')
s3_client = boto3.client('s3', config=s3_config)

CONNECTIONS_TABLE = os.environ.get('CONNECTIONS_TABLE', 'websocket-connections')
MESSAGES_TABLE = os.environ.get('MESSAGES_TABLE', 'chat-messages')
ROOMS_TABLE = os.environ.get('ROOMS_TABLE', 'chat-rooms')
IMAGE_BUCKET = os.environ.get('IMAGE_BUCKET')
AVATAR_BUCKET = os.environ.get('AVATAR_BUCKET', IMAGE_BUCKET)

# --- ÚJ: Változók a Push értesítésekhez ---
SUBSCRIPTIONS_TABLE = os.environ.get('SUBSCRIPTIONS_TABLE', 'chat-push-subscriptions')
VAPID_PRIVATE_KEY = os.environ.get('VAPID_PRIVATE_KEY')
VAPID_CONTACT_EMAIL = os.environ.get('VAPID_CONTACT_EMAIL', 'mailto:admin@example.com')

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

        # --- ÚJ: Push feliratkozás mentése a DynamoDB-be ---
        if action == 'savePushSub':
            username = body.get('username')
            subscription = body.get('subscription')
            if username and subscription:
                try:
                    dynamodb.put_item(
                        TableName=SUBSCRIPTIONS_TABLE,
                        Item={
                            'username': {'S': username},
                            'subscription': {'S': json.dumps(subscription)}
                        }
                    )
                    print(f"Push engedély elmentve {username} számára.")
                except Exception as e:
                    print(f"Hiba a push engedély mentésekor: {e}")
            return {'statusCode': 200}

        elif action == 'join':
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
                    
                    current_time = int(time.time())
                    
                    for item in res.get('Items', []):
                        exp = item.get('expiresAt', {}).get('N')
                        if exp and int(exp) < current_time:
                            continue
                            
                        m = {
                            'msgId': item.get('msgId', {}).get('S'),
                            'sender': item.get('sender', {}).get('S'),
                            'deviceId': item.get('deviceId', {}).get('S', 'unknown'),
                            'message': item.get('message', {}).get('S'),
                            'timestamp': int(item.get('timestamp', {}).get('N', 0)),
                            'isRead': item.get('isRead', {}).get('BOOL', False)
                        }
                        if item.get('audioUrl'): m['audioUrl'] = item['audioUrl']['S']
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
            
            is_secret = body.get('isSecretMode', False)
            
            timestamp = int(time.time() * 1000)
            
            if is_secret:
                expires_at = int(time.time()) + (5 * 60)
            else:
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
                is_secret = body.get('isSecretMode', False)
                if is_secret:
                    if apigw_management: 
                        apigw_management.post_to_connection(
                            ConnectionId=connection_id, 
                            Data=json.dumps({'type': 'error', 'message': '🔒 A Kalandmester nincs jelen a Titkos módban!'}).encode('utf-8')
                        )
                    return {'statusCode': 200}
                prompt = message.replace('/kaland', '').strip()
                ai_message = ""
                audio_url = None 
                
                try:
                    bedrock = boto3.client('bedrock-runtime', region_name='eu-central-1')
                    model_arn = 'arn:aws:bedrock:eu-central-1:682356774927:inference-profile/eu.anthropic.claude-haiku-4-5-20251001-v1:0'
                    messages_payload = [{"role": "user", "content": [{"text": f"Te egy magyar nyelvű humoros, titokzatos Kalandmester (Dungeon Master) vagy. Egy játékos ezt lépi a kalandban: '{prompt}'. Reagálj rá izgalmasan, fantázia stílusban maximum 3 mondatban, és tegyél fel neki egy újabb kérdést vagy kihívást!"}]}]
                    resp = bedrock.converse(modelId=model_arn, messages=messages_payload, inferenceConfig={"maxTokens": 400})
                    ai_message = resp['output']['message']['content'][0]['text']
                    
                    translate_payload = [{"role": "user", "content": [{"text": f"Translate this Hungarian fantasy text to epic British English. CRITICAL INSTRUCTION: Ignore all emojis completely! Do NOT write the word 'emoji'. Do NOT describe the emojis. Just translate the spoken words. Text to translate: {ai_message}"}]}]
                    trans_resp = bedrock.converse(modelId=model_arn, messages=translate_payload, inferenceConfig={"maxTokens": 400})
                    english_audio_text = trans_resp['output']['message']['content'][0]['text'].strip()
                    
                    english_audio_text = re.sub(r'\[.*?\]', '', english_audio_text)
                    english_audio_text = re.sub(r'\(.*?\)', '', english_audio_text)
                    english_audio_text = english_audio_text.replace('emoji', '').replace('Emoji', '')
                    
                    polly = boto3.client('polly', region_name='eu-central-1')
                    
                    safe_text = english_audio_text.replace('&', 'and').replace('<', '').replace('>', '')
                    ssml_text = f'<speak>{safe_text}</speak>'
                    
                    polly_res = polly.synthesize_speech(
                        Text=ssml_text,
                        OutputFormat='mp3',
                        TextType='ssml',
                        VoiceId='Arthur', 
                        Engine='neural'
                    )
                    
                    audio_key = f"kaland_audio_{uuid.uuid4()}.mp3"
                    s3_client.put_object(
                        Bucket=IMAGE_BUCKET, 
                        Key=audio_key, 
                        Body=polly_res['AudioStream'].read(), 
                        ContentType='audio/mpeg'
                    )
                    
                    audio_url = f"https://s3.eu-central-1.amazonaws.com/{IMAGE_BUCKET}/{audio_key}"

                except Exception as e:
                    print(f"BEDROCK/POLLY HIBA: {str(e)}")
                    ai_message = f"🧙‍♂️ Rendszerhiba a Kalandmesternél... Hiba: {str(e)[:50]}"
                
                ai_msg_id = str(uuid.uuid4())
                ai_timestamp = timestamp + 1
                ai_sender = "🧙‍♂️ Kalandmester|ai"
                
                ai_item = {
                    'room': {'S': room}, 'timestamp': {'N': str(ai_timestamp)}, 'msgId': {'S': ai_msg_id},
                    'sender': {'S': ai_sender}, 'deviceId': {'S': 'AI_BOT'}, 'message': {'S': ai_message}, 
                    'expiresAt': {'N': str(expires_at)}, 'isRead': {'BOOL': False}
                }
                
                if audio_url:
                    ai_item['audioUrl'] = {'S': audio_url}
                    
                dynamodb.put_item(TableName=MESSAGES_TABLE, Item=ai_item)
                
                broadcast_payload = {
                    'type': 'chat', 'msgId': ai_msg_id, 'sender': ai_sender, 
                    'deviceId': 'AI_BOT', 'message': ai_message, 'timestamp': ai_timestamp
                }
                if audio_url:
                    broadcast_payload['audioUrl'] = audio_url
                    
                if apigw_management: 
                    broadcast(apigw_management, broadcast_payload, room)

            elif message.strip().startswith('/kep'):
                is_secret = body.get('isSecretMode', False)
                if is_secret:
                    if apigw_management: 
                        apigw_management.post_to_connection(
                            ConnectionId=connection_id, 
                            Data=json.dumps({'type': 'error', 'message': '🔒 A Kalandmester nincs jelen a Titkos módban!'}).encode('utf-8')
                        )
                    return {'statusCode': 200}
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
            
            print(f"[DEBUG] markRead hívás érkezett: msgId={msg_id}, timestamp={ts}")
            
            if msg_id and ts:
                try: 
                    dynamodb.update_item(
                        TableName=MESSAGES_TABLE, 
                        Key={'room': {'S': room}, 'timestamp': {'N': str(ts)}}, 
                        UpdateExpression="SET isRead = :r", 
                        ExpressionAttributeValues={':r': {'BOOL': True}}
                    )
                    print("[DEBUG] DynamoDB sikeresen frissítve (isRead=True).")
                except Exception as e: 
                    print(f"[ERROR] DynamoDB markRead mentési hiba: {str(e)}")
                    
            if apigw_management: 
                try:
                    broadcast(apigw_management, {'type': 'msgRead', 'msgId': msg_id}, room)
                except Exception as e:
                    print(f"[ERROR] Broadcast markRead hiba: {str(e)}")

        elif action == 'deleteMessage':
            msg_id = body.get('msgId')
            ts = body.get('timestamp')
            room = body.get('room', 'main')
            sender = body.get('username')
            
            print(f"[DEBUG] Visszavonás kérés: msgId={msg_id}")
            if msg_id and ts and sender:
                try:
                    item_resp = dynamodb.get_item(TableName=MESSAGES_TABLE, Key={'room': {'S': room}, 'timestamp': {'N': str(ts)}})
                    item = item_resp.get('Item')
                    
                    if item:
                        db_sender = item.get('sender', {}).get('S', '')
                        if db_sender.split('|')[0] == sender.split('|')[0]:
                            
                            # JAVÍTÁS: Logikai törlés! Nem töröljük a sort, 
                            # csak átírjuk a szövegét "DELETED_MSG"-re és levesszük a reakciókat.
                            dynamodb.update_item(
                                TableName=MESSAGES_TABLE, 
                                Key={'room': {'S': room}, 'timestamp': {'N': str(ts)}},
                                UpdateExpression="SET message = :m REMOVE reactions",
                                ExpressionAttributeValues={':m': {'S': 'DELETED_MSG'}}
                            )
                            print("[DEBUG] Üzenet logikailag törölve (DELETED_MSG).")
                            
                            if apigw_management:
                                broadcast(apigw_management, {'type': 'deleteMessage', 'msgId': msg_id}, room)
                        else:
                            print(f"[WARNING] Törlés elutasítva: {db_sender} nem egyenlő {sender}")
                except Exception as e:
                    print(f"[ERROR] DynamoDB törlési hiba: {str(e)}")

        elif action == 'editMessage':
            msg_id = body.get('msgId')
            ts = body.get('timestamp')
            room = body.get('room', 'main')
            sender = body.get('username')
            new_message = body.get('newMessage')
            
            print(f"[DEBUG] Módosítás kérés: msgId={msg_id}")
            if msg_id and ts and sender and new_message:
                try:
                    item_resp = dynamodb.get_item(TableName=MESSAGES_TABLE, Key={'room': {'S': room}, 'timestamp': {'N': str(ts)}})
                    item = item_resp.get('Item')
                    
                    if item:
                        db_sender = item.get('sender', {}).get('S', '')
                        # Csak a saját üzenetét módosíthatja
                        if db_sender.split('|')[0] == sender.split('|')[0]:
                            dynamodb.update_item(
                                TableName=MESSAGES_TABLE, 
                                Key={'room': {'S': room}, 'timestamp': {'N': str(ts)}},
                                UpdateExpression="SET message = :m, isEdited = :e",
                                ExpressionAttributeValues={':m': {'S': new_message}, ':e': {'BOOL': True}}
                            )
                            print("[DEBUG] Üzenet sikeresen módosítva.")
                            
                            if apigw_management:
                                broadcast(apigw_management, {'type': 'editMessage', 'msgId': msg_id, 'newMessage': new_message}, room)
                        else:
                            print(f"[WARNING] Módosítás elutasítva: {db_sender} nem egyenlő {sender}")
                except Exception as e:
                    print(f"[ERROR] DynamoDB módosítási hiba: {str(e)}")

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
                        if emoji not in reactions_data:
                            reactions_data[emoji] = []
                        if is_add and username not in reactions_data[emoji]:
                            reactions_data[emoji].append(username)
                        elif not is_add and username in reactions_data[emoji]:
                            reactions_data[emoji].remove(username)
                        if not reactions_data[emoji]:
                            del reactions_data[emoji]
                        dynamodb.update_item(
                            TableName=MESSAGES_TABLE,
                            Key={'room': {'S': room}, 'timestamp': {'N': str(ts)}},
                            UpdateExpression="SET reactions = :r",
                            ExpressionAttributeValues={':r': {'S': json.dumps(reactions_data)}}
                        )
                except Exception as e:
                    print("Reaction save error:", str(e))

            if apigw_management:
                broadcast(apigw_management, {'type': 'reaction', 'msgId': msg_id, 'emoji': emoji, 'isAdd': is_add, 'username': username}, room)

        elif action == 'roomInvite':
            target_user = body.get('targetUser', '')
            sender      = body.get('username')
            room        = body.get('room', 'main')
            password    = body.get('password', '') 
            if apigw_management:
                conns = dynamodb.scan(TableName=CONNECTIONS_TABLE).get('Items', [])
                for c in conns:
                    conn_user = c.get('username', {}).get('S', '')
                    if conn_user.split('|')[0] == target_user.split('|')[0]:
                        try:
                            apigw_management.post_to_connection(
                                ConnectionId=c['connectionId']['S'],
                                Data=json.dumps({
                                    'type': 'roomInvite',
                                    'sender': sender,
                                    'room': room,
                                    'password': password 
                                }).encode('utf-8')
                            )
                        except: pass

        elif action == 'getUploadUrl':
            try:
                safe_name = f"{uuid.uuid4()}_{body.get('fileName', 'file')}"
                url = boto3.client('s3', region_name='eu-central-1', config=Config(signature_version='s3v4', s3={'addressing_style': 'path'})).generate_presigned_url('put_object', Params={'Bucket': IMAGE_BUCKET, 'Key': safe_name, 'ContentType': body.get('contentType', 'application/octet-stream')}, ExpiresIn=300)
                if apigw_management: apigw_management.post_to_connection(ConnectionId=connection_id, Data=json.dumps({'uploadUrl': url, 'fileUrl': f"https://s3.eu-central-1.amazonaws.com/{IMAGE_BUCKET}/{safe_name}"}))
            except Exception as e: print(f"S3 Hiba: {str(e)}")

        elif action == 'getAvatarUploadUrl':
            try:
                safe_name = f"avatars/{uuid.uuid4()}_{body.get('fileName', 'avatar.jpg')}"
                url = boto3.client('s3', region_name='eu-central-1',
                    config=Config(signature_version='s3v4', s3={'addressing_style': 'path'})
                ).generate_presigned_url('put_object',
                    Params={'Bucket': AVATAR_BUCKET, 'Key': safe_name, 'ContentType': body.get('contentType', 'image/jpeg')},
                    ExpiresIn=300
                )
                file_url = f"https://s3.eu-central-1.amazonaws.com/{AVATAR_BUCKET}/{safe_name}"
                if apigw_management:
                    apigw_management.post_to_connection(
                        ConnectionId=connection_id,
                        Data=json.dumps({'avatarUploadUrl': url, 'avatarFileUrl': file_url}).encode('utf-8')
                    )
            except Exception as e:
                print(f"Avatar S3 hiba: {e}")

        return {'statusCode': 200}
    return {'statusCode': 400}

def broadcast(apigw_management, payload, target_room):
    # 1. Lekérjük a kapcsolatokat az adatbázisból
    online_connections = dynamodb.scan(TableName=CONNECTIONS_TABLE).get('Items', [])
    successful_base_users = set() # ÚJ: Csak a neveket tároljuk avatar nélkül!

    for item in online_connections:
        if item.get('room', {}).get('S', 'main') == target_room:
            username_full = item.get('username', {}).get('S')
            try: 
                # Megpróbáljuk elküldeni az üzenetet WebSocketen
                apigw_management.post_to_connection(ConnectionId=item['connectionId']['S'], Data=json.dumps(payload).encode('utf-8'))
                if username_full:
                    # Levágjuk az avatart, csak a tiszta nevet mentjük el az online listába
                    successful_base_users.add(username_full.split('|')[0]) 
            except: 
                # Ha elhalt, töröljük a "szellem" kapcsolatot
                dynamodb.delete_item(TableName=CONNECTIONS_TABLE, Key={'connectionId': item['connectionId']})

    if payload.get('type') == 'chat' and VAPID_PRIVATE_KEY:
        try:
            sender_full = payload.get('sender', '')
            sender_base = sender_full.split('|')[0] # Csak a tiszta név, avatar nélkül
            msg_text = payload.get('message', '')
            
            if msg_text.startswith('U2FsdGVkX1'):
                msg_text = "🔒 Titkosított üzenet érkezett"
            elif 's3.eu-central-1.amazonaws.com' in msg_text:
                msg_text = "📸 Fájl vagy Hangüzenet érkezett"
            
            subscriptions = dynamodb.scan(TableName=SUBSCRIPTIONS_TABLE).get('Items', [])
            
            # --- ÚJ: Dedikált lista az egyedi eszközök (endpointok) követésére ---
            pushed_endpoints = set() 
            
            for sub_item in subscriptions:
                sub_username_full = sub_item.get('username', {}).get('S', '')
                sub_base = sub_username_full.split('|')[0] 
                
                if sub_base and sub_base not in successful_base_users and sub_base != sender_base:
                    sub_info_str = sub_item.get('subscription', {}).get('S')
                    if sub_info_str:
                        sub_info = json.loads(sub_info_str)
                        endpoint = sub_info.get('endpoint') # Ez a konkrét eszköz azonosítója
                        
                        # --- ÚJ: Csak akkor küldjük, ha erre az eszközre még NEM küldtük ki! ---
                        if endpoint and endpoint not in pushed_endpoints:
                            try:
                                webpush(
                                    subscription_info=sub_info,
                                    data=json.dumps({
                                        "title": f"Új üzenet: {sender_base} ({target_room})",
                                        "body": msg_text,
                                        "url": f"/?room={target_room}"
                                    }),
                                    vapid_private_key=VAPID_PRIVATE_KEY,
                                    vapid_claims={"sub": VAPID_CONTACT_EMAIL}
                                )
                                # Ha sikeres, felírjuk a listára, hogy ide már nem küldünk többet
                                pushed_endpoints.add(endpoint) 
                                print(f"Push sikeresen kiküldve: {sub_base}")
                            except WebPushException as ex:
                                if ex.response and ex.response.status_code in [404, 410]:
                                    dynamodb.delete_item(TableName=SUBSCRIPTIONS_TABLE, Key={'username': {'S': sub_username_full}})
        except Exception as e:
            print(f"Általános Push hiba: {e}")

def broadcast_user_list(apigw_management, target_room=None):
    items = dynamodb.scan(TableName=CONNECTIONS_TABLE).get('Items', [])
    users = [i['username']['S'] for i in items if 'username' in i and i['username']['S'] != 'Ismeretlen']
    users = list(set(users)) # Duplikációk kiszűrése
    
    payload = json.dumps({'type': 'userList', 'users': users}).encode('utf-8')
    
    # Mindenkinek elküldjük a teljes listát, hogy lehessen meghívót (roomInvite) küldeni!
    for item in items:
        try:
            apigw_management.post_to_connection(ConnectionId=item['connectionId']['S'], Data=payload)
        except Exception:
            dynamodb.delete_item(TableName=CONNECTIONS_TABLE, Key={'connectionId': item['connectionId']})