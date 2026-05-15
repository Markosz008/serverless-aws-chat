<!DOCTYPE html>
<html lang="hu">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover, interactive-widget=resizes-content">
    <title>AWS Chat</title>
    <link rel="manifest" href="manifest.json">
    <meta name="theme-color" content="#232f3e">
    <link rel="apple-touch-icon" href="https://cdn-icons-png.flaticon.com/512/134/134808.png">
    <script type="module" src="https://cdn.jsdelivr.net/npm/emoji-picker-element@^1/index.js"></script>
    <link rel="stylesheet" href="css/style.css">
    <link rel="stylesheet" href="css/secret.css">
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
        <div style="width:1px; background:var(--border-color); height:30px; margin:0 5px;"></div>
        <span onclick="initiateReplyFromMenu()">↩️</span>
    </div>

    <div id="emoji-picker-container">
        <emoji-picker></emoji-picker>
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
            <button id="toggle-video-btn" class="video-btn" onclick="toggleVideo()" style="background:#4CAF50;">📹 Kamera Ki</button>
            <button id="end-call-btn" class="video-btn" onclick="endCall()" style="background:#ff3b30;">Megszakítás ☎️</button>
        </div>
    </div>

    <!-- ═══════════════════════════════════════════════
         AVATAR SZERKESZTŐ MODAL
    ═══════════════════════════════════════════════ -->
    <div id="avatar-modal-overlay" onclick="closeAvatarModal()"></div>
    <div id="avatar-modal">
        <div id="avatar-modal-header">
            <span>🎨 Avatar beállítás</span>
            <button onclick="closeAvatarModal()" id="avatar-modal-close">✕</button>
        </div>

        <!-- Előnézet -->
        <div id="avatar-preview-wrap">
            <div id="avatar-preview-circle">
                <span id="avatar-preview-emoji">🦊</span>
                <img id="avatar-preview-photo" src="" alt="" style="display:none;">
            </div>
            <div id="avatar-preview-name">Márk</div>
        </div>

        <!-- Tab választó -->
        <div id="avatar-tab-row">
            <button class="avatar-tab active" id="tab-emoji" onclick="switchAvatarTab('emoji')">😀 Emoji</button>
            <button class="avatar-tab" id="tab-photo" onclick="switchAvatarTab('photo')">📷 Saját kép</button>
        </div>

        <!-- EMOJI TAB -->
        <div id="avatar-tab-emoji-content">
            <div id="emoji-avatar-grid">
                <!-- JS tölti fel -->
            </div>
        </div>

        <!-- FOTÓ TAB -->
        <div id="avatar-tab-photo-content" style="display:none;">
            <div id="photo-upload-area" onclick="document.getElementById('avatar-file-input').click()">
                <div id="photo-upload-icon">📷</div>
                <div id="photo-upload-text">Kattints a feltöltéshez</div>
                <div id="photo-upload-sub">JPG, PNG, max 2MB</div>
            </div>
            <input type="file" id="avatar-file-input" accept="image/jpeg,image/png,image/webp" style="display:none;">
            <div id="photo-upload-progress" style="display:none;">
                <div id="photo-upload-bar"></div>
                <span id="photo-upload-pct">0%</span>
            </div>
            <button id="remove-photo-btn" onclick="removeCustomPhoto()" style="display:none;">
                🗑️ Saját kép eltávolítása
            </button>
        </div>

        <!-- Mentés -->
        <button id="avatar-save-btn" onclick="saveAvatar()">✅ Mentés</button>
    </div>

    <!-- PROFIL DROPDOWN -->
    <div id="profile-overlay" onclick="closeProfileMenu()"></div>
    <div id="profile-dropdown">
        <div id="profile-dropdown-header">
            <div id="profile-dropdown-avatar-wrap">
                <span id="profile-dd-emoji">🦊</span>
                <img id="profile-dd-photo" src="" alt="" style="display:none;">
            </div>
            <div id="profile-dropdown-info">
                <div id="profile-dropdown-name">...</div>
                <div id="profile-dropdown-tag">🟢 Online</div>
            </div>
        </div>

        <!-- Avatar szerkesztés — megnyitja a modalt -->
        <button class="profile-menu-item" id="avatar-btn">
            <span class="pmi-icon">🎨</span>
            <div>
                <div class="pmi-label">Avatar szerkesztés</div>
                <div class="pmi-sub">Emoji vagy saját kép</div>
            </div>
        </button>

        <button class="profile-menu-item" id="change-name-btn">
            <span class="pmi-icon">✏️</span>
            <div>
                <div class="pmi-label">Névváltás</div>
                <div class="pmi-sub">Becenév megváltoztatása</div>
            </div>
        </button>

        <div class="profile-menu-sep"></div>

        <div class="profile-menu-item" onclick="toggleNotifications()">
            <span class="pmi-icon" id="notif-icon">🔔</span>
            <div style="flex:1;">
                <div class="pmi-label">Értesítések</div>
                <div class="pmi-sub" id="notif-sub">Bekapcsolva</div>
            </div>
            <div id="notif-switch" class="pmi-switch active"></div>
        </div>

        <div class="profile-menu-item" onclick="toggleSound()">
            <span class="pmi-icon" id="sound-icon">🔊</span>
            <div style="flex:1;">
                <div class="pmi-label">Hangjelzés</div>
                <div class="pmi-sub" id="sound-sub">Bekapcsolva</div>
            </div>
            <div id="sound-switch" class="pmi-switch active"></div>
        </div>
    </div>

    <!-- TÉMA PANEL -->
    <div id="theme-panel-overlay" onclick="closeThemePanel()"></div>
    <div id="theme-panel">
        <div id="theme-panel-title">🎨 Válassz témát</div>
        <div id="theme-options">
            <button class="theme-opt" data-t="light" onclick="setTheme('light',this)">
                <div class="theme-swatch" style="background:#5a4fcf;">☀️</div><span>Nappal</span>
            </button>
            <button class="theme-opt active" data-t="dark" onclick="setTheme('dark',this)">
                <div class="theme-swatch" style="background:#ff9900;">🌙</div><span>Sötét</span>
            </button>
            <button class="theme-opt" data-t="retro" onclick="setTheme('retro',this)">
                <div class="theme-swatch" style="background:#003300;color:#00ff41;font-family:monospace;font-size:13px;">&gt;_</div><span>Retro</span>
            </button>
            <button class="theme-opt" data-t="pastel" onclick="setTheme('pastel',this)">
                <div class="theme-swatch" style="background:#c084fc;">🌸</div><span>Pastel</span>
            </button>
            <button class="theme-opt" data-t="cyber" onclick="setTheme('cyber',this)">
                <div class="theme-swatch" style="background:#f000ff;box-shadow:0 0 10px rgba(240,0,255,0.6);">⚡</div><span>Cyber</span>
            </button>
        </div>
    </div>

    <!-- SZOBA MEGHÍVÓ TOAST -->
    <div id="invite-toast">
        <div id="invite-toast-content">
            <div id="invite-toast-avatar-wrap">
                <span id="invite-toast-emoji">👤</span>
                <img id="invite-toast-photo" src="" alt="" style="display:none;">
            </div>
            <div id="invite-toast-text">
                <div id="invite-toast-name"></div>
                <div id="invite-toast-room"></div>
            </div>
        </div>
        <div id="invite-toast-actions">
            <button id="invite-accept-btn" onclick="acceptRoomInvite()">✅ Csatlakozás</button>
            <button id="invite-decline-btn" onclick="declineRoomInvite()">✕</button>
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
            <div id="header" style="display:flex; flex-wrap:nowrap; justify-content:space-between; align-items:center; background:var(--header-bg); color:var(--header-text); padding:10px 15px; font-weight:bold; flex-shrink:0; gap:0; overflow:visible; position:relative; box-sizing:border-box;">
 
    <!-- BAL: avatar + cím -->
    <div id="header-left" style="display:flex; align-items:center; gap:8px; flex-shrink:0; min-width:0; overflow:visible;">
        <div id="header-avatar-wrap" onclick="toggleProfileMenu()" title="Profil" style="width:36px; height:36px; border-radius:50%; background:var(--sidebar-bg); border:2px solid rgba(255,153,0,0.4); display:flex; align-items:center; justify-content:center; font-size:20px; cursor:pointer; flex-shrink:0; overflow:hidden;">
            <span id="header-avatar-emoji">🦊</span>
            <img id="header-avatar-photo" src="" alt="" style="display:none; width:100%; height:100%; object-fit:cover; border-radius:50%;">
        </div>
        <div style="position:relative; display:flex; align-items:center;">
            <span id="header-chat-title" style="font-size:18px; white-space:nowrap;">Chat</span>
            <div id="nav-notif" style="pointer-events:none;"></div>
        </div>
    </div>
 
    <!-- JOBB: gombok — inline margin-left hogy ne legyen gap-ből eredő eltolás -->
    <div id="header-right" style="display:flex; align-items:center; flex-shrink:0; margin-left:auto; gap:0; padding-left:8px;">
        <button id="room-btn" class="header-btn" style="border-color:#4CAF50; color:#4CAF50; margin-left:0;">+ Szoba</button>
        <button id="theme-toggle" class="header-btn" onclick="toggleThemePanel()" style="margin-left:5px;">🎨 Témák</button>
        <button id="secret-mode-btn" class="header-btn" style="border-color:#ff3b30; color:#ff3b30; margin-left:5px;">🕵️ Titkos</button>
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
                    <div onclick="startKep()">🎨 AI Képgenerátor</div>
                </div>
                <input type="file" id="file-input" multiple style="display:none">
                <div class="input-wrapper">
                    <input type="text" id="message-input" placeholder="Üzenet..." disabled>
                    <button class="icon-btn" id="emoji-btn" disabled>😀</button>
                </div>
                <button id="send-btn" disabled>Küldés</button>
            </div>
        </div>
    </div>

<script>
window.WSS_URL = '${websocket_url}';

// ═══════════════════════════════════════════════════════════════
// AVATAR RENDSZER
// username formátum: "Márk|emoji:🦊" vagy "Márk|photo:https://..."
// ═══════════════════════════════════════════════════════════════

const AVATAR_EMOJIS = [
    '🦊','🐺','🐱','🐸','🤖','👾','🧙','🦄','💀','🎭',
    '🐯','🦁','🐻','🐼','🐨','🦝','🦋','🐙','🦈','🎃',
    '👻','🤡','👽','🧟','🧛','🧜','🧚','🧝','🥷','🤠',
    '😎','🤓','😈','🥸','🤩','🧑‍🚀','👨‍🎤','🧑‍🎨','👨‍💻','🧑‍🍳'
];

// Kiolvassa az avatar típusát és értékét a username-ből
window.parseAvatar = function(username) {
    if (!username) return { type: 'emoji', value: '❓' };
    const parts = username.split('|');
    if (parts.length < 2) return { type: 'emoji', value: '🦊' };
    const meta = parts[1];
    if (meta.startsWith('photo:')) return { type: 'photo', value: meta.slice(6) };
    if (meta.startsWith('emoji:')) return { type: 'emoji', value: meta.slice(6) };
    // Régi seed formátum — fallback emoji
    return { type: 'emoji', value: '🦊' };
};

// Avatar HTML egy adott elemsbe renderel (img vagy span)
window.renderAvatarInto = function(username, emojiEl, photoEl, size) {
    const av = window.parseAvatar(username);
    if (av.type === 'photo') {
        if (emojiEl) emojiEl.style.display = 'none';
        if (photoEl) { photoEl.src = av.value; photoEl.style.display = 'block'; if(size) photoEl.style.width = photoEl.style.height = size; }
    } else {
        if (photoEl) photoEl.style.display = 'none';
        if (emojiEl) { emojiEl.textContent = av.value; emojiEl.style.display = 'block'; }
    }
};

// Frissíti az összes UI elemet az aktuális saját avatarral
window.updateAllMyAvatars = function() {
    if (typeof state === 'undefined' || !state.myUsername) return;
    const av   = window.parseAvatar(state.myUsername);
    const name = state.myUsername.split('|')[0];

    // Header
    window.renderAvatarInto(state.myUsername,
        document.getElementById('header-avatar-emoji'),
        document.getElementById('header-avatar-photo'), '34px');

    // Profil dropdown fejléc
    window.renderAvatarInto(state.myUsername,
        document.getElementById('profile-dd-emoji'),
        document.getElementById('profile-dd-photo'), '42px');
    const dn = document.getElementById('profile-dropdown-name');
    if (dn) dn.textContent = name;

    // Avatar modal előnézet
    window.renderAvatarInto(state.myUsername,
        document.getElementById('avatar-preview-emoji'),
        document.getElementById('avatar-preview-photo'), '80px');
    const pn = document.getElementById('avatar-preview-name');
    if (pn) pn.textContent = name;
};
window.updateProfileDropdown = window.updateAllMyAvatars; // kompatibilitás

// ── AVATAR MODAL ────────────────────────────────────────────────

let _pendingAvatarEmoji  = null; // kiválasztott emoji (még nem mentett)
let _pendingAvatarPhoto  = null; // feltöltött S3 URL (még nem mentett)
let _avatarMode          = 'emoji'; // 'emoji' | 'photo'

function buildEmojiGrid() {
    const grid = document.getElementById('emoji-avatar-grid');
    if (!grid || grid.children.length > 0) return;
    AVATAR_EMOJIS.forEach(em => {
        const btn = document.createElement('button');
        btn.className = 'emoji-av-btn';
        btn.textContent = em;
        btn.onclick = () => {
            document.querySelectorAll('.emoji-av-btn').forEach(b => b.classList.remove('selected'));
            btn.classList.add('selected');
            _pendingAvatarEmoji = em;
            _avatarMode = 'emoji';
            // Előnézet frissítés
            document.getElementById('avatar-preview-emoji').textContent = em;
            document.getElementById('avatar-preview-emoji').style.display = 'block';
            document.getElementById('avatar-preview-photo').style.display = 'none';
        };
        grid.appendChild(btn);
    });
}

window.openAvatarModal = function() {
    closeProfileMenu();
    buildEmojiGrid();

    // Aktuális avatar beállítása
    if (typeof state !== 'undefined' && state.myUsername) {
        const av   = window.parseAvatar(state.myUsername);
        const name = state.myUsername.split('|')[0];
        _pendingAvatarEmoji = av.type === 'emoji' ? av.value : AVATAR_EMOJIS[0];
        _pendingAvatarPhoto = av.type === 'photo' ? av.value : null;
        _avatarMode = av.type;

        // Előnézet
        window.renderAvatarInto(state.myUsername,
            document.getElementById('avatar-preview-emoji'),
            document.getElementById('avatar-preview-photo'), '80px');
        document.getElementById('avatar-preview-name').textContent = name;

        // Emoji kijelölés
        document.querySelectorAll('.emoji-av-btn').forEach(b => {
            b.classList.toggle('selected', b.textContent === _pendingAvatarEmoji);
        });

        // Saját kép tab állapota
        updatePhotoTabUI(_pendingAvatarPhoto);
    }

    // Tab visszaállítás
    switchAvatarTab(_avatarMode === 'photo' ? 'photo' : 'emoji');

    document.getElementById('avatar-modal').classList.add('open');
    document.getElementById('avatar-modal-overlay').classList.add('active');
};

window.closeAvatarModal = function() {
    document.getElementById('avatar-modal').classList.remove('open');
    document.getElementById('avatar-modal-overlay').classList.remove('active');
};

window.switchAvatarTab = function(tab) {
    document.getElementById('avatar-tab-emoji-content').style.display = tab === 'emoji' ? '' : 'none';
    document.getElementById('avatar-tab-photo-content').style.display = tab === 'photo' ? '' : 'none';
    document.getElementById('tab-emoji').classList.toggle('active', tab === 'emoji');
    document.getElementById('tab-photo').classList.toggle('active', tab === 'photo');
};

function updatePhotoTabUI(photoUrl) {
    const removeBtn = document.getElementById('remove-photo-btn');
    const uploadArea = document.getElementById('photo-upload-area');
    if (photoUrl) {
        removeBtn.style.display = 'block';
        uploadArea.style.backgroundImage = 'url(' + photoUrl + ')';
        uploadArea.style.backgroundSize  = 'cover';
        uploadArea.style.backgroundPosition = 'center';
        document.getElementById('photo-upload-icon').style.display = 'none';
        document.getElementById('photo-upload-text').textContent = 'Kattints a csere feltöltéséhez';
        document.getElementById('photo-upload-sub').style.display = 'none';
    } else {
        removeBtn.style.display = 'none';
        uploadArea.style.backgroundImage = '';
        document.getElementById('photo-upload-icon').style.display = '';
        document.getElementById('photo-upload-text').textContent = 'Kattints a feltöltéshez';
        document.getElementById('photo-upload-sub').style.display = '';
    }
}

window.removeCustomPhoto = function() {
    _pendingAvatarPhoto = null;
    _avatarMode = 'emoji';
    updatePhotoTabUI(null);
    switchAvatarTab('emoji');
    // Előnézet visszaállítás emojira
    document.getElementById('avatar-preview-emoji').style.display = 'block';
    document.getElementById('avatar-preview-photo').style.display = 'none';
    document.getElementById('avatar-preview-emoji').textContent = _pendingAvatarEmoji || '🦊';
};

// Fotó feltöltés az avatar bucketbe
document.addEventListener('DOMContentLoaded', () => {
    const fileInput = document.getElementById('avatar-file-input');
    if (fileInput) {
        fileInput.addEventListener('change', async (e) => {
            const file = e.target.files[0];
            if (!file) return;
            if (file.size > 2 * 1024 * 1024) { alert('Max 2MB!'); return; }

            const progress = document.getElementById('photo-upload-progress');
            const bar      = document.getElementById('photo-upload-bar');
            const pct      = document.getElementById('photo-upload-pct');
            progress.style.display = 'flex';
            bar.style.width = '0%';
            pct.textContent = '0%';

            // Presigned URL lekérés az avatar bucketből
            if (typeof state === 'undefined' || !state.socket || state.socket.readyState !== WebSocket.OPEN) {
                alert('Nincs kapcsolat!'); progress.style.display = 'none'; return;
            }

            // Egyedi eseménykezelő a válaszra
            const fileName  = 'avatar_' + Date.now() + '_' + file.name.replace(/[^a-zA-Z0-9.]/g,'_');
            window._pendingAvatarUpload = { resolve: null };
            const avatarUrlPromise = new Promise(res => { window._pendingAvatarUpload.resolve = res; });

            state.socket.send(JSON.stringify({
                action: 'getAvatarUploadUrl',
                fileName: fileName,
                contentType: file.type
            }));

            const result = await avatarUrlPromise;
            if (!result) { progress.style.display = 'none'; return; }

            // S3 feltöltés XHR-rel (progress követéssel)
            const xhr = new XMLHttpRequest();
            xhr.open('PUT', result.uploadUrl, true);
            xhr.setRequestHeader('Content-Type', file.type);
            xhr.upload.onprogress = (ev) => {
                if (ev.lengthComputable) {
                    const p = Math.round(ev.loaded / ev.total * 100);
                    bar.style.width = p + '%';
                    pct.textContent = p + '%';
                }
            };
            xhr.onload = () => {
                progress.style.display = 'none';
                if (xhr.status === 200 || xhr.status === 204) {
                    _pendingAvatarPhoto = result.fileUrl;
                    _avatarMode = 'photo';
                    updatePhotoTabUI(_pendingAvatarPhoto);
                    // Előnézet frissítés
                    document.getElementById('avatar-preview-photo').src = _pendingAvatarPhoto;
                    document.getElementById('avatar-preview-photo').style.display = 'block';
                    document.getElementById('avatar-preview-emoji').style.display = 'none';
                } else { alert('Feltöltési hiba!'); }
                fileInput.value = '';
            };
            xhr.onerror = () => { progress.style.display = 'none'; alert('Hálózati hiba!'); };
            const reader = new FileReader();
            reader.onload = (ev) => xhr.send(ev.target.result);
            reader.readAsArrayBuffer(file);
        });
    }
});

window.saveAvatar = function() {
    if (typeof window.state === 'undefined' || !window.state.myUsername) return;
    const name    = window.state.myUsername.split('|')[0];
    let newMeta;

    if (_avatarMode === 'photo' && _pendingAvatarPhoto) {
        newMeta = 'photo:' + _pendingAvatarPhoto;
    } else {
        newMeta = 'emoji:' + (_pendingAvatarEmoji || '🦊');
    }

    window.state.myUsername = name + '|' + newMeta;
    localStorage.setItem('chatNickname', window.state.myUsername);

    if (window.state.socket && window.state.socket.readyState === WebSocket.OPEN) {
        window.state.socket.send(JSON.stringify({
            action: 'join',
            username: window.state.myUsername,
            room: window.state.currentRoom,
            password: window.state.currentRoomPassword || ''
        }));
    }

    window.updateAllMyAvatars();
    closeAvatarModal();
};

// ═══════════════════════════════════════════════════════════════
// PROFIL DROPDOWN
// ═══════════════════════════════════════════════════════════════

function positionProfileDropdown() {
    const icon = document.getElementById('header-avatar-wrap');
    const dd   = document.getElementById('profile-dropdown');
    if (!icon || !dd) return;
    const rect = icon.getBoundingClientRect();
    dd.style.top  = (rect.bottom + 8) + 'px';
    dd.style.left = Math.max(8, rect.left) + 'px';
}

function toggleProfileMenu() {
    const dd      = document.getElementById('profile-dropdown');
    const overlay = document.getElementById('profile-overlay');
    const isOpen  = dd.classList.contains('open');
    closeThemePanel();
    if (isOpen) { closeProfileMenu(); return; }
    positionProfileDropdown();
    dd.classList.add('open');
    overlay.classList.add('active');
    window.updateAllMyAvatars();
}
function closeProfileMenu() {
    document.getElementById('profile-dropdown').classList.remove('open');
    document.getElementById('profile-overlay').classList.remove('active');
}
window.addEventListener('resize', () => {
    if (document.getElementById('profile-dropdown').classList.contains('open'))
        positionProfileDropdown();
});

// ═══════════════════════════════════════════════════════════════
// ÉRTESÍTÉSEK & HANG
// ═══════════════════════════════════════════════════════════════

window.notifEnabled = localStorage.getItem('chatNotif') !== 'false';
window.soundEnabled = localStorage.getItem('chatSound') !== 'false';

function updateNotifUI() {
    document.getElementById('notif-icon').textContent = window.notifEnabled ? '🔔' : '🔕';
    document.getElementById('notif-sub').textContent  = window.notifEnabled ? 'Bekapcsolva' : 'Kikapcsolva';
    document.getElementById('notif-switch').classList.toggle('active', window.notifEnabled);
}
function updateSoundUI() {
    document.getElementById('sound-icon').textContent = window.soundEnabled ? '🔊' : '🔇';
    document.getElementById('sound-sub').textContent  = window.soundEnabled ? 'Bekapcsolva' : 'Kikapcsolva';
    document.getElementById('sound-switch').classList.toggle('active', window.soundEnabled);
}
window.toggleNotifications = function() {
    window.notifEnabled = !window.notifEnabled;
    localStorage.setItem('chatNotif', window.notifEnabled);
    updateNotifUI();
    if (window.notifEnabled && 'Notification' in window && Notification.permission === 'default')
        Notification.requestPermission();
};
window.toggleSound = function() {
    window.soundEnabled = !window.soundEnabled;
    localStorage.setItem('chatSound', window.soundEnabled);
    updateSoundUI();
};
updateNotifUI(); updateSoundUI();

// ═══════════════════════════════════════════════════════════════
// TÉMA PANEL
// ═══════════════════════════════════════════════════════════════

function toggleThemePanel() {
    const panel   = document.getElementById('theme-panel');
    const overlay = document.getElementById('theme-panel-overlay');
    closeProfileMenu();
    if (panel.classList.contains('open')) { closeThemePanel(); return; }
    panel.classList.add('open'); overlay.classList.add('active');
}
function closeThemePanel() {
    document.getElementById('theme-panel').classList.remove('open');
    document.getElementById('theme-panel-overlay').classList.remove('active');
}
function setTheme(theme, el) {
    document.documentElement.setAttribute('data-theme', theme);
    document.querySelectorAll('.theme-opt').forEach(o => o.classList.remove('active'));
    if (el) el.classList.add('active');
    localStorage.setItem('chatTheme', theme);
    setTimeout(closeThemePanel, 250);
}
window.setTheme = setTheme;

(function() {
    const t = localStorage.getItem('chatTheme');
    if (!t) return;
    document.documentElement.setAttribute('data-theme', t);
    document.addEventListener('DOMContentLoaded', () => {
        const btn = document.querySelector('.theme-opt[data-t="' + t + '"]');
        if (btn) { document.querySelectorAll('.theme-opt').forEach(o => o.classList.remove('active')); btn.classList.add('active'); }
    });
})();

// ═══════════════════════════════════════════════════════════════
// SZOBA MEGHÍVÓ
// FIX: a szerver a célszemélyt megkeresi az összes szobában,
// nem csak az aktuálisban, így cross-room invite is működik
// ═══════════════════════════════════════════════════════════════

let pendingInvite = null;

window.showRoomInvite = function(fromUser, toRoom, roomPassword) { // ÚJ: roomPassword paraméter
    const name = fromUser.split('|')[0];
    const av   = window.parseAvatar(fromUser);
    
    // ÚJ: Eltároljuk a jelszót a memóriában a csatlakozáshoz
    pendingInvite = { from: fromUser, room: toRoom, password: roomPassword };

    const emojiEl = document.getElementById('invite-toast-emoji');
    const photoEl = document.getElementById('invite-toast-photo');
    if (av.type === 'photo') {
        emojiEl.style.display = 'none';
        photoEl.src = av.value; photoEl.style.display = 'block';
    } else {
        photoEl.style.display = 'none';
        emojiEl.textContent = av.value; emojiEl.style.display = 'block';
    }

    document.getElementById('invite-toast-name').textContent = name + ' meghív';
    document.getElementById('invite-toast-room').textContent = '🏠 ' + (toRoom === 'main' ? 'Közös Szoba' : toRoom);
    document.getElementById('invite-toast').classList.add('show');
    clearTimeout(window._inviteTimer);
    window._inviteTimer = setTimeout(window.declineRoomInvite, 12000);
};

window.acceptRoomInvite = function() {
    if (!pendingInvite) return;
    if (typeof window.state !== 'undefined' && window.state.socket && window.state.socket.readyState === WebSocket.OPEN) {
        
        // ÚJ: Beállítjuk a saját kliensünkben a kapott jelszót, és el is küldjük!
        window.state.currentRoomPassword = pendingInvite.password || '';
        
        window.state.socket.send(JSON.stringify({
            action: 'join', 
            username: window.state.myUsername,
            room: pendingInvite.room, 
            password: pendingInvite.password || '' 
        }));
    }
    window.declineRoomInvite();
};

window.declineRoomInvite = function() {
    pendingInvite = null;
    clearTimeout(window._inviteTimer);
    document.getElementById('invite-toast').classList.remove('show');
};

window.sendRoomInvite = function(targetUser) {
    if (typeof window.state === 'undefined' || !window.state.socket || window.state.socket.readyState !== WebSocket.OPEN) return;
    window.state.socket.send(JSON.stringify({
        action: 'roomInvite',
        username: window.state.myUsername,
        targetUser: targetUser,
        room: window.state.currentRoom,
        password: window.state.currentRoomPassword || '' // ÚJ: Csatoljuk a szobánk jelszavát a meghívóhoz
    }));
    const btn = document.querySelector('[data-invite-target="' + CSS.escape(targetUser) + '"]');
    if (btn) { btn.textContent = '✅'; setTimeout(() => { btn.textContent = '📨'; }, 2000); }
};

// ═══════════════════════════════════════════════════════════════
// THEME-TOGGLE PATCH & DOM READY
// ═══════════════════════════════════════════════════════════════

document.addEventListener('DOMContentLoaded', () => {
    const tt = document.getElementById('theme-toggle');
    if (tt) { const clone = tt.cloneNode(true); tt.parentNode.replaceChild(clone, tt); }

    const avBtn = document.getElementById('avatar-btn');
    if (avBtn) {
        const clone = avBtn.cloneNode(true);
        avBtn.parentNode.replaceChild(clone, avBtn);
        clone.addEventListener('click', window.openAvatarModal);
    }

    setTimeout(window.updateAllMyAvatars, 400);
    setTimeout(window.updateAllMyAvatars, 1500);

    // JAVÍTÁS: Erőszakos görgetés a billentyűzet megjelenésekor
    const msgInput = document.getElementById('message-input');
    const forceScroll = () => {
        const msgs = document.getElementById('messages');
        if (msgs) msgs.scrollTop = msgs.scrollHeight + 10000;
    };

    if (msgInput) {
        msgInput.addEventListener('focus', () => {
            document.body.classList.add('keyboard-open');
            window.scrollTo(0,0);
            closeProfileMenu(); closeThemePanel();
            
            // Azonnali, majd egy késleltetett görgetés (megvárjuk az animációt)
            setTimeout(forceScroll, 100);
            setTimeout(forceScroll, 350); 
        });
        msgInput.addEventListener('blur', () => {
            setTimeout(() => document.body.classList.remove('keyboard-open'), 100);
        });
    }
});

// A legbiztosabb módszer mobilokra: a visualViewport figyelése
if (window.visualViewport) {
    window.visualViewport.addEventListener('resize', () => {
        // Dinamikusan állítjuk a CSS változót a maradék helyre
        document.documentElement.style.setProperty('--app-height', window.visualViewport.height + 'px');
        
        // Gépelés közben történő átméretezés esetén is lent tartjuk
        setTimeout(() => {
            const msgs = document.getElementById('messages');
            if (msgs) msgs.scrollTop = msgs.scrollHeight + 10000;
            window.scrollTo(0, 0);
        }, 150);
    });
}
</script>

    <script type="module" src="js/app.js"></script>
</body>
</html>
