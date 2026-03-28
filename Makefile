# DocuTranslate — operations Makefile
# Usage: make <target>
SHELL := /bin/bash
.PHONY: start stop restart rebuild status heal logs health e2e watchdog-install watchdog-remove help

COMPOSE   = docker compose
HEALTH_URL = https://127.0.0.1:18443/health
E2E_URL   = https://107.174.231.22:18443
WATCHDOG_SCRIPT := $(CURDIR)/scripts/watchdog.sh
HEAL_SCRIPT     := $(CURDIR)/scripts/auto_heal.sh
LOG_DIR         := $(CURDIR)/logs

# ── lifecycle ──────────────────────────────────────────

start:
	@echo "▶  Starting DocuTranslate …"
	@$(COMPOSE) up -d
	@sleep 3
	@$(MAKE) status

stop:
	@echo "■  Stopping DocuTranslate …"
	@$(COMPOSE) down
	@echo "✅  Stopped."

restart:
	@echo "↻  Restarting DocuTranslate …"
	@$(COMPOSE) restart
	@sleep 3
	@$(MAKE) status

rebuild:
	@echo "🔨  Rebuilding & restarting …"
	@$(COMPOSE) up -d --build
	@sleep 5
	@$(MAKE) status

# ── diagnostics ────────────────────────────────────────

status:
	@echo "──── DocuTranslate Status ────"
	@$(COMPOSE) ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "Compose not running"
	@echo ""
	@curl -skf --max-time 5 "$(HEALTH_URL)" 2>/dev/null && echo "" || echo "⚠️  Health check FAILED"
	@echo "──────────────────────────────"

health:
	@curl -sk --max-time 5 "$(HEALTH_URL)" 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "❌ Unreachable"

logs:
	@$(COMPOSE) logs --tail=80 -f

e2e:
	@E2E_BASE_URL=$(E2E_URL) E2E_REBUILD_LOCAL=0 bash scripts/e2e_verify.sh

# ── heal ───────────────────────────────────────────────

heal: ## Run AI auto-heal once now
	@mkdir -p $(LOG_DIR)
	@echo "🩺  Running AI auto-heal …"
	@bash $(HEAL_SCRIPT) 2>&1 | tee $(LOG_DIR)/heal-$$(date +%Y%m%d-%H%M%S).log

# ── watchdog (cron) ────────────────────────────────────

watchdog-install: ## Install 15-min cron watchdog
	@echo "⏰  Installing 15-min watchdog cron …"
	@bash $(WATCHDOG_SCRIPT) --install
	@echo "✅  Installed. Current cron:"
	@crontab -l | grep docutranslate

watchdog-remove: ## Remove watchdog cron
	@echo "🗑️  Removing watchdog cron …"
	@bash $(WATCHDOG_SCRIPT) --remove
	@echo "✅  Removed."

# ── help ───────────────────────────────────────────────

help:
	@echo "DocuTranslate Operations"
	@echo ""
	@echo "  make start             Start containers"
	@echo "  make stop              Stop containers"
	@echo "  make restart           Restart containers"
	@echo "  make rebuild           Rebuild images & restart"
	@echo "  make status            Show container + health status"
	@echo "  make health            JSON health endpoint"
	@echo "  make logs              Follow container logs"
	@echo "  make e2e               Run BDD test suite"
	@echo "  make heal              AI auto-heal (run once)"
	@echo "  make watchdog-install  Install 15-min cron watchdog"
	@echo "  make watchdog-remove   Remove cron watchdog"
