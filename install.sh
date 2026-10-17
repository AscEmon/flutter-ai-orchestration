#!/usr/bin/env bash
# ============================================================
# install.sh — install (or upgrade) flutter-ai-orchestration into a Flutter project
#
# Usage:
#   ./install.sh /path/to/flutter_project                        # auto-detect profile + state management
#   ./install.sh /path/to/flutter_project --force                # upgrade (backs up first)
#   ./install.sh /path/to/flutter_project --profile=generic      # ssl | generic
#   ./install.sh /path/to/flutter_project --state=bloc           # riverpod | bloc | custom
# Env alternatives (handy with curl | bash): AI_ORCH_PROFILE, AI_ORCH_STATE
#
# Profiles
#   ssl      projects made with ssl_cli (Mobile Team house style: Global widgets, SafeJson, GetIt, envied)
#   generic  ANY Flutter project — conventions are learned from the codebase by /bootstrap
#
# Never touches: .env, keystores, lib/, test/, pubspec.yaml, .claude/settings.local.json, .claude/gate.local.conf
# ============================================================
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="${1:-}"
FORCE=""
STATE="${AI_ORCH_STATE:-}"
PROFILE="${AI_ORCH_PROFILE:-}"
[ -n "$DEST" ] || { echo "Usage: ./install.sh /path/to/flutter_project [--force] [--profile=ssl|generic] [--state=riverpod|bloc|custom]"; exit 1; }
shift
for arg in "$@"; do
    case "$arg" in
        --force)     FORCE="--force" ;;
        --state=*)   STATE="${arg#--state=}" ;;
        --profile=*) PROFILE="${arg#--profile=}" ;;
        *) echo "✖ Unknown option: $arg"; exit 1 ;;
    esac
done
DEST="$(cd "$DEST" && pwd)"
PUB="$DEST/pubspec.yaml"
[ -f "$PUB" ] || { echo "✖ Not a Flutter project (no pubspec.yaml): $DEST"; exit 1; }
[ "$SRC" != "$DEST" ] || { echo "✖ Target is this template repo itself."; exit 1; }

VERSION_FILE="$DEST/.claude/ai-orchestration.version"
MANIFEST="$DEST/.claude/ai-orchestration.manifest"
UNLEARNED="ai-orch:unlearned"
OLD_PROFILE=""; OLD_STATE=""
if [ -f "$VERSION_FILE" ]; then
    OLD_PROFILE=$(grep '^profile=' "$VERSION_FILE" | cut -d= -f2 || true)
    OLD_STATE=$(grep '^state=' "$VERSION_FILE" | cut -d= -f2 || true)
fi
has_dep() { grep -qE "^[[:space:]]+($1):" "$PUB"; }
ask_tty() {  # ask_tty "prompt" → echoes answer ('' when no terminal, e.g. CI)
    local ans=""
    if { exec 3</dev/tty; } 2>/dev/null; then printf "%s" "$1" >&2; read -r ans <&3 || ans=""; exec 3<&-; fi
    echo "$ans"
}

# ── Profile ───────────────────────────────────────────────
if [ -z "$PROFILE" ]; then
    if [ -n "$OLD_PROFILE" ]; then PROFILE="$OLD_PROFILE"
    elif has_dep autosafe_json || [ -f "$DEST/lib/core/presentation/widgets/global_text.dart" ] \
         || grep -qs "orchestration v1" "$DEST/CLAUDE.md"; then PROFILE="ssl"
    else PROFILE="generic"; fi
fi
[ -d "$SRC/profiles/$PROFILE" ] || { echo "✖ Unknown profile '$PROFILE' (available: $(ls "$SRC/profiles" | tr '\n' ' '))"; exit 1; }
echo "• Profile: $PROFILE"

# ── State management ──────────────────────────────────────
STATE_PKG=""
if [ -z "$STATE" ] && [ -n "$OLD_STATE" ] && [ "$OLD_PROFILE" = "$PROFILE" ]; then STATE="$OLD_STATE"; fi
if [ -z "$STATE" ]; then
    b=0; r=0; has_dep flutter_bloc && b=1; has_dep 'flutter_riverpod|hooks_riverpod|riverpod' && r=1
    if [ $b -eq 1 ] && [ $r -eq 1 ]; then
        echo "✖ Both flutter_bloc and Riverpod are in pubspec.yaml — choose one with --state=riverpod|bloc"; exit 1
    elif [ $b -eq 1 ]; then STATE="bloc"
    elif [ $r -eq 1 ]; then STATE="riverpod"
    else
        for p in provider get mobx flutter_mobx stacked flutter_redux signals; do
            if has_dep "$p"; then STATE_PKG="$p"; break; fi
        done
        if [ -n "$STATE_PKG" ] && [ "$PROFILE" = "generic" ]; then
            STATE="custom"
        else
            echo "• No flutter_bloc / flutter_riverpod in pubspec.yaml."
            extra=""; [ "$PROFILE" = "generic" ] && extra="    3 for Other / learn from the code\n"
            ans=$(ask_tty "$(printf "  Select state management\n    1 for Riverpod\n    2 for Bloc\n${extra}  > ")")
            case "$ans" in
                1|riverpod) STATE="riverpod" ;;
                2|bloc)     STATE="bloc" ;;
                3|custom)   [ "$PROFILE" = "generic" ] && STATE="custom" ;;
            esac
            if [ -z "$STATE" ]; then
                if [ "$PROFILE" = "generic" ]; then STATE="custom"
                else echo "✖ No state management chosen. Re-run with --state=riverpod or --state=bloc"; exit 1; fi
            fi
        fi
    fi
fi
STATE_PACK="$SRC/profiles/$PROFILE/state-management/$STATE.md"
[ -f "$STATE_PACK" ] || { echo "✖ State management '$STATE' is not available for profile '$PROFILE' (available: $(ls "$SRC/profiles/$PROFILE/state-management" | sed 's/\.md$//' | tr '\n' ' '))"; exit 1; }
echo "• State management: $STATE${STATE_PKG:+ ($STATE_PKG)}"

# ── Existing installation ─────────────────────────────────
FILES=(AGENTS.md CLAUDE.md .mcp.json)
existing=()
for f in "${FILES[@]}" .claude; do [ -e "$DEST/$f" ] && existing+=("$f"); done
if [ ${#existing[@]} -gt 0 ]; then
    if [ "$FORCE" != "--force" ]; then
        if [ ! -f "$VERSION_FILE" ] && grep -qs "orchestration v1" "$DEST/CLAUDE.md"; then
            echo "• Found AI docs v1 generated by ssl_cli → upgrading to v2"
        elif [ -f "$VERSION_FILE" ]; then
            echo "✖ Already installed: $(grep '^version=' "$VERSION_FILE" | cut -d= -f2) ($OLD_PROFILE/$OLD_STATE). Re-run with --force to upgrade (a backup is made first)."
            exit 1
        else
            echo "✖ Existing AI files found: ${existing[*]}"
            echo "  Re-run with --force to replace them (a backup is made first; your own files in .claude/ are kept)."
            exit 1
        fi
    fi
    BK="$DEST/.ai-orchestration-backup/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BK"
    for f in "${existing[@]}"; do cp -R "$DEST/$f" "$BK/"; done
    echo "• Backup of current files → ${BK#$DEST/}"

    # Remove files managed by the previous install (keeps your own files and learned conventions)
    managed=()
    if [ -f "$MANIFEST" ]; then
        while IFS= read -r m; do [ -n "$m" ] && managed+=("$m"); done < "$MANIFEST"
    else  # v1 (ssl_cli) / v2.0.x layout
        managed=(.claude/rules/ARCHITECTURE.md .claude/rules/CLI_WORKFLOW.md .claude/rules/CODE_TEMPLATES.md
                 .claude/rules/UI_RULES.md .claude/skills/clean_architecture_pattern.md)
        [ -d "$DEST/.claude/state-management" ] && rm -rf "$DEST/.claude/state-management"
        [ -f "$DEST/.claude/rules/STATE_MANAGEMENT.md" ] && managed+=(.claude/rules/STATE_MANAGEMENT.md)
    fi
    for m in "${managed[@]}"; do
        case "$m" in .claude/rules/PROJECT_CONVENTIONS.md|.claude/rules/STATE_MANAGEMENT.md) continue ;; esac
        rm -f "$DEST/$m"
    done
fi

# ── 1. Core files ─────────────────────────────────────────
NEW_MANIFEST=()
for f in "${FILES[@]}"; do cp "$SRC/$f" "$DEST/$f"; NEW_MANIFEST+=("$f"); done
mkdir -p "$DEST/.claude/rules" "$DEST/.claude/skills" "$DEST/docs/specs"
EXCL=(settings.local.json audit.log tmp .DS_Store gate.local.conf ai-orchestration.version ai-orchestration.manifest)
if command -v rsync >/dev/null 2>&1; then
    rsync -a $(printf -- '--exclude %s ' "${EXCL[@]}") "$SRC/.claude/" "$DEST/.claude/"
else
    (cd "$SRC/.claude" && tar $(printf -- '--exclude ./%s ' "${EXCL[@]}") -cf - .) | (cd "$DEST/.claude" && tar -xf -)
fi
while IFS= read -r f; do NEW_MANIFEST+=(".claude/${f#./}"); done < <(cd "$SRC/.claude" && find . -type f ! -name .DS_Store ! -name audit.log ! -name settings.local.json ! -name gate.local.conf ! -path './tmp/*')
touch "$DEST/docs/specs/.gitkeep"
echo "• Core: AGENTS.md, CLAUDE.md, .mcp.json, .claude/ (hooks, agents, commands, scripts, docs)"

# ── 2. Profile files ──────────────────────────────────────
P="$SRC/profiles/$PROFILE"
for kind in rules skills; do
    [ -d "$P/$kind" ] || continue
    for f in "$P/$kind"/*; do
        name=$(basename "$f")
        [ "$kind/$name" = "rules/PROJECT_CONVENTIONS.md" ] && continue
        cp "$f" "$DEST/.claude/$kind/$name"; NEW_MANIFEST+=(".claude/$kind/$name")
    done
done
cp "$P/gate.conf" "$DEST/.claude/gate.conf"; NEW_MANIFEST+=(".claude/gate.conf")

# learned files are preserved unless still placeholders, or the profile changed
write_learned() {  # write_learned <src> <dest> [sed-expr]
    local src="$1" dst="$2" expr="${3:-}"
    if [ "$PROFILE" = "ssl" ] || [ ! -f "$dst" ] || grep -q "$UNLEARNED" "$dst" \
       || { [ -n "$OLD_PROFILE" ] && [ "$OLD_PROFILE" != "$PROFILE" ]; } \
       || { [ "$(basename "$dst")" = "STATE_MANAGEMENT.md" ] && [ "$STATE" != "custom" ]; } \
       || { [ "$(basename "$dst")" = "STATE_MANAGEMENT.md" ] && [ -n "$OLD_STATE" ] && [ "$OLD_STATE" != "$STATE" ]; }; then
        if [ -n "$expr" ]; then sed "$expr" "$src" > "$dst"; else cp "$src" "$dst"; fi
        echo "  - wrote ${dst#$DEST/}"
    else
        echo "  - kept ${dst#$DEST/} (already learned for this project)"
    fi
}
write_learned "$P/rules/PROJECT_CONVENTIONS.md" "$DEST/.claude/rules/PROJECT_CONVENTIONS.md"
write_learned "$STATE_PACK" "$DEST/.claude/rules/STATE_MANAGEMENT.md" "s/__STATE_PKG__/${STATE_PKG:-none}/"
NEW_MANIFEST+=(".claude/rules/PROJECT_CONVENTIONS.md" ".claude/rules/STATE_MANAGEMENT.md")
echo "• Profile '$PROFILE': .claude/rules/, .claude/skills/, .claude/gate.conf"

VERSION_TAG="${AI_ORCH_VERSION:-$(git -C "$SRC" describe --tags --always 2>/dev/null || echo dev)}"
printf 'version=%s\nprofile=%s\nstate=%s\ninstalled=%s\n' "$VERSION_TAG" "$PROFILE" "$STATE" "$(date +%Y-%m-%d)" > "$VERSION_FILE"
printf '%s\n' "${NEW_MANIFEST[@]}" | sort -u > "$MANIFEST"
[ -f "$DEST/.env.example" ] || { cp "$SRC/.env.example" "$DEST/.env.example"; echo "• Added .env.example (placeholders only)"; }
chmod +x "$DEST"/.claude/hooks/*.sh "$DEST"/.claude/scripts/*.sh

# ── Hints ─────────────────────────────────────────────────
if [ "$PROFILE" = "ssl" ] && [ ! -d "$DEST/lib/core" ]; then
    echo "⚠ lib/core not found — the ssl profile expects an ssl_cli project. Not one? Re-run with --profile=generic --force"
fi
case "$STATE" in
    bloc)     has_dep flutter_bloc || echo "⚠ flutter_bloc is not in pubspec.yaml yet — run: flutter pub add flutter_bloc  (or let /bootstrap do it)" ;;
    riverpod) has_dep 'flutter_riverpod|hooks_riverpod|riverpod' || echo "⚠ flutter_riverpod is not in pubspec.yaml yet — run: flutter pub add flutter_riverpod  (or let /bootstrap do it)" ;;
esac

# ── 3. .gitignore (append only missing lines) ─────────────
GI="$DEST/.gitignore"; touch "$GI"
REQUIRED=(
  ".env" ".env.*" "!.env.example"
  "android/key.properties" "android/local.properties" "android/app/*.jks" "*.keystore"
  "ios/Flutter/Secret.xcconfig" "lib/core/config/env.g.dart"
  "google-services.json" "GoogleService-Info.plist" "serviceAccountKey.json" "*.p12" "*.pem"
  "*.env" "*.pfx" "secrets.dart" "api_keys.dart" "credentials.dart" "service-account.json" "service_account.json"
  ".claude/settings.local.json" ".claude/audit.log" ".claude/tmp/" ".claude/secret_guard_report.txt" ".ai-orchestration-backup/"
)
added=0
for line in "${REQUIRED[@]}"; do
    if ! grep -qxF -- "$line" "$GI"; then
        [ $added -eq 0 ] && printf '\n# --- flutter-ai-orchestration (secrets + AI runtime files) ---\n' >> "$GI"
        echo "$line" >> "$GI"; added=$((added + 1))
    fi
done
echo "• .gitignore: $added entr$( [ $added -eq 1 ] && echo y || echo ies) added"

# ── 4. Git pre-commit hook → secret scan for human commits too ──
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

# ── 5. Tool check (informational) ─────────────────────────
TOOLS="flutter dart claude flutter-skill"; [ "$PROFILE" = "ssl" ] && TOOLS="flutter dart ssl_cli autosafe claude flutter-skill"
echo ""; echo "Tool check:"
for t in $TOOLS; do
    if command -v "$t" >/dev/null 2>&1; then echo "  ✔ $t"; else echo "  ✖ $t (not on PATH)"; fi
done

echo ""; echo "Done. Next steps:"
echo "  1. cd \"$DEST\""
echo "  2. git add -A && git commit -m \"chore: add AI orchestration\"   # gates compare against this baseline"
if [ "$PROFILE" = "ssl" ]; then
    echo "  3. cp .env.example .env && sh .claude/scripts/setup_secrets.sh   # real values from the team vault — never paste them into the AI"
    echo "  4. claude   → /bootstrap   then   /spec <feature> <Figma / BRD / description>"
else
    echo "  3. claude   → /bootstrap   (reads your code and writes .claude/rules/PROJECT_CONVENTIONS.md for you to review)"
    echo "  4. then: /spec <feature> <Figma / BRD / description>"
fi
