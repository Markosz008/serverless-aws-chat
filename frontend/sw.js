self.addEventListener('install', (e) => {
    self.skipWaiting();
});

self.addEventListener('activate', (e) => {
    e.waitUntil(self.clients.claim());
});

// Ez kapja el a Push üzenetet a Lambdától (Google/Apple szerverén keresztül)
self.addEventListener('push', function(event) {
    if (event.data) {
        const data = event.data.json();
        
        // Frissítjük az ikonon a számot (ha támogatja a rendszer)
        if ('setAppBadge' in navigator) {
            navigator.setAppBadge(); // Vagy egy konkrét számot is kaphatna
        }

        const options = {
            body: data.body,
            icon: 'https://cdn-icons-png.flaticon.com/512/134/134808.png',
            badge: 'https://cdn-icons-png.flaticon.com/512/134/134808.png',
            vibrate: [200, 100, 200],
            data: { url: data.url || '/' }
        };

        event.waitUntil(
            self.registration.showNotification(data.title, options)
        );
    }
});

// Ha a user rákattint az értesítésre:
self.addEventListener('notificationclick', function(event) {
    event.notification.close();
    event.waitUntil(
        clients.matchAll({ type: 'window' }).then(windowClients => {
            // Ha már nyitva van egy tab a chattel, azt fókuszálja
            for (var i = 0; i < windowClients.length; i++) {
                var client = windowClients[i];
                if (client.url.includes(self.registration.scope) && 'focus' in client) {
                    return client.focus();
                }
            }
            // Ha nincs nyitva, nyit egy újat
            if (clients.openWindow) {
                return clients.openWindow(event.notification.data.url);
            }
        })
    );
});