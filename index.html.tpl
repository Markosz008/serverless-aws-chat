<!DOCTYPE html>
<html lang="hu">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover, interactive-widget=resizes-content">
<title>AWS Chat</title>
<link rel="manifest" href="manifest.json">
<meta name="theme-color" content="#232f3e">
<link rel="apple-touch-icon" href="https://cdn-icons-png.flaticon.com/512/134/134808.png">
<style>
:root {
--bg-color: #f0f2f5; --container-bg: white; --text-color: #333;
--sidebar-bg: #232f3e; --sidebar-text: white; --header-bg: #232f3e;
--header-text: white; --input-bg: #fff; --border-color: #ddd;
--others-msg: #dcf8c6; --others-text: black; --mine-msg: #ff9900;
--mine-text: white; --system-text: #888; --app-height: 100dvh; 
}
[data-theme="dark"] {
--bg-color: #131921; --container-bg: #1a222d; --text-color: #f3f3f3;
--sidebar-bg: #0f141a; --input-bg: #232f3e; --border-color: #37475a;
--others-msg: #37475a; --others-text: white; --system-text: #aaa;
}

html, body { margin: 0; padding: 0; width: 100%; height: 100%; height: var(--app-height, 100%); overflow: hidden; background-color: var(--bg-color); font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; transition: background 0.3s; }
#app-container { width: 100%; height: 100%; max-width: 900px; margin: 0 auto; background: var(--container-bg); display: flex; flex-direction: row; overflow: hidden; position: relative; }

#login-screen { position: absolute; top: 0; left: 0; right: 0; bottom: 0; background: var(--container-bg); display: flex; flex-direction: column; justify-content: center; align-items: center; z-index: 20; }
#login-screen h2 { color: var(--text-color); margin-bottom: 20px; }
#username-input { padding: 12px; border: 1px solid var(--border-color); border-radius: 5px; width: 80%; max-width: 300px; margin-bottom: 15px; font-size: 16px; text-align: center; background: var(--container-bg); color: var(--text-color); }
#join-btn { background: #ff9900; color: white; border: none; padding: 12px 30px; border-radius: 25px; cursor: pointer; font-weight: bold; font-size: 16px; }

#sidebar { width: 220px; background: var(--sidebar-bg); color: var(--sidebar-text); display: flex; flex-direction: column; border-right: 1px solid var(--border-color); flex-shrink: 0; }
#sidebar h3 { padding: 12px; margin: 0; font-size: 13px; text-transform: uppercase; border-bottom: 1px solid rgba(255,255,255,0.1); color: #ff9900; text-align: center; background: rgba(0,0,0,0.2); letter-spacing: 1px; }
#user-list, #room-list { list-style: none; padding: 0; margin: 0; overflow-y: auto; flex: 1; }
#room-list { flex: 0.6; border-bottom: 2px solid rgba(0,0,0,0.2); background: rgba(0,0,0,0.05); }

#user-list li { padding: 10px 15px; font-size: 14px; display: flex; align-items: center; justify-content: space-between; border-bottom: 1px solid rgba(255,255,255,0.05); }
#user-list li span.user-name::before { display: none; }

.room-item { padding: 12px 15px; font-size: 14px; display: flex; align-items: center; border-bottom: 1px solid rgba(255,255,255,0.05); cursor: pointer; transition: 0.2s; position: relative; }
.room-item:hover { background: rgba(255,153,0,0.15); color: #ff9900; }
.room-item::before { content: "#"; margin-right: 10px; font-size: 16px; opacity: 0.5; }
.room-item.active-room { background: rgba(255,153,0,0.25); color: #ff9900; font-weight: bold; border-left: 4px solid #ff9900; }

#chat-area { flex: 1; display: flex; flex-direction: column; background: var(--container-bg); min-width: 0; min-height: 0; position: relative; }
#header { background: var(--header-bg); color: var(--header-text); padding: 10px 15px; display: flex; justify-content: space-between; align-items: center; font-weight: bold; flex-shrink: 0; gap: 5px; flex-wrap: wrap; }
#messages { flex: 1; padding: 15px; overflow-y: auto; display: flex; flex-direction: column; gap: 10px; -webkit-overflow-scrolling: touch; }

#nav-notif { display: none; background: #ff3b30; color: white; border-radius: 50%; width: 18px; height: 18px; font-size: 11px; text-align: center; line-height: 18px; margin-left: 5px; position: absolute; top: 8px; left: 60px; }
#typing-indicator { height: 20px; padding: 0 15px; font-size: 12px; color: var(--system-text); font-style: italic; transition: 0.3s opacity; opacity: 0; }

.link-card { background: rgba(0,0,0,0.05); border-radius: 8px; border-left: 3px solid #ff9900; margin-top: 8px; overflow: hidden; max-width: 250px; font-size: 13px; text-decoration: none; color: inherit; display: block; }
[data-theme="dark"] .link-card { background: rgba(255,255,255,0.08); }
.link-card img { width: 100%; height: 120px; object-fit: cover; margin-top: 0 !important; border-radius: 0 !important; }
.link-card-content { padding: 8px; }
.link-card-title { font-weight: bold; margin-bottom: 4px; display: block; color: #ff9900; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.link-card-desc { opacity: 0.8; font-size: 11px; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; }

/* AVATAR CSS */
.message-row { display: flex; align-items: flex-end; gap: 8px; margin-bottom: 5px; width: 100%; }
.message-row.mine { flex-direction: row-reverse; }
.avatar-img { width: 32px; height: 32px; border-radius: 50%; flex-shrink: 0; box-shadow: 0 2px 5px rgba(0,0,0,0.15); background: #eee; }
.message-wrapper { flex: 1; display: flex; flex-direction: column; }

.mine-wrapper { align-items: flex-end; }
.others-wrapper { align-items: flex-start; }
.reaction-container { display: flex; flex-wrap: wrap; gap: 4px; margin-top: -8px; z-index: 5; padding: 0 10px; }
.reaction-badge { background: var(--container-bg); border: 1px solid var(--border-color); border-radius: 12px; padding: 2px 6px; font-size: 12px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); color: var(--text-color); cursor: pointer; transition: 0.2s; }
.reaction-badge:hover { transform: scale(1.1); }
.reaction-badge.reacted { background: rgba(255, 153, 0, 0.15); border-color: #ff9900; }

#menu-overlay { display: none; position: fixed; top: 0; left: 0; right: 0; bottom: 0; z-index: 8000; }
.reaction-menu { display: none; position: fixed; background: var(--container-bg); border: 1px solid var(--border-color); border-radius: 30px; padding: 8px 15px; box-shadow: 0 4px 25px rgba(0,0,0,0.4); z-index: 9000; gap: 15px; align-items: center; }
.reaction-menu span { font-size: 26px; cursor: pointer; transition: transform 0.1s; display: inline-block; }
.reaction-menu span:hover { transform: scale(1.3); }

/* Játék Menü */
#game-menu { display: none; position: absolute; background: var(--container-bg); border: 1px solid var(--border-color); border-radius: 15px; padding: 5px 0; box-shadow: 0 -4px 15px rgba(0,0,0,0.2); z-index: 9000; flex-direction: column; bottom: 65px; right: 10px; }
#game-menu div { padding: 12px 20px; cursor: pointer; font-weight: bold; color: var(--text-color); border-bottom: 1px solid var(--border-color); }
#game-menu div:last-child { border-bottom: none; }
#game-menu div:hover { background: rgba(255,153,0,0.1); color: #ff9900; }

/* Rajztábla UI */
#whiteboard-container { display: none; position: absolute; top: 0; left: 0; width: 100%; height: 100%; background: var(--bg-color); z-index: 8500; flex-direction: column; align-items: center; justify-content: flex-start; }
#whiteboard-header { padding: 10px 15px; background: var(--header-bg); color: white; display: flex; justify-content: space-between; align-items: center; font-weight: bold; width: 100%; box-sizing: border-box; }
#drawing-board { cursor: crosshair; background: white; border-radius: 10px; box-shadow: 0 0 20px rgba(0,0,0,0.3); margin-top: 10px; touch-action: none; }

.desktop-react-btn, .desktop-reply-btn { position: absolute; top: 50%; transform: translateY(-50%); background: var(--container-bg); border: 1px solid var(--border-color); border-radius: 50%; width: 32px; height: 32px; display: none; align-items: center; justify-content: center; cursor: pointer; box-shadow: 0 2px 5px rgba(0,0,0,0.1); z-index: 10; font-size: 16px; }
.message-wrapper:hover .desktop-react-btn, .message-wrapper:hover .desktop-reply-btn { display: flex; }
.mine .desktop-react-btn { left: -40px; }
.mine .desktop-reply-btn { left: -80px; }
.others .desktop-react-btn { right: -40px; }
.others .desktop-reply-btn { right: -80px; }

.message { padding: 10px 15px; border-radius: 15px; max-width: 80%; word-wrap: break-word; font-size: 15px; position: relative; -webkit-touch-callout: none; -webkit-user-select: none; user-select: none; }
.message img { max-width: 200px; max-height: 200px; object-fit: cover; border-radius: 10px; margin-top: 5px; display: block; cursor: zoom-in; background: #eee; }
audio { max-width: 220px; height: 40px; margin-top: 5px; outline: none; }

.message.system { background: transparent; color: var(--system-text); font-size: 0.85em; text-align: center; align-self: center; margin: 5px 0; }
.message.mine { background: var(--mine-msg); color: var(--mine-text); border-bottom-right-radius: 3px; }
.message.others { background: var(--others-msg); color: var(--others-text); border-bottom-left-radius: 3px; }
.message.others .sender-name { font-size: 0.75em; font-weight: bold; opacity: 0.8; margin-bottom: 4px; display: block; }
.quoted-msg { background: rgba(0,0,0,0.1); border-left: 4px solid rgba(0,0,0,0.3); padding: 6px 10px; border-radius: 5px; margin-bottom: 8px; font-size: 0.85em; opacity: 0.85; overflow: hidden; text-overflow: ellipsis; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; white-space: normal; }
[data-theme="dark"] .quoted-msg { background: rgba(255,255,255,0.1); border-left-color: rgba(255,255,255,0.3); }

.file-link { display: inline-block; padding: 8px 12px; background: rgba(0,0,0,0.1); border-radius: 8px; text-decoration: none; color: inherit; font-weight: 500; word-break: break-all; margin-top: 5px; font-size: 14px; }
.file-link:hover { text-decoration: underline; background: rgba(0,0,0,0.15); }
[data-theme="dark"] .file-link { background: rgba(255,255,255,0.1); }
[data-theme="dark"] .file-link:hover { background: rgba(255,255,255,0.2); }

#input-area { display: flex; align-items: center; padding: 10px; background: var(--input-bg); border-top: 1px solid var(--border-color); position: relative; flex-shrink: 0; box-sizing: border-box; padding-bottom: calc(15px + env(safe-area-inset-bottom, 0px)); }
#message-input { flex: 1; padding: 10px 15px; border: 1px solid var(--border-color); border-radius: 20px; outline: none; background: var(--container-bg); color: var(--text-color); font-size: 16px; }
#send-btn { background: #ff9900; color: white; border: none; padding: 10px 15px; margin-left: 8px; border-radius: 20px; cursor: pointer; font-weight: bold; white-space: nowrap;}
.icon-btn { background: none; border: none; font-size: 20px; cursor: pointer; padding: 5px; margin: 0 1px; }

#mic-btn.recording { color: red; animation: pulse 1.5s infinite; }
@keyframes pulse { 0% { transform: scale(1); } 50% { transform: scale(1.3); } 100% { transform: scale(1); } }
.recording-placeholder::placeholder { color: red !important; font-weight: bold; opacity: 1; }

#lightbox { display: none; position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.9); z-index: 9999; justify-content: center; align-items: center; cursor: zoom-out; }
#lightbox img { max-width: 95%; max-height: 95%; border-radius: 5px; }
#lightbox-close { position: absolute; top: 20px; right: 20px; color: white; font-size: 40px; cursor: pointer; font-weight: bold; }

.call-user-btn { background: rgba(255,153,0,0.2); border: 1px solid #ff9900; border-radius: 50%; padding: 4px; font-size: 12px; cursor: pointer; display: flex; align-items: center; justify-content: center; width: 26px; height: 26px; transition: 0.2s; margin-left: auto; }
.call-user-btn:hover { background: #ff9900; color: white; transform: scale(1.1); }
#video-container { display: none; position: absolute; top: 0; left: 0; width: 100%; height: 100%; background: #000; z-index: 9999; flex-direction: column; justify-content: center; align-items: center; }
#remote-video { width: 100%; height: 100%; object-fit: cover; z-index: 10000; }
#local-video { position: absolute; bottom: 100px; right: 20px; width: 100px; height: 150px; object-fit: cover; border: 2px solid white; border-radius: 12px; box-shadow: 0 4px 15px rgba(0,0,0,0.5); background: #333; transition: opacity 0.3s; z-index: 10001; }
#video-controls { position: absolute; bottom: 30px; left: 0; width: 100%; display: flex; justify-content: center; gap: 15px; z-index: 10002; }
.video-btn { border: none; padding: 12px 20px; border-radius: 30px; font-weight: bold; font-size: 14px; cursor: pointer; box-shadow: 0 4px 10px rgba(0,0,0,0.4); display: flex; align-items: center; justify-content: center; color: white; transition: 0.2s; }
.video-btn:active { transform: scale(0.95); }

/* --- JAVÍTOTT MOBIL NÉZET: ELFÉR MINDEN GOMB! --- */
@media (max-width: 650px) {
#app-container { flex-direction: column; }
#sidebar { width: 100%; height: auto; max-height: 120px; border-right: none; border-bottom: 1px solid var(--border-color); display: flex; flex-direction: column;}
#sidebar h3 { display: none; }
#user-list, #room-list { display: flex; flex-direction: row; overflow-x: auto; white-space: nowrap; padding: 8px; align-items: center; border-bottom: none; }
#user-list li { border-bottom: none; padding: 4px 6px 4px 12px; background: rgba(255,255,255,0.1); border-radius: 16px; margin-right: 6px; flex-shrink: 0; font-size: 12px; display: flex; align-items: center; gap: 6px; }
.room-item { border-bottom: none; padding: 4px 10px; background: rgba(255,255,255,0.1); border-radius: 12px; margin-right: 6px; flex-shrink: 0; font-size: 12px; }
.room-item::before { display: none; }
#user-list li span.user-name::before { display: none; } 
.call-user-btn { margin-left: 5px; width: 22px; height: 22px; font-size: 10px; border: none; background: #ff9900; color: white; padding: 0; }
.desktop-react-btn, .desktop-reply-btn { display: none !important; }

/* Kisebb ikonok és gombok a mobil beviteli sávban */
#input-area { padding: 8px 5px !important; padding-bottom: calc(8px + env(safe-area-inset-bottom, 0px)) !important; }
.icon-btn { font-size: 19px; padding: 3px; margin: 0 1px; }
#message-input { padding: 8px 10px; font-size: 15px; border-radius: 18px; }
#send-btn { padding: 8px 12px; font-size: 14px; margin-left: 5px; border-radius: 18px; }
}

.header-btn { font-size: 12px; padding: 5px 10px; border-radius: 15px; border: 1px solid #ff9900; background: transparent; color: #ff9900; cursor: pointer; margin-left: 5px; }
#reply-preview { display: none; padding: 10px 15px; background: var(--bg-color); border-top: 1px solid var(--border-color); font-size: 13px; position: relative; border-left: 4px solid #ff9900; }
#reply-preview-close { position: absolute; right: 15px; top: 50%; transform: translateY(-50%); cursor: pointer; font-weight: bold; font-size: 22px; color: var(--system-text); }
#reply-preview-sender { font-weight: bold; margin-bottom: 3px; color: var(--text-color); }
#reply-preview-text { color: var(--system-text); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 90%; }
</style>
</head>
<body>

<div id="lightbox" onclick="closeLightbox()">
<span id="lightbox-close">&times;</span>
<img id="lightbox-img" src="">
</div>
<div id="menu-overlay" onclick="closeReactMenu()"></div>
<div id="reaction-menu" class="reaction-menu">
<span onclick="sendEmojiReact('❤️')">❤️</span>
<span onclick="sendEmojiReact('👍')">👍</span>
<span onclick="sendEmojiReact('😂')">😂</span>
<span onclick="sendEmojiReact('😮')">😮</span>
<span onclick="sendEmojiReact('🔥')">🔥</span>
<div style="width: 1px; background: var(--border-color); height: 30px; margin: 0 5px;"></div>
<span onclick="initiateReplyFromMenu()">↩️</span>
</div>

<div id="whiteboard-container">
    <div id="whiteboard-header">
        <span>🎨 Rajztábla</span>
        <div>
            <input type="color" id="draw-color" value="#ff9900" style="margin-right:10px; cursor:pointer;">
            <button class="header-btn" onclick="clearBoard()">🗑️</button>
            <button class="header-btn" style="border-color:#4CAF50; color:#4CAF50; font-weight:bold;" onclick="sendDrawingAsImage()">Küldés 🚀</button>
            <button class="header-btn" style="border-color:#ff3b30; color:#ff3b30;" onclick="closeWhiteboard()">X</button>
        </div>
    </div>
    <canvas id="drawing-board"></canvas>
</div>

<div id="video-container">
    <video id="remote-video" autoplay playsinline></video>
    <video id="local-video" autoplay playsinline muted></video>
    <div id="video-controls">
        <button id="toggle-video-btn" class="video-btn" onclick="toggleVideo()" style="background: #4CAF50;">📹 Kamera Ki</button>
        <button id="end-call-btn" class="video-btn" onclick="endCall()" style="background: #ff3b30;">Megszakítás ☎️</button>
    </div>
</div>

<div id="app-container">
<div id="login-screen">
<h2>AWS Chat 🟢</h2>
<input type="text" id="username-input" placeholder="Becenév...">
<button id="join-btn">Belépés</button>
</div>

<div id="sidebar">
<h3>Szobáim</h3>
<ul id="room-list"></ul>
<h3>Résztvevők</h3>
<ul id="user-list"></ul>
</div>

<div id="chat-area">
<div id="header">
    <div style="display:flex; align-items:center; position:relative;">
        <span style="font-size: 18px;">Chat</span>
        <div id="nav-notif">0</div>
    </div>
<div style="display: flex; gap: 5px;">
    <button id="avatar-btn" class="header-btn" style="border-color: #9c27b0; color: #9c27b0;">🎲 Avatar</button>
    <button id="room-btn" class="header-btn" style="border-color: #4CAF50; color: #4CAF50;">+ Szobaváltás</button>
    <button id="change-name-btn" class="header-btn" style="border-color: var(--header-text); color: var(--header-text);">Névváltás</button>
    <button id="theme-toggle" class="header-btn">Sötét mód</button>
</div>
</div>
<div id="messages"></div>

<div id="typing-indicator">Valaki gépel...</div>

<div id="reply-preview">
    <span id="reply-preview-close" onclick="cancelReply()">&times;</span>
    <div>
        <div id="reply-preview-sender"></div>
        <div id="reply-preview-text"></div>
    </div>
</div>

<div id="input-area">
<button class="icon-btn" id="mic-btn" disabled>🎤</button>
<button class="icon-btn" id="camera-btn" disabled>📸</button>
<button class="icon-btn" id="upload-btn" disabled>📎</button>
<button class="icon-btn" id="game-btn" disabled>🎮</button>

<div id="game-menu">
    <div onclick="openWhiteboard()">🎨 Rajztábla (Küldés)</div>
    <div onclick="startKaland()">🧙‍♂️ AI Kalandmester</div>
</div>

<input type="file" id="file-input" multiple style="display:none">
<input type="text" id="message-input" placeholder="Üzenet..." disabled>
<button id="send-btn" disabled>Küldés</button>
</div>
</div>
</div>

<script>
const setAppHeight = () => { let vh = window.innerHeight; if (window.visualViewport) { vh = window.visualViewport.height; } document.documentElement.style.setProperty('--app-height', vh + 'px'); };
window.addEventListener('resize', setAppHeight); window.addEventListener('orientationchange', setAppHeight);
if (window.visualViewport) { window.visualViewport.addEventListener('resize', setAppHeight); window.visualViewport.addEventListener('scroll', setAppHeight); }
setAppHeight(); 

const WSS_URL = '${websocket_url}';
let myUsername = ""; let socket; let reconnectTimer; 
let uploadQueue = []; let isUploading = false; let currentFileToUpload = null;
let activeMsgId = null; let activeMsgSender = ""; let activeMsgText = ""; let longPressTimer; let isLongPress = false; let myReactions = new Set(); let replyingTo = null;

let currentRoom = 'main'; let currentRoomPassword = '';
let savedRooms = JSON.parse(localStorage.getItem('chatSavedRooms') || '{"main": ""}');

let unreadCount = 0; let isTyping = false; let typingTimeout;
let unreadMsgQueue = []; 

let peerConnection; let localStream; let currentCallTarget = null;
let isVideoEnabled = true; 
const rtcConfig = { iceServers: [{ urls: 'stun:stun.l.google.com:19302' }, { urls: 'stun:stun1.l.google.com:19302' }] };
let candidateQueue = []; 

function updateBadge() {
    if (unreadCount > 0) {
        document.title = "(" + unreadCount + ") AWS Chat";
        document.getElementById('nav-notif').style.display = 'block';
        document.getElementById('nav-notif').innerText = unreadCount;
    } else {
        document.title = "Serverless AWS Chat";
        document.getElementById('nav-notif').style.display = 'none';
    }
    if ('setAppBadge' in navigator) {
        if (unreadCount > 0) navigator.setAppBadge(unreadCount).catch(console.error);
        else navigator.clearAppBadge().catch(console.error);
    }
}

window.addEventListener('focus', () => { 
    unreadCount = 0; updateBadge(); 
    if (socket && socket.readyState === WebSocket.OPEN && unreadMsgQueue.length > 0) {
        unreadMsgQueue.forEach(msg => {
            socket.send(JSON.stringify({ action: 'markRead', msgId: msg.msgId, timestamp: msg.timestamp, room: currentRoom }));
        });
        unreadMsgQueue = [];
    }
});

function renderSavedRooms() {
    const roomListUl = document.getElementById('room-list');
    if (!roomListUl) return; 
    roomListUl.innerHTML = '';
    if (!savedRooms.hasOwnProperty('main')) savedRooms['main'] = '';
    for (const [rName, rPwd] of Object.entries(savedRooms)) {
        const li = document.createElement('li');
        li.className = 'room-item' + (rName === currentRoom ? ' active-room' : '');
        li.textContent = rName === 'main' ? 'Közös Szoba' : rName;
        li.onclick = () => {
            if (rName === currentRoom) return; 
            currentRoomPassword = rPwd;
            if (socket && socket.readyState === WebSocket.OPEN) { socket.send(JSON.stringify({ action: 'join', username: myUsername, room: rName, password: rPwd })); }
        };
        roomListUl.appendChild(li);
    }
}

let myDeviceId = localStorage.getItem('chatDeviceId');
if (!myDeviceId) { myDeviceId = 'device-' + Math.random().toString(36).substr(2, 9) + '-' + Date.now(); localStorage.setItem('chatDeviceId', myDeviceId); }

const loginScreen = document.getElementById('login-screen'); const usernameInput = document.getElementById('username-input'); const joinBtn = document.getElementById('join-btn'); const messagesDiv = document.getElementById('messages'); const messageInput = document.getElementById('message-input'); const sendBtn = document.getElementById('send-btn'); const userListUl = document.getElementById('user-list'); const themeToggle = document.getElementById('theme-toggle'); const cameraBtn = document.getElementById('camera-btn'); const uploadBtn = document.getElementById('upload-btn'); const fileInput = document.getElementById('file-input'); const reactionMenu = document.getElementById('reaction-menu'); const menuOverlay = document.getElementById('menu-overlay'); const changeNameBtn = document.getElementById('change-name-btn'); const roomBtn = document.getElementById('room-btn'); const micBtn = document.getElementById('mic-btn');
const typingDiv = document.getElementById('typing-indicator');

const savedName = localStorage.getItem('chatNickname');
if (savedName) { 
    myUsername = savedName; 
    if (!myUsername.includes('|')) { myUsername += '|' + Math.floor(Math.random() * 1000000); localStorage.setItem('chatNickname', myUsername); }
    loginScreen.style.display = 'none'; connectToChat(); 
}

function isNameTaken(name) {
    let taken = false;
    let targetName = name.toLowerCase().replace(/\s/g, ''); 
    document.querySelectorAll('#user-list li span.user-name').forEach(span => {
        let existingName = span.textContent.replace(' (Te)', '').trim().toLowerCase().replace(/\s/g, '');
        if (existingName === targetName) taken = true;
    });
    return taken;
}

roomBtn.addEventListener('click', () => {
    let targetRoom = prompt("Írd be a szoba nevét (vagy hagyd üresen a Közös szobához):", currentRoom === 'main' ? '' : currentRoom);
    if (targetRoom !== null) {
        targetRoom = targetRoom.trim().toLowerCase();
        if (targetRoom === "" || targetRoom === "közös" || targetRoom === "main") { targetRoom = "main"; }
        let pwd = "";
        if (targetRoom !== "main") { pwd = prompt("Írd be a jelszót a(z) '" + targetRoom + "' szobához (ezzel jön létre):"); if (pwd === null) return; }
        currentRoomPassword = pwd;
        if (socket && socket.readyState === WebSocket.OPEN) { socket.send(JSON.stringify({ action: 'join', username: myUsername, room: targetRoom, password: pwd })); }
    }
});

changeNameBtn.addEventListener('click', () => {
    const oldDisp = myUsername.split('|')[0];
    const oldSeed = myUsername.split('|')[1] || Math.floor(Math.random() * 1000000);
    const newName = prompt("Írd be az új becenevedet:", oldDisp);
    if (newName && newName.trim() !== "" && newName.trim() !== oldDisp) {
        const cleanName = newName.trim();
        if (isNameTaken(cleanName)) { alert("Ez a név már foglalt ebben a szobában! Kérlek válassz másikat."); return; }
        myUsername = cleanName + '|' + oldSeed; 
        localStorage.setItem('chatNickname', myUsername); 
        if (socket && socket.readyState === WebSocket.OPEN) { socket.send(JSON.stringify({ action: 'join', username: myUsername, room: currentRoom, password: currentRoomPassword })); }
        addMessage("Sikeresen átírtad a neved erre: " + cleanName, true);
    }
});

document.getElementById('avatar-btn').addEventListener('click', () => {
    const dispName = myUsername.split('|')[0];
    const newSeed = Math.floor(Math.random() * 1000000);
    myUsername = dispName + '|' + newSeed;
    localStorage.setItem('chatNickname', myUsername);
    if (socket && socket.readyState === WebSocket.OPEN) { 
        socket.send(JSON.stringify({ action: 'join', username: myUsername, room: currentRoom, password: currentRoomPassword })); 
    }
    document.querySelectorAll('.avatar-img').forEach(img => {
        if (img.dataset.user === dispName) img.src = 'https://api.dicebear.com/7.x/adventurer/svg?seed=' + newSeed;
    });
});

messageInput.addEventListener('focus', () => { setTimeout(() => { window.scrollTo(0, 0); document.body.scrollTop = 0; scrollToBottom(); }, 300); });
messageInput.addEventListener('blur', () => { setTimeout(() => { window.scrollTo(0, 0); document.body.scrollTop = 0; }, 100); });

messageInput.addEventListener('input', () => {
    if (!isTyping) {
        isTyping = true;
        if (socket.readyState === 1) socket.send(JSON.stringify({ action: 'typing', username: myUsername, room: currentRoom, typing: true }));
    }
    clearTimeout(typingTimeout);
    typingTimeout = setTimeout(() => {
        isTyping = false;
        if (socket.readyState === 1) socket.send(JSON.stringify({ action: 'typing', username: myUsername, room: currentRoom, typing: false }));
    }, 2000);
});

window.addEventListener('beforeunload', () => { if (socket && socket.readyState === WebSocket.OPEN) { socket.close(); } });
function openLightbox(url) { document.getElementById('lightbox-img').src = url; document.getElementById('lightbox').style.display = 'flex'; }
function closeLightbox() { document.getElementById('lightbox').style.display = 'none'; }
themeToggle.addEventListener('click', () => { const theme = document.documentElement.getAttribute('data-theme') === 'dark' ? 'light' : 'dark'; document.documentElement.setAttribute('data-theme', theme); });

joinBtn.addEventListener('click', () => {
    let rawName = usernameInput.value.trim() || "Anonim_" + Math.floor(Math.random() * 1000);
    myUsername = rawName + '|' + Math.floor(Math.random() * 1000000); 
    localStorage.setItem('chatNickname', myUsername); 
    loginScreen.style.display = 'none'; connectToChat();
});

function checkIfMine(msgSender, msgDeviceId) { if (msgDeviceId && msgDeviceId !== 'unknown') return msgDeviceId === myDeviceId; return msgSender === myUsername; }

function connectToChat() {
    clearTimeout(reconnectTimer); socket = new WebSocket(WSS_URL);
    socket.onopen = () => {
        socket.send(JSON.stringify({ action: 'join', username: myUsername, room: currentRoom, password: currentRoomPassword }));
        [messageInput, sendBtn, cameraBtn, uploadBtn, micBtn, document.getElementById('game-btn')].forEach(el => el.disabled = false); sendBtn.innerText = "Küldés"; messageInput.placeholder = "Üzenet...";
        renderSavedRooms();
        
        if (document.visibilityState === 'visible' && unreadMsgQueue.length > 0) {
            unreadMsgQueue.forEach(msg => socket.send(JSON.stringify({ action: 'markRead', msgId: msg.msgId, timestamp: msg.timestamp, room: currentRoom })));
            unreadMsgQueue = [];
        }
    };
    socket.onclose = () => {
        [messageInput, sendBtn, cameraBtn, uploadBtn, micBtn, document.getElementById('game-btn')].forEach(el => el.disabled = true); sendBtn.innerText = "Csatlakozás..."; messageInput.placeholder = "Kapcsolat megszakadt...";
        reconnectTimer = setTimeout(connectToChat, 2000);
    };
    socket.onerror = (error) => { socket.close(); };

    socket.onmessage = async (event) => {
        const data = JSON.parse(event.data);
        if (data.type === 'error') { alert(data.message); }
        else if (data.type === 'roomJoined') {
            currentRoom = data.room; messagesDiv.innerHTML = ''; cancelReply();
            savedRooms[currentRoom] = currentRoomPassword; localStorage.setItem('chatSavedRooms', JSON.stringify(savedRooms)); renderSavedRooms();
        }
        else if (data.uploadUrl && currentFileToUpload) performUpload(data.uploadUrl, data.fileUrl);
        else if (data.type === 'userList') updateUserList(data.users);
        else if (data.type === 'reaction') updateReactionUI(data.msgId, data.emoji, data.isAdd);
        else if (data.type === 'typing') {
            if (data.sender !== myUsername) {
                typingDiv.innerText = data.sender.split('|')[0] + " éppen gépel...";
                typingDiv.style.opacity = data.typing ? "1" : "0";
            }
        }
        else if (data.type === 'msgRead') {
            const statEl = document.getElementById('status-' + data.msgId);
            if (statEl) { 
                statEl.innerText = '✓✓'; 
                statEl.style.color = '#4facfe'; 
            }
        }
        else if (data.type === 'webrtcSignal' && data.sender !== myUsername) {
            handleWebRTCSignal(data.signal, data.sender);
        }
        else if (data.message && data.sender) { 
            const isMine = checkIfMine(data.sender, data.deviceId); 
            
            if (isMine && data.tempId) {
                const pendingWrap = document.getElementById('wrap-' + data.tempId);
                if (pendingWrap) pendingWrap.remove();
            }

            addMessage(data.message, false, data.sender, isMine, data.msgId, data.replyTo, data.linkPreview, 'sent'); 
            
            if (!isMine) {
                if (document.visibilityState === 'visible') {
                    socket.send(JSON.stringify({ action: 'markRead', msgId: data.msgId, timestamp: data.timestamp, room: currentRoom }));
                } else {
                    unreadMsgQueue.push({ msgId: data.msgId, timestamp: data.timestamp });
                    unreadCount++;
                    updateBadge();
                }
            }
        }
        else if (data.type === 'history') { 
            messagesDiv.innerHTML = ''; 
            data.messages.forEach(msg => { 
                const isMine = checkIfMine(msg.sender, msg.deviceId); 
                const status = msg.isRead ? 'read' : 'sent'; 
                addMessage(msg.message, false, msg.sender, isMine, msg.msgId, msg.replyTo, msg.linkPreview, status); 
            }); 
            scrollToBottom(); 
        }
    };
}

let mediaRecorder; let audioChunks = []; let isRecording = false;

function getBestAudioMimeType() {
    const types = ['audio/webm;codecs=opus', 'audio/webm', 'audio/mp4', 'audio/aac', 'audio/ogg'];
    for (let t of types) { if (typeof MediaRecorder !== 'undefined' && MediaRecorder.isTypeSupported && MediaRecorder.isTypeSupported(t)) { return t; } }
    return '';
}

micBtn.addEventListener('click', async () => {
    if (!isRecording) {
        try {
            const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
            const bestMimeType = getBestAudioMimeType();
            const options = bestMimeType ? { mimeType: bestMimeType } : undefined;
            mediaRecorder = new MediaRecorder(stream, options);
            mediaRecorder.ondataavailable = (e) => { if (e.data.size > 0) audioChunks.push(e.data); };
            mediaRecorder.onstop = () => {
                const finalMimeType = mediaRecorder.mimeType || 'audio/webm';
                let ext = 'webm';
                if (finalMimeType.includes('mp4') || finalMimeType.includes('m4a')) ext = 'm4a';
                else if (finalMimeType.includes('ogg')) ext = 'ogg';
                const audioBlob = new Blob(audioChunks, { type: finalMimeType });
                const audioFile = new File([audioBlob], "VoiceNote_" + Math.floor(Date.now()/1000) + "." + ext, { type: finalMimeType });
                let currentReply = replyingTo ? { sender: replyingTo.sender, message: replyingTo.text } : null;
                uploadQueue.push({ file: audioFile, replyTo: currentReply });
                cancelReply(); if (!isUploading) processNextFile();
                audioChunks = []; stream.getTracks().forEach(track => track.stop());
            };
            mediaRecorder.start(); isRecording = true; 
            micBtn.classList.add('recording'); micBtn.innerHTML = '⏹️'; 
            messageInput.disabled = true; messageInput.value = ''; messageInput.classList.add('recording-placeholder'); messageInput.placeholder = '🔴 Felvétel folyamatban...';
        } catch (err) { alert("Nem sikerült hozzáférni a mikrofonhoz."); }
    } else { 
        mediaRecorder.stop(); isRecording = false; 
        micBtn.classList.remove('recording'); micBtn.innerHTML = '🎤';
        messageInput.disabled = false; messageInput.classList.remove('recording-placeholder'); messageInput.placeholder = 'Üzenet...';
    }
});

function initiateReply(sender, text) { 
    replyingTo = { sender, text }; 
    const dispName = sender.split('|')[0];
    const previewText = text.includes('.amazonaws.com/') ? "📸 [Fájl/Hang]" : text; 
    document.getElementById('reply-preview-sender').innerText = 'Válasz neki: ' + dispName; 
    document.getElementById('reply-preview-text').innerText = previewText; 
    document.getElementById('reply-preview').style.display = 'flex'; messageInput.focus(); closeReactMenu(); 
}
function initiateReplyFromMenu() { initiateReply(activeMsgSender, activeMsgText); }
function cancelReply() { replyingTo = null; document.getElementById('reply-preview').style.display = 'none'; }

function processNextFile() { 
    if (uploadQueue.length === 0) { isUploading = false; fileInput.value = ""; return; } 
    isUploading = true; currentFileToUpload = uploadQueue.shift(); 
    if (socket && socket.readyState === WebSocket.OPEN) { 
        const cType = currentFileToUpload.file.type || 'application/octet-stream';
        socket.send(JSON.stringify({ action: 'getUploadUrl', fileName: currentFileToUpload.file.name, contentType: cType })); 
    } else { isUploading = false; } 
}

function performUpload(uploadUrl, fileUrl) {
    const xhr = new XMLHttpRequest(); xhr.open("PUT", uploadUrl, true);
    const cType = currentFileToUpload.file.type || 'application/octet-stream'; xhr.setRequestHeader('Content-Type', cType);
    xhr.onload = function () {
        if (xhr.status === 200 || xhr.status === 204) {
            if (socket && socket.readyState === WebSocket.OPEN) {
                const payload = { action: 'sendMessage', message: fileUrl, username: myUsername, deviceId: myDeviceId, room: currentRoom };
                if (currentFileToUpload.replyTo) { payload.replyTo = currentFileToUpload.replyTo; }
                socket.send(JSON.stringify(payload));
            }
        }
        processNextFile(); 
    };
    xhr.onerror = function() { processNextFile(); }
    const reader = new FileReader(); reader.onload = function() { xhr.send(this.result); }; reader.readAsArrayBuffer(currentFileToUpload.file);
}

uploadBtn.addEventListener('click', () => { fileInput.removeAttribute('capture'); fileInput.click(); });
cameraBtn.addEventListener('click', () => { fileInput.setAttribute('capture', 'environment'); fileInput.click(); });
fileInput.addEventListener('change', (e) => { let currentReply = replyingTo ? { sender: replyingTo.sender, message: replyingTo.text } : null; for(let i=0; i < e.target.files.length; i++) { uploadQueue.push({ file: e.target.files[i], replyTo: currentReply }); } cancelReply(); if (!isUploading) processNextFile(); });

function updateUserList(users) { 
    userListUl.innerHTML = ''; 
    users.forEach(user => { 
        const dispName = user.split('|')[0];
        const seed = user.split('|')[1] || user;

        const li = document.createElement('li'); 
        const leftGroup = document.createElement('div');
        leftGroup.style.display = 'flex'; leftGroup.style.alignItems = 'center';

        const avatar = document.createElement('img');
        avatar.src = 'https://api.dicebear.com/7.x/adventurer/svg?seed=' + encodeURIComponent(seed);
        avatar.style.width = '24px'; avatar.style.height = '24px'; avatar.style.borderRadius = '50%'; avatar.style.marginRight = '8px'; avatar.style.background = '#e0e0e0';

        const textSpan = document.createElement('span'); textSpan.className = 'user-name';
        textSpan.innerText = dispName + (user === myUsername ? " (Te)" : "");
        
        leftGroup.appendChild(avatar); leftGroup.appendChild(textSpan); li.appendChild(leftGroup);
        
        if (user !== myUsername) {
            const callBtn = document.createElement('button');
            callBtn.className = 'call-user-btn'; callBtn.innerText = '📞';
            callBtn.onclick = () => startCall(user);
            li.appendChild(callBtn);
        }
        userListUl.appendChild(li); 
    }); 
}

function scrollToBottom() { setTimeout(() => { if (messagesDiv) { messagesDiv.scrollTop = messagesDiv.scrollHeight + 1000; } }, 150); }
function openReactMenu(clientX, clientY, msgId, sender, text) { activeMsgId = msgId; activeMsgSender = sender; activeMsgText = text; reactionMenu.style.display = 'flex'; menuOverlay.style.display = 'block'; let leftPos = clientX; let topPos = clientY - 60; if (leftPos > window.innerWidth - 220) leftPos = window.innerWidth - 220; if (leftPos < 10) leftPos = 10; if (topPos < 10) topPos = clientY + 30; reactionMenu.style.left = leftPos + 'px'; reactionMenu.style.top = topPos + 'px'; }
function closeReactMenu() { reactionMenu.style.display = 'none'; menuOverlay.style.display = 'none'; }
function sendEmojiReact(emoji) { if (activeMsgId && socket.readyState === 1) { const key = activeMsgId + ':' + emoji; const isAdding = !myReactions.has(key); if (isAdding) myReactions.add(key); else myReactions.delete(key); socket.send(JSON.stringify({ action: 'sendReaction', msgId: activeMsgId, emoji: emoji, isAdd: isAdding, room: currentRoom })); } closeReactMenu(); }
function updateReactionUI(msgId, emoji, isAdd = true) { const cont = document.getElementById('reacts-' + msgId); if (!cont) return; let badge = cont.querySelector('[data-emoji="' + emoji + '"]'); let delta = isAdd ? 1 : -1; if (badge) { let count = parseInt(badge.getAttribute('data-count')) + delta; if (count <= 0) { badge.remove(); } else { badge.setAttribute('data-count', count); badge.innerText = emoji + ' ' + count; const key = msgId + ':' + emoji; if (myReactions.has(key)) badge.classList.add('reacted'); else badge.classList.remove('reacted'); } } else if (isAdd) { badge = document.createElement('span'); badge.className = 'reaction-badge'; badge.setAttribute('data-emoji', emoji); badge.setAttribute('data-count', '1'); badge.innerText = emoji + ' 1'; badge.onclick = () => { activeMsgId = msgId; sendEmojiReact(emoji); }; const key = msgId + ':' + emoji; if (myReactions.has(key)) badge.classList.add('reacted'); cont.appendChild(badge); } scrollToBottom(); }

function addMessage(text, isSystem = false, sender = '', isMine = false, msgId = '', replyTo = null, linkPreview = null, status = 'sent') {
    let dispName = sender ? sender.split('|')[0] : '';
    let seed = sender ? (sender.split('|')[1] || sender) : (myUsername.split('|')[1] || myUsername);

    const row = document.createElement('div');
    row.className = 'message-row ' + (isMine ? 'mine' : 'others');
    row.id = 'wrap-' + msgId; 

    if (!isSystem) {
        const avatar = document.createElement('img');
        avatar.className = 'avatar-img'; avatar.dataset.user = dispName; 
        avatar.src = 'https://api.dicebear.com/7.x/adventurer/svg?seed=' + encodeURIComponent(seed);
        if (isMine) avatar.style.display = 'none'; 
        row.appendChild(avatar);
    }

    const wrapper = document.createElement('div'); 
    wrapper.className = 'message-wrapper ' + (isMine ? 'mine-wrapper' : 'others-wrapper');
    
    const msgDiv = document.createElement('div'); msgDiv.className = isSystem ? 'message system' : 'message ' + (isMine ? 'mine' : 'others');
    
    let contentHTML = ''; if (sender && !isMine) contentHTML += '<span class="sender-name">' + dispName + '</span>';
    if (replyTo) { const previewText = replyTo.message.includes('.amazonaws.com/') ? "📸 [Fájl/Hang]" : replyTo.message; contentHTML += '<div class="quoted-msg"><strong>' + replyTo.sender.split('|')[0] + '</strong><br><span>' + previewText + '</span></div>'; }
    if (text.includes('.amazonaws.com/')) {
        const urlParts = text.split('/'); const fullFileName = urlParts[urlParts.length - 1]; const originalName = fullFileName.split('_').slice(1).join('_') || "Fájl"; const ext = originalName.split('.').pop().toLowerCase(); 
        const imgExts = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic']; const audioExts = ['mp3', 'wav', 'ogg', 'webm', 'm4a', 'aac', 'mp4'];
        if (imgExts.includes(ext)) { const img = document.createElement('img'); img.src = text; img.onclick = (e) => { if (isLongPress) { isLongPress = false; e.preventDefault(); return; } openLightbox(text); }; img.onload = scrollToBottom; msgDiv.innerHTML = contentHTML; msgDiv.appendChild(img); } 
        else if (audioExts.includes(ext)) { msgDiv.innerHTML = contentHTML + '<audio controls src="' + text + '"></audio>'; }
        else { msgDiv.innerHTML = contentHTML + '<a href="' + text + '" target="_blank" class="file-link">📄 ' + originalName + '</a>'; }
    } else { const textNode = document.createTextNode(text); msgDiv.innerHTML = contentHTML; msgDiv.appendChild(textNode); }

    if (linkPreview) {
        const card = document.createElement('a'); card.className = 'link-card'; card.href = linkPreview.url; card.target = '_blank';
        let cardHTML = ''; if (linkPreview.image) cardHTML += '<img src="' + linkPreview.image + '">';
        cardHTML += '<div class="link-card-content"><span class="link-card-title">' + linkPreview.title + '</span>';
        if (linkPreview.description) cardHTML += '<div class="link-card-desc">' + linkPreview.description + '</div>';
        cardHTML += '</div>'; card.innerHTML = cardHTML; msgDiv.appendChild(card);
    }

    if (isMine && !isSystem) {
        let sIcon = '✓'; let sColor = 'var(--mine-text)';
        if (status === 'pending') { sIcon = '🕒'; } else if (status === 'failed') { sIcon = '❌'; sColor = '#ff3b30'; } else if (status === 'read') { sIcon = '✓✓'; sColor = '#4facfe'; }
        msgDiv.innerHTML += '<div style="text-align:right; margin-top:2px; font-size:12px; font-weight:bold;"><span id="status-' + msgId + '" style="color:' + sColor + '; margin-left: 5px; text-shadow: 0px 0px 2px rgba(0,0,0,0.3);">' + sIcon + '</span></div>';
    }

    if (!isSystem && msgId && status !== 'pending' && status !== 'failed') {
        msgDiv.ontouchstart = (e) => { isLongPress = false; let touch = e.touches[0]; longPressTimer = setTimeout(() => { isLongPress = true; openReactMenu(touch.clientX, touch.clientY, msgId, sender || myUsername, text); }, 500); };
        msgDiv.ontouchend = (e) => { clearTimeout(longPressTimer); if (isLongPress) e.preventDefault(); }; msgDiv.ontouchmove = () => { clearTimeout(longPressTimer); isLongPress = false; }; msgDiv.oncontextmenu = (e) => { e.preventDefault(); openReactMenu(e.clientX, e.clientY, msgId, sender || myUsername, text); };
        const hoverBtn = document.createElement('div'); hoverBtn.className = 'desktop-react-btn'; hoverBtn.innerHTML = '😀'; hoverBtn.onclick = (e) => { e.stopPropagation(); openReactMenu(e.clientX, e.clientY, msgId, sender || myUsername, text); }; msgDiv.appendChild(hoverBtn);
        const replyBtn = document.createElement('div'); replyBtn.className = 'desktop-reply-btn'; replyBtn.innerHTML = '↩️'; replyBtn.onclick = (e) => { e.stopPropagation(); initiateReply(sender || myUsername, text); }; msgDiv.appendChild(replyBtn);
    }
    
    wrapper.appendChild(msgDiv);
    if (!isSystem && msgId && status !== 'pending') { const rCont = document.createElement('div'); rCont.className = 'reaction-container'; rCont.id = 'reacts-' + msgId; wrapper.appendChild(rCont); }
    row.appendChild(wrapper); messagesDiv.appendChild(row); scrollToBottom();
}

function sendMessage() {
    const text = messageInput.value.trim();
    if (text) {
        const tempId = 'temp-' + Date.now();
        addMessage(text, false, myUsername, true, tempId, replyingTo, null, 'pending');
        if (socket.readyState === WebSocket.OPEN) {
            const payload = { action: 'sendMessage', message: text, username: myUsername, deviceId: myDeviceId, room: currentRoom, tempId: tempId };
            if (replyingTo) { payload.replyTo = { sender: replyingTo.sender, message: replyingTo.text }; }
            socket.send(JSON.stringify(payload)); 
            setTimeout(() => { const statEl = document.getElementById('status-' + tempId); if (statEl && statEl.innerText === '🕒') { statEl.innerText = '❌'; statEl.style.color = '#ff3b30'; } }, 8000);
        } else { setTimeout(() => { const statEl = document.getElementById('status-' + tempId); if (statEl) { statEl.innerText = '❌'; statEl.style.color = '#ff3b30'; } }, 100); }
        messageInput.value = ''; cancelReply(); isTyping = false;
        if (socket.readyState === WebSocket.OPEN) socket.send(JSON.stringify({ action: 'typing', username: myUsername, room: currentRoom, typing: false }));
    }
}
sendBtn.addEventListener('click', sendMessage); messageInput.addEventListener('keypress', (e) => { if (e.key === 'Enter') sendMessage(); });
if ('serviceWorker' in navigator) { window.addEventListener('load', () => { navigator.serviceWorker.register('/sw.js').then(reg => console.log('App mód (PWA) aktív!', reg.scope)).catch(err => console.error('PWA hiba:', err)); }); }

async function startCall(targetUser) {
    currentCallTarget = targetUser; document.getElementById('video-container').style.display = 'flex'; isVideoEnabled = true; candidateQueue = [];
    try {
        localStream = await navigator.mediaDevices.getUserMedia({ video: true, audio: true }); document.getElementById('local-video').srcObject = localStream;
        peerConnection = new RTCPeerConnection(rtcConfig); localStream.getTracks().forEach(track => peerConnection.addTrack(track, localStream));
        peerConnection.ontrack = event => { const remoteVideo = document.getElementById('remote-video'); if (remoteVideo.srcObject !== event.streams[0]) { remoteVideo.srcObject = event.streams[0]; } };
        peerConnection.onicecandidate = event => { if (event.candidate) { socket.send(JSON.stringify({ action: 'webrtcSignal', room: currentRoom, username: myUsername, targetUser: currentCallTarget, deviceId: myDeviceId, signal: { type: 'candidate', candidate: event.candidate } })); } };
        const offer = await peerConnection.createOffer(); await peerConnection.setLocalDescription(offer);
        socket.send(JSON.stringify({ action: 'webrtcSignal', room: currentRoom, username: myUsername, targetUser: currentCallTarget, deviceId: myDeviceId, signal: { type: 'offer', offer: offer } }));
    } catch (err) { alert("Kamera hiba: " + err.message); endCallLocal(); }
}

async function handleWebRTCSignal(signal, sender) {
    if (signal.type === 'offer') {
        const dispName = sender.split('|')[0];
        if (!confirm(dispName + " hívást indított! Felveszed? 📞")) { socket.send(JSON.stringify({ action: 'webrtcSignal', room: currentRoom, username: myUsername, targetUser: sender, deviceId: myDeviceId, signal: { type: 'end' } })); return; }
        currentCallTarget = sender; document.getElementById('video-container').style.display = 'flex'; isVideoEnabled = true; candidateQueue = []; 
        try {
            localStream = await navigator.mediaDevices.getUserMedia({ video: true, audio: true }); document.getElementById('local-video').srcObject = localStream;
            peerConnection = new RTCPeerConnection(rtcConfig); localStream.getTracks().forEach(track => peerConnection.addTrack(track, localStream));
            peerConnection.ontrack = event => { const remoteVideo = document.getElementById('remote-video'); if (remoteVideo.srcObject !== event.streams[0]) { remoteVideo.srcObject = event.streams[0]; } };
            peerConnection.onicecandidate = event => { if (event.candidate) { socket.send(JSON.stringify({ action: 'webrtcSignal', room: currentRoom, username: myUsername, targetUser: currentCallTarget, deviceId: myDeviceId, signal: { type: 'candidate', candidate: event.candidate } })); } };
            await peerConnection.setRemoteDescription(new RTCSessionDescription(signal.offer)); const answer = await peerConnection.createAnswer(); await peerConnection.setLocalDescription(answer);
            socket.send(JSON.stringify({ action: 'webrtcSignal', room: currentRoom, username: myUsername, targetUser: currentCallTarget, deviceId: myDeviceId, signal: { type: 'answer', answer: answer } }));
            candidateQueue.forEach(c => peerConnection.addIceCandidate(new RTCIceCandidate(c)).catch(e => console.log(e))); candidateQueue = [];
        } catch (err) { alert("Kamera hiba: " + err.message); endCallLocal(); }
    } 
    else if (signal.type === 'answer') { await peerConnection.setRemoteDescription(new RTCSessionDescription(signal.answer)); candidateQueue.forEach(c => peerConnection.addIceCandidate(new RTCIceCandidate(c)).catch(e => console.log(e))); candidateQueue = []; } 
    else if (signal.type === 'candidate') { if (peerConnection && peerConnection.remoteDescription && peerConnection.remoteDescription.type) { peerConnection.addIceCandidate(new RTCIceCandidate(signal.candidate)).catch(e => console.log(e)); } else { candidateQueue.push(signal.candidate); } } 
    else if (signal.type === 'end') { endCallLocal(); }
}

function toggleVideo() {
    if (localStream) {
        const videoTrack = localStream.getVideoTracks()[0];
        if (videoTrack) {
            isVideoEnabled = !isVideoEnabled; videoTrack.enabled = isVideoEnabled;
            const btn = document.getElementById('toggle-video-btn'); const localVid = document.getElementById('local-video');
            if (isVideoEnabled) { btn.innerText = '📹 Kamera Ki'; btn.style.background = '#4CAF50'; localVid.style.opacity = '1'; } 
            else { btn.innerText = '🚫 Kamera Be'; btn.style.background = '#888'; localVid.style.opacity = '0.3'; }
        }
    }
}
function endCall() { if (currentCallTarget) socket.send(JSON.stringify({ action: 'webrtcSignal', room: currentRoom, username: myUsername, targetUser: currentCallTarget, deviceId: myDeviceId, signal: { type: 'end' } })); endCallLocal(); }
function endCallLocal() {
    if (peerConnection) { peerConnection.close(); peerConnection = null; }
    if (localStream) { localStream.getTracks().forEach(t => t.stop()); localStream = null; }
    document.getElementById('video-container').style.display = 'none'; currentCallTarget = null; candidateQueue = [];
    const btn = document.getElementById('toggle-video-btn'); if(btn) { btn.innerText = '📹 Kamera Ki'; btn.style.background = '#4CAF50'; }
    const localVid = document.getElementById('local-video'); if(localVid) { localVid.style.opacity = '1'; }
}

// ==========================================
// 🚀 ZSENIÁLIS "RAJZ ÉS KÜLDÉS KÉPKÉNT" LOGIKA 🚀
// ==========================================

const canvas = document.getElementById('drawing-board');
const ctx = canvas.getContext('2d');
let isDrawing = false;

function resizeCanvas() { 
    const container = document.getElementById('whiteboard-container');
    if (!container || container.style.display === 'none') return;
    const headerHeight = document.getElementById('whiteboard-header').offsetHeight || 50;
    
    // Vászon méretezése
    canvas.width = window.innerWidth; 
    canvas.height = window.innerHeight - headerHeight; 
    
    // Fehér háttér, hogy a kép ne legyen átlátszó (Sötét módban is látszódjon a cseten!)
    ctx.fillStyle = "white";
    ctx.fillRect(0, 0, canvas.width, canvas.height);
}
window.addEventListener('resize', resizeCanvas); 

function openWhiteboard() { 
    document.getElementById('whiteboard-container').style.display = 'flex'; 
    document.getElementById('game-menu').style.display = 'none'; 
    setTimeout(resizeCanvas, 50); 
}
function closeWhiteboard() { document.getElementById('whiteboard-container').style.display = 'none'; }
function clearBoard() { 
    ctx.fillStyle = "white";
    ctx.fillRect(0, 0, canvas.width, canvas.height);
}

// --- ÚJ FUNKCIÓ: Rajz elküldése képként az Amazon S3-ba ---
function sendDrawingAsImage() {
    // 1. Kiszedjük a rajzot kép (PNG) formátumban
    const dataUrl = canvas.toDataURL('image/png');
    
    // 2. Szép animáció gombnyomásra
    closeWhiteboard();
    
    // 3. Kép Blob konvertálása és bedobása a feltöltési sorba (S3)
    fetch(dataUrl)
        .then(res => res.blob())
        .then(blob => {
            const file = new File([blob], "Rajz_" + Math.floor(Date.now()/1000) + ".png", { type: 'image/png' });
            uploadQueue.push({ file: file, replyTo: null });
            if (!isUploading) processNextFile();
        });
}

function drawLocal(x, y, type) {
    const color = document.getElementById('draw-color').value;
    ctx.strokeStyle = color; 
    ctx.lineWidth = 5; 
    ctx.lineCap = "round"; 
    ctx.lineJoin = "round";
    
    if (type === 'start') { 
        ctx.beginPath(); 
        ctx.moveTo(x, y); 
    }
    else if (type === 'move') { 
        ctx.lineTo(x, y); 
        ctx.stroke(); 
    }
}

// Egér (Asztali gép) - CSAK LOKÁLIS RAJZOLÁS!
canvas.onmousedown = (e) => { isDrawing = true; drawLocal(e.offsetX, e.offsetY, 'start'); };
canvas.onmousemove = (e) => { if(isDrawing) drawLocal(e.offsetX, e.offsetY, 'move'); };
window.onmouseup = () => { isDrawing = false; ctx.beginPath(); };

// Érintés (Mobil) - CSAK LOKÁLIS RAJZOLÁS!
canvas.ontouchstart = (e) => { 
    isDrawing = true; 
    const r = canvas.getBoundingClientRect(); 
    drawLocal(e.touches[0].clientX - r.left, e.touches[0].clientY - r.top, 'start'); 
    if (e.cancelable) e.preventDefault(); 
};
canvas.ontouchmove = (e) => { 
    if(isDrawing) { 
        const r = canvas.getBoundingClientRect(); 
        drawLocal(e.touches[0].clientX - r.left, e.touches[0].clientY - r.top, 'move'); 
    }
    if (e.cancelable) e.preventDefault(); 
};
window.ontouchend = () => { isDrawing = false; ctx.beginPath(); };

function startKaland() {
    document.getElementById('game-menu').style.display = 'none';
    messageInput.value = '/kaland ';
    messageInput.focus();
}

document.getElementById('game-btn').addEventListener('click', () => {
    const menu = document.getElementById('game-menu');
    menu.style.display = menu.style.display === 'flex' ? 'none' : 'flex';
});
document.addEventListener('click', (e) => {
    if (!e.target.closest('#game-menu') && e.target.id !== 'game-btn') {
        document.getElementById('game-menu').style.display = 'none';
    }
});
</script>
</body>
</html>