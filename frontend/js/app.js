// --- app.js ---
import { state, dom } from './state.js';
import { connectToChat } from './network.js';
import { addMessage, updateBadge } from './ui.js';
import { toggleMicrophone, processNextFile } from './media.js';
import { deriveKey, setE2EState, encryptMessage, e2eEnabled } from './crypto.js';

// --- Képernyőméret fix mobilokra ---
const setAppHeight = () => { let vh = window.innerHeight; if (window.visualViewport) { vh = window.visualViewport.height; } document.documentElement.style.setProperty('--app-height', vh + 'px'); };
window.addEventListener('resize', setAppHeight); window.addEventListener('orientationchange', setAppHeight);
if (window.visualViewport) { window.visualViewport.addEventListener('resize', setAppHeight); window.visualViewport.addEventListener('scroll', setAppHeight); }
setAppHeight(); 

// --- Inicializálás és Login ---
const savedName = localStorage.getItem('chatNickname');
if (savedName) { 
    state.myUsername = savedName; 
    if (!state.myUsername.includes('|')) { 
        state.myUsername += '|' + Math.floor(Math.random() * 1000000); 
        localStorage.setItem('chatNickname', state.myUsername); 
    }
    dom.loginScreen.style.display = 'none'; 
    connectToChat(); 
}

dom.joinBtn.addEventListener('click', () => {
    let rawName = dom.usernameInput.value.trim() || "Anonim_" + Math.floor(Math.random() * 1000);
    state.myUsername = rawName + '|' + Math.floor(Math.random() * 1000000); 
    localStorage.setItem('chatNickname', state.myUsername); 
    dom.loginScreen.style.display = 'none'; 
    connectToChat();
});

// --- Segédfüggvények ---
function isNameTaken(name) {
    let taken = false;
    let targetName = name.toLowerCase().replace(/\s/g, ''); 
    document.querySelectorAll('#user-list li span.user-name').forEach(span => {
        let existingName = span.textContent.replace(' (Te)', '').trim().toLowerCase().replace(/\s/g, '');
        if (existingName === targetName) taken = true;
    });
    return taken;
}

window.updateUserList = function(users) { 
    dom.userListUl.innerHTML = ''; 
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
        textSpan.innerText = dispName + (user === state.myUsername ? " (Te)" : "");
        
        leftGroup.appendChild(avatar); leftGroup.appendChild(textSpan); li.appendChild(leftGroup);
        
        if (user !== state.myUsername) {
            const callBtn = document.createElement('button');
            callBtn.className = 'call-user-btn'; callBtn.innerText = '📞';
            callBtn.onclick = () => window.startCall(user);
            li.appendChild(callBtn);
        }
        dom.userListUl.appendChild(li); 
    }); 
}

// --- Gomb Események (Header) ---
document.getElementById('room-btn').addEventListener('click', async () => {
    let targetRoom = prompt("Írd be a szoba nevét (vagy hagyd üresen a Közös szobához):", state.currentRoom === 'main' ? '' : state.currentRoom);
    if (targetRoom !== null) {
        targetRoom = targetRoom.trim().toLowerCase();
        if (targetRoom === "" || targetRoom === "közös" || targetRoom === "main") { targetRoom = "main"; }
        let pwd = "";
        
        if (targetRoom !== "main") { 
            pwd = prompt("Írd be a jelszót a(z) '" + targetRoom + "' szobához:"); 
            if (pwd === null) return; 
        }
        
        state.currentRoomPassword = pwd;
        
        setE2EState(false);
        await deriveKey(null);
        document.body.classList.remove('secret-mode');
        const secretBtn = document.getElementById('secret-mode-btn');
        if (secretBtn) secretBtn.innerHTML = "🕵️ Titkos";
        const ind = document.getElementById('secret-ind');
        if (ind) ind.remove();

        if (state.socket && state.socket.readyState === WebSocket.OPEN) { 
            state.socket.send(JSON.stringify({ action: 'join', username: state.myUsername, room: targetRoom, password: pwd })); 
        }
    }
});

// --- Titkos Gomb Esemény ---
const secretModeBtn = document.getElementById('secret-mode-btn');
if (secretModeBtn) {
    secretModeBtn.addEventListener('click', async () => {
        if (state.currentRoom === 'main' || !state.currentRoomPassword) {
            alert("Jelszóval védett privát szoba szükséges!");
            return;
        }

        if (!e2eEnabled) {
            setE2EState(true);
            await deriveKey(state.currentRoomPassword); 
            document.body.classList.add('secret-mode');
            secretModeBtn.innerHTML = "🔓 Kilépés";
            
            const headerTitle = document.querySelector('#header span');
            if (!document.getElementById('secret-ind')) {
                const indicator = document.createElement('span');
                indicator.id = "secret-ind";
                indicator.style.marginLeft = "8px";
                indicator.innerText = "🔒";
                headerTitle.appendChild(indicator);
            }
        } else {
            setE2EState(false);
            await deriveKey(null);
            document.body.classList.remove('secret-mode');
            secretModeBtn.innerHTML = "🕵️ Titkos";
            const ind = document.getElementById('secret-ind');
            if (ind) ind.remove();
        }
        if (state.socket && state.socket.readyState === WebSocket.OPEN) {
            dom.messagesDiv.innerHTML = ''; // Kiürítjük a chatet a frissítés előtt
            state.socket.send(JSON.stringify({ 
                action: 'join', 
                username: state.myUsername, 
                room: state.currentRoom, 
                password: state.currentRoomPassword 
            }));
        }
    });
}

document.getElementById('change-name-btn').addEventListener('click', () => {
    const oldDisp = state.myUsername.split('|')[0];
    const oldSeed = state.myUsername.split('|')[1] || Math.floor(Math.random() * 1000000);
    const newName = prompt("Új becenév:", oldDisp);
    if (newName && newName.trim() !== "" && newName.trim() !== oldDisp) {
        const cleanName = newName.trim();
        if (isNameTaken(cleanName)) { alert("Foglalt név!"); return; }
        state.myUsername = cleanName + '|' + oldSeed; 
        localStorage.setItem('chatNickname', state.myUsername); 
        if (state.socket && state.socket.readyState === WebSocket.OPEN) { 
            state.socket.send(JSON.stringify({ action: 'join', username: state.myUsername, room: state.currentRoom, password: state.currentRoomPassword })); 
        }
    }
});

document.getElementById('avatar-btn').addEventListener('click', () => {
    const dispName = state.myUsername.split('|')[0];
    const newSeed = Math.floor(Math.random() * 1000000);
    state.myUsername = dispName + '|' + newSeed;
    localStorage.setItem('chatNickname', state.myUsername);
    if (state.socket && state.socket.readyState === WebSocket.OPEN) { 
        state.socket.send(JSON.stringify({ action: 'join', username: state.myUsername, room: state.currentRoom, password: state.currentRoomPassword })); 
    }
});

document.getElementById('theme-toggle').addEventListener('click', () => { 
    const theme = document.documentElement.getAttribute('data-theme') === 'dark' ? 'light' : 'dark'; 
    document.documentElement.setAttribute('data-theme', theme); 
});

// --- GLOBÁLIS FÜGGVÉNYEK A HTML GOMBOKHOZ ---
if (!state.myReactions) state.myReactions = new Set();

window.openLightbox = function(url) { document.getElementById('lightbox-img').src = url; document.getElementById('lightbox').style.display = 'flex'; };
window.closeLightbox = function() { document.getElementById('lightbox').style.display = 'none'; };

window.openReactMenu = function(clientX, clientY, msgId, sender, text) { 
    window.activeMsgId = msgId; window.activeMsgSender = sender; window.activeMsgText = text; 
    document.getElementById('reaction-menu').style.display = 'flex'; 
    document.getElementById('menu-overlay').style.display = 'block'; 
    
    let menuWidth = 260; let leftPos = clientX - (menuWidth / 2); let topPos = clientY - 60; 
    if (leftPos < 10) leftPos = 10; if (leftPos + menuWidth > window.innerWidth) leftPos = window.innerWidth - menuWidth - 10; if (topPos < 10) topPos = clientY + 30; 
    
    document.getElementById('reaction-menu').style.left = leftPos + 'px'; 
    document.getElementById('reaction-menu').style.top = topPos + 'px'; 
};

window.closeReactMenu = function() { 
    document.getElementById('reaction-menu').style.display = 'none'; 
    document.getElementById('menu-overlay').style.display = 'none'; 
};

window.sendEmojiReact = function(emoji) { 
    if (window.activeMsgId && state.socket && state.socket.readyState === 1) { 
        const key = window.activeMsgId + ':' + emoji; 
        const isAdding = !state.myReactions.has(key); 
        if (isAdding) state.myReactions.add(key); else state.myReactions.delete(key); 
        
        const msgElement = document.getElementById('wrap-' + window.activeMsgId);
        const ts = msgElement ? msgElement.getAttribute('data-ts') : null;
        
        state.socket.send(JSON.stringify({ action: 'sendReaction', msgId: window.activeMsgId, timestamp: ts, emoji: emoji, isAdd: isAdding, room: state.currentRoom, username: state.myUsername })); 
    } 
    window.closeReactMenu(); 
};

window.initiateReply = function(sender, text) { 
    state.replyingTo = { sender: sender, message: text }; 
    const dispName = sender.split('|')[0];
    let previewHTML = text; 
    
    if (text.includes('.amazonaws.com/')) {
        const urlWithoutQuery = text.split('?')[0]; 
        const ext = urlWithoutQuery.split('.').pop().toLowerCase();
        if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'].includes(ext)) {
            previewHTML = '<img src="' + text + '" style="height:25px; width:auto; border-radius:4px; vertical-align:middle; margin-right:5px;"> 📸 Kép';
        } else { previewHTML = "📁 Fájl/Hang"; }
    }
    document.getElementById('reply-preview-sender').innerText = 'Válasz: ' + dispName; 
    document.getElementById('reply-preview-text').innerHTML = previewHTML; 
    document.getElementById('reply-preview').style.display = 'flex'; dom.messageInput.focus(); window.closeReactMenu(); 
};

window.initiateReplyFromMenu = function() { window.initiateReply(window.activeMsgSender, window.activeMsgText); };
window.cancelReply = function() { state.replyingTo = null; document.getElementById('reply-preview').style.display = 'none'; };

// --- ÜZENETKÜLDÉS ---
async function sendMessage() {
    const rawText = dom.messageInput.value.trim();
    if (rawText) {
        const tempId = 'temp-' + Date.now();
        addMessage(rawText, false, state.myUsername, true, tempId, state.replyingTo, null, 'pending', Date.now());
        const textToSend = await encryptMessage(rawText);

        if (state.socket && state.socket.readyState === WebSocket.OPEN) {
            const payload = { action: 'sendMessage', message: textToSend, username: state.myUsername, deviceId: state.myDeviceId, room: state.currentRoom, tempId: tempId, isSecretMode: e2eEnabled };
            if (state.replyingTo) { payload.replyTo = { sender: state.replyingTo.sender, message: state.replyingTo.message }; }
            state.socket.send(JSON.stringify(payload)); 
        }
        dom.messageInput.value = ''; window.cancelReply(); state.isTyping = false;
    }
}

dom.sendBtn.addEventListener('click', sendMessage); 
dom.messageInput.addEventListener('keypress', (e) => { if (e.key === 'Enter') sendMessage(); });

// --- Média Gombok ---
dom.micBtn.addEventListener('click', toggleMicrophone);
dom.uploadBtn.addEventListener('click', () => { dom.fileInput.removeAttribute('capture'); dom.fileInput.click(); });
dom.cameraBtn.addEventListener('click', () => { dom.fileInput.setAttribute('capture', 'environment'); dom.fileInput.click(); });
dom.fileInput.addEventListener('change', (e) => { 
    let currentReply = state.replyingTo ? { sender: state.replyingTo.sender, message: state.replyingTo.message } : null; 
    for(let i=0; i < e.target.files.length; i++) { state.uploadQueue.push({ file: e.target.files[i], replyTo: currentReply }); } 
    window.cancelReply(); 
    if (!state.isUploading) processNextFile(); 
});

window.startKaland = function() { document.getElementById('game-menu').style.display = 'none'; dom.messageInput.value = '/kaland '; dom.messageInput.focus(); }
window.startKep = function() { document.getElementById('game-menu').style.display = 'none'; dom.messageInput.value = '/kep '; dom.messageInput.focus(); }

dom.gameBtn.addEventListener('click', () => {
    const menu = document.getElementById('game-menu');
    menu.style.display = menu.style.display === 'flex' ? 'none' : 'flex';
    document.getElementById('emoji-picker-container').style.display = 'none'; 
});

dom.emojiBtn.addEventListener('click', () => {
    const container = document.getElementById('emoji-picker-container');
    container.style.display = container.style.display === 'block' ? 'none' : 'block';
    document.getElementById('game-menu').style.display = 'none'; 
});

document.querySelector('emoji-picker').addEventListener('emoji-click', event => {
    const cursorPosition = dom.messageInput.selectionStart;
    dom.messageInput.value = dom.messageInput.value.substring(0, cursorPosition) + event.detail.unicode + dom.messageInput.value.substring(cursorPosition);
    dom.messageInput.focus();
});

document.addEventListener('click', (e) => {
    if (!e.target.closest('#game-menu') && e.target.id !== 'game-btn') document.getElementById('game-menu').style.display = 'none';
    if (!e.target.closest('emoji-picker') && !e.target.closest('#emoji-btn')) document.getElementById('emoji-picker-container').style.display = 'none';
});

window.addEventListener('focus', () => { 
    state.unreadCount = 0; updateBadge(); 
    if (state.socket && state.socket.readyState === WebSocket.OPEN && state.unreadMsgQueue.length > 0) {
        state.unreadMsgQueue.forEach(msg => state.socket.send(JSON.stringify({ action: 'markRead', msgId: msg.msgId, timestamp: msg.timestamp, room: state.currentRoom })));
        state.unreadMsgQueue = [];
    }
});