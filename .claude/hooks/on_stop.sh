#!/bin/bash
# ============================================================
# .claude/hooks/on_stop.sh
#
# Claude Code Stop Hook — runs when the AI session ends.
# Performs a lightweight audit and logs the session.
#
# Exit 0 = always (Stop hooks are informational)
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AUDIT_LOG="$PROJECT_ROOT/.claude/audit.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

mkdir -p "$(dirname "$AUDIT_LOG")"

# ── Log session end ───────────────────────────────────────
echo "[$TIMESTAMP] SESSION END" >> "$AUDIT_LOG" 2>/dev/null

# ── Quick check: any secret files accidentally tracked? ───
if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null; then
    TRACKED=$(git ls-files 2>/dev/null)

    SENSITIVE_FILES=(".env" "key.properties" "local.properties"
                     "release.jks" "google-services.json"
                     "GoogleService-Info.plist" "env.g.dart"
                     "Secret.xcconfig")

    FOUND_ISSUE=0
    for sf in "${SENSITIVE_FILES[@]}"; do
        if echo "$TRACKED" | grep -qF "$sf"; then
            if [ $FOUND_ISSUE -eq 0 ]; then
                echo ""
                echo "  ⚠️  SESSION END — Secret file warning:"
                FOUND_ISSUE=1
            fi
            echo "     Tracked: $sf (should be gitignored)"
            echo "[$TIMESTAMP] WARNING: $sf is tracked" >> "$AUDIT_LOG" 2>/dev/null
        fi
    done

    if [ $FOUND_ISSUE -eq 1 ]; then
        echo ""
        echo "  Fix: git rm --cached <file> && add to .gitignore"
        echo ""
    fi
fi

exit 0
