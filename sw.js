// CARENOTE Service Worker - Cache Buster v6
// 이 파일은 이전 버전의 캐시를 모두 지우고 항상 네트워크에서 최신 파일을 가져옵니다.

self.addEventListener('install', event => {
  // 기존 SW를 기다리지 않고 즉시 활성화
  self.skipWaiting();
});

self.addEventListener('activate', event => {
  event.waitUntil(
    // 모든 캐시 삭제
    caches.keys()
      .then(keys => Promise.all(keys.map(k => {
        console.log('[SW] 캐시 삭제:', k);
        return caches.delete(k);
      })))
      .then(() => {
        console.log('[SW] 모든 캐시 삭제 완료');
        return self.clients.claim(); // 즉시 모든 탭 제어권 획득
      })
  );
});

self.addEventListener('fetch', event => {
  // 캐시 없이 항상 네트워크에서 가져옴
  event.respondWith(fetch(event.request));
});
