# 📌 STATUS: docutranslate.ru

## Ждём (⏳)
- Включить `Cloudflare` Load Balancer + geo steering для same-domain RU-path
- Поднять и привязать RU proxy на `212.28.182.235` по зафиксированному runbook
- После edge-cutover прогнать тот же набор smoke/confidence/rollback проверок уже на реальном steering

## Работает сейчас (✅)
- По IP: `https://107.174.231.22:2053` (пароль basic auth)
- Порт 2053 слушает, nginx+app контейнеры UP
- `docutranslate.ru` уже резолвится через Cloudflare
- `https://docutranslate.ru` открывает UI, `/health` отвечает `{"status":"ok","version":"1.7.1.post1"}`
- Landing smoke на основном домене проходит
- Landing confidence проходит для `main-domain`, `default`, `ru-like`, и `rollback-default` validation labels

## Не завершено (⚠️)
- Same-domain RU steering ещё не включён на edge
- `212.28.182.235` ещё не обслуживает продовый RU-path
- Порт 18443 снова опубликован как legacy compatibility alias для старых health checks и прямых ссылок
