#!/usr/bin/env bash
# ============================================================
# install.sh — install (or upgrade) flutter-ai-orchestration into a Flutter project
#
# Usage:
#   ./install.sh /path/to/flutter_project                    # first install (state mgmt auto-detected)
#   ./install.sh /path/to/flutter_project --force            # upgrade: backs up, then overwrites
#   ./install.sh /path/to/flutter_project --state=bloc       # force a state management: riverpod | bloc
#
# Never touches: .env, keystores, lib/, test/, pubspec.yaml, .claude/settings.local.json
# ============================================================
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="${1:-}"
FORCE=""
STATE=""
[ -n "$DEST" ] || { echo "Usage: ./install.sh /path/to/flutter_project [--force] [--state=riverpod|bloc]"; exit 1; }
shift
for arg in "$@"; do
    case "$arg" in
        --force)   FORCE="--force" ;;
        --state=*) STATE="${arg#--state=}" ;;
        *) echo "✖ Unknown option: $arg"; exit 1 ;;
    esac
done
DEST="$(cd "$DEST" && pwd)"
[ -f "$DEST/pubspec.yaml" ] || { echo "✖ Not a Flutter project (no pubspec.yaml): $DEST"; exit 1; }
[ "$SRC" != "$DEST" ] || { echo "✖ Target is this template repo itself."; exit 1; }

# State management: explicit --state, else detect from pubspec.yaml (what ssl_cli generated)
if [ -z "$STATE" ]; then
    has_bloc=$(grep -cE '^[[:space:]]+flutter_bloc:' "$DEST/pubspec.yaml" || true)
    has_riv=$(grep -cE '^[[:space:]]+(flutter_riverpod|hooks_riverpod):' "$DEST/pubspec.yaml" || true)
    if [ "$has_bloc" -gt 0 ] && [ "$has_riv" -gt 0 ]; then
        echo "✖ Both flutter_bloc and Riverpod found in pubspec.yaml — choose one: --state=riverpod or --state=bloc"; exit 1
    elif [ "$has_bloc" -gt 0 ]; then STATE="bloc"
    elif [ "$has_riv" -gt 0 ]; then STATE="riverpod"
    else
        echo "✖ Could not detect state management (no flutter_bloc / flutter_riverpod in pubspec.yaml)."
        echo "  Re-run with --state=riverpod or --state=bloc"; exit 1
    fi
fi
STATE_PACK="$SRC/.claude/state-management/$STATE.md"
[ -f "$STATE_PACK" ] || { echo "✖ Unsupported state management '$STATE' (supported: riverpod, bloc)"; exit 1; }
echo "• State management: $STATE"

FILES=(AGENTS.md CLAUDE.md .mcp.json)
existing=()
for f in "${FILES[@]}" .claude; do [ -e "$DEST/$f" ] && existing+=("$f"); done

if [ ${#existing[@]} -gt 0 ]; then
    if [ "$FORCE" != "--force" ]; then
        echo "✖ Already present in target: ${existing[*]}"
        echo "  Re-run with --force to upgrade (a backup is made first)."
        echo "  Note: 'ssl_cli create' already writes the v1 AI docs — use --force to upgrade them to v2."
        exit 1
    fi
    BK="$DEST/.ai-orchestration-backup/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BK"
    for f in "${existing[@]}"; do cp -R "$DEST/$f" "$BK/"; done
    echo "• Backup of current files → ${BK#$DEST/}"
fi

# 1. Copy orchestration files (personal/runtime files excluded)
for f in "${FILES[@]}"; do cp "$SRC/$f" "$DEST/$f"; done
mkdir -p "$DEST/.claude" "$DEST/docs/specs"
if command -v rsync >/dev/null 2>&1; then
    rsync -a --exclude settings.local.json --exclude audit.log --exclude tmp/ \
          --exclude state-management/ --exclude .DS_Store "$SRC/.claude/" "$DEST/.claude/"
else
    (cd "$SRC/.claude" && tar --exclude settings.local.json --exclude audit.log \
         --exclude ./tmp --exclude ./state-management --exclude .DS_Store -cf - .) | (cd "$DEST/.claude" && tar -xf -)
fi
touch "$DEST/docs/specs/.gitkeep"
cp "$STATE_PACK" "$DEST/.claude/rules/STATE_MANAGEMENT.md"
echo "• Presentation rules → .claude/rules/STATE_MANAGEMENT.md ($STATE)"
VERSION_TAG="${AI_ORCH_VERSION:-$(git -C "$SRC" describe --tags --always 2>/dev/null || echo dev)}"
printf 'version=%s\nstate=%s\ninstalled=%s\n' "$VERSION_TAG" "$STATE" "$(date +%Y-%m-%d)" > "$DEST/.claude/ai-orchestration.version"
if [ ! -f "$DEST/.env.example" ]; then cp "$SRC/.env.example" "$DEST/.env.example"; echo "• Added .env.example (placeholders only)"; fi
chmod +x "$DEST"/.claude/hooks/*.sh "$DEST"/.claude/scripts/*.sh
echo "• Copied AGENTS.md, CLAUDE.md, .mcp.json, .claude/, docs/specs/"

# 2. Merge required .gitignore entries (append only missing lines)
GI="$DEST/.gitignore"; touch "$GI"
REQUIRED=(
  ".env" ".env.*" "!.env.example"
  "android/key.properties" "android/local.properties" "android/app/*.jks" "*.keystore"
  "ios/Flutter/Secret.xcconfig" "lib/core/config/env.g.dart"
  "google-services.json" "GoogleService-Info.plist" "serviceAccountKey.json" "*.p12" "*.pem"
  ".claude/settings.local.json" ".claude/audit.log" ".claude/tmp/" ".ai-orchestration-backup/"
)
added=0
for line in "${REQUIRED[@]}"; do
    if ! grep -qxF -- "$line" "$GI"; then
        [ $added -eq 0 ] && printf '\n# --- flutter-ai-orchestration (secrets + AI runtime files) ---\n' >> "$GI"
        echo "$line" >> "$GI"; added=$((added + 1))
    fi
done
echo "• .gitignore: $added entr$( [ $added -eq 1 ] && echo y || echo ies) added"

# 3. Git pre-commit hook → secret scan for human commits too
if [ -d "$DEST/.git" ]; then
    HOOK="$DEST/.git/hooks/pre-commit"
    if [ -e "$HOOK" ] && ! grep -q "flutter-ai-orchestration" "$HOOK"; then
        echo "• Existing .git/hooks/pre-commit left untouched (add: bash .claude/hooks/pre_commit.sh)"
    else
        mkdir -p "$DEST/.git/hooks"
        cat > "$HOOK" <<'HOOK'
#!/bin/bash
# flutter-ai-orchestration: secret-leak scan before every commit (any IDE, any terminal)
ROOT="$(git rev-parse --show-toplevel)"
[ -f "$ROOT/.claude/hooks/pre_commit.sh" ] && exec bash "$ROOT/.claude/hooks/pre_commit.sh"
exit 0
HOOK
        chmod +x "$HOOK"
        echo "• Git pre-commit secret scan installed"
    fi
else
    echo "• Not a git repo yet — run 'git init' then re-run with --force to add the pre-commit hook"
fi

# 4. Tool check (informational)
echo ""
echo "Tool check:"
for t in flutter dart ssl_cli autosafe claude flutter-skill; do
    if command -v "$t" >/dev/null 2>&1; then echo "  ✔ $t"; else echo "  ✖ $t (not on PATH)"; fi
done

cat <<NEXT

Done. Next steps:
  1. cd "$DEST"
  2. cp .env.example .env   # fill real values from the team vault, never paste them into the AI
  3. sh .claude/scripts/setup_secrets.sh
  4. claude                 # then type: /spec <feature> <Figma link / BRD / description>
NEXT
