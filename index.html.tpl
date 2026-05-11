<!DOCTYPE html>
<html lang="hu">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<title>Serverless AWS Chat</title>
<style>
:root {
--bg-color: #f0f2f5;
--container-bg: white;
--text-color: #333;
--sidebar-bg: #232f3e;
--sidebar-text: white;
--header-bg: #232f3e;
--header-text: white;
--input-bg: #fff;
--border-color: #ddd;
--others-msg: #dcf8c6;
--others-text: black;
--mine-msg: #ff9900;
--mine-text: white;
--system-text: #888;
}

[data-theme="dark"] {
--bg-color: #131921;
--container-bg: #1a222d;
--text-color: #f3f3f3;
--sidebar-bg: #0f141a;
--input-bg: #232f3e;
--border-color: #37475a;
--others-msg: #37475a;
--others-text: white;
--system-text: #aaa;
}

body {
font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
background-color: var(--bg-color);
display: flex;
justify-content: center;
padding: 0;
margin: 0;
height: 100vh;
height: 100dvh;
box-sizing: border-box;
transition: background 0.3s;
overflow: hidden;
}
#app-container {
width: 100%;
max-width: 900px;
background: var(--container-bg);
display: flex;
flex-direction: row;
overflow: hidden;
height: 100%;
position: relative;
}
#login-screen { position: absolute; top: 0; left: 0; right: 0; bottom: 0; background: var(--container-bg); display: flex; flex-direction: column; justify-content: center; align-items: center; z-index: 20; }
#login-screen h2 { color: var(--text-color); margin-bottom: 20px; }
#username-input { padding: 12px; border: 1px solid var(--border-color); border-radius: 5px; width: 80%; max-width: 300px; margin-bottom: 15px; font-size: 16px; text-align: center; background: var(--container-bg); color: var(--text-color); }
#join-btn { background: #ff9900; color: white; border: none; padding: 12px 30px; border-radius: 25px; cursor: pointer; font-weight: bold; font-size: 16px; }

#sidebar { width: 220px; background: var(--sidebar-bg); color: var(--sidebar-text); display: flex; flex-direction: column; border-right: 1px solid var(--border-color); flex-shrink: 0; }
#sidebar h3 { padding: 15px; margin: 0; font-size: 14px; text-transform: uppercase; border-bottom: 1px solid var(--border-color); color: #ff9900; text-align: center; }
#user-list { list-style: none; padding: 0; margin: 0; overflow-y: auto; flex: 1; }
#user-list li { padding: 10px 15px; font-size: 14px; display: flex; align-items: center; border-bottom: 1px solid rgba(255,255,255,0.05); }
#user-list li::before { content: "●"; color: #44ff44; margin-right: 10px; font-size: 18px; }

#chat-area { flex: 1; display: flex; flex-direction: column; background: var(--container-bg); min-width: 0; }
#header { background: var(--header-bg); color: var(--header-text); padding: 10px 15px; display: flex; justify-content: space-between; align-items: center; font-weight: bold; flex-shrink: 0; }
#messages { flex: 1; padding: 15px; overflow-y: auto; display: flex; flex-direction: column; gap: 10px; -webkit-overflow-scrolling: touch; scroll-behavior: smooth; }

.message-wrapper { display: flex; flex-direction: column; width: 100%; margin-bottom: 5px; }
.mine-wrapper { align-items: flex-end; }
.others-wrapper { align-items: flex-start; }

.reaction-container { display: flex; flex-wrap: wrap; gap: 4px; margin-top: -8px; z-index: 5; padding: 0 10px; }
.reaction-badge { background: var(--container-bg); border: 1px solid var(--border-color); border-radius: 12px; padding: 2px 6px; font-size: 12px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); color: var(--text-color); cursor: pointer; transition: 0.2s; }
.reaction-badge:hover { transform: scale(1.1); }
.reaction-badge.reacted { background: rgba(255, 153, 0, 0.15); border-color: #ff9900; }

/* JAVÍTÁS: Átlátszó védőréteg a képernyőn, ami megakadályozza a véletlen kattintásokat */
#menu-overlay {
    display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%;
    z-index: 8000; /* Minden felett, de a menü alatt */
}

/* A menü garantáltan a legfelül lesz */
.reaction-menu { 
display: none; position: fixed; background: var(--container-bg); 
border: 1px solid var(--border-color); border-radius: 30px; padding: 8px 15px; 
box-shadow: 0 4px 25px rgba(0,0,0,0.4); z-index: 9000; gap: 15px;
}
.reaction-menu span { font-size: 26px; cursor: pointer; transition: transform 0.1s; display: inline-block; }
.reaction-menu span:hover { transform: scale(1.3); }

.desktop-react-btn {
    position: absolute;
    top: 50%;
    transform: translateY(-50%);
    background: var(--container-bg);
    border: 1px solid var(--border-color);
    border-radius: 50%;
    width: 32px;
    height: 32px;
    display: none;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    box-shadow: 0 2px 5px rgba(0,0,0,0.1);
    z-index: 10;
    font-size: 16px;
}
.message-wrapper:hover .desktop-react-btn { display: flex; }

.mine .desktop-react-btn { left: -40px; }
.others .desktop-react-btn { right: -40px; }

.message { padding: 10px 15px; border-radius: 15px; max-width: 80%; word-wrap: break-word; font-size: 15px; position: relative; -webkit-touch-callout: none; -webkit-user-select: none; user-select: none; }
.message img {
max-width: 200px;
max-height: 200px;
object-fit: cover;
border-radius: 10px;
margin-top: 5px;
display: block;
cursor: zoom-in;
background: #eee;
}

.message.system { background: transparent; color: var(--system-text); font-size: 0.85em; text-align: center; align-self: center; margin: 5px 0; }
.message.mine { background: var(--mine-msg); color: var(--mine-text); align-self: flex-end; border-bottom-right-radius: 3px; }
.message.others { background: var(--others-msg); color: var(--others-text); align-self: flex-start; border-bottom-left-radius: 3px; }
.message.others .sender-name { font-size: 0.75em; font-weight: bold; opacity: 0.8; margin-bottom: 4px; display: block; }
#input-area {
display: flex;
align-items: center;
padding: 10px;
background: var(--input-bg);
border-top: 1px solid var(--border-color);
position: relative;
flex-shrink: 0;
padding-bottom: calc(10px + env(safe-area-inset-bottom, 0px));
}
#message-input { flex: 1; padding: 10px 15px; border: 1px solid var(--border-color); border-radius: 20px; outline: none; background: var(--container-bg); color: var(--text-color); font-size: 16px; }
#send-btn { background: #ff9900; color: white; border: none; padding: 10px 15px; margin-left: 8px; border-radius: 20px; cursor: pointer; font-weight: bold; }
.icon-btn { background: none; border: none; font-size: 20px; cursor: pointer; padding: 5px; margin: 0 1px; }

#lightbox {
display: none;
position: fixed;
top: 0; left: 0; width: 100%; height: 100%;
background: rgba(0,0,0,0.9);
z-index: 9999;
justify-content: center;
align-items: center;
cursor: zoom-out;
}
#lightbox img { max-width: 95%; max-height: 95%; border-radius: 5px; }
#lightbox-close { position: absolute; top: 20px; right: 20px; color: white; font-size: 40px; cursor: pointer; font-weight: bold; }

@media (max-width: 650px) {
#app-container { flex-direction: column; }
#sidebar { width: 100%; height: auto; max-height: 50px; border-right: none; border-bottom: 1px solid var(--border-color); }
#sidebar h3 { display: none; }
#user-list { display: flex; flex-direction: row; overflow-x: auto; white-space: nowrap; padding: 8px; align-items: center; }
#user-list li { border-bottom: none; padding: 2px 10px; background: rgba(255,255,255,0.1); border-radius: 12px; margin-right: 6px; flex-shrink: 0; font-size: 12px; }
.desktop-react-btn { display: none !important; }
}
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
</div>

<div id="app-container">
<div id="login-screen">
<h2>AWS Chat 🟢</h2>
<input type="text" id="username-input" placeholder="Becenév...">
<button id="join-btn">Belépés</button>
</div>

<div id="sidebar">
<ul id="user-list"></ul>
</div>

<div id="chat-area">
<div id="header">
<span>Chat</span>
<button id="theme-toggle" style="font-size: 12px; padding: 5px 10px; border-radius: 15px; border: 1px solid #ff9900; background: transparent; color: #ff9900; cursor: pointer;">Sötét mód</button>
</div>
<div id="messages"></div>
<div id="input-area">
<button class="icon-btn" id="camera-btn" disabled>📸</button>
<button class="icon-btn" id="upload-btn" disabled>📎</button>
<input type="file" id="file-input" accept="image/*" style="display:none">
<input type="text" id="message-input" placeholder="Üzenet..." disabled>
<button id="send-btn" disabled>Küldés</button>
</div>
</div>
</div>

<script>
const WSS_URL = '${websocket_url}';
let myUsername = "";
let socket;
let selectedFile = null;

let activeMsgId = null;
let longPressTimer;
let isLongPress = false; 
let myReactions = new Set(); 

const loginScreen = document.getElementById('login-screen');
const usernameInput = document.getElementById('username-input');
const joinBtn = document.getElementById('join-btn');
const messagesDiv = document.getElementById('messages');
const messageInput = document.getElementById('message-input');
const sendBtn = document.getElementById('send-btn');
const userListUl = document.getElementById('user-list');
const themeToggle = document.getElementById('theme-toggle');
const cameraBtn = document.getElementById('camera-btn');
const uploadBtn = document.getElementById('upload-btn');
const fileInput = document.getElementById('file-input');
const reactionMenu = document.getElementById('reaction-menu');
const menuOverlay = document.getElementById('menu-overlay');

window.addEventListener('beforeunload', () => {
    if (socket && socket.readyState === WebSocket.OPEN) {
        socket.close();
    }
});

function openLightbox(url) {
document.getElementById('lightbox-img').src = url;
document.getElementById('lightbox').style.display = 'flex';
}
function closeLightbox() {
document.getElementById('lightbox').style.display = 'none';
}

themeToggle.addEventListener('click', () => {
const theme = document.documentElement.getAttribute('data-theme') === 'dark' ? 'light' : 'dark';
document.documentElement.setAttribute('data-theme', theme);
});

joinBtn.addEventListener('click', () => {
myUsername = usernameInput.value.trim() || "Anonim_" + Math.floor(Math.random() * 1000);
loginScreen.style.display = 'none';
connectToChat();
});

function connectToChat() {
socket = new WebSocket(WSS_URL);
socket.onopen = () => {
socket.send(JSON.stringify({ action: 'join', username: myUsername }));
[messageInput, sendBtn, cameraBtn, uploadBtn].forEach(el => el.disabled = false);
};
socket.onmessage = async (event) => {
const data = JSON.parse(event.data);
if (data.uploadUrl && selectedFile) performUpload(data.uploadUrl, data.fileUrl);
else if (data.type === 'userList') updateUserList(data.users);
else if (data.type === 'reaction') updateReactionUI(data.msgId, data.emoji, data.isAdd);
else if (data.message && data.sender) addMessage(data.message, false, data.sender, data.sender === myUsername, data.msgId);
};
}

function performUpload(uploadUrl, fileUrl) {
const xhr = new XMLHttpRequest();
xhr.open("PUT", uploadUrl, true);
xhr.onload = function () {
if (xhr.status === 200 || xhr.status === 204) {
socket.send(JSON.stringify({ action: 'sendMessage', message: fileUrl, username: myUsername }));
}
};
const reader = new FileReader();
reader.onload = function() { xhr.send(this.result); };
reader.readAsArrayBuffer(selectedFile);
selectedFile = null;
fileInput.value = "";
}

uploadBtn.addEventListener('click', () => { fileInput.removeAttribute('capture'); fileInput.click(); });
cameraBtn.addEventListener('click', () => { fileInput.setAttribute('capture', 'environment'); fileInput.click(); });
fileInput.addEventListener('change', (e) => {
selectedFile = e.target.files[0];
if (selectedFile) socket.send(JSON.stringify({ action: 'getUploadUrl' }));
});

function updateUserList(users) {
userListUl.innerHTML = '';
users.forEach(user => {
const li = document.createElement('li');
li.textContent = user + (user === myUsername ? " (Te)" : "");
userListUl.appendChild(li);
});
}

function scrollToBottom() {
setTimeout(() => { messagesDiv.scrollTop = messagesDiv.scrollHeight; }, 50);
}

function openReactMenu(clientX, clientY, msgId) {
activeMsgId = msgId;
reactionMenu.style.display = 'flex';
menuOverlay.style.display = 'block';

let leftPos = clientX;
let topPos = clientY - 60;

if (leftPos > window.innerWidth - 220) leftPos = window.innerWidth - 220;
if (leftPos < 10) leftPos = 10;
if (topPos < 10) topPos = clientY + 30;

reactionMenu.style.left = leftPos + 'px';
reactionMenu.style.top = topPos + 'px';
}

function closeReactMenu() { 
reactionMenu.style.display = 'none'; 
menuOverlay.style.display = 'none';
}

function sendEmojiReact(emoji) {
    if (activeMsgId && socket.readyState === 1) {
        const key = activeMsgId + ':' + emoji;
        const isAdding = !myReactions.has(key); 

        if (isAdding) myReactions.add(key);
        else myReactions.delete(key);

        socket.send(JSON.stringify({ 
            action: 'sendReaction', 
            msgId: activeMsgId, 
            emoji: emoji,
            isAdd: isAdding
        }));
    }
    closeReactMenu();
}

function updateReactionUI(msgId, emoji, isAdd = true) {
    const cont = document.getElementById('reacts-' + msgId);
    if (!cont) return;
    
    let badge = cont.querySelector(`[data-emoji="$${emoji}"]`);
    let delta = isAdd ? 1 : -1;

    if (badge) {
        let count = parseInt(badge.getAttribute('data-count')) + delta;
        if (count <= 0) {
            badge.remove(); 
        } else {
            badge.setAttribute('data-count', count);
            badge.innerText = emoji + ' ' + count;
            const key = msgId + ':' + emoji;
            if (myReactions.has(key)) badge.classList.add('reacted');
            else badge.classList.remove('reacted');
        }
    } else if (isAdd) {
        badge = document.createElement('span');
        badge.className = 'reaction-badge';
        badge.setAttribute('data-emoji', emoji);
        badge.setAttribute('data-count', '1');
        badge.innerText = emoji + ' 1';
        
        badge.onclick = () => {
            activeMsgId = msgId;
            sendEmojiReact(emoji);
        };

        const key = msgId + ':' + emoji;
        if (myReactions.has(key)) badge.classList.add('reacted');
        
        cont.appendChild(badge);
    }
    scrollToBottom();
}

function addMessage(text, isSystem = false, sender = '', isMine = false, msgId = '') {
const wrapper = document.createElement('div');
wrapper.className = 'message-wrapper ' + (isMine ? 'mine-wrapper' : 'others-wrapper');

const msgDiv = document.createElement('div');
msgDiv.className = isSystem ? 'message system' : 'message ' + (isMine ? 'mine' : 'others');
let content = '';
if (sender && !isMine) content += `<span class="sender-name">$${sender}</span>`;

if (text.includes('.amazonaws.com/') && text.includes('.jpg')) {
const img = document.createElement('img');
img.src = text;
img.onclick = (e) => {
    if (isLongPress) {
        isLongPress = false;
        e.preventDefault();
        return;
    }
    openLightbox(text); 
};
img.onload = scrollToBottom;
msgDiv.innerHTML = content;
msgDiv.appendChild(img);
} else {
const textNode = document.createTextNode(text);
msgDiv.innerHTML = content;
msgDiv.appendChild(textNode);
}

if (!isSystem && msgId) {
    msgDiv.ontouchstart = (e) => { 
        isLongPress = false;
        let touch = e.touches[0];
        longPressTimer = setTimeout(() => { 
            isLongPress = true; 
            openReactMenu(touch.clientX, touch.clientY, msgId); 
        }, 500); 
    };
    msgDiv.ontouchend = (e) => { 
        clearTimeout(longPressTimer);
        if (isLongPress) e.preventDefault();
    };
    msgDiv.ontouchmove = () => { 
        clearTimeout(longPressTimer); 
        isLongPress = false; 
    };
    msgDiv.oncontextmenu = (e) => { 
        e.preventDefault(); 
        openReactMenu(e.clientX, e.clientY, msgId); 
    };
    
    const hoverBtn = document.createElement('div');
    hoverBtn.className = 'desktop-react-btn';
    hoverBtn.innerHTML = '😀';
    hoverBtn.onclick = (e) => { 
        e.stopPropagation(); 
        openReactMenu(e.clientX, e.clientY, msgId); 
    };
    msgDiv.appendChild(hoverBtn);
}

wrapper.appendChild(msgDiv);

if (!isSystem && msgId) {
const rCont = document.createElement('div');
rCont.className = 'reaction-container';
rCont.id = 'reacts-' + msgId;
wrapper.appendChild(rCont);
}

messagesDiv.appendChild(wrapper);
scrollToBottom();
}

function sendMessage() {
const text = messageInput.value.trim();
if (text && socket.readyState === 1) {
socket.send(JSON.stringify({ action: 'sendMessage', message: text, username: myUsername }));
messageInput.value = '';
}
}
sendBtn.addEventListener('click', sendMessage);
messageInput.addEventListener('keypress', (e) => { if (e.key === 'Enter') sendMessage(); });
</script>
</body>
</html>