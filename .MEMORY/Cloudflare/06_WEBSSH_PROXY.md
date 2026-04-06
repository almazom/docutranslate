# 06 WEBSSH PROXY

Date: `2026-04-05`

What changed:
- origin `107.174.231.22:2053` now serves `docutranslate.ru/ssh` by proxying `/ssh` to the local WebSSH2 stack
- the origin path keeps `/ssh`, `/ssh/assets`, and `/ssh/socket.io` intact
- Contabo front door `212.28.182.235:443` now proxies `/ssh` to `https://107.174.231.22:2053`

Why:
- same-domain browser SSH must work no matter which front-door path `docutranslate.ru` reaches

Verified:
- `https://127.0.0.1:2053/ssh` returns `200` after basic auth
- `https://212.28.182.235/ssh` returns `200` after basic auth
- `https://docutranslate.ru/ssh` returns `200` after basic auth
