// --- state.js ---

export const state = {
    WSS_URL: window.WSS_URL || '',
    myUsername: "",
    myDeviceId: localStorage.getItem('chatDeviceId') || 'device-' + Math.random().toString(36).substr(2, 9) + '-' + Date.now(),
    currentRoom: 'main',
    currentRoomPassword: '',
    socket: null,
    reconnectTimer: null,
    unreadCount: 0,
    unreadMsgQueue: [],
    isTyping: false,
    typingTimeout: null,
    myReactions: new Set(),
    replyingTo: null,
    uploadQueue: [],
    isUploading: false,
    currentFileToUpload: null,
    activeMsgId: null,
    activeMsgSender: "",
    activeMsgText: "",
    savedRooms: JSON.parse(localStorage.getItem('chatSavedRooms') || '{"main": ""}')
};

// Eszköz ID mentése, ha még nincs
if (!localStorage.getItem('chatDeviceId')) {
    localStorage.setItem('chatDeviceId', state.myDeviceId);
}

// Gyakran használt DOM elemek exportálása
export const dom = {
    loginScreen: document.getElementById('login-screen'),
    usernameInput: document.getElementById('username-input'),
    joinBtn: document.getElementById('join-btn'),
    messagesDiv: document.getElementById('messages'),
    messageInput: document.getElementById('message-input'),
    sendBtn: document.getElementById('send-btn'),
    userListUl: document.getElementById('user-list'),
    roomListUl: document.getElementById('room-list'),
    navNotif: document.getElementById('nav-notif'),
    typingDiv: document.getElementById('typing-indicator'),
    reactionMenu: document.getElementById('reaction-menu'),
    menuOverlay: document.getElementById('menu-overlay'),
    micBtn: document.getElementById('mic-btn'),
    cameraBtn: document.getElementById('camera-btn'),
    uploadBtn: document.getElementById('upload-btn'),
    fileInput: document.getElementById('file-input'),
    gameBtn: document.getElementById('game-btn'),
    emojiBtn: document.getElementById('emoji-btn')
};