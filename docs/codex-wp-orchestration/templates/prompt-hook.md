# Hook Prompt

Use this as `--hook-prompt` for automatic continuation.

---

## Standard Hook Prompt

```text
Continue implementing next Trello card. Do not stop. Check kanban.json for remaining cards. Treat kanban.json as the only writable execution SSOT.
```

---

## Extended Hook Prompt (with error handling)

```text
Continue implementing. Do not stop.

## Check Progress

1. Read kanban.json to see current state
2. Identify: done count, in_progress cards, ready cards
3. Continue from current card or start next ready card

## If codex-review is Stuck

If review takes more than 3 minutes:
1. Kill the review process
2. Try: codex-review --backend kimi_wp --timeout 180
3. If still failing, mark card as 'needs manual review'
4. Move to next ready card immediately

## Do NOT

- Do NOT stop between cards
- Do NOT wait for user confirmation
- Do NOT edit files outside the card scope

## DO

- DO check kanban.json after each card
- DO continue to next ready card automatically
- DO treat kanban.json as the only SSOT
```

---

## Minimal Hook Prompt

```text
Continue. Check kanban.json. Next card. Do not stop.
```

---

## Usage

```bash
# Standard
codex_wp --hook stop --hook-times 10 \
  --hook-prompt "Continue implementing next Trello card. Do not stop. Check kanban.json for remaining cards." \
  exec --json "Initial prompt..."

# Extended
codex_wp --hook stop --hook-times 10 \
  --hook-prompt "$(cat prompt-hook.md)" \
  exec --json "Initial prompt..."
```

## Recommendations

| Hook Times | Cards Expected | Use Case |
|------------|----------------|----------|
| 3 | 1 card | Single card |
| 5 | 2 cards | Small batches |
| 10 | 4-5 cards | Medium batches |
| 20 | 8-10 cards | Large batches |

**Rule of thumb:** ~2-3 turns per card (implement + commit + review)
