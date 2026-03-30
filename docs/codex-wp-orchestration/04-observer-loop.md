# Observer Loop — Цикл мониторинга Orchestrator

## Роль Orchestrator

```
┌────────────────────────────────────────────────────────────┐
│                     ORCHESTRATOR                            │
│                                                             │
│  1. READ kanban.json → понять состояние                     │
│  2. LAUNCH worker → codex_wp exec --json                    │
│  3. WAIT for exit → worker остановился                      │
│  4. READ kanban.json → проверить прогресс                   │
│  5. DECIDE:                                                 │
│     - done < total → RESUME worker                          │
│     - done == total → FINISH (notify user)                  │
│     - blocked → ESCALATE to user                            │
│  6. REPEAT until done == total                              │
│                                                             │
└────────────────────────────────────────────────────────────┘
```

## Ключевые метрики из kanban.json

```json
{
  "card_count": 8,
  "status_counts": {
    "done": 2,
    "in_progress": 1,
    "ready": 1,
    "backlog": 4,
    "blocked": 0
  }
}
```

**Условия остановки:**

| Статус | Действие |
|--------|----------|
| `done == card_count` | ✅ FINISH — всё готово |
| `blocked > 0` | ⚠️ ESCALATE — есть блокер |
| `in_progress > 0 && worker stopped` | 🔄 RESUME — продолжить |
| `ready > 0 && in_progress == 0` | 🚀 START — новая карта |

## Пример скрипта мониторинга

```bash
#!/bin/bash
# orchestrator-loop.sh

KANBAN="/path/to/kanban.json"
REPO_ROOT="/path/to/repo"
PACKAGE="/path/to/package"

while true; do
    # Читаем состояние
    DONE=$(jq '.status_counts.done' $KANBAN)
    TOTAL=$(jq '.card_count' $KANBAN)
    BLOCKED=$(jq '.status_counts.blocked' $KANBAN)

    echo "Progress: $DONE / $TOTAL (blocked: $BLOCKED)"

    # Проверка завершения
    if [ "$DONE" -eq "$TOTAL" ]; then
        echo "✅ All cards done!"
        t2me "DocuTranslate: All $TOTAL cards implemented!"
        exit 0
    fi

    # Проверка блокировки
    if [ "$BLOCKED" -gt 0 ]; then
        echo "⛔ Blocked cards detected"
        t2me "DocuTranslate: $BLOCKED cards blocked!"
        exit 1
    fi

    # Resume или запуск worker
    SESSION=$(cat /tmp/current_session_id 2>/dev/null || echo "")

    if [ -n "$SESSION" ]; then
        echo "Resuming session $SESSION..."
        timeout 600 codex_wp exec resume --json "$SESSION" "Continue implementing" 2>&1 | tee /tmp/worker.log
    else
        echo "Starting new worker..."
        timeout 600 codex_wp --hook stop --hook-times 10 \
            --hook-prompt "Continue to next card" \
            exec --json "Implement cards from $PACKAGE" 2>&1 | tee /tmp/worker.log
        # Сохраняем session_id
        grep '"type":"thread.started"' /tmp/worker.log | head -1 | jq -r '.thread_id' > /tmp/current_session_id
    fi

    sleep 5
done
```

## Детекция причин остановки

```bash
# Worker exit code
EXIT_CODE=$?

# 0 = нормальное завершение
# 1 = ошибка
# 124 = timeout
# 137 = killed (OOM или signal)
```

## Telegram уведомления

```bash
# После каждого цикла
DONE=$(jq '.status_counts.done' $KANBAN)
TOTAL=$(jq '.card_count' $KANBAN)

t2me "🔄 DocuTranslate progress: $DONE/$TOTAL cards done"
```

## Рекомендации

1. **Timeout на worker** — всегда ставь `timeout 600` или больше
2. **Сохраняй session_id** — для resume
3. **Логируй output** — `tee worker.log`
4. **Пауза между циклами** — `sleep 5` чтобы не спамить
5. **Notify при блокировке** — сразу в Telegram
