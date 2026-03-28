# Implementation Plan: Deploy DocuTranslate as a Public Website

## Summary
Take the existing FastAPI web app (already has Web UI, REST API, Dockerfile) and make it accessible via a public HTTPS URL. A user opens `https://translate.example.com` in any browser and can immediately translate documents.

## Objective
- Public HTTPS URL with reverse proxy (Nginx + Let's Encrypt)
- Docker-based production deployment (Gunicorn + Uvicorn)
- Centralized config via environment variables
- Health endpoint for monitoring
- Playwright BDD live verification before user handoff

## Scope
- **In scope**: Docker compose, Gunicorn runner, Nginx reverse proxy with HTTPS, config management, health endpoint, Playwright BDD tests
- **Out of scope**: Auth system (defer — use VPN/basic auth if needed), Redis persistence (defer — in-memory is fine for now), rate limiting (defer), Prometheus metrics (defer), frontend redesign, CI/CD pipeline

---

## Phase 1: Docker Compose Production Setup (SP: 2, ~2h)

**Goal**: Production-ready Dockerfile + docker-compose that starts the app behind Nginx.

**Files to create/modify**:
- `Dockerfile` — update existing for production multi-stage build
- `docker-compose.yml` — new, app + nginx services
- `.dockerignore` — new, exclude `.git`, `tests`, `images`, `*.spec`, `generated/`

**Work**:
1. Update `Dockerfile`:
   - Stage 1: install deps via `uv`
   - Stage 2: slim runtime image with non-root user, expose 8010
2. Create `docker-compose.yml`:
   - `app` service: build from Dockerfile, env_file `.env`
   - `nginx` service: image `nginx:alpine`, ports 80/443, volumes for config + certs
3. Create `.dockerignore`

**Acceptance**:
- `docker compose build` succeeds
- `docker compose up` starts app + nginx
- App responds on port 8010 internally

---

## Phase 2: Gunicorn Production Runner (SP: 1, ~1h)

**Goal**: Replace bare uvicorn with Gunicorn + Uvicorn workers for production stability.

**Files to create/modify**:
- `pyproject.toml` — add `gunicorn>=22.0.0` dependency
- `gunicorn.conf.py` — new, production settings
- `scripts/start_production.sh` — new, entry point

**Work**:
1. Add `gunicorn>=22.0.0` to `pyproject.toml` dependencies
2. Create `gunicorn.conf.py`:
   - `workers = 1` (stateful tasks; scale via containers not workers)
   - `worker_class = "uvicorn.workers.UvicornWorker"`
   - `bind = "0.0.0.0:8010"`
   - `timeout = 300` (long translation tasks)
3. Ensure `from docutranslate.app import app` works without starting uvicorn
4. Create `scripts/start_production.sh`: `exec gunicorn -c gunicorn.conf.py docutranslate.app:app`
5. Update Dockerfile CMD to use `scripts/start_production.sh`

**Acceptance**:
- `gunicorn -c gunicorn.conf.py docutranslate.app:app` starts and serves requests
- Existing `docutranslate -i` local mode still works unchanged

---

## Phase 3: Nginx Reverse Proxy + HTTPS (SP: 2, ~2h)

**Goal**: Nginx terminates TLS, proxies to app. Auto-cert via Let's Encrypt.

**Files to create/modify**:
- `nginx/nginx.conf` — new, main config
- `nginx/conf.d/docutranslate.conf` — new, site config with proxy + SSL
- `scripts/setup_ssl.sh` — new, certbot automation
- `docker-compose.yml` — update nginx service with cert volumes

**Work**:
1. Create Nginx config:
   - HTTP → HTTPS redirect
   - HTTPS proxy to `app:8010`
   - `client_max_body_size 100M`
   - SSE support: `proxy_buffering off`, `proxy_read_timeout 300s`
   - Proper `X-Forwarded-*` headers
2. Update `docker-compose.yml`:
   - Nginx volumes: `./nginx/conf.d`, certbot certs
   - Optional certbot service for renewal
3. Create `scripts/setup_ssl.sh`:
   - Args: `--domain`, `--email`
   - Run certbot standalone, copy certs to volume
4. Fallback: self-signed cert for dev/testing without a domain

**Acceptance**:
- HTTP redirects to HTTPS
- `https://<domain>/` loads Web UI
- `https://<domain>/docs` loads Swagger
- SSE log streaming works through proxy
- Self-signed cert works for local testing

---

## Phase 4: Centralized Config + Health Endpoint (SP: 1, ~1h)

**Goal**: All settings from env vars. One health endpoint for monitoring.

**Files to create/modify**:
- `docutranslate/config.py` — new, Pydantic Settings
- `docutranslate/app.py` — add `GET /health`
- `.env.example` — new, all variables documented
- `docker-compose.yml` — add `env_file: .env`
- `.gitignore` — add `data/`, `.env`

**Work**:
1. Create `docutranslate/config.py`:
   ```python
   class Settings(BaseSettings):
       host: str = "0.0.0.0"
       port: int = 8010
       debug: bool = False
       default_base_url: str = ""
       default_api_key: str = ""
       default_model_id: str = ""
       model_config = SettingsConfigDict(env_prefix="DOCUTRANSLATE_")
   ```
2. Add `GET /health` to `app.py`: returns `{"status": "ok", "version": "..."}`, no auth
3. Create `.env.example` with every option documented
4. Update `docker-compose.yml` to use `env_file: .env`
5. Add Docker healthcheck in compose: `curl -f http://localhost:8010/health`

**Acceptance**:
- All config via `DOCUTRANSLATE_*` env vars
- `/health` returns 200 without auth
- `.env.example` documents every option
- Docker healthcheck reports container status

---

## Phase 5: Playwright BDD Live Verification (SP: 3, ~3h)

**Goal**: Before user handoff, run Playwright BDD scenarios in a real headless Chromium browser that verify the site works end-to-end. Uses Gherkin `.feature` files + step definitions + screenshots.

**Files to create**:
- `playwright.config.ts` — Playwright config, base URL from env, headless Chromium
- `tests/e2e/features/landing.feature` — Gherkin: open URL, see UI
- `tests/e2e/features/translate.feature` — Gherkin: upload file, translate, download
- `tests/e2e/features/health.feature` — Gherkin: health endpoint responds
- `tests/e2e/steps/landing_steps.ts` — step definitions for landing page
- `tests/e2e/steps/translate_steps.ts` — step definitions for translate flow
- `tests/e2e/steps/health_steps.ts` — step definitions for health checks
- `package.json` — new, minimal: `@playwright/test`, `playwright-bdd`
- `scripts/e2e_verify.sh` — single command to run all BDD scenarios

**Work**:
1. Create minimal `package.json` with deps:
   ```json
   {
     "devDependencies": {
       "@playwright/test": "^1.58.0",
       "playwright-bdd": "^1.0.0"
     }
   }
   ```
2. Run `npm install && npx playwright install chromium`
3. Create `playwright.config.ts`:
   ```typescript
   import { defineConfig } from '@playwright/test';
   export default defineConfig({
     testDir: './tests/e2e/steps',
     baseURL: process.env.E2E_BASE_URL || 'http://localhost:8010',
     use: { headless: true, screenshot: 'only-on-failure', trace: 'on-first-retry' },
     timeout: 120000,
   });
   ```
4. Create `tests/e2e/features/landing.feature`:
   ```gherkin
   Feature: Public Landing Page
     As a visitor
     I want to open the DocuTranslate URL
     So that I can see the translation interface

     Scenario: Landing page loads successfully
       Given I open the DocuTranslate URL
       Then the page title contains "DocuTranslate"
       And the file upload area is visible
       And the language selector is visible

     Scenario: API docs are accessible
       Given I open the DocuTranslate URL
       When I navigate to "/docs"
       Then the Swagger UI page loads
   ```
5. Create `tests/e2e/features/health.feature`:
   ```gherkin
   Feature: Health Endpoint
     As an operator
     I want the health endpoint to respond
     So that I know the service is alive

     Scenario: Health check returns OK
       Given I send a GET request to "/health"
       Then the response status is 200
       And the response contains "status" with value "ok"
   ```
6. Create `tests/e2e/features/translate.feature`:
   ```gherkin
   Feature: Document Translation
     As a user
     I want to upload a document and get it translated
     So that I can read it in my language

     Scenario: Translate a plain text file
       Given I open the DocuTranslate URL
       And the translation form is ready
       When I upload the file "test_sample.txt"
       And I select target language "Chinese"
       And I submit the translation
       Then the task starts processing
       And the task completes within 120 seconds
       And a download link appears
       And the downloaded file contains translated text

     Scenario: File upload rejects unsupported format
       Given I open the DocuTranslate URL
       When I upload the file "test_malicious.exe"
       Then an error message is displayed
   ```
7. Create step definitions in `tests/e2e/steps/`:
   - `landing_steps.ts` — navigate, assert title, assert UI elements visible, screenshot
   - `health_steps.ts` — HTTP GET, assert status + JSON body
   - `translate_steps.ts` — upload file, set language, submit, poll task status, download, verify content, screenshots at each step
8. Create test fixtures: `tests/e2e/fixtures/test_sample.txt` with sample English text
9. Create `scripts/e2e_verify.sh`:
   ```bash
   #!/bin/bash
   set -e
   echo "Running Playwright BDD verification..."
   export E2E_BASE_URL="${E2E_BASE_URL:-http://localhost:8010}"
   npx bddgen tests/e2e/features -o tests/e2e/steps/generated
   npx playwright test tests/e2e/steps/generated --reporter=html
   echo "All BDD scenarios passed."
   ```
10. Add `screenshots/`, `test-results/`, `playwright-report/` to `.gitignore`

**Acceptance**:
- `bash scripts/e2e_verify.sh` runs headless Chromium against live URL
- All 3 `.feature` files pass: landing, health, translate
- Screenshots captured on failure
- If any scenario fails → deploy is NOT handed to user; fix and re-run
- BDD scenarios serve as living documentation of expected behavior

---

## Phase 6: Full Deploy & BDD Verification (SP: 2, ~2h)

**Goal**: Deploy to VPS, run BDD suite, hand off working URL to user.

**Work**:
1. Provision VPS (or use existing server)
2. Clone repo, `cp .env.example .env`, fill in values:
   - `DOCUTRANSLATE_BASE_URL`, `DOCUTRANSLATE_API_KEY`, `DOCUTRANSLATE_MODEL_ID`
   - `DOCUTRANSLATE_DOMAIN`, `DOCUTRANSLATE_SSL_EMAIL`
3. `docker compose build && docker compose up -d`
4. Run `bash scripts/setup_ssl.sh --domain <domain> --email <email>`
5. Run `bash scripts/e2e_verify.sh` against `https://<domain>`
6. If all BDD scenarios pass → hand off URL to user
7. If any fail → fix, redeploy, re-run

**Acceptance**:
- `https://<domain>/` loads in external browser
- `bash scripts/e2e_verify.sh` passes all scenarios against production URL
- Screenshots saved as proof
- User receives working URL

---

## Phase 7: Update README with Deploy Instructions (SP: 1, ~0.5h)

**Goal**: Document the deploy process so anyone can reproduce it.

**Files to modify**:
- `README.md` — add "Production Deployment" section

**Work**:
1. Add section to README:
   - Prerequisites: VPS with Docker, domain name
   - Quick deploy: clone → `.env` → `docker compose up` → SSL → done
   - Configuration reference (link to `.env.example`)
   - BDD verification: `bash scripts/e2e_verify.sh`

**Acceptance**:
- README has clear deploy instructions
- A new developer can follow the steps and deploy

---

## Environment Variables Summary

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DOCUTRANSLATE_HOST` | No | `0.0.0.0` | Listen address |
| `DOCUTRANSLATE_PORT` | No | `8010` | Listen port |
| `DOCUTRANSLATE_DEBUG` | No | `false` | Debug mode |
| `DOCUTRANSLATE_BASE_URL` | **Yes** | — | LLM API base URL |
| `DOCUTRANSLATE_API_KEY` | **Yes** | — | LLM API key |
| `DOCUTRANSLATE_MODEL_ID` | **Yes** | — | LLM model ID |
| `DOCUTRANSLATE_TO_LANG` | No | `中文` | Default target language |
| `DOCUTRANSLATE_DOMAIN` | **Yes** | — | Public domain for SSL |
| `DOCUTRANSLATE_SSL_EMAIL` | **Yes** | — | Email for Let's Encrypt |
| `E2E_BASE_URL` | No | `http://localhost:8010` | URL for BDD tests |

---

## Acceptance Criteria

| ID | Criterion | Card |
|----|-----------|------|
| AC-001 | `docker compose build && docker compose up` starts app + nginx without errors | Card 1 |
| AC-002 | `gunicorn -c gunicorn.conf.py docutranslate.app:app` starts and serves requests; `docutranslate -i` still works locally | Card 2 |
| AC-003 | `https://<domain>/` loads Web UI with valid TLS; HTTP redirects to HTTPS; SSE works | Card 3 |
| AC-004 | `/health` returns 200; all config via env vars; `.env.example` documents every option | Card 4 |
| AC-005 | `bash scripts/e2e_verify.sh` passes all Playwright BDD scenarios (landing, health, translate) with headless Chromium | Card 5 |
| AC-006 | Full deploy to VPS passes BDD suite against production URL; user receives working HTTPS link | Card 6 |
| AC-007 | README has reproducible deploy instructions | Card 7 |

## Done Criteria

- [ ] All acceptance criteria AC-001 through AC-007 pass
- [ ] `bash scripts/e2e_verify.sh` completes green with screenshots
- [ ] External browser can open `https://<domain>/` and translate a document
- [ ] No secrets committed to repository

## Deferred (not deleted)

| Feature | When to add | Estimated cards |
|---------|-------------|----------------|
| User authentication (JWT) | When you need multi-user | ~8 cards |
| Redis task persistence | When restarts matter | ~6 cards |
| Rate limiting | When abuse happens | ~4 cards |
| Prometheus metrics | When you need dashboards | ~3 cards |

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| No auth = anyone can use API key | Use VPN or HTTP basic auth in Nginx as interim fix; add JWT auth later |
| In-memory state lost on restart | Accept for MVP; add Redis when it matters |
| LLM API cost from open access | Nginx IP whitelist or basic auth as interim; add rate limiting later |
