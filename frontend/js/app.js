// --- app.js ---
import { state, dom } from './state.js';
import { connectToChat } from './network.js';
import { addMessage, updateBadge } from './ui.js';
import { toggleMicrophone, processNextFile } from './media.js';
import { deriveKey, setE2EState, encryptMessage, e2eEnabled } from './crypto.js';

window.state = state; // GLOBÁLIS EXPORT A HTML TPL-NEK

// --- Képernyőméret fix mobilokra ---
const setAppHeight = () => { let vh = window.innerHeight; if (window.visualViewport) { vh = window.visualViewport.height; } document.documentElement.style.setProperty('--app-height', vh + 'px'); };
window.addEventListener('resize', setAppHeight); window.addEventListener('orientationchange', setAppHeight);
if (window.visualViewport) { window.visualViewport.addEventListener('resize', setAppHeight); window.visualViewport.addEventListener('scroll', setAppHeight); }
setAppHeight(); 

// --- Inicializálás és Login ---
const savedName = localStorage.getItem('chatNickname');
if (savedName) {
    let username = savedName;
    // Régi formátum: csak számokból áll a meta → konvertálás
    const parts = savedName.split('|');
    if (parts.length >= 2 && /^\d+$/.test(parts[1])) {
        username = parts[0] + '|emoji:🦊';
        localStorage.setItem('chatNickname', username);
    }
    state.myUsername = username;
    dom.loginScreen.style.display = 'none';
    connectToChat();
    // PWA / Brave ellenőrzés auto-login után
    setTimeout(checkAndSubscribePush, 2000);
}

dom.joinBtn.addEventListener('click', () => {
    let rawName = dom.usernameInput.value.trim() || "Anonim_" + Math.floor(Math.random() * 1000);
    // Alapértelmezett emoji a belépéskor:
    state.myUsername = rawName + '|emoji:🦊';
    localStorage.setItem('chatNickname', state.myUsername);
    dom.loginScreen.style.display = 'none';
    connectToChat();
    setTimeout(() => { if (window.updateAllMyAvatars) window.updateAllMyAvatars(); }, 300);
    // PWA / Brave ellenőrzés belépés gomb után
    setTimeout(checkAndSubscribePush, 2000);
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
    
    // --- ÚJ RÉSZ: Duplikációk kiszűrése a megjelenítés előtt ---
    const uniqueUsersMap = new Map();
    
    users.forEach(userString => {
        const usernamePart = userString.split('|')[0];
        // Csak akkor mentjük el, ha még nem láttuk ezt a nevet, VAGY ha ez az aktuális eszköz
        if (!uniqueUsersMap.has(usernamePart) || userString === state.myUsername) {
            uniqueUsersMap.set(usernamePart, userString);
        }
    });

    const uniqueUsersArray = Array.from(uniqueUsersMap.values());
    // --- ÚJ RÉSZ VÉGE ---

    // Az eredeti kirajzoló logika, de már a szűrt listán (uniqueUsersArray) megy végig
    uniqueUsersArray.forEach(user => {
        const dispName = user.split('|')[0];
        const av       = window.parseAvatar ? window.parseAvatar(user) : { type:'emoji', value:'🦊' };
 
        const li = document.createElement('li');
 
        const leftGroup = document.createElement('div');
        leftGroup.style.cssText = 'display:flex; align-items:center; flex:1; min-width:0;';
 
        // Avatar (emoji vagy foto)
        const avWrap = document.createElement('div');
        avWrap.style.cssText = 'width:24px;height:24px;border-radius:50%;margin-right:8px;background:var(--bg-color);display:flex;align-items:center;justify-content:center;font-size:14px;flex-shrink:0;overflow:hidden;';
        if (av.type === 'photo') {
            const img = document.createElement('img');
            img.src = av.value; img.style.cssText = 'width:100%;height:100%;object-fit:cover;border-radius:50%;';
            avWrap.appendChild(img);
        } else {
            avWrap.textContent = av.value;
        }
 
        const textSpan = document.createElement('span');
        textSpan.className = 'user-name';
        textSpan.innerText = dispName + (user === state.myUsername ? " (Te)" : "");
 
        leftGroup.appendChild(avWrap);
        leftGroup.appendChild(textSpan);
        li.appendChild(leftGroup);
 
        if (user !== state.myUsername) {
            const callBtn = document.createElement('button');
            callBtn.className = 'call-user-btn'; callBtn.innerText = '📞';
            callBtn.onclick = () => window.startCall(user);
            li.appendChild(callBtn);
 
            // Meghívó gomb
            const invBtn = document.createElement('button');
            invBtn.className = 'invite-user-btn'; invBtn.innerText = '📨';
            invBtn.title = 'Meghívás ebbe a szobába';
            invBtn.setAttribute('data-invite-target', user);
            invBtn.onclick = () => window.sendRoomInvite(user);
            li.appendChild(invBtn);
        }
        dom.userListUl.appendChild(li);
    });
    // Saját avatar frissítése
    if (window.updateAllMyAvatars) window.updateAllMyAvatars();
};

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
    if (window.updateAllMyAvatars) window.updateAllMyAvatars();
        if (window.closeProfileMenu)   window.closeProfileMenu();
    }
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
        // A titkosítás mindkét esetben kell
        const textToSend = await encryptMessage(rawText);

        if (window.state.editingMsgId) {
            // --- SZERKESZTÉS MÓD ---
            if (state.socket && state.socket.readyState === WebSocket.OPEN) {
                state.socket.send(JSON.stringify({ 
                    action: 'editMessage', 
                    msgId: window.state.editingMsgId, 
                    timestamp: window.state.editingMsgTimestamp,
                    room: state.currentRoom, 
                    username: state.myUsername,
                    newMessage: textToSend 
                }));
            }
            
            // UI visszaállítása normál állapotra
            window.state.editingMsgId = null;
            window.state.editingMsgTimestamp = null;
            dom.sendBtn.innerText = 'Küldés';
            dom.sendBtn.style.background = '#ff9900'; // Vissza az eredeti narancssárgára
            
        } else {
            // --- NORMÁL KÜLDÉS MÓD (A te eredeti kódod) ---
            const tempId = 'temp-' + Date.now();
            addMessage(rawText, false, state.myUsername, true, tempId, state.replyingTo, null, 'pending', Date.now());

            if (state.socket && state.socket.readyState === WebSocket.OPEN) {
                const payload = { action: 'sendMessage', message: textToSend, username: state.myUsername, deviceId: state.myDeviceId, room: state.currentRoom, tempId: tempId, isSecretMode: e2eEnabled };
                if (state.replyingTo) { payload.replyTo = { sender: state.replyingTo.sender, message: state.replyingTo.message }; }
                state.socket.send(JSON.stringify(payload)); 
            }
        }

        // Mindkét esetben ürítjük a beviteli mezőt és lezárjuk a gépelést
        dom.messageInput.value = ''; 
        window.cancelReply(); 
        state.isTyping = false;
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

// --- JAVÍTVA: Agresszív újracsatlakozás és Ghost Socket védelem ---
function handleAppWakeUp() {
    if (!document.hidden) {
        state.unreadCount = 0; 
        updateBadge(); 
        
        // 1. Ghost Socket (halott kapcsolat) ellenőrzése
        if (state.socket && state.socket.readyState === WebSocket.OPEN) {
            try { 
                state.socket.send(JSON.stringify({ action: 'ping' })); 
            } catch(e) { 
                connectToChat(); 
                return; 
            }
        } else if (!state.socket || state.socket.readyState !== WebSocket.OPEN) {
            connectToChat(); 
            return;
        }

        // 2. Várakozó olvasási jelzések kiküldése (késleltetve a tűzfal miatt)
        if (state.unreadMsgQueue && state.unreadMsgQueue.length > 0) {
            state.unreadMsgQueue.forEach((msg, index) => {
                setTimeout(() => {
                    if (state.socket && state.socket.readyState === WebSocket.OPEN) {
                        state.socket.send(JSON.stringify({ action: 'markRead', msgId: msg.msgId, timestamp: msg.timestamp, room: state.currentRoom }));
                    }
                }, index * 100);
            });
            state.unreadMsgQueue = [];
        }
    }
}

// --- ÚJ ÉS JAVÍTOTT ESEMÉNYFIGYELŐK (EVENT LISTENERS) ---

// 1. Ha az asztali böngésző vagy az ablak visszakapja a fókuszt
window.addEventListener('focus', handleAppWakeUp);

// 2. Kombinált Visibility Change: Lekezeli a háttérbe rakást ÉS a visszatérést is
document.addEventListener('visibilitychange', () => {
    if (!document.hidden) {
        // App visszatért a fókuszba -> Ébresztés
        handleAppWakeUp();
    } else {
        // App háttérbe került (pl. iOS swipe up) -> Azonnali, szabályos bontás
        if (state.socket && state.socket.readyState === WebSocket.OPEN) {
            state.socket.close(1000, "App backgrounded");
        }
    }
});

// 3. Extra védelem: Ha a felhasználó konkrétan bezárja a böngészőlapot/appot
window.addEventListener('pagehide', () => {
    if (state.socket && state.socket.readyState === WebSocket.OPEN) {
        state.socket.close(1000, "App closed");
    }
});

// 4. BOMBABIZTOS TRÜKK: Beragadt olvasási pipák kiküldése egérmozgásra/érintésre
['mousemove', 'click', 'keydown', 'touchstart'].forEach(evt => {
    document.addEventListener(evt, () => {
        // Csak akkor futtatjuk, ha van beragadt olvasatlan üzenet
        if (state.unreadMsgQueue && state.unreadMsgQueue.length > 0) {
            handleAppWakeUp();
        }
    }, { passive: true });
});


// ═══════════════════════════════════════════════════════════════
// WEB PUSH API & SERVICE WORKER (OFFLINE ÉRTESÍTÉSEK)
// ═══════════════════════════════════════════════════════════════

const VAPID_PUBLIC_KEY = 'BD8VoYkxZK-eg6aZ0z7vTrz0K3FFfNbQ3bwLhy3gNc6RCaakaHKYXeTpmhr5rBC53jLibEO-ahPPjVOFJ896OM0'; 

function urlB64ToUint8Array(base64String) {
    const padding = '='.repeat((4 - base64String.length % 4) % 4);
    const base64 = (base64String + padding).replace(/\-/g, '+').replace(/_/g, '/');
    const rawData = window.atob(base64);
    const outputArray = new Uint8Array(rawData.length);
    for (let i = 0; i < rawData.length; ++i) { outputArray[i] = rawData.charCodeAt(i); }
    return outputArray;
}

if ('serviceWorker' in navigator && 'PushManager' in window) {
    navigator.serviceWorker.register('/sw.js').then(function(swReg) {
        console.log('Service Worker regisztrálva, Push készen áll.');
        
        window.subscribeToPush = function() {
            swReg.pushManager.getSubscription().then(function(sub) {
                if (sub === null) {
                    swReg.pushManager.subscribe({
                        userVisibleOnly: true,
                        applicationServerKey: urlB64ToUint8Array(VAPID_PUBLIC_KEY)
                    }).then(function(newSub) {
                        sendPushSubToBackend(newSub);
                    }).catch(function(e) { 
                        console.log('Push nem elérhető (Brave/Asztali), belső értesítés mód aktív.');
                        // Belső jelzés a Headerben Brave esetében
                        const statusDot = document.getElementById('nav-notif');
                        if (statusDot) { statusDot.style.background = '#ff9900'; statusDot.title = "Belső értesítések aktívak"; }
                    });
                } else {
                    sendPushSubToBackend(sub);
                }
            });
        };
    }).catch(function(error) {
        console.error('Service Worker regisztrációs hiba:', error);
    });
}

function sendPushSubToBackend(subscription) {
    if (window.state && window.state.socket && window.state.socket.readyState === WebSocket.OPEN) {
        window.state.socket.send(JSON.stringify({
            action: 'savePushSub',
            username: window.state.myUsername,
            subscription: subscription
        }));
        console.log("Push Token elküldve a backendnek!");
    }
}

// --- Push feliratkozás vezérlése (Brave/PWA logika) ---
async function checkAndSubscribePush() {
    const isPWA = window.matchMedia('(display-mode: standalone)').matches || window.navigator.standalone;
    const isBrave = !!(navigator.brave && await navigator.brave.isBrave());

    console.log("Környezet ellenőrzése - PWA:", isPWA, "Brave:", isBrave);

    if (isPWA || !isBrave) {
        console.log("Push regisztráció indítása...");
        if (window.subscribeToPush) window.subscribeToPush();
    } else {
        console.log("Push regisztráció kihagyva (Brave asztali mód). Belső értesítések aktívak.");
    }
}

// --- ÚJ: 3 PONTOS (Továbbiak) MENÜ ÉS VISSZAVONÁS LOGIKA ---
window.openMessageOptions = function(e, msgId, timestamp, isMine) {
    window.activeMsgId = msgId;
    window.activeMsgTimestamp = timestamp;

    let menu = document.getElementById('options-menu');
    if (!menu) {
        menu = document.createElement('div');
        menu.id = 'options-menu';
        // A Messenger-szerű lebegő menü stílusa
        menu.style.cssText = 'position:fixed; background:var(--bg-color, #2a2d31); border:1px solid #4facfe; border-radius:8px; padding:5px 0; display:none; z-index:9999; flex-direction:column; box-shadow:0 4px 15px rgba(0,0,0,0.5); min-width:180px;';
        document.body.appendChild(menu);
        
        // Ha bárhova máshova kattintunk, záródjon be
        document.addEventListener('click', (ev) => {
            if (!ev.target.closest('#options-menu') && !ev.target.classList.contains('options-btn')) {
                menu.style.display = 'none';
            }
        });
    }

    menu.innerHTML = ''; // Kiürítjük a korábbi gombokat

    if (isMine) {
        const delBtn = document.createElement('button');
        delBtn.innerHTML = '🗑️ Visszavonás mindkét félnél';
        delBtn.style.cssText = 'background:none; border:none; color:#ff4d4d; padding:10px 15px; cursor:pointer; text-align:left; font-size:14px; width:100%;';
        delBtn.onmouseover = () => delBtn.style.background = 'rgba(255, 77, 77, 0.1)';
        delBtn.onmouseout = () => delBtn.style.background = 'transparent';
        
        delBtn.onclick = () => {
            if (confirm('Biztosan visszavonod ezt az üzenetet mindkét félnél? A művelet nem vonható vissza!')) {
                if (state.socket && state.socket.readyState === WebSocket.OPEN) {
                    state.socket.send(JSON.stringify({
                        action: 'deleteMessage',
                        msgId: window.activeMsgId,
                        timestamp: window.activeMsgTimestamp,
                        room: state.currentRoom,
                        username: state.myUsername
                    }));
                }
                menu.style.display = 'none';
            }
        };
        menu.appendChild(delBtn);
        
        // Előkészítjük a jövőbeli funkciót
        const editBtn = document.createElement('button');
        editBtn.innerHTML = '✏️ Módosítás';
        editBtn.style.cssText = 'background:none; border:none; color:#4facfe; padding:10px 15px; cursor:pointer; text-align:left; font-size:14px; width:100%; border-top:1px solid rgba(255,255,255,0.1);';
        editBtn.onmouseover = () => editBtn.style.background = 'rgba(79, 172, 254, 0.1)';
        editBtn.onmouseout = () => editBtn.style.background = 'transparent';
        
        editBtn.onclick = () => {
            const wrap = document.getElementById('wrap-' + window.activeMsgId);
            let oldText = "";
            if (wrap) {
                const bubble = wrap.querySelector('.message');
                // Megkeressük az eredeti, nyers szöveget a buborékban
                for (let i = 0; i < bubble.childNodes.length; i++) {
                    if (bubble.childNodes[i].nodeType === Node.TEXT_NODE && bubble.childNodes[i].nodeValue.trim() !== '') {
                        oldText = bubble.childNodes[i].nodeValue;
                        break;
                    }
                }
            }
            
            // 1. Visszatesszük a szöveget az inputba
            const inputField = document.getElementById('message-input');
            inputField.value = oldText;
            inputField.focus();
            
            // 2. Beállítjuk a szerkesztési állapotot
            window.state.editingMsgId = window.activeMsgId;
            window.state.editingMsgTimestamp = window.activeMsgTimestamp;
            
            // 3. A "Küldés" gombot átalakítjuk "Mentés" gombbá
            const sBtn = document.getElementById('send-btn');
            sBtn.innerText = '💾 Mentés';
            sBtn.style.background = '#4facfe'; // Kékre vált, hogy egyértelmű legyen
            
            // 4. Bezárjuk a felugró menüt
            menu.style.display = 'none';
        };
        menu.appendChild(editBtn);

    } else {
        menu.innerHTML = '<div style="padding:10px 15px; color:#888; font-size:14px;">Nincs elérhető opció</div>';
    }

    menu.style.display = 'flex';
    
    // Pozicionálás az ikon mellé
    const rect = e.target.getBoundingClientRect();
    menu.style.left = Math.min(rect.left, window.innerWidth - 190) + 'px';
    menu.style.top = (rect.top + 25) + 'px';
};