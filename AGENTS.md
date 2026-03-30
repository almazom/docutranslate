# AGENTS.md — DocuTranslate

## Quick Start
- Read `.MEMORY.md` — project overview, deployment, credentials
- Read `.MEMORY/` folder — task-specific memory cards (Momento-style short notes)
- When continuing multi-session work: read ALL cards in `.MEMORY/` to restore context

## .MEMORY Convention
- `.MEMORY.md` — master context (always up to date)
- `.MEMORY/<topic>/` — numbered cards per topic:
  - `00_STATUS.md` — current state, what's pending
  - `01_WHAT_WE_DID.md` — checklist of completed steps
  - `02_HOW_IT_WORKS.md` — technical flow diagram
  - `03_SERVER_MAP.md` — infrastructure details
  - `04_TODO.md` — next steps
  - `05_CREDENTIALS.md` — access info
- Cards are short, scannable, written in mixed Russian/English
- Update cards after each session that changes state

## Project Rules
- Server: `107.174.231.22`, user `pets`, no sudo without password
- Ports 80/443 occupied by Caddy — don't touch
- DocuTranslate runs in Docker: app (8010) + nginx (18080/2053)
- Basic auth on all routes except `/health`
- E2E tests via Playwright BDD
