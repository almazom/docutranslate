#!/bin/bash
# parse-progress.sh — Parse kanban.json and show progress
# Usage: ./parse-progress.sh /path/to/kanban.json

set -e

KANBAN="${1:-./kanban.json}"

if [ ! -f "$KANBAN" ]; then
    echo "Error: kanban.json not found at $KANBAN"
    exit 1
fi

# Validate JSON
if ! jq '.' "$KANBAN" > /dev/null 2>&1; then
    echo "Error: kanban.json is not valid JSON"
    exit 1
fi

# Extract metrics
DONE=$(jq '.status_counts.done' "$KANBAN")
TOTAL=$(jq '.card_count' "$KANBAN")
IN_PROGRESS=$(jq '.status_counts.in_progress' "$KANBAN")
READY=$(jq '.status_counts.ready' "$KANBAN")
BLOCKED=$(jq '.status_counts.blocked' "$KANBAN")
BACKLOG=$(jq '.status_counts.backlog' "$KANBAN")

# Calculate percentage
if [ "$TOTAL" -gt 0 ]; then
    PERCENT=$((DONE * 100 / TOTAL))
else
    PERCENT=0
fi

# Progress bar
BAR_WIDTH=20
if [ "$TOTAL" -gt 0 ]; then
    FILLED=$((DONE * BAR_WIDTH / TOTAL))
else
    FILLED=0
fi
EMPTY=$((BAR_WIDTH - FILLED))
BAR=$(printf '█%.0s' $(seq 1 $FILLED 2>/dev/null))$(printf '░%.0s' $(seq 1 $EMPTY 2>/dev/null))

# Output
echo "┌───────────────────────────────────────────────────┐"
echo "│  CARDS: $BAR $DONE/$TOTAL ($PERCENT%)            │"
echo "│  STATUS: in_progress=$IN_PROGRESS, ready=$READY, blocked=$BLOCKED, backlog=$BACKLOG"
echo "└───────────────────────────────────────────────────┘"

# Current card
if [ "$IN_PROGRESS" -gt 0 ]; then
    CURRENT=$(jq -r '.cards[] | select(.status == "in_progress") | "\(.id) - \(.title[:50])"' "$KANBAN" | head -1)
    echo "📍 CURRENT: $CURRENT"
fi

# Next ready card
if [ "$READY" -gt 0 ]; then
    NEXT=$(jq -r '.cards[] | select(.status == "ready") | "\(.id) - \(.title[:50])"' "$KANBAN" | head -1)
    echo "⏭️  NEXT READY: $NEXT"
fi

# Blocked cards
if [ "$BLOCKED" -gt 0 ]; then
    echo ""
    echo "⛔ BLOCKED CARDS:"
    jq -r '.cards[] | select(.status == "blocked") | "  - \(.id): \(.title[:40])"' "$KANBAN"
fi

# Exit codes for automation
if [ "$DONE" -eq "$TOTAL" ]; then
    exit 0  # All done
elif [ "$BLOCKED" -gt 0 ]; then
    exit 2  # Blocked
else
    exit 1  # In progress
fi
