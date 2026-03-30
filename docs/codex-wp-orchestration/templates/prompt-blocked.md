# Blocked Card Prompt

Use this when a card is blocked and you need to decide what to do.

---

## Prompt for Orchestrator Decision

```text
A card is blocked. Analyze and decide.

## Blocked Card

ID: {CARD_ID}
Title: {CARD_TITLE}
Blocker: {BLOCKER_REASON}

## Options

1. **Try Alternative Approach**
   - Can the card be implemented differently?
   - Is there a simpler solution?
   - Can we skip a non-essential part?

2. **Mark as Blocked and Continue**
   - Move card to 'blocked' status
   - Add detailed blocker note to kanban.json
   - Continue to next ready card
   - User will handle later

3. **Request User Input**
   - Stop orchestrator
   - Notify user with blocker details
   - Wait for user decision

## Decision Criteria

- If blocker is technical (API down, dependency missing): Option 2
- If blocker is logical (requirements unclear): Option 3
- If blocker can be worked around: Option 1

## Your Task

Analyze the blocker and choose the best option.
Then either:
- Fix and continue (Option 1)
- Mark blocked and continue (Option 2)
- Stop and notify user (Option 3)

Do NOT leave the card in limbo.
```

---

## Command to Mark Blocked

```bash
PYTHONPATH=src python -m split_to_tasks_skill_cli implementation-stage \
  --package {PACKAGE} \
  --card {CARD_ID} \
  --to blocked \
  --note "{BLOCKER_REASON}"
```

---

## Notification Template

```text
⛔ DocuTranslate: Card {CARD_ID} blocked

Title: {CARD_TITLE}
Reason: {BLOCKER_REASON}

Options:
1. Try alternative approach
2. Skip for now (mark blocked)
3. Stop and wait for user

Current decision: {DECISION}
```

---

## Blocked Card Detection

```bash
# Check for blocked cards
BLOCKED=$(jq '.status_counts.blocked' kanban.json)

if [ "$BLOCKED" -gt 0 ]; then
    # Get blocker details
    jq '.cards[] | select(.status == "blocked") | {id, title, blocker: .transition_history[-1].note}' kanban.json

    # Notify user
    t2me "⛔ Blocked cards detected. Check kanban.json"

    # Exit with special code
    exit 2
fi
```

---

## Resume After Blocker Resolved

```text
Blocker resolved for card {CARD_ID}.

Resume implementation:
1. Move card from 'blocked' to 'ready'
2. Start card from beginning
3. Apply the fix/solution
4. Continue through full lifecycle

Command to unblock:
```bash
PYTHONPATH=src python -m split_to_tasks_skill_cli implementation-stage \
  --package {PACKAGE} \
  --card {CARD_ID} \
  --to ready \
  --note "Blocker resolved: {RESOLUTION}"
```
```
