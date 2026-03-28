#!/usr/bin/env bash
# ── DocuTranslate watchdog ──
# Runs every 15 min via cron.
# Checks health → tries self-repair → escalates to AI heal if needed.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT_DIR/logs"
HEAL_SCRIPT="$ROOT_DIR/scripts/auto_heal.sh"
LOG="$LOG_DIR/watchdog.log"
HEALTH_URL="https://127.0.0.1:18443/health"
MAX_REPAIR_ATTEMPTS=2

mkdir -p "$LOG_DIR"

ts() { date '+%Y-%m-%d %H:%M:%S'; }

log()  { echo "[$(ts)] $1" | tee -a "$LOG"; }
warn() { echo "[$(ts)] ⚠️  $1" | tee -a "$LOG"; }
fail() { echo "[$(ts)] ❌ $1" | tee -a "$LOG"; }

# ── install / remove cron ───────────────────────────
if [[ "${1:-}" == "--install" ]]; then
    CRON_LINE="*/15 * * * * cd $ROOT_DIR && /bin/bash $ROOT_DIR/scripts/watchdog.sh >> $ROOT_DIR/logs/watchdog.log 2>&1"
    # Remove old entry if exists, then add
    (crontab -l 2>/dev/null | grep -v "docutranslate.*watchdog"; echo "$CRON_LINE") | crontab -
    echo "✅ Watchdog cron installed (every 15 min)"
    exit 0
fi

if [[ "${1:-}" == "--remove" ]]; then
    crontab -l 2>/dev/null | grep -v "docutranslate.*watchdog" | crontab -
    echo "✅ Watchdog cron removed"
    exit 0
fi

# ── health check ────────────────────────────────────
log "── Watchdog tick ──"

check_health() {
    local code
    code=$(curl -skf --max-time 10 -o /dev/null -w '%{http_code}' "$HEALTH_URL" 2>/dev/null) && true
    echo "${code:-000}"
}

HTTP=$(check_health)

if [[ "$HTTP" == "200" ]]; then
    # Healthy — but also verify containers aren't restarting
    RESTARTING=$(cd "$ROOT_DIR" && docker compose ps --format '{{.Status}}' 2>/dev/null | grep -ci "restarting" || true)
    if [[ "$RESTARTING" -eq 0 ]]; then
        log "✅ Healthy (HTTP $HTTP)"
        exit 0
    else
        warn "Containers restarting ($RESTARTING)"
    fi
fi

# ── unhealthy — attempt repair ──────────────────────
warn "Health check failed (HTTP $HTTP). Starting repair …"

ATTEMPT=0
while [[ $ATTEMPT -lt $MAX_REPAIR_ATTEMPTS ]]; do
    ATTEMPT=$((ATTEMPT + 1))
    log "🔧 Repair attempt $ATTEMPT/$MAX_REPAIR_ATTEMPTS"

    case $ATTEMPT in
        1)
            # Quick fix: just restart
            log "  → docker compose restart"
            cd "$ROOT_DIR" && docker compose restart 2>&1 | tail -3 | while read -r line; do log "  $line"; done
            sleep 10
            ;;
        2)
            # Harder fix: rebuild
            log "  → docker compose up -d --build --force-recreate"
            cd "$ROOT_DIR" && docker compose up -d --build --force-recreate 2>&1 | tail -5 | while read -r line; do log "  $line"; done
            sleep 15
            ;;
    esac

    HTTP=$(check_health)
    if [[ "$HTTP" == "200" ]]; then
        log "✅ Repaired on attempt $ATTEMPT (HTTP $HTTP)"
        exit 0
    fi
    warn "  Still unhealthy after attempt $ATTEMPT (HTTP $HTTP)"
done

# ── repair failed — escalate to AI heal ─────────────
fail "Auto-repair failed after $MAX_REPAIR_ATTEMPTS attempts. Escalating to AI auto-heal …"
bash "$HEAL_SCRIPT" 2>&1 | while IFS= read -r line; do log "  AI: $line"; done

HTTP=$(check_health)
if [[ "$HTTP" == "200" ]]; then
    log "✅ AI heal successful (HTTP $HTTP)"
else
    fail "AI heal did not restore service (HTTP $HTTP). Manual intervention required."
fi
