# SESSION LEARNINGS — Codex WP Orchestration

> Критические уроки из реального запуска 2026-03-30

## User Expectations (from user inputs)

### Timeout expectations per task
- **Single card**: 10-20 minutes
- **Full package (8 cards)**: 80-160 minutes
- **Worker timeout**: Set to 120-180 minutes with buffer

### Critical rules from user
1. **Always mention `$implementation-skill`** when asking codex_wp to implement
   - ❌ Wrong: "Implement cards from kanban.json"
   - ✅ Right: "Use `$implementation-skill` to implement cards from kanban.json"

2. **Always monitor JSONL session logs** when running headless
   - Never assume worker is "stuck" without checking
   - JSONL shows real activity: file changes, commands, turns
   - Use `tail -f ~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl`

3. **codex-review needs patience**
   - 10-20 minutes is normal for review
   - Use `--timeout 600-1200` for review runs
   - **Use `glm_wp` backend, NOT `kimi_wp`** (kimi_wp hangs!)

## Critical Finding: Review Backend

### Problem
- `kimi_wp` backend **HANGS** even on trivial prompts
- Timeout after 30s with no output
- Even `--bare` mode doesn't help

### Solution
```bash
# Step 1: Try codex native first
codex-review --backend codex --timeout 300

# Step 2: If codex fails, use glm_wp fallback
codex-review --backend glm_wp --timeout 600

# ❌ NEVER USE - kimi_wp hangs
codex-review --backend kimi_wp  # BROKEN!
```

### Backend priority
1. `codex` — native, try FIRST (if healthy)
2. `glm_wp` — fallback, use ONLY if codex fails
3. `kimi_wp` — **BROKEN**, do not use

### If codex fails - investigate proxy

```bash
# Check proxy health
cdx status --json

# Check auth keys
cdx doctor --probe

# See usage dashboard
cdx all

# Rotate to next key
cdx rotate

# Reset blacklist if keys recovered
cdx reset --state blacklist

# Preview rotation
cdx rotate --dry-run
```

## JSONL Observability Rule

### When running headless, ALWAYS:

```bash
# 1. Start worker
codex_wp --hook stop --hook-times 10 exec --json "Task" 2>&1 | tee /tmp/worker.log &

# 2. Get session ID
SESSION=$(grep '"type":"thread.started"' /tmp/worker.log | head -1 | jq -r '.thread_id')

# 3. Monitor JSONL in real-time
tail -f ~/.codex/sessions/2026/03/30/rollout-*$SESSION*.jsonl | jq -c '{type, item_type: .item.type, text: .item.text[0:100]}'
```

### JSONL activity indicators

| Event | Meaning |
|-------|---------|
| `thread.started` | Session created |
| `turn.started` | New turn begins |
| `item.started` | Action in progress |
| `item.completed` | Action finished |
| `turn.completed` | Turn done, check usage |
| No events for 60s | **Possibly stuck** - check process |

### Check if stuck

```bash
# Check process CPU
ps -o pid,etimes,pcpu,stat,cmd -p $(pgrep -f "codex.*$SESSION")

# CPU > 0% = still working
# CPU = 0% for >60s = likely stuck
```

## Full Run Command Template

```bash
cd /home/pets/zoo/docutranslate && \
timeout 10800 codex_wp \
  --hook stop \
  --hook-times 15 \
  --hook-prompt "Continue implementing. Use \$implementation-skill. Do not stop." \
  exec --json "
Use \$implementation-skill to implement cards from /path/to/package.

Current state: [describe blocked/done/ready]

Rules:
- Treat kanban.json as SSOT
- Skip codex-review if timeout >5min (mark 'needs manual review')
- Use --backend codex for reviews (glm_wp fallback)
- Do NOT stop until done == total
" 2>&1 | tee /tmp/worker.log
```

## Lessons Learned

### What worked ✅
1. Hooks mechanism - worker continues after stops
2. JSONL parsing - easy to extract progress
3. implementation-skill commands - correctly update kanban
4. code-simplifier + auto-commit - auto commits

### What failed ❌
1. **kimi_wp backend** - hangs on everything
2. **600s timeout** - too short for 8 cards + review
3. **No JSONL monitoring** - assumed stuck when actually working
4. **Forgot `$implementation-skill`** - skill wasn't triggered properly

### Recommendations for next run

```bash
# 1. Longer timeout
timeout 10800 codex_wp ...  # 3 hours

# 2. Monitor JSONL in parallel
tail -f ~/.codex/sessions/*/$(date +%Y/%m/%d)/*.jsonl &

# 3. Use correct backend
codex-review --backend codex --timeout 600  # or glm_wp

# 4. Skip review if needed
"If codex-review times out, mark as 'needs manual review' and continue"

# 5. Always mention skill
"Use \$implementation-skill to implement..."
```
