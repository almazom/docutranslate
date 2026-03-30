# Skill Proposal: codex-orchestrator

> Как превратить эти знания в повторно используемый skill

## Структура skill

```
~/.agents/skills/codex-orchestrator/
├── SKILL.md                 # Главная инструкция
├── references/
│   ├── worker-commands.md   # Шпаргалка команд
│   ├── observer-pattern.md  # Паттерн мониторинга
│   └── kanban-schema.md     # Схема kanban.json
└── templates/
    ├── kickoff-prompt.md    # Промпт для старта worker
    ├── resume-prompt.md     # Промпт для resume
    └── notify-template.md   # Шаблон уведомления
```

## SKILL.md (черновик)

```markdown
# Codex Orchestrator Skill

Use when you need to manage multiple codex_wp workers implementing
Trello cards from a kanban.json package.

## Role

You are an Orchestrator. You do NOT write code.
You manage codex_wp workers in headless mode.

## Workflow

1. READ kanban.json → understand current state
2. LAUNCH worker → codex_wp --hook stop --hook-times N exec --json
3. WAIT for exit → capture session_id from JSONL
4. READ kanban.json → check progress
5. DECIDE:
   - done < total → RESUME worker with instruction
   - done == total → NOTIFY user, FINISH
   - blocked > 0 → ESCALATE to user
6. REPEAT until done == total

## Commands

### Start worker
```bash
codex_wp --hook stop --hook-times 10 \
  --hook-prompt "Continue implementing. Check kanban.json. Do not stop." \
  exec --json "Implement cards from PACKAGE. Full lifecycle per card."
```

### Resume worker
```bash
codex_wp exec resume --json $SESSION_ID "Continue with next ready card"
```

### Check progress
```bash
jq '.status_counts.done, .card_count' kanban.json
```

## Progress Visualization

Always show:
```
┌─────────────────────────────────────────┐
│  CARDS: ████░░░░░░░░░░░░ 3/8 (37%)     │
│  STATUS: in_progress=1, ready=1         │
│  CURRENT: 0004 - TLS Setup              │
└─────────────────────────────────────────┘
```

## Notifications

After each worker cycle, notify user:
```bash
t2me "🔄 Package: $DONE/$TOTAL cards done. Current: $CURRENT_CARD"
```

## Blocking conditions

- `blocked > 0` in kanban.json
- Worker exit code != 0 AND != 124 (timeout)
- kanban.json corrupted (jq parse error)

On block: STOP, notify user with details, do NOT auto-retry.
```

## Интеграция с AGENTS.md

Добавить в проектный AGENTS.md:

```markdown
## Codex Orchestrator

When implementing Trello card packages:

1. Use skill `codex-orchestrator`
2. Treat kanban.json as the only writable execution SSOT
3. Run workers with hooks for multi-turn execution
4. Resume sessions when workers stop prematurely
5. Notify user after each cycle
6. Never stop until done == total OR blocked > 0
```

## Регистрация skill

В `~/.pi/agent/agents/default/AGENTS.md`:

```markdown
- codex-orchestrator: Manage codex_wp workers implementing Trello cards.
  Use when implementing packages from split-to-tasks skill.
  (file: ~/.agents/skills/codex-orchestrator/SKILL.md)
```

## Пример использования

```text
User: Implement the package at /path/to/package using codex-orchestrator

Agent:
🚀 Starting codex-orchestrator skill

┌─────────────────────────────────────────┐
│  CARDS: ░░░░░░░░░░░░░░░░ 0/8 (0%)      │
│  STATUS: ready=1, backlog=7             │
│  CURRENT: 0001 - Same-Domain Steering   │
└─────────────────────────────────────────┘

Launching worker with 10 hook cycles...

[Worker output...]

┌─────────────────────────────────────────┐
│  CARDS: ████░░░░░░░░░░░░ 2/8 (25%)     │
│  STATUS: in_progress=1, done=2          │
│  CURRENT: 0003 - RU-path Proxy          │
└─────────────────────────────────────────┘

Worker stopped. Resuming session 019d3d1b...

[Continue until done == total]

✅ All 8 cards implemented!
```

## Преимущества skill

1. **Повторяемость** — одинаковый workflow для всех проектов
2. **Визуализация** — понятный прогресс-бар
3. **Уведомления** — пользователь в курсе
4. **Обработка ошибок** — явные правила для блокировок
5. **Документация** — все знания в одном месте
