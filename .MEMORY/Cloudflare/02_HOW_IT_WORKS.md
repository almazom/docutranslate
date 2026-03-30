# 🧭 КАК ЭТО РАБОТАЕТ

Юзер в РФ
  ↓
https://docutranslate.ru (порт 443 стандартный)
  ↓
Cloudflare CDN (скрывает реальный IP)
  ↓ Origin Rule: порт → 2053
Сервер 107.174.231.22:2053
  ↓
Nginx (SSL, basic auth)
  ↓
DocuTranslate app (:8010)
