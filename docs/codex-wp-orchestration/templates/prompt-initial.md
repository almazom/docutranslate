# Initial Worker Prompt

Use this prompt when starting a new worker session.

---

```text
Read {PACKAGE}/AGENTS.md and implement card 0001.

## Start Command

cd /home/pets/TOOLS/split_to_tasks_skill_cli && \
PYTHONPATH=src python -m split_to_tasks_skill_cli implementation-start \
  --package {PACKAGE} \
  --repo-root {REPO_ROOT}

## Card Lifecycle

Implement the full lifecycle for each card:

1. **implement** - Write code, create files
2. **simplify** - Run code-simplifier on touched files
3. **commit** - Create task-scoped git commit
4. **codex-review** - Run review on the commit
   - If timeout: use `--backend kimi_wp --timeout 180`
   - If still stuck: mark as 'needs manual review' and continue
5. **done** - Move card to done state

## After Card Completion

- Check kanban.json for next ready card
- Start next card immediately
- Do NOT stop between cards

## Important Rules

- Treat kanban.json as the ONLY writable execution SSOT
- Do NOT edit state.json or progress.md manually
- Use implementation-stage commands for transitions
- After each card, check for newly unblocked dependencies
- Continue until ALL cards are done

## Error Handling

If codex-review times out:
```
/home/pets/TOOLS/codex-review-skill_cli/codex-review \
  --target {REPO_ROOT} \
  --commit <sha> \
  --backend kimi_wp \
  --timeout 180
```

If still failing after 3 minutes:
- Move card to 'codex-review' stage with note "needs manual review"
- Continue to next ready card
- Do NOT block the entire pipeline

## Goal

Complete ALL cards in the package without stopping.
```

## Template Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `{PACKAGE}` | Path to Trello package | `/home/pets/zoo/docutranslate/generated/ru-entry-for-docutranslate` |
| `{REPO_ROOT}` | Path to git repository | `/home/pets/zoo/docutranslate` |

## Usage

```bash
# Replace variables
sed "s|{PACKAGE}|$PACKAGE|g; s|{REPO_ROOT}|$REPO_ROOT|g" prompt-initial.md > /tmp/prompt.txt

# Use in codex_wp command
codex_wp --hook stop --hook-times 10 \
  --hook-prompt "$(cat prompt-hook.md)" \
  exec --json "$(cat /tmp/prompt.txt)"
```
