// --- ui.js ---
import { state, dom } from './state.js';

// CSS dinamikus befűzése: Asztalin -120px-re tolva, Mobilon letisztítva
if (!document.getElementById('chat-options-style')) {
    const style = document.createElement('style');
    style.id = 'chat-options-style';
    style.innerHTML = `
        .desktop-options-btn {
            position: absolute;
            top: 50%;
            transform: translateY(-50%);
            background: var(--container-bg, #fff);
            border: 1px solid var(--border-color, #ddd);
            border-radius: 50%;
            width: 32px;
            height: 32px;
            display: none;
            align-items: center;
            justify-content: center;
            cursor: pointer;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
            font-size: 16px;
            color: var(--text-color, #333);
            z-index: 10;
        }
        .message-wrapper:hover .desktop-options-btn { display: flex; }
        .mine .desktop-options-btn { left: -120px; }
        
        @media (max-width: 650px) {
            .desktop-options-btn {
                display: flex !important;
                width: 24px; height: 24px; font-size: 14px;
                background: transparent; border: none; box-shadow: none; opacity: 0.6;
            }
            .mine .desktop-options-btn { left: -25px; }
        }
    `;
    document.head.appendChild(style);
}

let isLongPress = false;
let longPressTimer;

export function updateBadge() {
    if (state.unreadCount > 0) {
        document.title = "(" + state.unreadCount + ") AWS Chat";
        dom.navNotif.style.display = 'block';
        dom.navNotif.innerText = state.unreadCount;
    } else {
        document.title = "Serverless AWS Chat";
        dom.navNotif.style.display = 'none';
    }
    if ('setAppBadge' in navigator) {
        if (state.unreadCount > 0) navigator.setAppBadge(state.unreadCount).catch(console.error);
        else navigator.clearAppBadge().catch(console.error);
    }
}

export function scrollToBottom() { 
    setTimeout(() => { if (dom.messagesDiv) { dom.messagesDiv.scrollTop = dom.messagesDiv.scrollHeight + 1000; } }, 150); 
}

export function updateReactionUI(msgId, emoji, isAdd = true) { 
    const cont = document.getElementById('reacts-' + msgId); 
    if (!cont) return; 
    let badge = cont.querySelector('[data-emoji="' + emoji + '"]'); 
    let delta = isAdd ? 1 : -1; 
    if (badge) { 
        let count = parseInt(badge.getAttribute('data-count')) + delta; 
        if (count <= 0) { badge.remove(); } else { 
            badge.setAttribute('data-count', count); badge.innerText = emoji + ' ' + count; 
            const key = msgId + ':' + emoji; 
            if (state.myReactions && state.myReactions.has(key)) badge.classList.add('reacted'); 
            else badge.classList.remove('reacted'); 
        } 
    } else if (isAdd) { 
        badge = document.createElement('span'); 
        badge.className = 'reaction-badge'; 
        badge.setAttribute('data-emoji', emoji); 
        badge.setAttribute('data-count', '1'); 
        badge.innerText = emoji + ' 1'; 
        badge.onclick = () => { window.activeMsgId = msgId; window.sendEmojiReact(emoji); }; 
        const key = msgId + ':' + emoji; 
        if (state.myReactions && state.myReactions.has(key)) badge.classList.add('reacted'); 
        cont.appendChild(badge); 
    } 
    scrollToBottom(); 
}

export function addMessage(text, isSystem = false, sender = '', isMine = false, msgId = '', replyTo = null, linkPreview = null, status = 'sent', timestamp = 0, initialReactions = null, audioUrl = null) {
    let dispName = sender ? sender.split('|')[0] : '';
    let seed = sender ? (sender.split('|')[1] || sender) : (state.myUsername.split('|')[1] || state.myUsername);

    const row = document.createElement('div');
    row.className = 'message-row ' + (isMine ? 'mine' : 'others');
    row.id = 'wrap-' + msgId; 
    row.setAttribute('data-ts', timestamp);

    if (!isSystem) {
        const avatarWrap = document.createElement('div');
        avatarWrap.className = 'avatar-wrap' + (isMine ? ' hidden' : '');
        avatarWrap.dataset.user = dispName;
    
        const av = window.parseAvatar ? window.parseAvatar(sender) : { type: 'emoji', value: '🦊' };
        if (av.type === 'photo') {
            const img = document.createElement('img');
            img.src = av.value; img.alt = dispName;
            avatarWrap.appendChild(img);
        } else {
            avatarWrap.textContent = av.value;
        }
        row.appendChild(avatarWrap);
    }

    const wrapper = document.createElement('div'); 
    wrapper.className = 'message-wrapper ' + (isMine ? 'mine-wrapper' : 'others-wrapper');
    
    const msgDiv = document.createElement('div'); msgDiv.className = isSystem ? 'message system' : 'message ' + (isMine ? 'mine' : 'others');
    let contentHTML = ''; if (sender && !isMine) contentHTML += '<span class="sender-name">' + dispName + '</span>';
    
    if (replyTo) { 
        let previewContent = replyTo.message;
        if (replyTo.message.includes('.amazonaws.com/')) {
            const urlWithoutQuery = replyTo.message.split('?')[0];
            const ext = urlWithoutQuery.split('.').pop().toLowerCase();
            if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'].includes(ext)) {
                previewContent = '<img src="' + replyTo.message + '" style="height:35px; width:auto; border-radius:4px; margin-top:4px; display:block;">';
            } else { previewContent = "📁 [Fájl/Hang]"; }
        }
        contentHTML += '<div class="quoted-msg"><strong>' + replyTo.sender.split('|')[0] + '</strong><br><span>' + previewContent + '</span></div>'; 
    }
    
    if (text.includes('.amazonaws.com/') && !audioUrl) {
        const urlParts = text.split('/'); const fullFileName = urlParts[urlParts.length - 1]; const originalName = fullFileName.split('_').slice(1).join('_') || "Fájl"; const ext = originalName.split('.').pop().toLowerCase(); 
        const imgExts = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic']; const audioExts = ['mp3', 'wav', 'ogg', 'webm', 'm4a', 'aac', 'mp4'];
        
        if (imgExts.includes(ext)) { 
            const img = document.createElement('img'); img.src = text; 
            img.onclick = (e) => { if (isLongPress) { isLongPress = false; e.preventDefault(); return; } window.openLightbox(text); }; 
            img.onload = scrollToBottom; msgDiv.innerHTML = contentHTML; msgDiv.appendChild(img); 
        } 
        else if (audioExts.includes(ext)) { 
            msgDiv.innerHTML = contentHTML + '<audio controls preload="metadata" playsinline src="' + text + '#t=0.001"></audio>'; 
        }
        else { msgDiv.innerHTML = contentHTML + '<a href="' + text + '" target="_blank" class="file-link">📄 ' + originalName + '</a>'; }
    } else { 
        const textNode = document.createTextNode(text); 
        msgDiv.innerHTML = contentHTML; 
        msgDiv.appendChild(textNode); 
    }

    if (audioUrl) {
        const playerDiv = document.createElement('div');
        playerDiv.className = 'kalandmester-player';
        const playBtn = document.createElement('button');
        playBtn.className = 'km-play-btn';
        playBtn.innerHTML = '▶️';
        const waveDiv = document.createElement('div');
        waveDiv.className = 'km-waveform';
        for(let i=0; i<5; i++) { waveDiv.appendChild(document.createElement('span')); }
        const audioObj = new Audio(audioUrl);
        playBtn.onclick = (e) => {
            e.stopPropagation();
            if (audioObj.paused) { audioObj.play(); playBtn.innerHTML = '⏸️'; waveDiv.classList.add('playing'); } 
            else { audioObj.pause(); playBtn.innerHTML = '▶️'; waveDiv.classList.remove('playing'); }
        };
        audioObj.onended = () => { playBtn.innerHTML = '▶️'; waveDiv.classList.remove('playing'); };
        playerDiv.appendChild(playBtn); playerDiv.appendChild(waveDiv); msgDiv.appendChild(playerDiv);
    }

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
        
        // A JAVÍTÁS: insertAdjacentHTML-t használunk, ami csak BESZÚRJA az új kódot a végére,
        // így nem semmisíti meg az előtte lévő elemek (pl. a képek) kattintási eseményeit!
        msgDiv.insertAdjacentHTML('beforeend', '<div style="text-align:right; margin-top:2px; font-size:12px; font-weight:bold;"><span id="status-' + msgId + '" style="color:' + sColor + '; margin-left: 5px; text-shadow: 0px 0px 2px rgba(0,0,0,0.3);">' + sIcon + '</span></div>');
    }

    // --- REAKCIÓ / HOSSZÚ NYOMÁS ESEMÉNYEK ---
    if (!isSystem && msgId && status !== 'pending' && status !== 'failed') {
        let startX, startY;
        msgDiv.ontouchstart = (e) => { 
            isLongPress = false; let touch = e.touches[0]; startX = touch.clientX; startY = touch.clientY;
            longPressTimer = setTimeout(() => { 
                isLongPress = true; 
                if(window.openReactMenu) window.openReactMenu(touch.clientX, touch.clientY, msgId, sender || state.myUsername, text); 
            }, 400); 
        };
        msgDiv.ontouchend = (e) => { clearTimeout(longPressTimer); if (isLongPress) e.preventDefault(); }; 
        msgDiv.ontouchmove = (e) => { 
            let touch = e.touches[0];
            if (Math.abs(touch.clientX - startX) > 10 || Math.abs(touch.clientY - startY) > 10) { clearTimeout(longPressTimer); isLongPress = false; }
        }; 
        msgDiv.oncontextmenu = (e) => { e.preventDefault(); if(window.openReactMenu) window.openReactMenu(e.clientX, e.clientY, msgId, sender || state.myUsername, text); };
        
        const hoverBtn = document.createElement('div'); hoverBtn.className = 'desktop-react-btn'; hoverBtn.innerHTML = '😀'; 
        hoverBtn.onclick = (e) => { e.stopPropagation(); if(window.openReactMenu) window.openReactMenu(e.clientX, e.clientY, msgId, sender || state.myUsername, text); }; 
        msgDiv.appendChild(hoverBtn);
        
        const replyBtn = document.createElement('div'); replyBtn.className = 'desktop-reply-btn'; replyBtn.innerHTML = '↩️'; 
        replyBtn.onclick = (e) => { e.stopPropagation(); if(window.initiateReply) window.initiateReply(sender || state.myUsername, text); }; 
        msgDiv.appendChild(replyBtn);

        // --- ÚJ: 3 PONT (TOVÁBBIAK) GOMB - CSAK SAJÁT ÜZENETNÉL! ---
        if (isMine) {
            const optionsBtn = document.createElement('div'); 
            optionsBtn.className = 'desktop-options-btn'; 
            optionsBtn.innerHTML = '⋮'; 
            optionsBtn.onclick = (e) => { 
                e.stopPropagation(); 
                if(window.openMessageOptions) window.openMessageOptions(e, msgId, timestamp, isMine); 
            }; 
            msgDiv.appendChild(optionsBtn);
        }
    }
    
    wrapper.appendChild(msgDiv);
    
    if (!isSystem && msgId && status !== 'pending') { 
        const rCont = document.createElement('div'); 
        rCont.className = 'reaction-container'; rCont.id = 'reacts-' + msgId; 
        
        if (initialReactions) {
            if (!state.myReactions) state.myReactions = new Set();
            for (const [em, users] of Object.entries(initialReactions)) {
                if (users.length > 0) {
                    const badge = document.createElement('span'); 
                    badge.className = 'reaction-badge'; 
                    if (users.includes(state.myUsername)) { badge.classList.add('reacted'); state.myReactions.add(msgId + ':' + em); }
                    badge.setAttribute('data-emoji', em); badge.setAttribute('data-count', users.length); 
                    badge.innerText = em + ' ' + users.length; 
                    badge.onclick = () => { window.activeMsgId = msgId; window.sendEmojiReact(em); };
                    rCont.appendChild(badge);
                }
            }
        }
        wrapper.appendChild(rCont); 
    }
    
    row.appendChild(wrapper); dom.messagesDiv.appendChild(row); scrollToBottom();
}