# Troubleshooting — Проблемы и решения

## Worker завис

### Симптомы
- Процесс `codex` работает, но нет output
- CPU usage 0%, процесс "спит"
- Timeout не срабатывает

### Диагностика
```bash
# Проверить процесс
ps -ef | grep codex

# CPU/Memory
top -p $(pgrep -f "codex.*exec")

# Стек вызовов
cat /proc/$(pgrep -f "codex.*exec")/stack
```

### Решение
```bash
# Убить process tree
pkill -P $(pgrep -f "codex_wp")  # Сначала детей
pkill -f "codex_wp"              # Потом родителя

# Resume с новой инструкцией
codex_wp exec resume --json $SESSION_ID "Continue. If stuck, skip current task and move to next."
```

## codex-review timeout

### Симптомы
- `rc=124` в request.json
- `report.md` не создан
- Процесс висит 5+ минут

### Решение
```bash
# Использовать kimi_wp backend напрямую
/home/pets/TOOLS/codex-review-skill_cli/codex-review \
  --target /path/to/repo \
  --commit SHA \
  --backend kimi_wp \
  --timeout 180
```

## Auth ошибки

### Симптомы
- `401 Unauthorized`
- `rc=1` при запуске codex

### Диагностика
```bash
cdx doctor --probe
cdx status --json
```

### Решение
```bash
# Ротация ключа
cdx rotate

# Сброс blacklist если починили ключи
cdx reset --state blacklist
```

## Kanban corrupted

### Симптомы
- `jq '.' kanban.json` падает
- Несовпадение counts

### Решение
```bash
# Бэкап
cp kanban.json kanban.json.bak

# Ручное исправление (если возможно)
jq '.' kanban.json.bak > kanban.json

# Или регенерация из BOARD.md (если есть skill)
```

## Session не найдена

### Симптомы
- `codex_wp exec resume` говорит session not found

### Решение
```bash
# Найти последнюю сессию
ls -lt ~/.codex/sessions/2026/03/30/ | head -5

# Использовать --last
codex_wp exec resume --json --last "Continue"
```

## Proxy недоступен

### Симптомы
- `Connection refused 127.0.0.1:50787`
- Timeout на всех запросах

### Решение
```bash
# Проверить proxy
cdx status --json

# Перезапустить proxy
cdx proxy --stop
cdx proxy --start

# Или без proxy (напрямую к OpenAI)
codex_wp exec --json -c openai_base_url="https://chatgpt.com/backend-api" "Task"
```

## Zellij проблемы

### Симптомы
- `failed to resolve floating zellij geometry`
- `failed to parse zellij tab list`

### Решение
```bash
# Не использовать zellij флаги в headless
# Вместо:
codex_wp --zellij-floating ...  # ❌

# Использовать:
codex_wp exec --json ...        # ✅
```

## Memory / Context overflow

### Симптомы
- Worker начинает "забывать" контекст
- Повторяет уже сделанные задачи

### Решение
```bash
# Начать новую сессию с явным контекстом
codex_wp exec --json "
CURRENT STATE from kanban.json:
$(jq '.status_counts' kanban.json)

DONE cards: $(jq '.cards[] | select(.status == "done") | .id' kanban.json)

Continue from where we left off.
"
```
