#!/bin/bash
# ============================================================
# .claude/hooks/pre_commit.sh
#
# The commit guard — runs ALL secret checks before any commit.
# Called automatically by pre_bash_git_guard.sh when Claude
# (or the developer) runs "git commit".
#
# Can also be run manually at any time:
#   bash .claude/hooks/pre_commit.sh
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_secret_patterns.sh"

BLOCKED=0
declare -a BLOCKED_FILES_LIST

echo ""
echo "┌──────────────────────────────────────────────────────────┐"
echo "│  SECRET GUARD — Pre-Commit Check                        │"
echo "└──────────────────────────────────────────────────────────┘"

# ── Get staged files ──────────────────────────────────────
STAGED=$(git diff --cached --name-only 2>/dev/null)

if [ -z "$STAGED" ]; then
    echo "  No staged files. Nothing to check."
    exit 0
fi

FILE_COUNT=$(echo "$STAGED" | grep -c . 2>/dev/null || echo 0)
echo "  Staged files : $FILE_COUNT"
echo ""

# ─────────────────────────────────────────────────────────
# CHECK 1 — Blocked filenames
# ─────────────────────────────────────────────────────────
echo "  ▶ CHECK 1: Sensitive filename scan"

while IFS= read -r file; do
    [ -z "$file" ] && continue
    match=$(is_blocked_filename "$file")
    if [ $? -eq 0 ]; then
        echo "    ✖  $file  →  blocked pattern: '$match'"
        BLOCKED_FILES_LIST+=("$file")
        BLOCKED=1
    fi
done <<< "$STAGED"

[ $BLOCKED -eq 0 ] && echo "    ✔  No blocked files found"

# ─────────────────────────────────────────────────────────
# CHECK 2 — Secret patterns in staged diffs
# ─────────────────────────────────────────────────────────
echo ""
echo "  ▶ CHECK 2: Secret pattern scan (staged content only)"

while IFS= read -r file; do
    [ -z "$file" ] && continue

    # Only scan the diff (added lines) — not full file content
    PATCH=$(git diff --cached -- "$file" 2>/dev/null)
    [ -z "$PATCH" ] && continue

    FILE_BLOCKED=0
    for entry in "${SECRET_PATTERNS[@]}"; do
        label="${entry%%%:::*}"
        pattern="${entry#*:::}"

        # grep only the '+' lines from the diff
        HIT=$(echo "$PATCH" | grep -P "^\+" | grep -Pi "$pattern" 2>/dev/null | head -1)
        if [ -n "$HIT" ]; then
            echo "    ✖  $file"
            echo "       Secret type : $label"
            # Show redacted snippet
            SNIPPET=$(echo "$HIT" | sed 's/^\+//' | cut -c1-60)
            echo "       Snippet     : ${SNIPPET}..."
            BLOCKED_FILES_LIST+=("$file")
            BLOCKED=1
            FILE_BLOCKED=1
            break   # one match per file is enough
        fi
    done
done <<< "$STAGED"

[ $BLOCKED -eq 0 ] && echo "    ✔  No secret patterns detected"

# ─────────────────────────────────────────────────────────
# CHECK 3 — .gitignore coverage
# ─────────────────────────────────────────────────────────
echo ""
echo "  ▶ CHECK 3: .gitignore coverage"

MUST_IGNORE=(
    ".env" ".env.*" "*.env"
    "key.properties" "local.properties"
    "*.keystore" "*.jks"
    "google-services.json" "GoogleService-Info.plist"
    "secrets.dart" "api_keys.dart" "credentials.dart"
    "*.p12" "*.pem" "*.pfx"
    "service-account.json" "service_account.json"
    ".claude/audit.log" ".claude/secret_guard_report.txt"
)

MISSING_IGNORES=()
for item in "${MUST_IGNORE[@]}"; do
    if ! grep -qF "$item" .gitignore 2>/dev/null; then
        MISSING_IGNORES+=("$item")
    fi
done

if [ ${#MISSING_IGNORES[@]} -gt 0 ]; then
    echo "    ⚠  Missing from .gitignore:"
    for m in "${MISSING_IGNORES[@]}"; do
        echo "       $m"
    done
    echo ""
    echo "    Auto-fix command:"
    echo "       bash .claude/hooks/setup.sh --fix-gitignore"
else
    echo "    ✔  .gitignore looks good"
fi

# ─────────────────────────────────────────────────────────
# RESULT
# ─────────────────────────────────────────────────────────
echo ""
if [ $BLOCKED -eq 1 ]; then
    # Deduplicate
    UNIQUE=($(printf "%s\n" "${BLOCKED_FILES_LIST[@]}" | sort -u))

    echo "┌──────────────────────────────────────────────────────────┐"
    echo "│  ✖  COMMIT BLOCKED — sensitive data detected             │"
    echo "└──────────────────────────────────────────────────────────┘"
    echo ""
    echo "  HOW TO FIX:"
    echo ""
    echo "  1.  Unstage the file(s):"
    for f in "${UNIQUE[@]}"; do
        echo "        git restore --staged \"$f\""
    done
    echo ""
    echo "  2.  Add to .gitignore so it never stages again:"
    for f in "${UNIQUE[@]}"; do
        bname=$(basename "$f")
        echo "        echo '$bname' >> .gitignore && git add .gitignore"
    done
    echo ""
    echo "  3.  Use envied for secrets (the only approved method):"
    echo "      Flutter example:"
    echo "        import 'package:your_app/core/config/env.dart';"
    echo "        final apiKey = Env.paymentApiKey;"
    echo ""
    echo "  4.  Already in git history? Run the history scanner:"
    echo "        bash .claude/hooks/scan_git_history.sh"
    echo ""
    echo "  5.  ROTATE exposed credentials immediately — treat as leaked."
    echo ""
    exit 1   # non-zero = abort commit (used by git pre-commit hook)
else
    echo "  ✔  All clear — commit is safe to proceed."
    echo ""
    exit 0
fi
