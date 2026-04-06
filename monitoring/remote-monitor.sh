#!/bin/bash
# ============================================================
# remote-monitor.sh — RackNerd cron every 10 min
#
# 1. Remote health check (from outside Contabo)
# 2. If DOWN + Contabo state=critical → AI diagnosis + fix
# 3. Reports progress via t2me
# ============================================================

# No set -e — we handle errors explicitly to avoid curl/ssh exit codes killing the script

# --- Config ---
DOMAIN="https://docutranslate.ru"
HEALTH_URL="${DOMAIN}/health"
CONTABO_SSH="ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -i /home/pets/.ssh/docutranslate_ru_proxy almaz@212.28.182.235"
STATE_FILE="/tmp/docutranslate-remote-state.json"
COMPOSE_DIR="/home/almaz/pets/docutranslate_contabo"

# --- Helpers ---
now_ts() { date +%s; }
now_iso() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
log() { echo "[$(now_iso)] $*"; }

notify() {
    local msg="$1"
    log "NOTIFY: $msg"
    t2me send --markdown "$msg" 2>/dev/null || true
}

update_state() {
    cat > "$STATE_FILE" << EOF
{"status":"$1","detail":"$2","ts":"$(now_iso)"}
EOF
}

check_health_remote() {
    local http_code
    http_code=$(curl -sk -o /dev/null -w '%{http_code}' --max-time 15 "$HEALTH_URL" 2>/dev/null)
    http_code=$(echo "$http_code" | grep -oE '^[0-9]+$' | head -1)
    http_code=${http_code:-000}
    if [ "$http_code" = "200" ]; then echo "ok"
    else echo "fail:$http_code"
    fi
}

get_contabo_state() {
    $CONTABO_SSH "cat /tmp/docutranslate-health.json 2>/dev/null || echo '{\"status\":\"unknown\"}'" 2>/dev/null \
        | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4
}

# ============================================================
# MAIN
# ============================================================

log "=== Remote monitor start ==="

# 1. Remote health check
result=$(check_health_remote)
log "Remote health: $result"

if [ "$result" = "ok" ]; then
    update_state "healthy" "remote check ok"
    log "✅ Healthy — silent exit"
    exit 0
fi

# === UNHEALTHY from outside ===
log "❌ Remote check failed: $result"
update_state "unhealthy" "$result"

# 2. Check Contabo state
contabo_state=$(get_contabo_state)
log "Contabo state: $contabo_state"

# If Contabo says healthy/recovered — check if state is fresh (< 30 min)
# Stale state (> 30 min) means Contabo monitor hasn't run since recovery → treat as unknown
is_stale=false
contabo_ts=$($CONTABO_SSH "cat /tmp/docutranslate-health.json 2>/dev/null" 2>/dev/null \
    | grep -o '"ts":"[^"]*"' | head -1 | cut -d'"' -f4)
if [ -n "$contabo_ts" ]; then
    state_epoch=$(date -d "$(echo $contabo_ts | sed 's/T/ /;s/Z//')" +%s 2>/dev/null || echo 0)
    state_age=$(( $(now_ts) - state_epoch ))
    if [ "$state_age" -gt 1800 ]; then
        log "Contabo state is stale (${state_age}s old) — treating as unknown"
        contabo_state="unknown"
    fi
fi

if [ "$contabo_state" = "healthy" ] || [ "$contabo_state" = "recovered" ]; then
    notify "🟡 \`docutranslate.ru\` unreachable remotely but Contabo says healthy
Possible DNS/network issue. Skipping auto-fix."
    exit 0
fi

# 3. Contabo is critical or unknown → AI diagnosis
notify "🤖 RackNerd observer: \`docutranslate.ru\` down ($result)
Contabo state: ${contabo_state:-unknown}
Starting AI diagnosis..."

# 4. Collect fresh diagnostics
DIAG_FILE="/tmp/docutranslate-remote-diag.txt"
{
    echo "=== Remote Diagnostics $(now_iso) ==="
    echo ""
    echo "--- Remote curl ---"
    curl -skv "$HEALTH_URL" 2>&1 | tail -20
    echo ""
    echo "--- DNS ---"
    dig docutranslate.ru +short 2>/dev/null || nslookup docutranslate.ru 2>/dev/null
    echo ""
    echo "--- Contabo Docker ---"
    $CONTABO_SSH "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'" 2>/dev/null || echo "SSH failed"
    echo ""
    echo "--- Contabo App Logs ---"
    $CONTABO_SSH "docker logs --tail 30 docutranslate_contabo-app-1" 2>/dev/null || echo "SSH logs failed"
    echo ""
    echo "--- Contabo Nginx Logs ---"
    $CONTABO_SSH "docker logs --tail 20 docutranslate_contabo-nginx-1" 2>/dev/null || echo "SSH logs failed"
    echo ""
    echo "--- Contabo System ---"
    $CONTABO_SSH "echo Disk: \$(df -h / | awk 'NR==2{print \$5}') Mem: \$(free -h | awk '/Mem:/{print \$3\"/\"\$2}') Uptime: \$(uptime -p)" 2>/dev/null || echo "SSH system failed"
} > "$DIAG_FILE" 2>&1

# 5. Send diagnostics to user
notify "📋 Diagnostics collected. Sending to user for AI analysis."
t2me send --markdown --caption "📋 DocuTranslate diagnostics" --file "$DIAG_FILE" 2>/dev/null || true

# 6. Attempt SSH remote heal (docker compose restart)
notify "🔧 Attempting remote heal via SSH..."

$CONTABO_SSH "cd /home/almaz/pets/docutranslate_contabo && docker compose down && docker compose up -d --build" 2>/dev/null
sleep 40

# 7. Check if healed
result_final=$(check_health_remote)
if [ "$result_final" = "ok" ]; then
    notify "🟢 \`docutranslate.ru\` RECOVERED by remote heal!
All systems operational."
    update_state "recovered" "remote heal worked"
    log "✅ Recovered via remote heal"
    exit 0
fi

# 8. Still dead — trigger AI agent
notify "🔴🔴 \`docutranslate.ru\` still down after all attempts.
Triggering AI agent (\`codex_wp\`) for deep diagnosis..."

# Write a trigger file that the AI watcher can pick up
cat > /tmp/docutranslate-ai-trigger.json << EOF
{
    "event": "critical_failure",
    "domain": "$DOMAIN",
    "remote_result": "$result_final",
    "contabo_state": "${contabo_state:-unknown}",
    "diag_file": "$DIAG_FILE",
    "timestamp": "$(now_iso)"
}
EOF

log "AI trigger written to /tmp/docutranslate-ai-trigger.json"
log "Run: codex_wp or pi to diagnose using $DIAG_FILE"
