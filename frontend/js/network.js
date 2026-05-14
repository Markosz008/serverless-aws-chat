// --- network.js ---
import { state, dom } from './state.js';
import { addMessage, updateBadge, updateReactionUI, scrollToBottom } from './ui.js';
import { decryptMessage } from './crypto.js';

function checkIfMine(msgSender, msgDeviceId) { 
    if (msgDeviceId && msgDeviceId !== 'unknown') return msgDeviceId === state.myDeviceId; 
    return msgSender === state.myUsername; 
}

export function renderSavedRooms() {
    if (!dom.roomListUl) return; 
    dom.roomListUl.innerHTML = '';
    if (!state.savedRooms.hasOwnProperty('main')) state.savedRooms['main'] = '';
    for (const [rName, rPwd] of Object.entries(state.savedRooms)) {
        const li = document.createElement('li');
        li.className = 'room-item' + (rName === state.currentRoom ? ' active-room' : '');
        li.textContent = rName === 'main' ? 'Közös Szoba' : rName;
        li.onclick = () => {
            if (rName === state.currentRoom) return; 
            state.currentRoomPassword = rPwd;
            if (state.socket && state.socket.readyState === WebSocket.OPEN) { 
                state.socket.send(JSON.stringify({ action: 'join', username: state.myUsername, room: rName, password: rPwd })); 
            }
        };
        dom.roomListUl.appendChild(li);
    }
}

export function connectToChat() {
    clearTimeout(state.reconnectTimer); 
    state.socket = new WebSocket(state.WSS_URL);
    
    // ÚJ: Memória a "beelőző" kék pipáknak
    if (!state.knownReadMessages) state.knownReadMessages = new Set(); 

    state.socket.onopen = () => {
        state.socket.send(JSON.stringify({ action: 'join', username: state.myUsername, room: state.currentRoom, password: state.currentRoomPassword }));
        [dom.messageInput, dom.sendBtn, dom.cameraBtn, dom.uploadBtn, dom.micBtn, dom.gameBtn, dom.emojiBtn].forEach(el => el.disabled = false); 
        dom.sendBtn.innerText = "Küldés"; dom.messageInput.placeholder = "Üzenet...";
        renderSavedRooms();
        
        if ((document.visibilityState === 'visible' || document.hasFocus()) && state.unreadMsgQueue && state.unreadMsgQueue.length > 0) {
            state.unreadMsgQueue.forEach((msg, index) => {
                setTimeout(() => {
                    if (state.socket && state.socket.readyState === WebSocket.OPEN) {
                        state.socket.send(JSON.stringify({ action: 'markRead', msgId: msg.msgId, timestamp: msg.timestamp, room: state.currentRoom }));
                    }
                }, index * 150);
            });
            state.unreadMsgQueue = [];
        }
    };
    
    state.socket.onclose = () => {
        [dom.messageInput, dom.sendBtn, dom.cameraBtn, dom.uploadBtn, dom.micBtn, dom.gameBtn, dom.emojiBtn].forEach(el => el.disabled = true); 
        dom.sendBtn.innerText = "Csatlakozás..."; dom.messageInput.placeholder = "Kapcsolat megszakadt...";
        state.reconnectTimer = setTimeout(connectToChat, 2000);
    };
    
    state.socket.onerror = (error) => { state.socket.close(); };

    state.socket.onmessage = async (event) => {
        const data = JSON.parse(event.data);
        
        if (data.type === 'error') { alert(data.message); }
        else if (data.type === 'roomJoined') {
            state.currentRoom = data.room; dom.messagesDiv.innerHTML = ''; window.cancelReply();
            state.savedRooms[state.currentRoom] = state.currentRoomPassword; 
            localStorage.setItem('chatSavedRooms', JSON.stringify(state.savedRooms)); 
            renderSavedRooms();
        }
        else if (data.uploadUrl && state.currentFileToUpload) {
            window.performUpload(data.uploadUrl, data.fileUrl);
        }
        else if (data.type === 'userList') {
            window.updateUserList(data.users);
        }
        else if (data.type === 'reaction') {
            updateReactionUI(data.msgId, data.emoji, data.isAdd);
        }
        else if (data.type === 'roomInvite') {
            if (window.showRoomInvite) window.showRoomInvite(data.sender, data.room, data.password);
        }
        else if (data.avatarUploadUrl && window._pendingAvatarUpload) {
            window._pendingAvatarUpload.resolve({ uploadUrl: data.avatarUploadUrl, fileUrl: data.avatarFileUrl });
        }
        else if (data.type === 'typing') {
            if (data.sender !== state.myUsername) {
                dom.typingDiv.innerText = data.sender.split('|')[0] + " éppen gépel...";
                dom.typingDiv.style.opacity = data.typing ? "1" : "0";
            }
        }
        else if (data.type === 'msgRead') {
            // JAVÍTÁS 1: Bejegyezzük a memóriába, hogy jött rá egy pipa!
            if (!state.knownReadMessages) state.knownReadMessages = new Set();
            state.knownReadMessages.add(data.msgId);

            const statEl = document.getElementById('status-' + data.msgId);
            if (statEl) { 
                statEl.innerText = '✓✓'; statEl.style.color = '#4facfe'; 
            } else {
                // Ha még nincs a képernyőn (mert épp dekódol a processzor), adunk neki fél másodperc esélyt!
                setTimeout(() => {
                    const retryEl = document.getElementById('status-' + data.msgId);
                    if (retryEl) { retryEl.innerText = '✓✓'; retryEl.style.color = '#4facfe'; }
                }, 500);
            }
        }
        else if (data.type === 'deleteMessage') {
            const wrap = document.getElementById('wrap-' + data.msgId);
            if (wrap) {
                // JAVÍTÁS: A doboz osztálya .message (nem .msg-bubble)
                const bubble = wrap.querySelector('.message');
                if (bubble) {
                    // Felülírjuk a tartalmat, ami egyben kidobja a benne lévő gombokat is!
                    bubble.innerHTML = '<div style="padding: 5px;">🚫 <i>Az üzenetet visszavonták.</i></div>';
                    bubble.style.background = 'transparent';
                    bubble.style.border = '1px dashed #666';
                    bubble.style.color = '#888';
                    bubble.style.boxShadow = 'none';
                }
                
                // Eltüntetjük a meglévő reakciókat is (amik a buborék alatt/mellett vannak)
                const reactions = wrap.querySelector('.reaction-container');
                if (reactions) reactions.remove();
                
                // Eltüntetjük a pipákat is, ha ott lennének
                const statusIcon = document.getElementById('status-' + data.msgId);
                if (statusIcon && statusIcon.parentNode) statusIcon.parentNode.remove();
            }
        }
        else if (data.type === 'webrtcSignal' && data.sender !== state.myUsername) {
            window.handleWebRTCSignal(data.signal, data.sender);
        }
        else if (data.message && data.sender) { 
            const isMine = checkIfMine(data.sender, data.deviceId); 
            if (isMine && data.tempId) {
                const pendingWrap = document.getElementById('wrap-' + data.tempId);
                if (pendingWrap) pendingWrap.remove();
            }

            // A lassan lefutó aszinkron dekódolás (itt előzött be a pipa!)
            const decryptedMsg = await decryptMessage(data.message);
            
            // JAVÍTÁS 2: Megkérdezzük a memóriát, hogy a dekódolás ALATT érkezett-e már kék pipa parancs!
            let currentStatus = 'sent';
            if (state.knownReadMessages && state.knownReadMessages.has(data.msgId)) {
                currentStatus = 'read';
            }

            addMessage(decryptedMsg, false, data.sender, isMine, data.msgId, data.replyTo, data.linkPreview, currentStatus, data.timestamp, null, data.audioUrl); 
            
            if (!isMine) {
                if (!document.hidden) {
                    if (state.socket && state.socket.readyState === WebSocket.OPEN) {
                        state.socket.send(JSON.stringify({ 
                            action: 'markRead', 
                            msgId: data.msgId, 
                            timestamp: data.timestamp, 
                            room: state.currentRoom 
                        }));
                    }
                } else {
                    if (!state.unreadMsgQueue) state.unreadMsgQueue = [];
                    state.unreadMsgQueue.push({ msgId: data.msgId, timestamp: data.timestamp });
                    state.unreadCount++;
                    updateBadge();
                }
            }
        }
        else if (data.type === 'history') { 
            dom.messagesDiv.innerHTML = ''; 
            let delay = 0; 
            
            for (const msg of data.messages) {
                const isMine = checkIfMine(msg.sender, msg.deviceId); 
                const status = msg.isRead ? 'read' : 'sent'; 
                
                // JAVÍTÁS: Ha logikailag törölt üzenetet kapunk az előzményekben
                if (msg.message === 'DELETED_MSG') {
                    // Üres üzenetként letesszük a DOM-ba
                    addMessage('', false, msg.sender, isMine, msg.msgId, null, null, status, msg.timestamp, null, null);
                    
                    // Azonnal rátesszük a visszavont designt
                    const wrap = document.getElementById('wrap-' + msg.msgId);
                    if (wrap) {
                        const bubble = wrap.querySelector('.message');
                        if (bubble) {
                            bubble.innerHTML = '<div style="padding: 5px;">🚫 <i>Az üzenetet visszavonták.</i></div>';
                            bubble.style.background = 'transparent';
                            bubble.style.border = '1px dashed #666';
                            bubble.style.color = '#888';
                            bubble.style.boxShadow = 'none';
                        }
                        const optionsBtn = wrap.querySelector('.desktop-options-btn');
                        if (optionsBtn) optionsBtn.remove();
                    }
                } 
                // Ha normál üzenet, akkor megy a szokásos dekódolás
                else {
                    const decryptedMsg = await decryptMessage(msg.message);
                    addMessage(decryptedMsg, false, msg.sender, isMine, msg.msgId, msg.replyTo, msg.linkPreview, status, msg.timestamp, msg.reactions, msg.audioUrl); 
                    
                    if (!isMine && !msg.isRead) {
                        delay += 150; 
                        setTimeout(() => {
                            if (state.socket && state.socket.readyState === WebSocket.OPEN) {
                                state.socket.send(JSON.stringify({ action: 'markRead', msgId: msg.msgId, timestamp: msg.timestamp, room: state.currentRoom }));
                            }
                        }, delay);
                    }
                }
            }
            scrollToBottom(); 
        }
    };
}