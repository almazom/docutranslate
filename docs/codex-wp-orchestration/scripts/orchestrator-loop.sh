#!/bin/bash
# orchestrator-loop.sh — Main orchestrator loop
# Usage: ./orchestrator-loop.sh /path/to/package /path/to/repo

set -e

PACKAGE="${1:-/home/pets/zoo/docutranslate/generated/ru-entry-for-docutranslate}"
REPO_ROOT="${2:-/home/pets/zoo/docutranslate}"
KANBAN="$PACKAGE/trello-cards/kanban.json"
SESSION_FILE="/tmp/codex-orchestrator-session.txt"
LOG_DIR="/tmp/codex-orchestrator-logs"
MAX_CYCLES=20
HOOK_TIMES=5
WORKER_TIMEOUT=600

# Setup
mkdir -p "$LOG_DIR"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Functions
log() {
    echo "[$(date '+%H:%M:%S')] $1"
}

get_progress() {
    "$SCRIPT_DIR/parse-progress.sh" "$KANBAN"
    return $?
}

notify() {
    local done=$(jq '.status_counts.done' "$KANBAN")
    local total=$(jq '.card_count' "$KANBAN")
    local current=$(jq -r '.cards[] | select(.status == "in_progress") | .id' "$KANBAN" | head -1)
    local status="$1"
    local details="$2"

    "$SCRIPT_DIR/notify-progress.sh" "$done" "$total" "$current" "$status" "$details"
}

run_worker() {
    local session_id="$1"
    local log_file="$LOG_DIR/worker-$(date '+%Y%m%d-%H%M%S').log"

    log "Starting worker, log: $log_file"

    if [ -n "$session_id" ] && [ -f "$SESSION_FILE" ]; then
        # Resume existing session
        log "Resuming session: $session_id"
        timeout $WORKER_TIMEOUT codex_wp exec resume --json "$session_id" \
            "Continue implementing. Check kanban.json. Do not stop until all cards done." \
            2>&1 | tee "$log_file"
    else
        # Start new session
        log "Starting new session"
        timeout $WORKER_TIMEOUT codex_wp \
            --hook stop \
            --hook-times $HOOK_TIMES \
            --hook-prompt "Continue implementing next Trello card. Do not stop. Check kanban.json for remaining cards. If codex-review times out, use --backend kimi_wp." \
            exec --json \
            "Read $PACKAGE/AGENTS.md and implement cards from kanban.json. Start with: cd /home/pets/TOOLS/split_to_tasks_skill_cli && PYTHONPATH=src python -m split_to_tasks_skill_cli implementation-start --package $PACKAGE --repo-root $REPO_ROOT. Implement full lifecycle per card: implement -> simplify -> commit -> codex-review -> done. After each card, continue to next ready card. Do NOT stop until all cards done." \
            2>&1 | tee "$log_file"
    fi

    local exit_code=$?

    # Extract session_id for resume
    grep '"type":"thread.started"' "$log_file" | tail -1 | jq -r '.thread_id' > "$SESSION_FILE" 2>/dev/null || true

    return $exit_code
}

# Main loop
log "=== Orchestrator Started ==="
log "Package: $PACKAGE"
log "Repo: $REPO_ROOT"
log "Kanban: $KANBAN"

notify "start"

cycle=0
while [ $cycle -lt $MAX_CYCLES ]; do
    cycle=$((cycle + 1))
    log ""
    log "=== Cycle $cycle/$MAX_CYCLES ==="

    # Check progress
    get_progress
    progress_code=$?

    case $progress_code in
        0)
            log "✅ All cards done!"
            notify "done"
            exit 0
            ;;
        2)
            log "⛔ Blocked cards detected!"
            notify "blocked" "Check kanban.json for details"
            exit 2
            ;;
    esac

    # Get session_id if exists
    session_id=""
    if [ -f "$SESSION_FILE" ]; then
        session_id=$(cat "$SESSION_FILE")
    fi

    # Run worker
    run_worker "$session_id"
    worker_exit=$?

    log "Worker exit code: $worker_exit"

    # Handle exit codes
    case $worker_exit in
        0)
            log "Worker completed normally"
            ;;
        124)
            log "Worker timed out (this is expected)"
            ;;
        137)
            log "Worker killed (OOM or signal)"
            notify "error" "Worker killed"
            ;;
        *)
            log "Worker exited with error: $worker_exit"
            notify "error" "Exit code: $worker_exit"
            ;;
    esac

    # Notify cycle complete
    notify "cycle"

    # Small pause between cycles
    sleep 5
done

log "Max cycles reached ($MAX_CYCLES)"
notify "error" "Max cycles reached without completion"
exit 1
