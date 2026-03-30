# Kanban Integration — Интеграция с implementation-skill

## Структура kanban.json

```json
{
  "meta": {
    "status": "ready",
    "updated_at": "2026-03-30T04:48:06Z"
  },
  "card_count": 8,
  "total_story_points": 11,
  "status_counts": {
    "backlog": 7,
    "ready": 1,
    "in_progress": 0,
    "simplify": 0,
    "commit": 0,
    "codex-review": 0,
    "done": 0,
    "blocked": 0
  },
  "cards": [...]
}
```

## Lifecycle карты

```
backlog → ready → in_progress → simplify → commit → codex-review → done
                            ↓
                         blocked
```

## Команды implementation-skill

```bash
# Старт карты
cd /home/pets/TOOLS/split_to_tasks_skill_cli && \
PYTHONPATH=src python -m split_to_tasks_skill_cli implementation-start \
  --package /path/to/package \
  --repo-root /path/to/repo

# Переход между стадиями
PYTHONPATH=src python -m split_to_tasks_skill_cli implementation-stage \
  --package /path/to/package \
  --card 0001 \
  --to simplify \
  --note "Implementation complete"

# Статус
PYTHONPATH=src python -m split_to_tasks_skill_cli summary \
  --package /path/to/package
```

## Парсинг для Orchestrator

```bash
# Сколько всего карт
jq '.card_count' kanban.json

# Сколько done
jq '.status_counts.done' kanban.json

# Есть ли blocked
jq '.status_counts.blocked' kanban.json

# Текущая карта
jq '.cards[] | select(.status == "in_progress") | .id' kanban.json

# Следующая ready карта
jq '.cards[] | select(.status == "ready") | .id' kanban.json | head -1
```

## Промпт для worker

```text
Read /path/to/package/AGENTS.md and implement card 0001.

Start with:
  cd /home/pets/TOOLS/split_to_tasks_skill_cli && \
  PYTHONPATH=src python -m split_to_tasks_skill_cli implementation-start \
    --package /path/to/package \
    --repo-root /path/to/repo

Then implement the full card lifecycle:
  implement → simplify → commit → codex-review → done

After card is done, continue to the next ready card automatically.
Do NOT stop until all cards are done.
Treat kanban.json as the only writable execution SSOT.
```

## Зависимости между картами

```json
{
  "id": "0002",
  "depends_on": ["0001"]
}
```

- Карта 0002 не станет `ready` пока 0001 не `done`
- Worker автоматически увидит разблокировку
- Orchestrator проверяет `ready` карты после каждого цикла

## Валидация

```bash
# Проверить что kanban валидный JSON
jq '.' kanban.json > /dev/null && echo "OK" || echo "CORRUPT"

# Проверить консистентность
DONE=$(jq '.status_counts.done' kanban.json)
ACTUAL=$(jq '[.cards[] | select(.status == "done")] | length' kanban.json)
[ "$DONE" -eq "$ACTUAL" ] && echo "Consistent" || echo "MISMATCH!"
```
