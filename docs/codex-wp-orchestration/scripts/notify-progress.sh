#!/bin/bash
# notify-progress.sh — Send Telegram notification about progress
# Usage: ./notify-progress.sh <done> <total> <current_card> <status> [details]

DONE="${1:-0}"
TOTAL="${2:-0}"
CURRENT="${3:-unknown}"
STATUS="${4:-progress}"
DETAILS="${5:-}"

PERCENT=$((DONE * 100 / TOTAL))

case "$STATUS" in
    "progress")
        MESSAGE="🔄 DocuTranslate: $DONE/$TOTAL ($PERCENT%) cards done.
📍 Current: $CURRENT"
        ;;
    "done")
        MESSAGE="✅ DocuTranslate: All $TOTAL cards implemented!

🎉 Implementation complete.
Branch: ru-fixes-with-contabo"
        ;;
    "blocked")
        MESSAGE="⛔ DocuTranslate: BLOCKED on card $CURRENT

$DETAILS

Manual intervention required."
        ;;
    "error")
        MESSAGE="❌ DocuTranslate: Worker crashed

Last successful: $DONE/$TOTAL ($PERCENT%)
Last card: $CURRENT

$DETAILS"
        ;;
    "start")
        MESSAGE="🚀 DocuTranslate: Starting implementation

📦 Total cards: $TOTAL
🌿 Branch: ru-fixes-with-contabo"
        ;;
    "cycle")
        MESSAGE="🔁 DocuTranslate: Worker cycle complete

Progress: $DONE/$TOTAL ($PERCENT%)
Current: $CURRENT"
        ;;
    *)
        MESSAGE="📊 DocuTranslate: $DONE/$TOTAL ($PERCENT%)
Current: $CURRENT
Status: $STATUS"
        ;;
esac

# Send via t2me
if command -v t2me &> /dev/null; then
    echo "$MESSAGE" | t2me
else
    echo "t2me not found, printing message:"
    echo "$MESSAGE"
fi
