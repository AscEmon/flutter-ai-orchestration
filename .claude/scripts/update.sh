#!/usr/bin/env bash
# ============================================================
# .claude/scripts/update.sh — update flutter-ai-orchestration in THIS project
#
#   bash .claude/scripts/update.sh            # update to the latest release (backup first)
#   bash .claude/scripts/update.sh --check    # only show installed vs latest
#   bash .claude/scripts/update.sh v2.3.0     # update / roll back to a specific release
#
# Keeps: your profile + state, learned PROJECT_CONVENTIONS.md, PROJECT_NOTES.md, gate.local.conf.
# Only release TAGS are ever downloaded and run — never the master branch.
# Mirror: AI_ORCH_REPO=<owner/repo> (GitHub)
# ============================================================
set -euo pipefail
REPO="${AI_ORCH_REPO:-AscEmon/flutter-ai-orchestration}"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"
[ -f pubspec.yaml ] || { echo "✖ Run this inside your Flutter project."; exit 1; }

CURRENT=$(grep '^version=' .claude/ai-orchestration.version 2>/dev/null | cut -d= -f2 || true)
CURRENT="${CURRENT:-unknown}"

latest_tag() {
    git ls-remote --tags --refs "https://github.com/${REPO}.git" 'v*' 2>/dev/null \
      | sed 's#.*refs/tags/##' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
      | sed 's/^v//' | sort -t. -k1,1n -k2,2n -k3,3n | tail -1 | sed 's/^/v/'
}

TARGET=""; CHECK=0
for a in "$@"; do
    case "$a" in
        --check) CHECK=1 ;;
        v[0-9]*) TARGET="$a" ;;
        *) echo "✖ Unknown option: $a"; exit 1 ;;
    esac
done
if [ -z "$TARGET" ]; then
    TARGET=$(latest_tag)
    [ -n "$TARGET" ] || { echo "✖ Could not read releases from github.com/$REPO (offline? proxy?)"; exit 1; }
fi

echo "• Installed: $CURRENT"
echo "• Target:    $TARGET   (changes: https://github.com/$REPO/blob/$TARGET/CHANGELOG.md)"
[ "$CHECK" = 1 ] && exit 0
if [ "$CURRENT" = "$TARGET" ]; then echo "✔ Already up to date."; exit 0; fi

if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    echo "⚠ You have uncommitted changes. Commit them first so the update is easy to review and undo:"
    echo "    git add -A && git commit -m \"wip\""
    exit 1
fi

curl -fsSL "https://raw.githubusercontent.com/${REPO}/${TARGET}/get.sh" \
  | AI_ORCH_VERSION="$TARGET" AI_ORCH_REPO="$REPO" bash -s -- --force

echo ""
echo "Review and commit the update:"
echo "    git diff --stat && git add -A && git commit -m \"chore: update AI orchestration to $TARGET\""
