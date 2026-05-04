#!/bin/bash
# ============================================================
# .claude/hooks/pre_bash_git_guard.sh
#
# Claude Code PreToolUse Hook — intercepts every Bash tool call.
# When Claude tries to run "git commit" or "git push",
# it delegates to pre_commit.sh for the full secret check.
#
# Exit 0 = allow the command
# Exit 2 = BLOCK the command (Claude Code specific)
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Read the bash command Claude wants to run ─────────────
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    ti = d.get('tool_input', d)
    print(ti.get('command', ''))
except:
    print('')
" 2>/dev/null)

# ── Only intercept git commit / git push ──────────────────
if ! echo "$COMMAND" | grep -qE "git\s+(commit|push)"; then
    exit 0
fi

# ── Log the attempt ───────────────────────────────────────
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
mkdir -p ".claude"
echo "[$TIMESTAMP] GIT CMD: $COMMAND" >> ".claude/audit.log" 2>/dev/null

# ── Delegate to the shared pre_commit.sh ─────────────────
bash "$SCRIPT_DIR/pre_commit.sh"
RESULT=$?

if [ $RESULT -ne 0 ]; then
    # pre_commit.sh already printed the full error + fix steps
    echo ""
    echo "  [Claude Hook] Commit blocked by Secret Guard."
    echo "  Fix the issues above, then ask me to commit again."
    echo ""
    exit 2   # EXIT CODE 2 = Claude Code hard block
fi

exit 0
