# Resume Worker Prompt

Use this prompt when resuming an existing worker session.

---

```text
Continue implementing from where we left off.

## Current State (from kanban.json)

- Done: {DONE_COUNT} cards
- Total: {TOTAL_COUNT} cards
- In Progress: {IN_PROGRESS_COUNT} cards
- Ready: {READY_COUNT} cards
- Blocked: {BLOCKED_COUNT} cards

## Current Card

ID: {CURRENT_CARD_ID}
Title: {CURRENT_CARD_TITLE}
Stage: {CURRENT_STAGE}

## Instructions

1. Complete the current card from its current stage:
   - Current stage: {CURRENT_STAGE}
   - Continue through: simplify → commit → codex-review → done

2. After current card is done:
   - Check kanban.json for next ready card
   - Start next card immediately
   - Do NOT pause between cards

3. Continue until ALL cards reach 'done' status

## Stage Transitions

Use these commands:

```bash
# To simplify
PYTHONPATH=src python -m split_to_tasks_skill_cli implementation-stage \
  --package {PACKAGE} --card {CARD_ID} --to simplify

# To commit
PYTHONPATH=src python -m split_to_tasks_skill_cli implementation-stage \
  --package {PACKAGE} --card {CARD_ID} --to commit

# To codex-review
PYTHONPATH=src python -m split_to_tasks_skill_cli implementation-stage \
  --package {PACKAGE} --card {CARD_ID} --to codex-review

# To done
PYTHONPATH=src python -m split_to_tasks_skill_cli implementation-stage \
  --package {PACKAGE} --card {CARD_ID} --to done
```

## If Stuck

If current card is blocked:
1. Move card to 'blocked' with detailed note
2. Start next ready card
3. Do NOT stop the entire pipeline

## Goal

Complete ALL remaining cards without stopping.
```

## Template Variables

| Variable | Source |
|----------|--------|
| `{DONE_COUNT}` | `jq '.status_counts.done' kanban.json` |
| `{TOTAL_COUNT}` | `jq '.card_count' kanban.json` |
| `{IN_PROGRESS_COUNT}` | `jq '.status_counts.in_progress' kanban.json` |
| `{READY_COUNT}` | `jq '.status_counts.ready' kanban.json` |
| `{BLOCKED_COUNT}` | `jq '.status_counts.blocked' kanban.json` |
| `{CURRENT_CARD_ID}` | `jq -r '.cards[] \| select(.status == "in_progress") \| .id' kanban.json` |
| `{CURRENT_CARD_TITLE}` | `jq -r '.cards[] \| select(.status == "in_progress") \| .title' kanban.json` |
| `{CURRENT_STAGE}` | `jq -r '.cards[] \| select(.status == "in_progress") \| .status' kanban.json` |
| `{PACKAGE}` | Package path |
| `{CARD_ID}` | Current card ID |

## Usage

```bash
# Extract values from kanban
DONE=$(jq '.status_counts.done' kanban.json)
TOTAL=$(jq '.card_count' kanban.json)
CURRENT_ID=$(jq -r '.cards[] | select(.status == "in_progress") | .id' kanban.json)
# ... etc

# Build prompt
sed "s/{DONE_COUNT}/$DONE/g; s/{TOTAL_COUNT}/$TOTAL/g; ..." prompt-resume.md > /tmp/resume-prompt.txt

# Resume with prompt
codex_wp exec resume --json $SESSION_ID "$(cat /tmp/resume-prompt.txt)"
```
