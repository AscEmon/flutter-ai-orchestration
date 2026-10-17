#!/usr/bin/env bash
# ============================================================
# .claude/hooks/log_subagent.sh — audit trail for subagents (never blocks)
#   PreToolUse (Task|Agent) → SUBAGENT_START <type> | <description>
#   SubagentStop            → SUBAGENT_STOP
# Check:  grep SUBAGENT .claude/audit.log
# ============================================================
INPUT=$(cat)
ROOT="${CLAUDE_PROJECT_DIR:-.}"
mkdir -p "$ROOT/.claude"
if [ "${1:-}" = "--stop" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUBAGENT_STOP" >> "$ROOT/.claude/audit.log"
    exit 0
fi
INFO=$(printf '%s' "$INPUT" | python3 -c "
import json, sys
try:
    t = json.load(sys.stdin).get('tool_input', {})
    print((t.get('subagent_type') or 'general-purpose') + ' | ' + (t.get('description') or '')[:80])
except Exception:
    print('unknown')
" 2>/dev/null)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUBAGENT_START ${INFO:-unknown}" >> "$ROOT/.claude/audit.log"
exit 0
