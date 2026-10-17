#!/bin/bash
# ============================================================
# .claude/hooks/post_write.sh
#
# Claude Code PostToolUse Hook — runs after every Write|Edit.
# Performs lightweight checks on the written file.
#
# Exit 0 = ok · Exit 2 = secret found → stderr is fed back to Claude so it removes it
# ============================================================

INPUT=$(cat)

# ── Extract the target file path ──────────────────────────
FILE=$(echo "$INPUT" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    ti = d.get('tool_input', d)
    path = ti.get('file_path', ti.get('path', ti.get('target', '')))
    print(path)
except:
    print('')
" 2>/dev/null)

[ -z "$FILE" ] && exit 0

# ── Secret scan of the file just written (exit 2 → Claude sees this and must fix it) ──
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
case "$FILE" in
    *"/.claude/hooks/"*|*"/.claude/docs/"*) ;;     # orchestration's own pattern docs
    *)
        if [ -f "$FILE" ] && [ -f "$SCRIPT_DIR/_secret_patterns.sh" ]; then
            # shellcheck disable=SC1091
            source "$SCRIPT_DIR/_secret_patterns.sh"
            if ! FOUND=$(scan_file_for_secrets "$FILE"); then
                {
                    echo "SECRET DETECTED in the file you just wrote:"
                    echo "$FOUND"
                    echo "Remove the value now. Read secrets through the project's approved mechanism"
                    echo "(PROJECT_CONVENTIONS.md → Secrets) and use [PLACEHOLDER] in examples and tests."
                } >&2
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] SECRET_WRITE_BLOCKED $FILE" >> "${CLAUDE_PROJECT_DIR:-.}/.claude/audit.log" 2>/dev/null
                exit 2
            fi
        fi
        ;;
esac

BNAME=$(basename "$FILE")

# ── Reminder: regenerate assets if an image/svg was added ─
case "$BNAME" in
    *.png|*.jpg|*.jpeg|*.svg|*.webp)
        echo ""
        echo "  📸 Asset file written: $BNAME"
        command -v ssl_cli >/dev/null 2>&1 && echo "  💡 Remember to run: ssl_cli generate k_assets.dart"
        echo ""
        ;;
esac

# ── Reminder: run autosafe if a model file was modified ───
if [[ "$FILE" == *"_model.dart" || "$FILE" == *"_response.dart" ]]; then
    echo ""
    echo "  🔧 Model file modified: $BNAME"
    command -v autosafe >/dev/null 2>&1 && echo "  💡 Remember to run: autosafe $FILE"
    echo ""
fi

# ── Reminder: run build_runner if env.dart was modified ───
if [[ "$BNAME" == "env.dart" && "$FILE" == *"core/config/env.dart"* ]]; then
    echo ""
    echo "  🔐 env.dart modified"
    echo "  💡 Remember to run: dart run build_runner build --delete-conflicting-outputs"
    echo ""
fi

exit 0
