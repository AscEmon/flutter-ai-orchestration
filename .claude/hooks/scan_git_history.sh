#!/bin/bash
# ============================================================
# scan_git_history.sh
# Scans the ENTIRE git history for secrets that may have
# already been committed. Shows exact commits + remediation.
#
# Usage:
#   bash .claude/hooks/scan_git_history.sh
#   bash .claude/hooks/scan_git_history.sh --fix    (auto-add to .gitignore)
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_secret_patterns.sh"

FIX_MODE=0
[[ "$1" == "--fix" ]] && FIX_MODE=1

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║   SECRET GUARD — Full Git History Scanner                   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$PROJECT_ROOT" ]; then
    echo "  ERROR: Not inside a git repository."
    exit 1
fi

TOTAL_COMMITS=$(git rev-list --count HEAD 2>/dev/null || echo "?")
echo "  Repository : $PROJECT_ROOT"
echo "  Commits    : $TOTAL_COMMITS"
echo "  Started    : $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

FOUND_ANY=0
declare -a LEAK_REPORT

# ── SCAN 1: Check if blocked files exist in history ───────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  [SCAN 1] Checking if sensitive files exist in history..."
echo ""

for fname in "${BLOCKED_FILES[@]}"; do
    # git log searches for commits that touched files matching this name
    COMMITS=$(git log --all --full-history --oneline -- "**/$fname" "*./$fname" "$fname" 2>/dev/null | head -5)
    if [ -n "$COMMITS" ]; then
        echo "  ✖ FOUND IN HISTORY: $fname"
        echo "$COMMITS" | while read -r line; do
            echo "      Commit: $line"
        done
        LEAK_REPORT+=("file_in_history:$fname")
        FOUND_ANY=1
        echo ""
    fi
done

# ── SCAN 2: Grep full history content for secret patterns ─
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  [SCAN 2] Scanning all commit diffs for secret patterns..."
echo "  (This may take a minute on large repos)"
echo ""

for entry in "${SECRET_PATTERNS[@]}"; do
    label="${entry%%%:::*}"
    pattern="${entry#*:::}"

    # Search all commits for this pattern in added lines
    HITS=$(git log --all -p --follow 2>/dev/null | grep -Pi "^\+.*$pattern" 2>/dev/null | head -3)

    if [ -n "$HITS" ]; then
        # Find which commit(s)
        COMMIT_HASHES=$(git log --all --oneline -S"$(echo "$HITS" | head -1 | sed 's/^\+//')" 2>/dev/null | head -3)
        echo "  ✖ PATTERN FOUND: $label"
        if [ -n "$COMMIT_HASHES" ]; then
            echo "$COMMIT_HASHES" | while read -r c; do
                echo "      Commit : $c"
            done
        fi
        echo "      Sample : $(echo "$HITS" | head -1 | cut -c1-80)..."
        LEAK_REPORT+=("pattern_in_history:$label")
        FOUND_ANY=1
        echo ""
    fi
done

# ── SCAN 3: Check current working tree ────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  [SCAN 3] Checking current working tree..."
echo ""

# Check tracked files that should NOT be tracked
TRACKED=$(git ls-files 2>/dev/null)
while IFS= read -r file; do
    match=$(is_blocked_filename "$file")
    if [ $? -eq 0 ]; then
        echo "  ⚠ TRACKED (should not be): $file"
        LEAK_REPORT+=("tracked_sensitive:$file")
        FOUND_ANY=1
    fi
done <<< "$TRACKED"

# ── REPORT ────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
if [ $FOUND_ANY -eq 0 ]; then
    echo "║  ✔  CLEAN — No secrets found in git history              ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    exit 0
fi

echo "║  ✖  SECRETS DETECTED IN HISTORY — Action required!          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  REMEDIATION GUIDE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  STEP 1 — ROTATE ALL EXPOSED CREDENTIALS IMMEDIATELY"
echo "  ─────────────────────────────────────────────────────"
echo "  Do this FIRST, before anything else."
echo "  Treat any found key/secret as already compromised."
echo ""
echo "  STEP 2 — REMOVE FROM CURRENT TRACKING"
echo "  ─────────────────────────────────────────────────────"
for entry in "${LEAK_REPORT[@]}"; do
    type="${entry%%:*}"
    value="${entry#*:}"
    if [[ "$type" == "tracked_sensitive" ]]; then
        echo "    git rm --cached $value"
        echo "    echo '$value' >> .gitignore"
    fi
done
echo ""
echo "  STEP 3 — PURGE FROM GIT HISTORY"
echo "  ─────────────────────────────────────────────────────"
echo "  Option A — BFG Repo Cleaner (recommended, faster):"
echo ""
echo "    # Install: brew install bfg  OR  download bfg.jar"
echo ""
echo "    # Remove a specific file from all history:"
echo "    bfg --delete-files .env"
echo "    bfg --delete-files key.properties"
echo "    bfg --delete-files google-services.json"
echo ""
echo "    # Replace secret strings in history:"
echo "    echo 'AIzaXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX' > secrets.txt"
echo "    bfg --replace-text secrets.txt"
echo ""
echo "    # Then clean up and force-push:"
echo "    git reflog expire --expire=now --all"
echo "    git gc --prune=now --aggressive"
echo "    git push --force --all"
echo ""
echo "  Option B — git filter-repo (built-in, slower):"
echo ""
echo "    pip install git-filter-repo"
echo "    git filter-repo --path .env --invert-paths"
echo "    git filter-repo --path key.properties --invert-paths"
echo "    git push --force --all"
echo ""
echo "  Option C — git filter-branch (legacy, slowest):"
echo ""
echo "    git filter-branch --force --index-filter \\"
echo "      'git rm --cached --ignore-unmatch .env key.properties' \\"
echo "      --prune-empty --tag-name-filter cat -- --all"
echo "    git push --force --all"
echo ""
echo "  STEP 4 — NOTIFY YOUR TEAM"
echo "  ─────────────────────────────────────────────────────"
echo "  Anyone who has cloned/pulled this repo must:"
echo "    git fetch --all && git reset --hard origin/main"
echo "  (Their local history may still contain the secrets)"
echo ""
echo "  STEP 5 — PREVENT FUTURE LEAKS"
echo "  ─────────────────────────────────────────────────────"
echo "  Claude Code hooks are in .claude/hooks/ — no manual git hook needed."
echo "  Ensure .claude/settings.local.json is configured correctly."
echo "  Run: bash .claude/hooks/pre_commit.sh  (manual check anytime)"
echo ""
echo "  Add all sensitive patterns to .gitignore:"
for fname in ".env" ".env.*" "key.properties" "local.properties" \
             "*.keystore" "*.jks" "google-services.json" \
             "GoogleService-Info.plist" "secrets.dart" "api_keys.dart"; do
    if ! grep -qxF "$fname" .gitignore 2>/dev/null; then
        echo "    echo '$fname' >> .gitignore"
        if [ $FIX_MODE -eq 1 ]; then
            echo "$fname" >> .gitignore
        fi
    fi
done

if [ $FIX_MODE -eq 1 ]; then
    echo ""
    echo "  --fix mode: .gitignore entries added automatically."
fi

echo ""
echo "  Report saved to: .claude/secret_guard_report.txt"
echo ""

# Save report
{
    echo "Secret Guard Report — $(date)"
    echo "=========================="
    for entry in "${LEAK_REPORT[@]}"; do
        echo "LEAK: $entry"
    done
} > ".claude/secret_guard_report.txt" 2>/dev/null

exit 1
