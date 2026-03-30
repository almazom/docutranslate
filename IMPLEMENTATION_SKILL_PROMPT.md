# Implementation Skill Prompt

Use this exact prompt for another agent:

```text
Use skill `implementation-skill` on folder:

`/home/pets/zoo/docutranslate/generated/ru-entry-for-docutranslate`

Repo root:

`/home/pets/zoo/docutranslate`

Work in autonomous non-stop mode.

Rules:
- Implement Trello cards one by one in order.
- Do not stop between cards.
- Do not pause for confirmation.
- Continue until all actionable Trello cards are implemented and moved through the full lifecycle.
- Only stop if there is a real blocker that prevents further progress.
- If blocked, move the current card to `blocked` with a real note and evidence.
- Treat `kanban.json` as the only writable execution SSOT.
- Do not edit `state.json`, `progress.md`, or `BOARD.md` manually.
- Always use runtime commands like `implementation-start`, `implementation-stage`, and `implementation-status`.
- For each card, follow the full workflow:
  1. start the card
  2. implement it
  3. run verification
  4. move to `simplify`
  5. run simplification
  6. move to `commit`
  7. create commit
  8. move to `codex-review`
  9. run review
  10. move to `done`
- After a card is `done`, immediately continue to the next ready card.
- Keep going until no actionable cards remain.

Important product goal:
- keep only one public domain: `docutranslate.ru`
- do not introduce a user-facing `ru.` subdomain
- route Russian users through `212.28.182.235`
- keep the current working origin `107.174.231.22:2053`

Read first:
- `/home/pets/zoo/docutranslate/generated/ru-entry-for-docutranslate/AGENTS.md`
- `/home/pets/zoo/docutranslate/generated/ru-entry-for-docutranslate/trello-cards/KICKOFF.md`
- `/home/pets/zoo/docutranslate/generated/ru-entry-for-docutranslate/trello-cards/BOARD.md`
- `/home/pets/zoo/docutranslate/generated/ru-entry-for-docutranslate/trello-cards/kanban.json`

Start with:
`cd /home/pets/TOOLS/split_to_tasks_skill_cli && PYTHONPATH=src python -m split_to_tasks_skill_cli implementation-start --package /home/pets/zoo/docutranslate/generated/ru-entry-for-docutranslate --repo-root /home/pets/zoo/docutranslate`

When you report progress:
- show current card id and title
- show files touched
- show verification run
- show stage transitions
- keep going automatically unless a real blocker appears
```
