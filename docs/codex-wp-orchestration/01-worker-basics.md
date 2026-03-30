# Worker Basics — Базовые команды

## Headless Exec (без TTY)

```bash
# Минимальный запуск
codex_wp exec --json "Your prompt here"

# С таймаутом (через bash)
timeout 600 codex_wp exec --json "Long running task"

# С конфигурацией
codex_wp exec --json -m gpt-5.4 "Prompt"
```

## Exec с файлом контекста

```bash
# Добавить файл как контекст
codex_wp -f /path/to/context.md exec --json "Read context and implement"
```

## Proxy команды (cdx)

```bash
# Статус прокси
cdx status --json

# Health check ключей
cdx doctor --probe

# Usage dashboard
cdx all

# Превью ротации
cdx rotate --dry-run
```

## Важные флаги

| Флаг | Назначение |
|------|------------|
| `--json` | Обязателен для headless + hooks |
| `-C /path` | Рабочая директория |
| `-m model` | Модель (gpt-5.4, o3, etc) |
| `--dangerously-bypass-approvals-and-sandbox` | Без sandbox (осторожно!) |

## Output parsing

JSONL формат — каждая строка = JSON объект:

```json
{"type":"thread.started","thread_id":"..."}
{"type":"turn.started"}
{"type":"item.completed","item":{...}}
{"type":"turn.completed","usage":{...}}
```

Ключевые типы:
- `thread.started` → `thread_id` для resume
- `turn.completed` → конец одного оборота
- `item.completed` → результат действия
