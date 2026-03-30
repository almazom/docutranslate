# 🗺️ КАРТА ПОРТОВ СЕРВЕРА

| Порт | Кто | Зачем |
|------|-----|-------|
| :80  | Caddy (systemd) | publish-pages → :8888 |
| :443 | ??? занят | — |
| :2053 | **DocuTranslate nginx** | ← Cloudflare стучится сюда |
| :18080 | DocuTranslate nginx | HTTP (не используется через CF) |
| :8002 | phoenix-translation | другой проект |
| :8443 | webssh2-public-proxy | Caddy в Docker |
| :18888 | Caddy | publish-pages прямой доступ |

## Контакты сервера
- IP: 107.174.231.22
- Провайдер: RackNerd (США)
- OS: Ubuntu 24.04
