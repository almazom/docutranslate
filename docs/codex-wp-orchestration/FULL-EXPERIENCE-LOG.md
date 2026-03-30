# Full Experience Log — Реальный запуск orchestrator

> Полный лог опыта запуска codex_wp в режиме orchestrator для реализации Trello package

## Дата: 2026-03-30

## Проект: DocuTranslate RU Entry

- **Repo**: `~/zoo/docutranslate`
- **Branch**: `ru-fixes-with-contabo`
- **Package**: `~/zoo/docutranslate/generated/ru-entry-for-docutranslate`
- **Cards**: 8 total, 1 ready, 7 backlog

---

## 1. Подготовка и чтение контекста

### Команды

```bash
# Проверка ветки
cd ~/zoo/docutranslate && git branch --show-current && git status --short

# Чтение AGENTS.md
read /home/pets/zoo/docutranslate/generated/ru-entry-for-docutranslate/AGENTS.md

# Чтение kanban.json
read /home/pets/zoo/docutranslate/generated/ru-entry-for-docutranslate/trello-cards/kanban.json

# Чтение KICKOFF.md
read /home/pets/zoo/docutranslate/generated/ru-entry-for-docutranslate/trello-cards/KICKOFF.md
```

### Результат

```
Branch: ru-fixes-with-contabo ✓
Cards: 8
Status: backlog=7, ready=1, done=0
First card: 0001 - Same-Domain Steering Strategy
```

---

## 2. Первый запуск worker

### Промпт (полный)

```bash
cd /home/pets/zoo/docutranslate && codex_wp --hook stop --hook-times 5 \
  --hook-prompt "Continue implementing next Trello card. Do not stop. Check kanban.json for remaining cards." \
  exec --json "Read /home/pets/zoo/docutranslate/generated/ru-entry-for-docutranslate/AGENTS.md and implement card 0001. Start with: cd /home/pets/TOOLS/split_to_tasks_skill_cli && PYTHONPATH=src python -m split_to_tasks_skill_cli implementation-start --package /home/pets/zoo/docutranslate/generated/ru-entry-for-docutranslate --repo-root /home/pets/zoo/docutranslate. Then implement the full card lifecycle: implement -> simplify -> commit -> codex-review -> done. After card 0001 is done, continue to the next ready card automatically. Do NOT stop until all cards are done."
```

### Параметры

| Параметр | Значение | Обоснование |
|----------|----------|-------------|
| `--hook stop` | ✅ | Включить stop hook |
| `--hook-times` | 5 | ~2-3 карты по 2 turns каждая |
| `--hook-prompt` | "Continue implementing..." | Инструкция продолжать |
| `exec --json` | ✅ | Обязателен для hooks |
| `timeout` | 600s | Внешний timeout |

### Что произошло

Worker запустился, начал выполнять карту 0001:

1. ✅ Прочитал AGENTS.md
2. ✅ Запустил `implementation-start`
3. ✅ Создал/обновил `RU_ACCESS_PLAN.md` и `.MEMORY.md`
4. ✅ Запустил code-simplifier (skill auto-commit)
5. ✅ Создал коммит `b602411` - "docs: choose same-domain RU steering"
6. ✅ Перевёл карту в `codex-review`
7. ⚠️ Запустил `codex-review --commit b602411...`

### Проблема: codex-review timeout

```
codex backend timed out (rc=124)
Fallback to kimi_wp initiated
But wrapper got stuck
```

**Детали из лога:**

```json
// request.json показал fallback
{
  "backend": "codex",
  "fallback_reason": "codex failed with rc=124",
  "is_fallback": true
}
```

**Процессы:**
```
PID 69739 - python3 -m codex_review_skill_cli.cli (stuck)
PID 69769 - codex exec review (stuck, 350 seconds elapsed)
```

### Решение

```bash
# Убил зависшие процессы
kill 69739 69769

# Перезапустил с явным backend
codex-review --target /home/pets/zoo/docutranslate \
  --commit b6024119c97a908c2f6f1b85e17663dce229a21d \
  --backend kimi_wp --timeout 180
```

### Итог первого запуска

```
Timeout: 600s достигнут
Карта 0001: in codex-review (не завершена)
Остальные карты: не начаты
```

---

## 3. Анализ JSONL output

### Ключевые события из лога

```jsonl
{"type":"thread.started","thread_id":"019d3d1b-9925-79b2-8d29-c3621fedf778"}
{"type":"turn.started"}
{"type":"item.completed","item":{"type":"agent_message","text":"Creating RU_ACCESS_PLAN.md..."}}
{"type":"item.completed","item":{"type":"file_change","changes":[{"path":"RU_ACCESS_PLAN.md","kind":"add"}]}}
{"type":"item.completed","item":{"type":"command_execution","command":"git add RU_ACCESS_PLAN.md .MEMORY.md && git commit..."}}
{"type":"turn.completed","usage":{"input_tokens":71784,"cached_input_tokens":43392,"output_tokens":651}}
// ... ещё turns
{"type":"thread.started","thread_id":"019d3d1b-9925-79b2-8d29-c3621fedf778"}  // resume via hook
```

### Структура turns

```
Turn 1: implementation-start, create files
Turn 2: hook prompt injected → simplify, commit
Turn 3: hook prompt injected → codex-review (stuck here)
```

---

## 4. Уроки и выводы

### Что сработало ✅

1. **Hooks механизм** — worker продолжал после каждого stop
2. **JSONL формат** — легко парсить progress
3. **implementation-skill команды** — корректно обновляли kanban.json
4. **code-simplifier + auto-commit** — автоматически создал коммит

### Что НЕ сработало ❌

1. **codex-review timeout** — native codex backend завис на 5+ минут
2. **Fallback не завершился** — kimi_wp fallback тоже не успел
3. **Общий timeout 600s** — недостаточно для полного цикла с review

### Рекомендации для следующего запуска

```bash
# 1. Увеличить timeout
timeout 1200 codex_wp ...

# 2. Явно указать backend для review
# В prompt добавить:
"If codex-review times out, use: codex-review --backend kimi_wp --timeout 180"

# 3. Меньше hook-times, больше циклов
--hook-times 3  # Меньше оборотов за раз
# И resume несколько раз

# 4. Пропускать review если завис
# В prompt:
"If review takes >3 minutes, mark card as 'needs manual review' and continue to next card"
```

---

## 5. Промпты для разных сценариев

### A. Начальный запуск (полный lifecycle)

```text
Read /home/pets/zoo/docutranslate/generated/ru-entry-for-docutranslate/AGENTS.md and implement card 0001.

Start with:
  cd /home/pets/TOOLS/split_to_tasks_skill_cli && \
  PYTHONPATH=src python -m split_to_tasks_skill_cli implementation-start \
    --package /home/pets/zoo/docutranslate/generated/ru-entry-for-docutranslate \
    --repo-root /home/pets/zoo/docutranslate

Then implement the full card lifecycle:
  implement -> simplify -> commit -> codex-review -> done

IMPORTANT for codex-review:
- If codex-review times out, use: /home/pets/TOOLS/codex-review-skill_cli/codex-review --backend kimi_wp --timeout 180
- If review still fails after 3 minutes, mark card as 'needs manual review' and MOVE ON

After card 0001 is done, continue to the next ready card automatically.
Do NOT stop until all cards are done.
Treat kanban.json as the only writable execution SSOT.
```

### B. Resume после timeout

```text
Continue implementing from where we left off.

Current state from kanban.json:
  - done: X cards
  - in_progress: Y cards
  - ready: Z cards

Current card: [ID] - [TITLE]

Complete the current card lifecycle:
  [current stage] -> ... -> done

Then continue to next ready card.
Do not stop until done == total.
```

### C. Resume после блокировки

```text
Previous worker was blocked. Resume with different strategy.

Blocked card: [ID] - [reason]

Options:
1. Try alternative approach
2. Skip and mark as 'blocked' in kanban.json
3. Document blocker and move to next ready card

Decision: [your decision]

Continue with: implementation-start for next ready card
```

### D. Hook prompt для продолжения

```text
Continue implementing next Trello card. Do not stop. Check kanban.json for remaining cards.

If current card is stuck on codex-review:
  - Kill the review process
  - Use kimi_wp backend with 180s timeout
  - If still stuck, mark 'needs manual review' and continue

Treat kanban.json as the only writable execution SSOT.
```

---

## 6. Скрипт для парсинга прогресса

```bash
#!/bin/bash
# parse-progress.sh

KANBAN="/home/pets/zoo/docutranslate/generated/ru-entry-for-docutranslate/trello-cards/kanban.json"

DONE=$(jq '.status_counts.done' $KANBAN)
TOTAL=$(jq '.card_count' $KANBAN)
IN_PROGRESS=$(jq '.status_counts.in_progress' $KANBAN)
READY=$(jq '.status_counts.ready' $KANBAN)
BLOCKED=$(jq '.status_counts.blocked' $KANBAN)

PERCENT=$((DONE * 100 / TOTAL))

# Progress bar
BAR_WIDTH=20
FILLED=$((DONE * BAR_WIDTH / TOTAL))
EMPTY=$((BAR_WIDTH - FILLED))
BAR=$(printf '█%.0s' $(seq 1 $FILLED))$(printf '░%.0s' $(seq 1 $EMPTY))

echo "┌─────────────────────────────────────────┐"
echo "│  CARDS: $BAR $DONE/$TOTAL ($PERCENT%)     │"
echo "│  STATUS: in_progress=$IN_PROGRESS, ready=$READY, blocked=$BLOCKED"
echo "└─────────────────────────────────────────┘"

# Current card
if [ "$IN_PROGRESS" -gt 0 ]; then
    CURRENT=$(jq -r '.cards[] | select(.status == "in_progress") | "\(.id) - \(.title)"' $KANBAN | head -1)
    echo "CURRENT: $CURRENT"
fi

# Exit codes
if [ "$DONE" -eq "$TOTAL" ]; then
    exit 0  # All done
elif [ "$BLOCKED" -gt 0 ]; then
    exit 2  # Blocked
else
    exit 1  # In progress
fi
```

---

## 7. Telegram notification template

```bash
#!/bin/bash
# notify-progress.sh

DONE=$1
TOTAL=$2
CURRENT=$3
STATUS=$4

case $STATUS in
    "progress")
        t2me "🔄 DocuTranslate: $DONE/$TOTAL cards done. Current: $CURRENT"
        ;;
    "done")
        t2me "✅ DocuTranslate: All $TOTAL cards implemented!"
        ;;
    "blocked")
        t2me "⛔ DocuTranslate: Blocked on card $CURRENT. Needs manual intervention."
        ;;
    "error")
        t2me "❌ DocuTranslate: Worker crashed. Last successful: $DONE/$TOTAL"
        ;;
esac
```

---

## 8. Финальная структура knowledge base

```
docs/codex-wp-orchestration/
├── README.md              # Обзор
├── 01-worker-basics.md    # Команды worker
├── 02-hooks-workflow.md   # Hooks
├── 03-resume-strategy.md  # Resume
├── 04-observer-loop.md    # Orchestrator loop
├── 05-kanban-integration.md # Kanban
├── 06-troubleshooting.md  # Проблемы
├── SKILL-PROPOSAL.md      # Как сделать skill
├── FULL-EXPERIENCE-LOG.md # Этот файл
├── scripts/
│   ├── parse-progress.sh  # Парсинг kanban
│   ├── notify-progress.sh # Уведомления
│   └── orchestrator-loop.sh # Главный цикл
└── templates/
    ├── prompt-initial.md
    ├── prompt-resume.md
    ├── prompt-hook.md
    └── prompt-blocked.md
```
