#!/bin/bash
# ============================================================
# health-monitor.sh — Contabo cron every 5 min
#
# Logic:
#   healthy → silent exit, no messages
#   unhealthy → restart → report progress → fix → report result
#   critical → request AI help from RackNerd
# ============================================================

set -euo pipefail

# --- Config ---
DOMAIN="https://docutranslate.ru"
HEALTH_URL="${DOMAIN}/health"
STATE_FILE="/tmp/docutranslate-health.json"
ALERT_LOCK="/tmp/docutranslate-alert-lock"
MAX_ALERT_INTERVAL=900  # 15 min between repeat alerts

# SSH to RackNerd for t2me
RACKNERD_SSH="ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no pets@107.174.231.22"

# Docker
APP_CONTAINER="docutranslate_contabo-app-1"
NGINX_CONTAINER="docutranslate_contabo-nginx-1"
COMPOSE_DIR="/home/almaz/pets/docutranslate_contabo"

# --- Helpers ---
now_ts() { date +%s; }
now_iso() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
log() { echo "[$(now_iso)] $*"; }

send_alert() {
    local msg="$1"
    log "ALERT: $msg"
    $RACKNERD_SSH "t2me send --markdown '$msg'" 2>/dev/null || true
}

# Only send if enough time passed since last alert (avoid spam)
send_alert_throttled() {
    local msg="$1"
    if [ -f "$ALERT_LOCK" ]; then
        local lock_ts=$(cat "$ALERT_LOCK" 2>/dev/null || echo 0)
        local elapsed=$(( $(now_ts) - lock_ts ))
        if [ "$elapsed" -lt "$MAX_ALERT_INTERVAL" ]; then
            log "Throttled (${elapsed}s < ${MAX_ALERT_INTERVAL}s)"
            return
        fi
    fi
    send_alert "$msg"
    echo "$(now_ts)" > "$ALERT_LOCK"
}

update_state() {
    local status="$1"
    local detail="$2"
    cat > "$STATE_FILE" << EOF
{"status":"$status","detail":"$detail","ts":"$(now_iso)"}
EOF
}

# --- Health Check ---
check_health() {
    local http_code
    http_code=$(curl -sk -o /dev/null -w '%{http_code}' --max-time 10 "$HEALTH_URL" 2>/dev/null || echo "000")
    if [ "$http_code" = "200" ]; then
        echo "ok"
    else
        echo "fail:$http_code"
    fi
}

# --- System Warnings (silent unless threshold) ---
check_disk() {
    local pct
    pct=$(df / | awk 'NR==2{print $5}' | tr -d '%')
    if [ "$pct" -ge 95 ]; then
        send_alert_throttled "⚠️ Contabo disk ${pct}% full"
    fi
}

check_memory() {
    local pct
    pct=$(free | awk '/Mem:/{printf "%.0f", $3/$2*100}')
    if [ "$pct" -ge 90 ]; then
        send_alert_throttled "⚠️ Contabo memory ${pct}% used"
    fi
}

check_cert() {
    command -v openssl &>/dev/null || return
    local days_left
    days_left=$(echo | openssl s_client -connect localhost:443 -servername docutranslate.ru 2>/dev/null \
        | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2 \
        | xargs -I{} date -d "{}" +%s 2>/dev/null \
        | xargs -I{} echo $(( ({} - $(date +%s)) / 86400 )) 2>/dev/null || echo "999")
    if [ "$days_left" -lt 14 ] && [ "$days_left" -ge 0 ]; then
        send_alert_throttled "⚠️ SSL cert expires in ${days_left} days"
    fi
}

# ============================================================
# MAIN
# ============================================================

log "=== Monitor start ==="

# Background system checks (only alert on threshold)
check_disk
check_memory
check_cert

# Health check
result=$(check_health)
log "Health: $result"

# === HEALTHY → silent exit ===
if [ "$result" = "ok" ]; then
    update_state "healthy" "ok"
    log "✅ Healthy — silent exit"
    exit 0
fi

# === UNHEALTHY → fix with progress reports ===
log "❌ Unhealthy: $result"
update_state "unhealthy" "$result"

# Step 1: Alert + simple restart
send_alert "🔴 \`docutranslate.ru\` DOWN (${result})
🔧 Step 1/3: restarting containers..."

log "Step 1: restarting app + nginx..."
cd "$COMPOSE_DIR"
/usr/bin/docker restart "$APP_CONTAINER" "$NGINX_CONTAINER" 2>/dev/null || true
sleep 30

result2=$(check_health)
if [ "$result2" = "ok" ]; then
    update_state "recovered" "restart fixed it"
    send_alert "🟢 \`docutranslate.ru\` RECOVERED after container restart"
    log "✅ Recovered (step 1)"
    exit 0
fi

# Step 2: full compose up
send_alert "🔧 Step 2/3: simple restart failed (${result2})
Rebuilding with \`docker compose up\`..."

log "Step 2: docker compose up..."
/usr/bin/docker compose up -d --build 2>/dev/null || true
sleep 45

result3=$(check_health)
if [ "$result3" = "ok" ]; then
    update_state "recovered" "compose up fixed it"
    send_alert "🟢 \`docutranslate.ru\` RECOVERED after full compose rebuild"
    log "✅ Recovered (step 2)"
    exit 0
fi

# Step 3: collect diagnostics + request AI help
send_alert "🔴🔴 \`docutranslate.ru\` CRITICAL — all fixes failed
📋 Collecting diagnostics for AI agent..."

log "Step 3: collecting diagnostics..."
DIAG_FILE="/tmp/docutranslate-diag.txt"
{
    echo "=== DocuTranslate Diagnostics $(now_iso) ==="
    echo ""
    echo "--- Health check ---"
    curl -sk -w "\nHTTP: %{http_code}\n" "$HEALTH_URL" 2>/dev/null || echo "curl failed"
    echo ""
    echo "--- Docker ps ---"
    /usr/bin/docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null
    echo ""
    echo "--- App logs (last 50) ---"
    /usr/bin/docker logs --tail 50 "$APP_CONTAINER" 2>&1
    echo ""
    echo "--- Nginx logs (last 30) ---"
    /usr/bin/docker logs --tail 30 "$NGINX_CONTAINER" 2>&1
    echo ""
    echo "--- System ---"
    echo "Disk: $(df -h / | awk 'NR==2{print $5}')"
    echo "Memory: $(free -h | awk '/Mem:/{print $3"/"$2}')"
    echo "Swap: $(free -h | awk '/Swap:/{print $3"/"$2}')"
    echo "Uptime: $(uptime)"
    echo ""
    echo "--- State ---"
    cat "$STATE_FILE" 2>/dev/null || echo "no state file"
} > "$DIAG_FILE" 2>&1

# Send diagnostics to RackNerd for AI analysis
scp -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
    "$DIAG_FILE" pets@107.174.231.22:/tmp/docutranslate-diag.txt 2>/dev/null || true

send_alert "🔴🔴 \`docutranslate.ru\` CRITICAL
All 3 recovery steps failed. Diagnostics sent to RackNerd.
Requesting AI agent diagnosis..."

update_state "critical" "all recovery failed, AI help needed"
log "💀 Critical — AI help requested"
