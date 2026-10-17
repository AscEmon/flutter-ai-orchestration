#!/usr/bin/env bash
# ============================================================
# .claude/hooks/stop_gate.sh — the "loop engineering" gate
#
# Claude Code Stop hook: blocks "done" until the work passes
#   1. check_rules.sh   (profile rules · required tests · test integrity)
#   2. analyzer         (ANALYZE_SCOPE=changed: errors anywhere + warnings in changed files | all)
#   3. tests            (TEST_SCOPE=all | related: tests for changed files only)
#
# Exit 2 = keep working (stderr is fed back to Claude as the failure report)
# Exit 0 = allow stop. Retry budget: STOP_GATE_MAX_RETRIES (default 3), then hand back to the human.
# Other IDEs / manual run:  bash .claude/hooks/stop_gate.sh --manual   (prints result, exit 1 on failure)
# Scopes are set in .claude/gate.conf (profile) and .claude/gate.local.conf (your overrides).
# ============================================================
set -uo pipefail
MANUAL=0; [ "${1:-}" = "--manual" ] && MANUAL=1
[ $MANUAL -eq 1 ] || cat >/dev/null                         # drain hook JSON from stdin

ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$ROOT" || exit 0
# shellcheck disable=SC1091
. .claude/hooks/_gate_config.sh

MAX="${STOP_GATE_MAX_RETRIES:-3}"
CNT=".claude/tmp/stop_gate_count"
mkdir -p .claude/tmp
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> .claude/audit.log; }

[ -f pubspec.yaml ] || exit 0
command -v flutter >/dev/null 2>&1 || { echo "stop_gate: flutter not on PATH, gate skipped" >&2; exit 0; }
CHANGED=$(changed_files lib test integration_test)
if [ -z "$CHANGED" ] && [ $MANUAL -eq 0 ]; then rm -f "$CNT"; exit 0; fi

n=$(cat "$CNT" 2>/dev/null || echo 0)
if [ $MANUAL -eq 0 ] && [ "$n" -ge "$MAX" ]; then
    rm -f "$CNT"; log "STOP_GATE ESCALATED after $MAX retries"
    echo "Stop gate failed $MAX times. STOP and report the remaining failures to the user." >&2
    exit 0
fi

fail() {
    if [ $MANUAL -eq 1 ]; then echo "✖ GATE FAILED — $1"; echo "$2" | tail -60; exit 1; fi
    echo $((n + 1)) > "$CNT"; log "STOP_GATE FAIL ($1) attempt $((n + 1))/$MAX"
    { echo "STOP GATE FAILED — $1 (attempt $((n + 1))/$MAX)."
      echo "Fix the CODE, not the tests or lint config. Then finish again."
      echo "----"; echo "$2" | tail -60; } >&2
    exit 2
}

# 1. Rules
out=$(bash .claude/hooks/check_rules.sh 2>&1) || fail "rules / missing tests / test integrity" "$out"

# 2. Analyzer
if [ "$ANALYZE_SCOPE" = "all" ] || ! command -v dart >/dev/null 2>&1; then
    out=$(flutter analyze --no-pub --no-fatal-infos 2>&1) || fail "flutter analyze" "$out"
else
    # machine format: SEVERITY|TYPE|CODE|FILE|LINE|COL|LEN|MESSAGE
    raw=$(dart analyze --format=machine 2>&1 || true)
    errors=$(echo "$raw" | awk -F'|' '$1=="ERROR"')
    warns=""
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        w=$(echo "$raw" | awk -F'|' -v f="/$f" '$1=="WARNING" && index($4, f) && substr($4, length($4)-length(f)+1)==f')
        [ -n "$w" ] && warns="${warns}${w}
"
    done <<< "$CHANGED"
    issues=$(printf '%s\n%s' "$errors" "$warns" | sed '/^$/d' \
             | awk -F'|' '{ printf "%s %s:%s:%s %s (%s)\n", $1, $4, $5, $6, $8, $3 }')
    [ -z "$issues" ] || fail "analyzer (errors anywhere, warnings in changed files)" "$issues"
fi

# 3. Tests
if find test -name '*_test.dart' -print -quit 2>/dev/null | grep -q .; then
    if [ "$TEST_SCOPE" = "related" ]; then
        targets=""
        while IFS= read -r f; do
            [ -z "$f" ] && continue
            case "$f" in
                test/*_test.dart) targets="$targets $f" ;;
                lib/*) base=$(basename "$f" .dart)
                       t=$(find test -name "${base}_test.dart" 2>/dev/null | head -5 | tr '\n' ' ')
                       targets="$targets $t" ;;
            esac
        done <<< "$CHANGED"
        targets=$(echo "$targets" | tr ' ' '\n' | sed '/^$/d' | sort -u | tr '\n' ' ')
        if [ -n "$targets" ]; then
            # shellcheck disable=SC2086
            out=$(flutter test --no-pub $targets 2>&1) || fail "flutter test (related)" "$out"
        fi
    else
        out=$(flutter test --no-pub 2>&1) || fail "flutter test" "$out"
    fi
fi

rm -f "$CNT"; log "STOP_GATE PASS"
[ $MANUAL -eq 1 ] && echo "✔ Gate passed (profile: $PROFILE, analyze: $ANALYZE_SCOPE, tests: $TEST_SCOPE)"
exit 0
