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
    
    <!-- Itt hívjuk be az új, kiszervezett CSS-t! -->
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
                    <button id="secret-mode-btn" class="header-btn" style="border-color: #ff3b30; color: #ff3b30;">🕵️ Titkos Mód</button>

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

    <!-- Itt injektáljuk be a WebSocket URL-t a Terraformmal -->
    <script>
        window.WSS_URL = '${websocket_url}';
    </script>
    
    <!-- És itt hívjuk be az új, kiszervezett JavaScriptet! -->
    <script type="module" src="js/app.js"></script>
</body>
</html>