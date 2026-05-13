// --- media.js ---
import { state, dom } from './state.js';

// ---- FELTÖLTÉS (S3) ----
export function processNextFile() { 
    if (state.uploadQueue.length === 0) { state.isUploading = false; dom.fileInput.value = ""; return; } 
    state.isUploading = true; state.currentFileToUpload = state.uploadQueue.shift(); 
    if (state.socket && state.socket.readyState === WebSocket.OPEN) { 
        const cType = state.currentFileToUpload.file.type || 'application/octet-stream';
        state.socket.send(JSON.stringify({ action: 'getUploadUrl', fileName: state.currentFileToUpload.file.name, contentType: cType })); 
    } else { state.isUploading = false; } 
}
window.processNextFile = processNextFile;

export function performUpload(uploadUrl, fileUrl) {
    const xhr = new XMLHttpRequest(); xhr.open("PUT", uploadUrl, true);
    const cType = state.currentFileToUpload.file.type || 'application/octet-stream'; 
    xhr.setRequestHeader('Content-Type', cType);
    xhr.onload = function () {
        if (xhr.status === 200 || xhr.status === 204) {
            if (state.socket && state.socket.readyState === WebSocket.OPEN) {
                const payload = { action: 'sendMessage', message: fileUrl, username: state.myUsername, deviceId: state.myDeviceId, room: state.currentRoom };
                if (state.currentFileToUpload.replyTo) { payload.replyTo = state.currentFileToUpload.replyTo; }
                state.socket.send(JSON.stringify(payload));
            }
        }
        processNextFile(); 
    };
    xhr.onerror = function() { processNextFile(); }
    const reader = new FileReader(); 
    reader.onload = function() { xhr.send(this.result); }; 
    reader.readAsArrayBuffer(state.currentFileToUpload.file);
}
window.performUpload = performUpload;

// ---- HANGFELVÉTEL (iOS JAVÍTÁSSAL) ----
let mediaRecorder; let audioChunks = []; let isRecording = false;

function getBestAudioMimeType() {
    const types = ['audio/webm;codecs=opus', 'audio/webm', 'audio/mp4', 'audio/aac', 'audio/ogg'];
    for (let t of types) { if (typeof MediaRecorder !== 'undefined' && MediaRecorder.isTypeSupported && MediaRecorder.isTypeSupported(t)) { return t; } }
    return '';
}

export async function toggleMicrophone() {
    if (!isRecording) {
        try {
            const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
            const bestMimeType = getBestAudioMimeType();
            const options = bestMimeType ? { mimeType: bestMimeType } : undefined;
            mediaRecorder = new MediaRecorder(stream, options);
            mediaRecorder.ondataavailable = (e) => { if (e.data.size > 0) audioChunks.push(e.data); };
            mediaRecorder.onstop = () => {
                const finalMimeType = mediaRecorder.mimeType || 'audio/webm';
                let ext = 'webm';
                if (finalMimeType.includes('mp4') || finalMimeType.includes('m4a')) ext = 'm4a';
                else if (finalMimeType.includes('ogg')) ext = 'ogg';
                
                // APPLE JAVÍTÁS: Ha iOS eszközön vagyunk, kényszerítjük a Safari-barát formátumot
                const isIOS = /iPad|iPhone|iPod|Macintosh/.test(navigator.userAgent);
                const safeMimeType = (ext === 'webm' && isIOS) ? 'audio/mp4' : finalMimeType;
                const safeExt = (ext === 'webm' && isIOS) ? 'mp4' : ext;

                const audioBlob = new Blob(audioChunks, { type: safeMimeType });
                const audioFile = new File([audioBlob], "VoiceNote_" + Math.floor(Date.now()/1000) + "." + safeExt, { type: safeMimeType });
                
                let currentReply = state.replyingTo ? { sender: state.replyingTo.sender, message: state.replyingTo.message } : null;
                state.uploadQueue.push({ file: audioFile, replyTo: currentReply });
                if (window.cancelReply) window.cancelReply(); 
                if (!state.isUploading) processNextFile();
                audioChunks = []; stream.getTracks().forEach(track => track.stop());
            };
            mediaRecorder.start(); isRecording = true; 
            dom.micBtn.classList.add('recording'); dom.micBtn.innerHTML = '⏹️'; 
            dom.messageInput.disabled = true; dom.messageInput.value = ''; 
            dom.messageInput.classList.add('recording-placeholder'); dom.messageInput.placeholder = '🔴 Felvétel folyamatban...';
        } catch (err) { alert("Nem sikerült hozzáférni a mikrofonhoz."); }
    } else { 
        mediaRecorder.stop(); isRecording = false; 
        dom.micBtn.classList.remove('recording'); dom.micBtn.innerHTML = '🎤';
        dom.messageInput.disabled = false; dom.messageInput.classList.remove('recording-placeholder'); dom.messageInput.placeholder = 'Üzenet...';
    }
}
window.toggleMicrophone = toggleMicrophone;

// ---- WEBRTC VIDEÓHÍVÁS ----
let peerConnection; let localStream; let currentCallTarget = null;
let isVideoEnabled = true; let candidateQueue = [];
const rtcConfig = { iceServers: [{ urls: 'stun:stun.l.google.com:19302' }, { urls: 'stun:stun1.l.google.com:19302' }] };

export async function startCall(targetUser) {
    currentCallTarget = targetUser; document.getElementById('video-container').style.display = 'flex'; isVideoEnabled = true; candidateQueue = [];
    try {
        localStream = await navigator.mediaDevices.getUserMedia({ video: true, audio: true }); document.getElementById('local-video').srcObject = localStream;
        peerConnection = new RTCPeerConnection(rtcConfig); localStream.getTracks().forEach(track => peerConnection.addTrack(track, localStream));
        peerConnection.ontrack = event => { const remoteVideo = document.getElementById('remote-video'); if (remoteVideo.srcObject !== event.streams[0]) { remoteVideo.srcObject = event.streams[0]; } };
        peerConnection.onicecandidate = event => { if (event.candidate) { state.socket.send(JSON.stringify({ action: 'webrtcSignal', room: state.currentRoom, username: state.myUsername, targetUser: currentCallTarget, deviceId: state.myDeviceId, signal: { type: 'candidate', candidate: event.candidate } })); } };
        const offer = await peerConnection.createOffer(); await peerConnection.setLocalDescription(offer);
        state.socket.send(JSON.stringify({ action: 'webrtcSignal', room: state.currentRoom, username: state.myUsername, targetUser: currentCallTarget, deviceId: state.myDeviceId, signal: { type: 'offer', offer: offer } }));
    } catch (err) { alert("Kamera hiba: " + err.message); window.endCallLocal(); }
}
window.startCall = startCall;

export async function handleWebRTCSignal(signal, sender) {
    if (signal.type === 'offer') {
        const dispName = sender.split('|')[0];
        if (!confirm(dispName + " hívást indított! Felveszed? 📞")) { state.socket.send(JSON.stringify({ action: 'webrtcSignal', room: state.currentRoom, username: state.myUsername, targetUser: sender, deviceId: state.myDeviceId, signal: { type: 'end' } })); return; }
        currentCallTarget = sender; document.getElementById('video-container').style.display = 'flex'; isVideoEnabled = true; candidateQueue = []; 
        try {
            localStream = await navigator.mediaDevices.getUserMedia({ video: true, audio: true }); document.getElementById('local-video').srcObject = localStream;
            peerConnection = new RTCPeerConnection(rtcConfig); localStream.getTracks().forEach(track => peerConnection.addTrack(track, localStream));
            peerConnection.ontrack = event => { const remoteVideo = document.getElementById('remote-video'); if (remoteVideo.srcObject !== event.streams[0]) { remoteVideo.srcObject = event.streams[0]; } };
            peerConnection.onicecandidate = event => { if (event.candidate) { state.socket.send(JSON.stringify({ action: 'webrtcSignal', room: state.currentRoom, username: state.myUsername, targetUser: currentCallTarget, deviceId: state.myDeviceId, signal: { type: 'candidate', candidate: event.candidate } })); } };
            await peerConnection.setRemoteDescription(new RTCSessionDescription(signal.offer)); const answer = await peerConnection.createAnswer(); await peerConnection.setLocalDescription(answer);
            state.socket.send(JSON.stringify({ action: 'webrtcSignal', room: state.currentRoom, username: state.myUsername, targetUser: currentCallTarget, deviceId: state.myDeviceId, signal: { type: 'answer', answer: answer } }));
            candidateQueue.forEach(c => peerConnection.addIceCandidate(new RTCIceCandidate(c)).catch(e => console.log(e))); candidateQueue = [];
        } catch (err) { alert("Kamera hiba: " + err.message); window.endCallLocal(); }
    } 
    else if (signal.type === 'answer') { await peerConnection.setRemoteDescription(new RTCSessionDescription(signal.answer)); candidateQueue.forEach(c => peerConnection.addIceCandidate(new RTCIceCandidate(c)).catch(e => console.log(e))); candidateQueue = []; } 
    else if (signal.type === 'candidate') { if (peerConnection && peerConnection.remoteDescription && peerConnection.remoteDescription.type) { peerConnection.addIceCandidate(new RTCIceCandidate(signal.candidate)).catch(e => console.log(e)); } else { candidateQueue.push(signal.candidate); } } 
    else if (signal.type === 'end') { window.endCallLocal(); }
}
window.handleWebRTCSignal = handleWebRTCSignal;

export function toggleVideo() {
    if (localStream) {
        const videoTrack = localStream.getVideoTracks()[0];
        if (videoTrack) {
            isVideoEnabled = !isVideoEnabled; videoTrack.enabled = isVideoEnabled;
            const btn = document.getElementById('toggle-video-btn'); const localVid = document.getElementById('local-video');
            if (isVideoEnabled) { btn.innerText = '📹 Kamera Ki'; btn.style.background = '#4CAF50'; localVid.style.opacity = '1'; } 
            else { btn.innerText = '🚫 Kamera Be'; btn.style.background = '#888'; localVid.style.opacity = '0.3'; }
        }
    }
}
window.toggleVideo = toggleVideo;

export function endCall() { 
    if (currentCallTarget) state.socket.send(JSON.stringify({ action: 'webrtcSignal', room: state.currentRoom, username: state.myUsername, targetUser: currentCallTarget, deviceId: state.myDeviceId, signal: { type: 'end' } })); 
    window.endCallLocal(); 
}
window.endCall = endCall;

export function endCallLocal() {
    if (peerConnection) { peerConnection.close(); peerConnection = null; }
    if (localStream) { localStream.getTracks().forEach(t => t.stop()); localStream = null; }
    document.getElementById('video-container').style.display = 'none'; currentCallTarget = null; candidateQueue = [];
    const btn = document.getElementById('toggle-video-btn'); if(btn) { btn.innerText = '📹 Kamera Ki'; btn.style.background = '#4CAF50'; }
    const localVid = document.getElementById('local-video'); if(localVid) { localVid.style.opacity = '1'; }
}
window.endCallLocal = endCallLocal;

// ---- RAJZTÁBLA ----
const canvas = document.getElementById('drawing-board');
const ctx = canvas.getContext('2d');
let isDrawing = false;

export function resizeCanvas() { 
    const container = document.getElementById('whiteboard-container');
    if (!container || container.style.display === 'none') return;
    const headerHeight = document.getElementById('whiteboard-header').offsetHeight || 50;
    canvas.width = window.innerWidth; canvas.height = window.innerHeight - headerHeight; 
    ctx.fillStyle = "white"; ctx.fillRect(0, 0, canvas.width, canvas.height);
}
window.addEventListener('resize', resizeCanvas); 
window.resizeCanvas = resizeCanvas;

export function openWhiteboard() { 
    document.getElementById('whiteboard-container').style.display = 'flex'; 
    document.getElementById('game-menu').style.display = 'none'; 
    setTimeout(resizeCanvas, 50); 
}
window.openWhiteboard = openWhiteboard;

export function closeWhiteboard() { document.getElementById('whiteboard-container').style.display = 'none'; }
window.closeWhiteboard = closeWhiteboard;

export function clearBoard() { ctx.fillStyle = "white"; ctx.fillRect(0, 0, canvas.width, canvas.height); }
window.clearBoard = clearBoard;

export function sendDrawingAsImage() {
    const dataUrl = canvas.toDataURL('image/png');
    closeWhiteboard();
    fetch(dataUrl).then(res => res.blob()).then(blob => {
        const file = new File([blob], "Rajz_" + Math.floor(Date.now()/1000) + ".png", { type: 'image/png' });
        let currentReply = state.replyingTo ? { sender: state.replyingTo.sender, message: state.replyingTo.message } : null;
        state.uploadQueue.push({ file: file, replyTo: currentReply });
        if (!state.isUploading) processNextFile();
    });
}
window.sendDrawingAsImage = sendDrawingAsImage;

function drawLocal(x, y, type) {
    const color = document.getElementById('draw-color').value;
    ctx.strokeStyle = color; ctx.lineWidth = 5; ctx.lineCap = "round"; ctx.lineJoin = "round";
    if (type === 'start') { ctx.beginPath(); ctx.moveTo(x, y); }
    else if (type === 'move') { ctx.lineTo(x, y); ctx.stroke(); }
}

canvas.onmousedown = (e) => { isDrawing = true; drawLocal(e.offsetX, e.offsetY, 'start'); };
canvas.onmousemove = (e) => { if(isDrawing) drawLocal(e.offsetX, e.offsetY, 'move'); };
window.onmouseup = () => { isDrawing = false; ctx.beginPath(); };

canvas.ontouchstart = (e) => { 
    isDrawing = true; const r = canvas.getBoundingClientRect(); 
    drawLocal(e.touches[0].clientX - r.left, e.touches[0].clientY - r.top, 'start'); 
    if (e.cancelable) e.preventDefault(); 
};
canvas.ontouchmove = (e) => { 
    if(isDrawing) { const r = canvas.getBoundingClientRect(); drawLocal(e.touches[0].clientX - r.left, e.touches[0].clientY - r.top, 'move'); }
    if (e.cancelable) e.preventDefault(); 
};
window.ontouchend = () => { isDrawing = false; ctx.beginPath(); };