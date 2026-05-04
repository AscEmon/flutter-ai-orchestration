#!/bin/bash
# ============================================================
# .claude/hooks/post_write.sh
#
# Claude Code PostToolUse Hook — runs after every Write|Edit.
# Performs lightweight checks on the written file.
#
# Exit 0 = success (informational only, post hooks don't block)
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

BNAME=$(basename "$FILE")

# ── Reminder: regenerate assets if an image/svg was added ─
case "$BNAME" in
    *.png|*.jpg|*.jpeg|*.svg|*.webp)
        echo ""
        echo "  📸 Asset file written: $BNAME"
        echo "  💡 Remember to run: ssl_cli generate k_assets.dart"
        echo ""
        ;;
esac

# ── Reminder: run autosafe if a model file was modified ───
if [[ "$FILE" == *"_model.dart" ]]; then
    echo ""
    echo "  🔧 Model file modified: $BNAME"
    echo "  💡 Remember to run: autosafe $FILE"
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
