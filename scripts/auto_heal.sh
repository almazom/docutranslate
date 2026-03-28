#!/usr/bin/env bash
# ── DocuTranslate AI Auto-Heal ──
# Diagnoses the problem via health + logs, then asks an AI agent to fix it.
# Uses glm_wp (primary) or codex_wp as fallback.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT_DIR/logs"
HEALTH_URL="https://127.0.0.1:18443/health"
DIAG_FILE="$LOG_DIR/diagnosis-$(date +%Y%m%d-%H%M%S).md"

mkdir -p "$LOG_DIR"

ts() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(ts)] $1"; }

# ── 1. Gather diagnostics ───────────────────────────
log "📊 Gathering diagnostics …"

HEALTH_JSON=$(curl -sk --max-time 10 "$HEALTH_URL" 2>/dev/null || echo '{"status":"unreachable"}')

COMPOSE_PS=$(cd "$ROOT_DIR" && docker compose ps 2>/dev/null || echo "compose ps failed")

APP_LOGS=$(cd "$ROOT_DIR" && docker compose logs app --tail=50 2>/dev/null || echo "no app logs")
NGINX_LOGS=$(cd "$ROOT_DIR" && docker compose logs nginx --tail=20 2>/dev/null || echo "no nginx logs")

DOCKER_DISK=$(df -h / | tail -1)
DOCKER_MEM=$(free -h | head -2)

PORT_CHECK=$(ss -tlnp | grep -E ':(18080|18443|8010)' || echo "no listeners found")

cat > "$DIAG_FILE" << DIAG
# DocuTranslate Auto-Heal Diagnosis
Generated: $(ts)

## Health Endpoint
\`\`\`json
$HEALTH_JSON
\`\`\`

## Container Status
\`\`\`
$COMPOSE_PS
\`\`\`

## Port Listeners
\`\`\`
$PORT_CHECK
\`\`\`

## App Logs (last 50 lines)
\`\`\`
$APP_LOGS
\`\`\`

## Nginx Logs (last 20 lines)
\`\`\`
$NGINX_LOGS
\`\`\`

## System Resources
Disk: $DOCKER_DISK
Memory:
$DOCKER_MEM
DIAG

log "📝 Diagnosis written to $DIAG_FILE"

# ── 2. Build the AI prompt ──────────────────────────
PROMPT="You are an expert DevOps AI. The DocuTranslate service at https://107.174.231.22:18443 is DOWN or unhealthy.

Your job: read the diagnosis file, identify the root cause, and produce a SINGLE bash script that fixes it.

Rules:
1. The project is at $ROOT_DIR
2. It runs via docker compose (docker compose up -d --build)
3. nginx handles HTTPS on port 18443, app runs on port 8010 internally
4. Read the diagnosis at $DIAG_FILE for logs and status
5. Output ONLY a fix script — no explanations, no markdown fences
6. The fix must be idempotent (safe to run multiple times)
7. After applying the fix, verify with: curl -sk https://127.0.0.1:18443/health
8. If the fix involves code changes, rebuild with: cd $ROOT_DIR && docker compose up -d --build

Common fixes to consider:
- Container crashed → restart or rebuild
- Port conflict → kill conflicting process
- SSL cert expired → regenerate self-signed cert
- Config error → fix .env or nginx config
- Disk full → clean docker / output
- App dependency error → rebuild container

Diagnosis file: $DIAG_FILE"

# ── 3. Run AI heal (glm_wp primary, codex_wp fallback) ─
log "🤖 Running AI auto-heal …"

HEAL_LOG="$LOG_DIR/ai-heal-$(date +%Y%m%d-%H%M%S).log"

# Try glm_wp first (fast, reliable)
if command -v glm_wp &>/dev/null; then
    log "  → Using glm_wp"
    if glm_wp -p "$PROMPT" -f "$DIAG_FILE" 2>&1 | tee "$HEAL_LOG"; then
        log "✅ glm_wp completed"
    else
        log "⚠️  glm_wp failed, trying codex_wp …"
        if command -v codex_wp &>/dev/null; then
            codex_wp -p "$PROMPT" -f "$DIAG_FILE" 2>&1 | tee -a "$HEAL_LOG" || true
        else
            log "❌ Neither glm_wp nor codex_wp available"
        fi
    fi
elif command -v codex_wp &>/dev/null; then
    log "  → Using codex_wp"
    codex_wp -p "$PROMPT" -f "$DIAG_FILE" 2>&1 | tee "$HEAL_LOG" || true
else
    log "❌ No AI agent available (need glm_wp or codex_wp)"
    exit 1
fi

# ── 4. Verify ────────────────────────────────────────
sleep 5
HTTP=$(curl -skf --max-time 10 -o /dev/null -w '%{http_code}' "$HEALTH_URL" 2>/dev/null || echo "000")
log "Post-heal health: HTTP $HTTP"

if [[ "$HTTP" == "200" ]]; then
    log "✅ Service restored!"
else
    log "⚠️  Service still unhealthy. Check $HEAL_LOG for AI output."
fi
