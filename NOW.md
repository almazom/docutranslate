# NOW — Current Status (2026-03-28)

## Kanban Board: 6/7 done

| Card | Status | Title |
|------|--------|-------|
| 0001 | ✅ done | Docker Compose production setup |
| 0002 | ✅ done | Gunicorn production runner |
| 0003 | ✅ done | Nginx reverse proxy + HTTPS |
| 0004 | ✅ done | Centralized config + health endpoint |
| 0005 | ✅ done | Playwright BDD live verification |
| 0006 | ✅ done | Full deploy & BDD verification |
| 0007 | 🔜 ready | Update README with deploy instructions |

## Where We Stopped

**Card 0006 complete.** Stack is live on VPS, BDD 8/8 green, basic auth working.

**Next immediate step: Card 0007** — Update README with deploy instructions.
- Add Production Deployment section
- Prerequisites, quick deploy steps, config reference, BDD verification command

**Blocked / Waiting on user:**
1. **Domain purchase** — IP `107.174.231.22` blocked in RF. User plans to buy Russian domain + route via Cloudflare (free). Once domain is ready:
   - Update `.env` (`DOCUTRANSLATE_SSL_CN`, ports)
   - Run `scripts/setup_ssl.sh --domain <domain> --email <email>` for Let's Encrypt
   - Update nginx config for the domain
   - Test BDD against new domain
2. **API key for DeepSeek** — UI defaults point to DeepSeek but no `DOCUTRANSLATE_DEFAULT_API_KEY` in `.env` (users enter their own via UI)

## Session artifacts
- Kanban: `generated/deploy-docutranslate-as-a-public-website/trello-cards/kanban.json`
- Plan: `IMPLEMENTATION_PLAN.md`
- This file: `NOW.md`
