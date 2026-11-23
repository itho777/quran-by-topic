/* tafseer.id service worker.
 *
 * The previous version was cache-first for EVERYTHING, including index.html,
 * and only revalidated .js/.css//data/. A browser with the worker installed
 * therefore kept its old app shell forever: any new <script> added to
 * index.html (for example razi-chat.js) never reached returning visitors,
 * which is exactly how Razi ended up invisible on mobile while a desktop
 * without the worker showed it.
 *
 * Rules now:
 *   navigation + HTML  -> network first, cache only when offline
 *   .js/.css//data/    -> stale-while-revalidate
 *   images/fonts       -> cache first
 *   anything else      -> network, falling through
 *
 * Bump CACHE_NAME on every shell change: activate() drops older caches,
 * and the HTML is no longer pinned by the cache anyway.
 */
const CACHE_NAME = 'tafseer-pwa-v71';
const ASSETS = [
  './',
  './index.html',
  './app.css',
  './app.js',
  './manifest.json',
  './razi-chat.js',
  './razi-avatar.jpg'
];

const isHtml = (req, url) =>
  req.mode === 'navigate' ||
  (req.headers.get('accept') || '').includes('text/html') ||
  url.pathname === '/' ||
  url.pathname.endsWith('.html');

const isStaleWhileRevalidate = (url) =>
  url.pathname.startsWith('/data/') ||
  url.pathname.endsWith('.js') ||
  url.pathname.endsWith('.css') ||
  url.pathname.endsWith('.json');

const isCacheFirst = (url) =>
  /\.(png|jpg|jpeg|webp|svg|gif|ico|woff2?|ttf|otf)$/i.test(url.pathname);

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => cache.addAll(ASSETS.map(a => new Request(a, { cache: 'reload' }))))
      .catch(err => console.warn('[SW] Precache incomplete', err))
  );
  self.skipWaiting();
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys => Promise.all(
      keys.map(key => (key !== CACHE_NAME ? caches.delete(key) : null))
    ))
  );
  self.clients.claim();
});

self.addEventListener('fetch', event => {
  const req = event.request;
  if (req.method !== 'GET') return;

  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;

  // Never let the chat endpoint or the worker script be served from cache.
  if (url.pathname.endsWith('/service-worker.js')) return;

  if (isHtml(req, url)) {
    event.respondWith(
      fetch(req)
        .then(res => {
          if (res && res.status === 200) {
            const copy = res.clone();
            caches.open(CACHE_NAME).then(c => c.put(req, copy)).catch(() => {});
          }
          return res;
        })
        .catch(() => caches.match(req).then(hit => hit || caches.match('./index.html')))
    );
    return;
  }

  if (isStaleWhileRevalidate(url)) {
    event.respondWith(
      caches.match(req).then(hit => {
        const network = fetch(req)
          .then(res => {
            if (res && res.status === 200) {
              const copy = res.clone();
              caches.open(CACHE_NAME).then(c => c.put(req, copy)).catch(() => {});
            }
            return res;
          })
          .catch(() => hit);
        return hit || network;
      })
    );
    return;
  }

  if (isCacheFirst(url)) {
    event.respondWith(
      caches.match(req).then(hit => hit || fetch(req).then(res => {
        if (res && res.status === 200) {
          const copy = res.clone();
          caches.open(CACHE_NAME).then(c => c.put(req, copy)).catch(() => {});
        }
        return res;
      }))
    );
    return;
  }

  event.respondWith(
    fetch(req).catch(() => caches.match(req))
  );
});
