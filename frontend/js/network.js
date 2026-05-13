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
    
    state.socket.onopen = () => {
        state.socket.send(JSON.stringify({ action: 'join', username: state.myUsername, room: state.currentRoom, password: state.currentRoomPassword }));
        [dom.messageInput, dom.sendBtn, dom.cameraBtn, dom.uploadBtn, dom.micBtn, dom.gameBtn, dom.emojiBtn].forEach(el => el.disabled = false); 
        dom.sendBtn.innerText = "Küldés"; dom.messageInput.placeholder = "Üzenet...";
        renderSavedRooms();
        
        if (document.visibilityState === 'visible' && state.unreadMsgQueue.length > 0) {
            state.unreadMsgQueue.forEach(msg => state.socket.send(JSON.stringify({ action: 'markRead', msgId: msg.msgId, timestamp: msg.timestamp, room: state.currentRoom })));
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
            window.performUpload(data.uploadUrl, data.fileUrl); // media.js-ből jön
        }
        else if (data.type === 'userList') {
            window.updateUserList(data.users); // app.js-ben lesz definiálva
        }
        else if (data.type === 'reaction') {
            updateReactionUI(data.msgId, data.emoji, data.isAdd);
        }
        else if (data.type === 'typing') {
            if (data.sender !== state.myUsername) {
                dom.typingDiv.innerText = data.sender.split('|')[0] + " éppen gépel...";
                dom.typingDiv.style.opacity = data.typing ? "1" : "0";
            }
        }
        else if (data.type === 'msgRead') {
            const statEl = document.getElementById('status-' + data.msgId);
            if (statEl) { statEl.innerText = '✓✓'; statEl.style.color = '#4facfe'; }
        }
        else if (data.type === 'webrtcSignal' && data.sender !== state.myUsername) {
            window.handleWebRTCSignal(data.signal, data.sender); // media.js-ből jön
        }
        else if (data.message && data.sender) { 
            const isMine = checkIfMine(data.sender, data.deviceId); 
            if (isMine && data.tempId) {
                const pendingWrap = document.getElementById('wrap-' + data.tempId);
                if (pendingWrap) pendingWrap.remove();
            }

            const decryptedMsg = await decryptMessage(data.message);
            // --- ÚJ: Hozzáadva az audioUrl a hívás végéhez (11. paraméter) ---
            addMessage(decryptedMsg, false, data.sender, isMine, data.msgId, data.replyTo, data.linkPreview, 'sent', data.timestamp, null, data.audioUrl); 
            
            if (!isMine) {
                if (document.visibilityState === 'visible') {
                    state.socket.send(JSON.stringify({ action: 'markRead', msgId: data.msgId, timestamp: data.timestamp, room: state.currentRoom }));
                } else {
                    state.unreadMsgQueue.push({ msgId: data.msgId, timestamp: data.timestamp });
                    state.unreadCount++;
                    updateBadge();
                }
            }
        }
        else if (data.type === 'history') { 
            dom.messagesDiv.innerHTML = ''; 
            
            // for...of ciklus kell az aszinkron decrypt miatt!
            for (const msg of data.messages) {
                const isMine = checkIfMine(msg.sender, msg.deviceId); 
                const status = msg.isRead ? 'read' : 'sent'; 
                
                const decryptedMsg = await decryptMessage(msg.message);
                
                // --- ÚJ: Hozzáadva a msg.audioUrl a hívás végéhez (11. paraméter) ---
                addMessage(decryptedMsg, false, msg.sender, isMine, msg.msgId, msg.replyTo, msg.linkPreview, status, msg.timestamp, msg.reactions, msg.audioUrl); 
            }
            scrollToBottom(); 
        }
    };
}