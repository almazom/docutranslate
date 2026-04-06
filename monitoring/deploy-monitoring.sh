#!/bin/bash
# ============================================================
# deploy-monitoring.sh — installs monitoring on both servers
# Run from RackNerd
# ============================================================

set -euo pipefail

CONTABO_SSH="ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -i /home/pets/.ssh/docutranslate_ru_proxy almaz@212.28.182.235"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Deploying DocuTranslate Monitoring ==="

# --- 1. RackNerd (local) ---
echo ""
echo "📦 RackNerd: installing remote-monitor.sh..."

cp "$SCRIPT_DIR/remote-monitor.sh" /usr/local/bin/docutranslate-remote-monitor 2>/dev/null || \
    cp "$SCRIPT_DIR/remote-monitor.sh" /home/pets/docutranslate-remote-monitor
chmod +x /home/pets/docutranslate-remote-monitor

# Install cron
CRON_CMD="/home/pets/docutranslate-remote-monitor >> /tmp/docutranslate-remote-monitor.log 2>&1"
(
    crontab -l 2>/dev/null | grep -v "docutranslate-remote-monitor"
    echo "*/10 * * * * $CRON_CMD"
) | crontab -

echo "✅ RackNerd cron installed (every 10 min)"

# --- 2. Contabo (remote) ---
echo ""
echo "📦 Contabo: installing health-monitor.sh..."

scp -i /home/pets/.ssh/docutranslate_ru_proxy \
    "$SCRIPT_DIR/health-monitor.sh" \
    almaz@212.28.182.235:/home/almaz/docutranslate-health-monitor

$CONTABO_SSH "chmod +x /home/almaz/docutranslate-health-monitor"

# Install cron on Contabo
$CONTABO_SSH bash << 'REMOTE'
CRON_CMD="/home/almaz/docutranslate-health-monitor >> /tmp/docutranslate-health-monitor.log 2>&1"
(
    crontab -l 2>/dev/null | grep -v "docutranslate-health-monitor"
    echo "*/5 * * * * $CRON_CMD"
) | crontab -
echo "✅ Contabo cron installed (every 5 min)"
REMOTE

# --- 3. Test ---
echo ""
echo "🧪 Running test checks..."

echo "  Contabo health-monitor (dry run)..."
$CONTABO_SSH "bash -x /home/almaz/docutranslate-health-monitor" 2>&1 | tail -5

echo "  RackNerd remote-monitor..."
bash -x /home/pets/docutranslate-remote-monitor 2>&1 | tail -5

echo ""
echo "=== Deployment Complete ==="
echo "  Contabo: health-monitor every 5 min"
echo "  RackNerd: remote-monitor every 10 min"
echo "  Alerts: via t2me (only on failures)"
echo ""
echo "Logs:"
echo "  Contabo: /tmp/docutranslate-health-monitor.log"
echo "  RackNerd: /tmp/docutranslate-remote-monitor.log"
