# 🔧 ЧТО СДЕЛАЛИ

## Сервер (107.174.231.22)
- [x] Порт 18443 → **2053** (Cloudflare-совместимый)
- [x] .env: DOCUTRANSLATE_HTTPS_PORT=2053
- [x] Docker контейнеры пересозданы

## Cloudflare (dash.cloudflare.com)
- [x] Домен добавлен (Free план)
- [x] DNS A: docutranslate.ru → 107.174.231.22 (Proxied ☁️)
- [x] DNS A: www → 107.174.231.22 (Proxied ☁️)
- [x] SSL/TLS = **Full**
- [x] Origin Rule: "all coming requests" → Rewrite port to **2053**

## nameself.com (регистратор)
- [x] NS: archer.ns.cloudflare.com
- [x] NS: carlane.ns.cloudflare.com
- [ ] ⏳ Ждём propagation
