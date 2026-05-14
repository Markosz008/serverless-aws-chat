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
        <div style="width: 1px; background: var(--border-color); height: 30px; margin: 0 5px;"></div>
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
            <button id="toggle-video-btn" class="video-btn" onclick="toggleVideo()" style="background: #4CAF50;">📹 Kamera Ki</button>
            <button id="end-call-btn" class="video-btn" onclick="endCall()" style="background: #ff3b30;">Megszakítás ☎️</button>
        </div>
    </div>

    <!-- PROFIL DROPDOWN -->
    <div id="profile-overlay" onclick="closeProfileMenu()"></div>
    <div id="profile-dropdown">
        <div id="profile-dropdown-header">
            <img id="profile-dropdown-avatar" src="https://api.dicebear.com/7.x/adventurer/svg?seed=default" alt="avatar">
            <div id="profile-dropdown-info">
                <div id="profile-dropdown-name">...</div>
                <div id="profile-dropdown-tag">🟢 Online</div>
            </div>
        </div>

        <button class="profile-menu-item" id="avatar-btn">
            <span class="pmi-icon">🎲</span>
            <div>
                <div class="pmi-label">Új Avatar</div>
                <div class="pmi-sub">Véletlenszerű kinézet</div>
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
            <button class="theme-opt" data-t="light" onclick="setTheme('light', this)">
                <div class="theme-swatch" style="background:#5a4fcf;">☀️</div>
                <span>Nappal</span>
            </button>
            <button class="theme-opt active" data-t="dark" onclick="setTheme('dark', this)">
                <div class="theme-swatch" style="background:#ff9900;">🌙</div>
                <span>Sötét</span>
            </button>
            <button class="theme-opt" data-t="retro" onclick="setTheme('retro', this)">
                <div class="theme-swatch" style="background:#003300; color:#00ff41; font-family:monospace; font-size:13px;">&gt;_</div>
                <span>Retro</span>
            </button>
            <button class="theme-opt" data-t="pastel" onclick="setTheme('pastel', this)">
                <div class="theme-swatch" style="background:#c084fc;">🌸</div>
                <span>Pastel</span>
            </button>
            <button class="theme-opt" data-t="cyber" onclick="setTheme('cyber', this)">
                <div class="theme-swatch" style="background:#f000ff; box-shadow:0 0 10px rgba(240,0,255,0.6);">⚡</div>
                <span>Cyber</span>
            </button>
        </div>
    </div>

    <!-- SZOBA MEGHÍVÓ TOAST -->
    <div id="invite-toast">
        <div id="invite-toast-content">
            <img id="invite-toast-avatar" src="" alt="">
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
            <div id="header">
                <div style="display:flex; align-items:center; gap:8px; position:relative; flex-shrink:0;">
                    <img id="header-avatar-icon"
                         src="https://api.dicebear.com/7.x/adventurer/svg?seed=default"
                         alt="profil"
                         onclick="toggleProfileMenu()"
                         title="Profil beállítások">
                    <div style="display:flex; align-items:center; position:relative;">
                        <span style="font-size:18px; white-space:nowrap;">Chat</span>
                        <div id="nav-notif">0</div>
                    </div>
                </div>

                <!-- ... gomb eltávolítva -->
                <div style="display:flex; gap:5px; align-items:center; flex-shrink:0;">
                    <button id="room-btn" class="header-btn" style="border-color:#4CAF50; color:#4CAF50;">+ Szoba</button>
                    <button id="theme-toggle" class="header-btn" onclick="toggleThemePanel()" style="position:relative; z-index:101; pointer-events:auto;">🎨 Témák</button>
                    <button id="secret-mode-btn" class="header-btn" style="border-color:#ff3b30; color:#ff3b30;">🕵️ Titkos</button>
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

        // ── PROFIL DROPDOWN ──────────────────────────────────────────

        function positionProfileDropdown() {
            const icon = document.getElementById('header-avatar-icon');
            const dd   = document.getElementById('profile-dropdown');
            if (!icon || !dd) return;
            const rect = icon.getBoundingClientRect();
            dd.style.top  = (rect.bottom + 8) + 'px';
            // balra igazítás: az ikon bal széle, de legalább 8px a képernyő szélétől
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
            updateProfileDropdown();
        }

        function closeProfileMenu() {
            document.getElementById('profile-dropdown').classList.remove('open');
            document.getElementById('profile-overlay').classList.remove('active');
        }

        // FIX: avatar frissítés — header ikon + dropdown egyszerre
        function updateProfileDropdown() {
            if (typeof state === 'undefined' || !state.myUsername) return;
            const parts     = state.myUsername.split('|');
            const name      = parts[0] || 'Anonim';
            const seed      = parts[1] || parts[0];
            const url       = 'https://api.dicebear.com/7.x/adventurer/svg?seed=' + encodeURIComponent(seed);

            const hi = document.getElementById('header-avatar-icon');
            if (hi) hi.src = url;

            const da = document.getElementById('profile-dropdown-avatar');
            if (da) da.src = url;

            const dn = document.getElementById('profile-dropdown-name');
            if (dn) dn.textContent = name;
        }
        window.updateProfileDropdown = updateProfileDropdown;

        window.addEventListener('resize', () => {
            if (document.getElementById('profile-dropdown').classList.contains('open'))
                positionProfileDropdown();
        });

        // ── ÉRTESÍTÉSEK & HANG ───────────────────────────────────────

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
        updateNotifUI();
        updateSoundUI();

        // ── TÉMA PANEL ───────────────────────────────────────────────

        function toggleThemePanel() {
            const panel   = document.getElementById('theme-panel');
            const overlay = document.getElementById('theme-panel-overlay');
            closeProfileMenu();
            if (panel.classList.contains('open')) { closeThemePanel(); return; }
            panel.classList.add('open');
            overlay.classList.add('active');
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

        // Mentett téma visszaállítása
        (function() {
            const t = localStorage.getItem('chatTheme');
            if (!t) return;
            document.documentElement.setAttribute('data-theme', t);
            document.addEventListener('DOMContentLoaded', () => {
                const btn = document.querySelector('.theme-opt[data-t="' + t + '"]');
                if (btn) { document.querySelectorAll('.theme-opt').forEach(o => o.classList.remove('active')); btn.classList.add('active'); }
            });
        })();

        // ── SZOBA MEGHÍVÓ ────────────────────────────────────────────

        let pendingInvite = null;

        window.showRoomInvite = function(fromUser, toRoom) {
            const parts  = fromUser.split('|');
            const name   = parts[0];
            const seed   = parts[1] || parts[0];
            const url    = 'https://api.dicebear.com/7.x/adventurer/svg?seed=' + encodeURIComponent(seed);
            pendingInvite = { from: fromUser, room: toRoom };

            document.getElementById('invite-toast-avatar').src        = url;
            document.getElementById('invite-toast-name').textContent  = name + ' meghív';
            document.getElementById('invite-toast-room').textContent  = '🏠 ' + (toRoom === 'main' ? 'Közös Szoba' : toRoom);

            document.getElementById('invite-toast').classList.add('show');
            clearTimeout(window._inviteTimer);
            window._inviteTimer = setTimeout(declineRoomInvite, 12000);
        };

        window.acceptRoomInvite = function() {
            if (!pendingInvite) return;
            if (typeof state !== 'undefined' && state.socket && state.socket.readyState === WebSocket.OPEN) {
                state.currentRoomPassword = '';
                state.socket.send(JSON.stringify({
                    action: 'join', username: state.myUsername,
                    room: pendingInvite.room, password: ''
                }));
            }
            declineRoomInvite();
        };

        window.declineRoomInvite = function() {
            pendingInvite = null;
            clearTimeout(window._inviteTimer);
            document.getElementById('invite-toast').classList.remove('show');
        };

        // Ezt az app.js updateUserList-je után kell meghívni
        // hogy a 📨 gomb megjelenjen az online userek mellett
        window.sendRoomInvite = function(targetUser) {
            if (typeof state === 'undefined' || !state.socket || state.socket.readyState !== WebSocket.OPEN) return;
            state.socket.send(JSON.stringify({
                action: 'roomInvite',
                username: state.myUsername,
                targetUser: targetUser,
                room: state.currentRoom
            }));
            const btn = document.querySelector('[data-invite-target="' + CSS.escape(targetUser) + '"]');
            if (btn) { btn.textContent = '✅'; setTimeout(() => { btn.textContent = '📨'; }, 2000); }
        };

        // ── THEME-TOGGLE PATCH ───────────────────────────────────────
        // Az app.js dark/light toggle listenerét neutralizáljuk

        document.addEventListener('DOMContentLoaded', () => {
            const tt = document.getElementById('theme-toggle');
            if (tt) {
                const clone = tt.cloneNode(true);
                tt.parentNode.replaceChild(clone, tt);
            }

            // Profil frissítés state betöltés után
            setTimeout(updateProfileDropdown, 400);
            setTimeout(updateProfileDropdown, 1500);

            const msgInput = document.getElementById('message-input');
            if (msgInput) {
                msgInput.addEventListener('focus', () => {
                    document.body.classList.add('keyboard-open');
                    window.scrollTo(0, 0);
                    closeProfileMenu();
                    closeThemePanel();
                });
                msgInput.addEventListener('blur', () => {
                    setTimeout(() => document.body.classList.remove('keyboard-open'), 100);
                });
            }
        });

        if (window.visualViewport) {
            window.visualViewport.addEventListener('resize', () => {
                window.scrollTo(0, 0);
                document.body.scrollTop = 0;
            });
        }
    </script>

    <script type="module" src="js/app.js"></script>
</body>
</html>
