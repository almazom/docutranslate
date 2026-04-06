#!/bin/bash
# ============================================================
# e2e-daily-check.sh — Daily Playwright BDD full auth cycle
# Runs on RackNerd, tests against Contabo (production)
# Can also test RackNerd fallback
#
# Schedule: once per day via cron (e.g. 08:00 MSK = 05:00 UTC)
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="/home/pets/zoo/docutranslate"

# --- Config ---
CONTABO_URL="https://docutranslate.ru"
RACKNERD_URL="https://107.174.231.22:2053"
AUTH_USER="admin"
AUTH_PASS="tataronrails78"

# --- Helpers ---
now_ts() { date +%s; }
now_iso() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
log() { echo "[$(now_iso)] $*"; }

notify() {
    local msg="$1"
    log "NOTIFY: $msg"
    t2me send --markdown "$msg" 2>/dev/null || true
}

notify_file() {
    local file="$1"
    local caption="$2"
    t2me send --markdown --file "$file" --caption "$caption" 2>/dev/null || true
}

# --- Test runner ---
run_e2e_test() {
    local target="$1"
    local url="$2"
    local label="$3"
    
    log "=== Running E2E tests against $label ($url) ==="
    
    cd "$PROJECT_DIR"
    
    # Export env for Playwright
    export E2E_BASE_URL="$url"
    export E2E_BASIC_AUTH_USER="$AUTH_USER"
    export E2E_BASIC_AUTH_PASS="$AUTH_PASS"
    export E2E_ROUTE_LABEL="$label"
    
    # Create temp report dir
    local report_dir="/tmp/docutranslate-e2e-${label}-$(date +%Y%m%d)"
    mkdir -p "$report_dir"
    
    # Run Playwright BDD tests — health + landing + translate (skip real-translation)
    local exit_code=0
    npx bddgen 2>/dev/null || true
    
    npx playwright test \
        --project=chromium \
        --grep-invert="@real-translation|translation_matrix|translate" \
        --reporter="list,json:${report_dir}/results.json" \
        --output="$report_dir" \
        --timeout=60000 \
        2>&1 | tee "$report_dir/output.log" || exit_code=$?
    
    # Count results
    local total=$(cat "$report_dir/results.json" 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('suites',[])))" 2>/dev/null || echo "?")
    local passed=$(grep -c "✓\|passed" "$report_dir/output.log" 2>/dev/null || echo "0")
    local failed=$(grep -c "✘\|failed\|Error" "$report_dir/output.log" 2>/dev/null || echo "0")
    
    log "$label results: exit=$exit_code passed~=$passed failed~=$failed"
    
    # Return status
    if [ "$exit_code" -eq 0 ]; then
        echo "pass"
    else
        echo "fail:$exit_code"
    fi
    
    # Return report dir for notifications
    echo "$report_dir" > "/tmp/docutranslate-e2e-last-report-${label}"
}

# ============================================================
# MAIN
# ============================================================

log "=== Daily E2E Check Start ==="

# --- Test 1: Contabo (production) ---
contabo_result=$(run_e2e_test "contabo" "$CONTABO_URL" "Contabo-Production")
contabo_report=$(cat "/tmp/docutranslate-e2e-last-report-contabo" 2>/dev/null)

if echo "$contabo_result" | grep -q "^pass"; then
    log "✅ Contabo E2E: ALL PASSED"
    notify "🟢 Daily E2E: \`docutranslate.ru\` — all BDD tests passed ✅"
else
    log "❌ Contabo E2E: FAILED"
    
    # Collect artifacts
    notify "🔴 Daily E2E: \`docutranslate.ru\` — BDD tests FAILED
📋 Collecting screenshots and logs..."
    
    # Send failure output
    if [ -f "$contabo_report/output.log" ]; then
        tail -100 "$contabo_report/output.log" > /tmp/docutranslate-e2e-fail.log
        notify_file "/tmp/docutranslate-e2e-fail.log" "📋 E2E failure log — \`docutranslate.ru\`"
    fi
    
    # Send screenshots if any
    local screenshots=$(find "$contabo_report" -name "*.png" 2>/dev/null | head -3)
    for ss in $screenshots; do
        notify_file "$ss" "📸 E2E failure screenshot"
    done
    
    # If landing page test failed — trigger health monitor cascade
    if grep -q "landing\|title\|page" "$contabo_report/output.log" 2>/dev/null; then
        notify "🔴🔴 Landing page test failed — website may be broken (not just API)
Infrastructure monitor should pick this up on next cycle."
    fi
fi

# --- Test 2: RackNerd (fallback) ---
racknerd_result=$(run_e2e_test "racknerd" "$RACKNERD_URL" "RackNerd-Fallback")
racknerd_report=$(cat "/tmp/docutranslate-e2e-last-report-racknerd" 2>/dev/null)

if echo "$racknerd_result" | grep -q "^pass"; then
    log "✅ RackNerd E2E: ALL PASSED"
    # Don't notify separately for pass — include in summary
else
    log "❌ RackNerd E2E: FAILED (fallback — lower priority)"
    notify "🟡 Daily E2E: RackNerd fallback — BDD tests failed (not critical, Contabo is primary)"
fi

# --- Summary ---
log "=== Daily E2E Summary ==="
log "Contabo: $contabo_result"
log "RackNerd: $racknerd_result"

# Clean up old reports (keep 7 days)
find /tmp -name "docutranslate-e2e-*" -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true

log "=== Daily E2E Check Complete ==="
