# 📋 TODO

## Срочно
- [ ] Развернуть Docker-based RU proxy на `212.28.182.235` по `RU_ACCESS_PLAN.md`
- [ ] Подготовить TLS на `212.28.182.235` для `docutranslate.ru`
- [ ] Включить `Cloudflare` Load Balancer + geo steering: `RU -> 212.28.182.235`, default -> current path
- [ ] После cutover повторить route-labeled validation: `default`, `ru-like`, `main-domain`, `rollback-default`

## Потом
- [ ] Проверить доступ из реального российского подключения, не только через proxy/VPS
- [ ] Выполнить operator rollback drill уже после реального steering enable
- [ ] Убрать порт 18443 из старых ссылок
- [ ] Записать пароль basic auth в безопасное место

## Если НЕ заработает через CF
- [ ] Не делать partial cutover; вернуть весь трафик на default path одним steering change
- [ ] Рассмотреть GeoDNS только как отдельное fallback-решение, а не как silent substitution
