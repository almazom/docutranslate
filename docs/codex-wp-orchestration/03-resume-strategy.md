# Resume Strategy — Продолжение сессий

## Когда нужен resume

1. Worker остановился (hook-times исчерпан)
2. Worker упал по ошибке
3. Worker завис и был убит по timeout
4. Нужно дать новую инструкцию

## Получение session ID

### Из JSONL output

```bash
# При запуске worker
codex_wp exec --json "Task" 2>&1 | tee session.log

# Извлечь thread_id
grep '"type":"thread.started"' session.log | jq -r '.thread_id'
# → 019d3d19-20b1-7210-b95d-f71f10aaf9e1
```

### Из файловой системы

```bash
# Сессии сохраняются по дате
ls -lt ~/.codex/sessions/2026/03/30/ | head -5

# Имя файла содержит thread_id
# rollout-2026-03-30T07-55-50-019d3d19-20b1-7210-b95d-f71f10aaf9e1.jsonl
```

## Resume команды

```bash
# По ID — headless
codex_wp exec resume --json 019d3d19-20b1-7210-b95d-f71f10aaf9e1 "Continue with next card"

# Последняя сессия — headless
codex_wp exec resume --json --last "Continue"

# Интерактивный (нужен TTY)
codex_wp resume 019d3d19-20b1-7210-b95d-f71f10aaf9e1
```

## Стратегия Orchestrator

```python
# Псевдокод
def orchestrate(kanban_path, repo_root):
    while not all_cards_done(kanban_path):
        # Запуск worker
        session_id = run_worker(kanban_path, repo_root)

        # Проверка прогресса
        done_count = count_done_cards(kanban_path)

        if done_count == total_cards:
            break  # Готово!

        # Resume с инструкцией продолжать
        session_id = resume_worker(session_id, "Continue with next ready card")

    notify("All cards completed!")
```

## Resume с новым промптом

```bash
# Дать контекст — сколько осталось
codex_wp exec resume --json $SESSION_ID "
Cards remaining: 5 of 8.
Continue implementing from kanban.json.
Do not stop until all cards are done.
"
```

## Важно

- **Resume сохраняет контекст** — worker помнит всё из предыдущих turns
- **Новый prompt добавляется** — не заменяет, а расширяет
- **Kanban.json уже изменён** — worker увидит актуальное состояние
