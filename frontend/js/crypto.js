// --- crypto.js ---

// Titkosítás bekapcsolva? Ezt később az app.js fogja állítani.
export let e2eEnabled = false;
let cryptoKey = null;

export function setE2EState(isEnabled) {
    e2eEnabled = isEnabled;
}

// 1. Lépés: A megadott jelszóból egy kriptográfiailag erős kulcs (Key Material) készítése
async function getKeyMaterial(password) {
    const enc = new TextEncoder();
    return window.crypto.subtle.importKey(
        "raw",
        enc.encode(password),
        { name: "PBKDF2" },
        false,
        ["deriveBits", "deriveKey"]
    );
}

// 2. Lépés: A Key Materialból egy AES-GCM titkosító kulcs generálása (Salt segítségével)
export async function deriveKey(password) {
    if (!password) {
        cryptoKey = null;
        return;
    }
    const keyMaterial = await getKeyMaterial(password);
    
    // Titkosítási tipp: A Salt normál esetben véletlenszerű és az üzenet mellett utazik.
    // Egyszerűség kedvéért most egy fix (de erős) Saltot használunk, hogy a szoba tagjai
    // ugyanazt a kulcsot tudják legenerálni a jelszóból a hálózati egyeztetés nélkül.
    const salt = new TextEncoder().encode("aws-serverless-chat-super-secret-salt-2026");
    
    cryptoKey = await window.crypto.subtle.deriveKey(
        {
            name: "PBKDF2",
            salt: salt,
            iterations: 100000, // Bruteforce elleni védelem (lassítja a törést)
            hash: "SHA-256"
        },
        keyMaterial,
        { name: "AES-GCM", length: 256 },
        true,
        ["encrypt", "decrypt"]
    );
}

// 3. Lépés: Üzenet titkosítása (AES-GCM)
export async function encryptMessage(text) {
    if (!cryptoKey || !e2eEnabled) return text; // Ha nincs kulcs vagy kikapcsolt, sima szöveg
    
    try {
        const enc = new TextEncoder();
        const encodedText = enc.encode(text);
        
        // Az Initialization Vector (IV) elengedhetetlen az AES-GCM-hez. Ezt minden
        // üzenetnél véletlenszerűen generáljuk.
        const iv = window.crypto.getRandomValues(new Uint8Array(12));
        
        const ciphertext = await window.crypto.subtle.encrypt(
            {
                name: "AES-GCM",
                iv: iv
            },
            cryptoKey,
            encodedText
        );
        
        // A kimenet egy bináris buffer. Összefűzzük az IV-t és a titkosított szöveget,
        // majd Base64 kódolással alakítjuk karakterlummá (hogy JSON-be lehessen tenni).
        const ivArray = Array.from(iv);
        const cipherArray = Array.from(new Uint8Array(ciphertext));
        
        const payload = {
            v: 1, // Verzió (jövőbeli kompatibilitáshoz)
            iv: window.btoa(String.fromCharCode.apply(null, ivArray)),
            data: window.btoa(String.fromCharCode.apply(null, cipherArray))
        };
        
        // Az AWS felé ezt a speciális jelző stringet küldjük:
        return "E2E_MSG::" + JSON.stringify(payload);
        
    } catch (e) {
        console.error("Titkosítási hiba:", e);
        return text;
    }
}

// 4. Lépés: Üzenet visszafejtése
export async function decryptMessage(encryptedString) {
    if (!encryptedString.startsWith("E2E_MSG::")) return encryptedString; // Ha sima üzenet, visszaadja
    
    // --- ÚJ: Ha nincs kulcsunk, egy esztétikus lakatot mutatunk a ronda kód helyett! ---
    if (!cryptoKey) return "🔒 [Titkosított üzenet. Lépj be a Titkos Módba az olvasásához!]"; 
    
    try {
        const payloadStr = encryptedString.replace("E2E_MSG::", "");
        const payload = JSON.parse(payloadStr);
        
        // Base64 visszaalakítása bináris adattá
        const ivString = window.atob(payload.iv);
        const ivArray = new Uint8Array(ivString.length);
        for (let i = 0; i < ivString.length; i++) ivArray[i] = ivString.charCodeAt(i);
            
        const dataString = window.atob(payload.data);
        const dataArray = new Uint8Array(dataString.length);
        for (let i = 0; i < dataString.length; i++) dataArray[i] = dataString.charCodeAt(i);

        const decryptedBuffer = await window.crypto.subtle.decrypt(
            { name: "AES-GCM", iv: ivArray }, cryptoKey, dataArray
        );

        const dec = new TextDecoder();
        return dec.decode(decryptedBuffer);

    } catch (e) {
        console.error("Visszafejtési hiba:", e);
        return "🔒 [Titkosított üzenet - Hibás jelszó!]";
    }
}