# Codex WP Orchestration Knowledge Base

> Руководство по управлению codex_wp workers в headless режиме с мониторингом и resume.

## Структура

```
codex-wp-orchestration/
├── README.md              # Этот файл — обзор
├── 01-worker-basics.md    # Базовые команды worker
├── 02-hooks-workflow.md   # Hooks и multi-turn выполнение
├── 03-resume-strategy.md  # Resume сессий
├── 04-observer-loop.md    # Цикл мониторинга (оркестратор)
├── 05-kanban-integration.md # Интеграция с kanban.json
├── 06-troubleshooting.md  # Проблемы и решения
└── SKILL-PROPOSAL.md      # Как превратить в skill
```

## Быстрый старт

```bash
# Запуск worker с hooks (5 оборотов, auto-resume)
codex_wp --hook stop --hook-times 5 \
  --hook-prompt "Continue implementing. Check kanban.json for remaining cards." \
  exec --json "Implement card 0001. Full lifecycle: implement -> simplify -> commit -> review -> done"

# Resume последней сессии
codex_wp exec resume --json --last "Continue with next card"

# Resume по ID
codex_wp exec resume --json 019d3d19-20b1-7210-b95d-f71f10aaf9e1 "Continue"
```

## Ключевые принципы

1. **Headless = `exec --json`** — обязателен для hooks
2. **SSOT = `kanban.json`** — единственный источник правды о прогрессе
3. **Resume по ID** — сессия сохраняется в `~/.codex/sessions/YYYY/MM/DD/`
4. **Hooks не работают с manual resume** — только через начальный `exec`

## Роль Orchestrator

Orchestrator НЕ пишет код. Orchestrator:
- Запускает `codex_wp` workers
- Читает `kanban.json` после остановки
- Решает: resume или следующий worker
- Повторяет до `done == total`
