#!/usr/bin/env bash
# ============================================================
# .claude/hooks/stop_gate.sh
#
# Claude Code Stop Hook — the "loop engineering" gate.
# Blocks Claude from finishing until the work passes:
#   1. flutter analyze   (errors + warnings)
#   2. check_rules.sh    (AGENTS.md golden rules + required tests)
#   3. flutter test
#
# Exit 2 = keep working (stderr is fed back to Claude as the failure report)
# Exit 0 = allow stop
# Retry budget: STOP_GATE_MAX_RETRIES (default 3), then hand back to the human.
# ============================================================
set -uo pipefail
cat >/dev/null                                   # drain hook JSON from stdin

ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$ROOT" || exit 0

MAX="${STOP_GATE_MAX_RETRIES:-3}"
CNT=".claude/tmp/stop_gate_count"
mkdir -p .claude/tmp

# Nothing to verify: no Dart changes, or not a Flutter project / no SDK.
[ -f pubspec.yaml ] || exit 0
command -v flutter >/dev/null 2>&1 || { echo "stop_gate: flutter not on PATH, gate skipped" >&2; exit 0; }
if [ -z "$(git status --porcelain -- lib test 2>/dev/null)" ]; then rm -f "$CNT"; exit 0; fi

n=$(cat "$CNT" 2>/dev/null || echo 0)
if [ "$n" -ge "$MAX" ]; then
    rm -f "$CNT"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] STOP_GATE ESCALATED after $MAX retries" >> .claude/audit.log
    echo "Stop gate failed $MAX times. STOP and report the remaining failures to the user." >&2
    exit 0
fi

fail() {
    echo $((n + 1)) > "$CNT"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] STOP_GATE FAIL ($1) attempt $((n + 1))/$MAX" >> .claude/audit.log
    {
        echo "STOP GATE FAILED — $1 (attempt $((n + 1))/$MAX)."
        echo "Fix the CODE, not the tests or lint config. Then finish again."
        echo "----"
        echo "$2" | tail -60
    } >&2
    exit 2
}

out=$(flutter analyze --no-pub --no-fatal-infos 2>&1) || fail "flutter analyze" "$out"
out=$(bash .claude/hooks/check_rules.sh 2>&1)          || fail "golden rules / missing tests" "$out"
if find test -name '*_test.dart' -print -quit 2>/dev/null | grep -q .; then
    out=$(flutter test --no-pub 2>&1)                  || fail "flutter test" "$out"
fi

rm -f "$CNT"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] STOP_GATE PASS" >> .claude/audit.log
exit 0
