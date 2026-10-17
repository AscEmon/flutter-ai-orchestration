#!/usr/bin/env bash
# ============================================================
# install.sh — install (or upgrade) flutter-ai-orchestration into a Flutter project
#
# Usage:
#   ./install.sh /path/to/flutter_project                        # first install: asks which coding pattern (ssl_cli or your own)
#   ./install.sh /path/to/flutter_project --force                # upgrade (backs up first)
#   ./install.sh /path/to/flutter_project --profile=generic      # ssl | generic
#   ./install.sh /path/to/flutter_project --state=bloc           # riverpod | bloc | custom
#   ./install.sh /path/to/empty_folder                           # creates the Flutter project (+ ssl_cli create if chosen)
#   --yes / AI_ORCH_YES=1                                        # approve prompts (needed without a terminal, e.g. CI)
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
YES="${AI_ORCH_YES:-0}"
PROFILE_FROM_MENU=0; CREATED_FLUTTER=0; SSL_CREATED=0
[ -n "$DEST" ] || { echo "Usage: ./install.sh /path/to/flutter_project [--force] [--profile=ssl|generic] [--state=riverpod|bloc|custom]"; exit 1; }
shift
for arg in "$@"; do
    case "$arg" in
        --force)     FORCE="--force" ;;
        --state=*)   STATE="${arg#--state=}" ;;
        --profile=*) PROFILE="${arg#--profile=}" ;;
        --yes|-y)    YES=1 ;;
        *) echo "✖ Unknown option: $arg"; exit 1 ;;
    esac
done
DEST="$(cd "$DEST" && pwd)"
PUB="$DEST/pubspec.yaml"
[ "$SRC" != "$DEST" ] || { echo "✖ Target is this template repo itself."; exit 1; }

if { exec 3</dev/tty; } 2>/dev/null; then HAS_TTY=1; exec 3<&-; else HAS_TTY=0; fi
ask_tty() {  # ask_tty "prompt" → echoes answer ('' when no terminal, e.g. CI)
    local ans=""
    if { exec 3</dev/tty; } 2>/dev/null; then printf "%s" "$1" >&2; read -r ans <&3 || ans=""; exec 3<&-; fi
    echo "$ans"
}
confirm() {  # confirm "question" Y|N  → 0 = yes. --yes / AI_ORCH_YES=1 answers yes; no terminal → default
    local def="$2" ans
    [ "$YES" = 1 ] && return 0
    if [ "$HAS_TTY" = 1 ]; then
        ans=$(ask_tty "$1 [$( [ "$def" = Y ] && echo "Y/n" || echo "y/N" )] ")
    else
        # No terminal: never approve an action on our own — needs --yes / AI_ORCH_YES=1
        [ "$def" = Y ] && echo "  (no terminal — re-run with --yes to approve:$1)" >&2
        return 1
    fi
    case "${ans:-$def}" in [Yy]*) return 0 ;; *) return 1 ;; esac
}
pkg_name() {  # folder name → valid Dart package name
    local n; n=$(basename "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9_]+/_/g; s/^_+//; s/_+$//')
    case "$n" in [0-9]*|"") n="app_$n" ;; esac
    echo "${n%_}"
}

# Empty folder → offer to create the Flutter project here
if [ ! -f "$PUB" ]; then
    others=$(ls -A "$DEST" | grep -vE '^(\.git|\.DS_Store|README.*|LICENSE.*|\.gitignore)$' || true)
    if [ -n "$others" ]; then echo "✖ Not a Flutter project (no pubspec.yaml) and the folder isn't empty: $DEST"; exit 1; fi
    command -v flutter >/dev/null 2>&1 || { echo "✖ Empty folder and flutter is not on PATH — install Flutter, or run this inside a Flutter project."; exit 1; }
    NAME_DEFAULT=$(pkg_name "$DEST")
    echo "• No Flutter project in this folder yet." >&2
    confirm "  Create a new Flutter project here?" Y || { echo "✖ Cancelled."; exit 1; }
    NAME="$NAME_DEFAULT"
    if [ "$HAS_TTY" = 1 ] && [ "$YES" != 1 ]; then
        n=$(ask_tty "  Project name [$NAME_DEFAULT]: "); [ -n "$n" ] && NAME=$(pkg_name "$n")
    fi
    echo "• flutter create --project-name $NAME ." >&2
    (cd "$DEST" && flutter create --project-name "$NAME" . >/dev/null) || { echo "✖ flutter create failed"; exit 1; }
    CREATED_FLUTTER=1
fi

VERSION_FILE="$DEST/.claude/ai-orchestration.version"
MANIFEST="$DEST/.claude/ai-orchestration.manifest"
UNLEARNED="ai-orch:unlearned"
OLD_PROFILE=""; OLD_STATE=""
if [ -f "$VERSION_FILE" ]; then
    OLD_PROFILE=$(grep '^profile=' "$VERSION_FILE" | cut -d= -f2 || true)
    OLD_STATE=$(grep '^state=' "$VERSION_FILE" | cut -d= -f2 || true)
fi
has_dep() { grep -qE "^[[:space:]]+($1):" "$PUB"; }
# New project = fresh `flutter create` scaffold: ≤1 Dart file in lib/, no lib/core, no state-management package
lib_dart=$(find "$DEST/lib" -name '*.dart' 2>/dev/null | wc -l | tr -d ' ')
IS_NEW=0
if [ "$lib_dart" -le 1 ] && [ ! -d "$DEST/lib/core" ] && [ -z "$OLD_PROFILE" ] \
   && ! has_dep 'flutter_bloc|flutter_riverpod|hooks_riverpod|riverpod|provider|get|mobx|flutter_mobx|stacked|flutter_redux|signals'; then
    IS_NEW=1
fi
IS_SSL=0
if has_dep autosafe_json || [ -f "$DEST/lib/core/presentation/widgets/global_text.dart" ] \
   || grep -qs "orchestration v1" "$DEST/CLAUDE.md"; then IS_SSL=1; fi


# ── Profile ───────────────────────────────────────────────
SSL_CLI_URL="https://pub.dev/packages/ssl_cli"
AUTOSAFE_URL="https://pub.dev/packages/autosafe_json"
if [ -z "$PROFILE" ] && [ -n "$OLD_PROFILE" ]; then
    PROFILE="$OLD_PROFILE"
    echo "• Profile: $PROFILE (from previous install — use --profile=ssl|generic to change)"
elif [ -z "$PROFILE" ]; then
    # Recommend based on what the project looks like, but let the developer decide.
    if [ "$IS_SSL" = 1 ]; then
        REC=1; REC_WHY="this project was created with ssl_cli"
    elif [ "$IS_NEW" = 1 ]; then
        REC=1; REC_WHY="new project — ssl_cli generates a ready-made Clean Architecture structure for you"
    else
        REC=2; REC_WHY="existing project — keep your own pattern"
    fi
    cat >&2 <<MENU

  ┌────────────────────────────────────────────────────────────────────┐
  │  Which coding pattern should the AI agent follow in this project?  │
  └────────────────────────────────────────────────────────────────────┘

  1) ssl_cli pattern — Clean Architecture scaffolded by ssl_cli
       • Feature modules generated with:  ssl_cli module <name>
       • Global widgets (GlobalText, GlobalButton, GlobalAppBar…), flutter_screenutil
       • Safe JSON with autosafe_json (SafeJson.as*), Either<Failure, T>, GetIt DI, envied secrets
       • Riverpod or Bloc
       Learn the pattern:  $SSL_CLI_URL
                           $AUTOSAFE_URL
       Best for: NEW apps (I'll run 'ssl_cli create' for you) or projects already created with ssl_cli.

  2) Your own pattern (generic) — any architecture, any state management
       • MVC, MVVM, Clean Architecture, feature-first or layer-first…
       • Riverpod, Bloc, Provider, GetX, MobX…
       • The AI learns YOUR conventions from your code (/bootstrap) and you review them.
       Best for: existing projects and teams that don't use ssl_cli.

  Recommended: $REC  ($REC_WHY)
MENU
    if [ "$HAS_TTY" = 0 ]; then
        echo "  (no terminal — using the recommendation; pass --profile=ssl|generic to choose)" >&2
        ans=""
    fi
    for _try in 1 2 3; do
        [ "$HAS_TTY" = 1 ] && ans=$(ask_tty "  Choose 1 or 2 [Enter = $REC]: ")
        case "${ans:-$REC}" in
            1|ssl)     PROFILE="ssl"; PROFILE_FROM_MENU=1; break ;;
            2|generic) PROFILE="generic"; PROFILE_FROM_MENU=1; break ;;
            *) echo "  Please type 1 or 2." >&2; [ "$HAS_TTY" = 1 ] || break ;;
        esac
    done
    [ -n "$PROFILE" ] || { echo "✖ No valid choice. Re-run and choose 1 or 2 (or pass --profile=ssl|generic)"; exit 1; }
    echo "• Profile: $PROFILE"
else
    echo "• Profile: $PROFILE"
fi
[ -d "$SRC/profiles/$PROFILE" ] || { echo "✖ Unknown profile '$PROFILE' (available: $(ls "$SRC/profiles" | tr '\n' ' '))"; exit 1; }
if [ "$PROFILE" = "ssl" ]; then
    command -v ssl_cli >/dev/null 2>&1 || echo "  ℹ ssl_cli not installed — dart pub global activate ssl_cli   ($SSL_CLI_URL)"
    command -v autosafe >/dev/null 2>&1 || echo "  ℹ autosafe not installed — dart pub global activate autosafe_json   ($AUTOSAFE_URL)"
fi

# ── ssl profile: scaffold a NEW project with ssl_cli, guard existing ones ──
if [ "$PROFILE" = "ssl" ] && [ "$IS_SSL" = 0 ]; then
    if [ "$IS_NEW" = 1 ]; then
        NAME=$(grep -E '^name:' "$PUB" | head -1 | sed -E 's/^name:[[:space:]]*//; s/[[:space:]]+$//')
        echo "" >&2
        echo "• New project + ssl_cli pattern → I'll run: ssl_cli create $NAME  (pattern 4 · Clean Architecture)" >&2
        # ssl_cli binary (installs it if missing)
        SSL_CLI=$(command -v ssl_cli || true)
        [ -z "$SSL_CLI" ] && [ -x "$HOME/.pub-cache/bin/ssl_cli" ] && SSL_CLI="$HOME/.pub-cache/bin/ssl_cli"
        if [ -z "$SSL_CLI" ]; then
            command -v dart >/dev/null 2>&1 || { echo "✖ dart is not on PATH — install Flutter first."; exit 1; }
            if confirm "  ssl_cli is not installed. Install it now (dart pub global activate ssl_cli)?" Y; then
                dart pub global activate ssl_cli >/dev/null || { echo "✖ Could not install ssl_cli — see $SSL_CLI_URL"; exit 1; }
                dart pub global activate autosafe_json >/dev/null || echo "  ⚠ autosafe_json not installed — see $AUTOSAFE_URL"
                SSL_CLI=$(command -v ssl_cli || echo "$HOME/.pub-cache/bin/ssl_cli")
                case ":$PATH:" in *":$HOME/.pub-cache/bin:"*) ;; *) echo "  ℹ Add to your shell profile:  export PATH=\"\$PATH:\$HOME/.pub-cache/bin\"" >&2 ;; esac
            else
                echo "✖ ssl_cli is required for this choice. Install: dart pub global activate ssl_cli  ($SSL_CLI_URL)"; exit 1
            fi
        fi
        # state management for ssl_cli (1 Riverpod / 2 Bloc)
        case "$STATE" in
            riverpod) SM=1 ;; bloc) SM=2 ;;
            "")
                if [ "$HAS_TTY" = 1 ] && [ "$YES" != 1 ]; then
                    SM=""
                    for _try in 1 2 3; do
                        SM=$(ask_tty "$(printf "  Select state management for ssl_cli\n    1 for Riverpod\n    2 for Bloc\n  > ")")
                        case "$SM" in 1|2) break ;; *) echo "  Please type 1 or 2." >&2; SM="" ;; esac
                    done
                    [ -n "$SM" ] || { echo "✖ No state management chosen."; exit 1; }
                else
                    echo "✖ No terminal: pass --state=riverpod or --state=bloc for ssl_cli create"; exit 1
                fi ;;
            *) echo "✖ ssl_cli supports --state=riverpod or --state=bloc (got '$STATE')"; exit 1 ;;
        esac
        STATE=$([ "$SM" = 1 ] && echo riverpod || echo bloc)
        echo "  ssl_cli create replaces lib/main.dart and adds its packages to pubspec.yaml (fine for a fresh project)." >&2
        confirm "  Run 'ssl_cli create $NAME' with $STATE now?" Y || { echo "✖ Cancelled — nothing was changed."; exit 1; }
        # ssl_cli prompts: continue (y) → pattern (4 = Clean Architecture) → state management (1/2)
        if ! (cd "$DEST" && printf 'y\n4\n%s\n' "$SM" | "$SSL_CLI" create "$NAME"); then
            echo "✖ ssl_cli create failed. Run it yourself: cd \"$DEST\" && ssl_cli create $NAME  (pattern 4, state $SM), then re-run this installer."; exit 1
        fi
        if [ ! -d "$DEST/lib/core" ]; then
            echo "✖ ssl_cli create finished but lib/core was not generated. Run 'ssl_cli create $NAME' manually (pattern 4), then re-run this installer."; exit 1
        fi
        echo "• ssl_cli project generated ($STATE)" >&2
        IS_SSL=1; SSL_CREATED=1
    else
        echo "" >&2
        echo "  ⚠ This is an EXISTING project that wasn't created with ssl_cli." >&2
        echo "    I won't run 'ssl_cli create' here — it would overwrite your code." >&2
        echo "    The ssl rules expect ssl_cli's structure (lib/core, Global widgets, SafeJson…)." >&2
        if [ "$PROFILE_FROM_MENU" = 1 ] && ! confirm "  Use the ssl_cli rules anyway?" N; then
            PROFILE="generic"; echo "• Profile: generic (your own pattern)"
        fi
    fi
fi

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
    echo "⚠ lib/core not found — the ssl profile expects a project created by ssl_cli ($SSL_CLI_URL)."
    echo "    New app?      ssl_cli create <name>  (pattern 4), then run this installer inside it."
    echo "    Existing app? Re-run with --profile=generic --force to use your own pattern."
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
    if command -v "$t" >/dev/null 2>&1; then echo "  ✔ $t"
    elif [ -x "$HOME/.pub-cache/bin/$t" ]; then echo "  ✔ $t (in ~/.pub-cache/bin — add it to PATH)"
    else echo "  ✖ $t (not on PATH)"; fi
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
