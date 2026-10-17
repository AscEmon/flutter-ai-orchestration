#!/usr/bin/env bash
# ============================================================
# .claude/hooks/check_rules.sh — config-driven rules check on CHANGED files
#   1. Banned patterns          (gate.conf → BANNED_PATTERNS, per profile)
#   2. Required tests           (gate.conf → REQUIRE_TESTS_FOR)
#   3. Test integrity           (no deleted tests, no new skip:/// ignore:)
# Run manually:  bash .claude/hooks/check_rules.sh
# CI mode:       CHECK_RULES_BASE=origin/main bash .claude/hooks/check_rules.sh
# Exit 1 = violations found
# ============================================================
set -uo pipefail
ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$ROOT" || exit 0
# shellcheck disable=SC1091
. .claude/hooks/_gate_config.sh

status=0
# shellcheck disable=SC2086
files=$(changed_files $RULES_SCOPE)

# 1. Banned patterns (comment lines ignored)
if [ -n "$files" ]; then
    hits_all=""
    while IFS= read -r rule; do
        [ -z "${rule// }" ] && continue
        case "$rule" in \#*) continue ;; esac
        re="${rule%%|||*}"; msg="${rule#*|||}"; [ "$msg" = "$rule" ] && msg="banned pattern"
        # shellcheck disable=SC2086
        hits=$(grep -nHE -- "$re" $files 2>/dev/null | grep -vE '^[^:]+:[0-9]+:[[:space:]]*//')
        [ -n "$hits" ] && hits_all="${hits_all}→ ${msg}
${hits}
"
    done <<< "$BANNED_PATTERNS"
    if [ -n "$hits_all" ]; then
        echo "Rule violations (profile: $PROFILE — see .claude/rules/PROJECT_CONVENTIONS.md):"
        printf '%s' "$hits_all"
        status=1
    fi
fi

# 2. Business-logic files need a test (mirrored path, or any test/ file with the same base name)
missing=""
for f in $(changed_files lib); do
    base=$(basename "$f" .dart)
    need=0
    for pat in $REQUIRE_TESTS_FOR; do
        # shellcheck disable=SC2254
        case "$(basename "$f")" in $pat) need=1 ;; esac
    done
    [ $need -eq 1 ] || continue
    mirrored="test/${f#lib/}"; mirrored="${mirrored%.dart}_test.dart"
    if [ ! -f "$mirrored" ] && ! find test integration_test -name "${base}_test.dart" -print -quit 2>/dev/null | grep -q .; then
        missing="${missing}  $f  →  expected $mirrored (or any test/**/${base}_test.dart)
"
    fi
done
if [ -n "$missing" ]; then
    echo "Missing tests (use the test-writer subagent):"
    printf '%s' "$missing"
    status=1
fi

# 3. Test integrity — fix code, never weaken tests
if [ -n "$BASE" ]; then
    deleted=$(git diff --name-only --diff-filter=D "$BASE" -- test integration_test 2>/dev/null)
    SKIP_RE="skip:[[:space:]]*(true|'|\")|//[[:space:]]*ignore(_for_file)?:"
    weakened=$(git diff -U0 "$BASE" -- lib test integration_test 2>/dev/null \
               | grep -E '^\+' | grep -vE '^\+\+\+' | grep -E "$SKIP_RE")
    if [ -n "$deleted" ]; then
        echo "Deleted test files (not allowed — restore them and fix the code):"
        echo "$deleted" | sed 's/^/  /'
        status=1
    fi
    if [ -n "$weakened" ]; then
        echo "New skip:/ignore suppressions (not allowed — fix the root cause):"
        echo "$weakened" | sed 's/^/  /'
        status=1
    fi
fi

exit $status
