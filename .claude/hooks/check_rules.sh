#!/usr/bin/env bash
# ============================================================
# .claude/hooks/check_rules.sh
#
# Enforces the AGENTS.md golden rules on CHANGED feature files,
# and requires a mirrored test for every changed UseCase / Provider (Riverpod) / Bloc / Cubit.
# Run manually:  bash .claude/hooks/check_rules.sh
# Exit 1 = violations found (printed as file:line: code)
# ============================================================
set -uo pipefail
ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$ROOT" || exit 0

# Compare against HEAD locally; in CI set CHECK_RULES_BASE=origin/<target-branch> to check the whole MR/PR.
BASE_REF="${CHECK_RULES_BASE:-HEAD}"
BASE=$(git merge-base "$BASE_REF" HEAD 2>/dev/null || echo HEAD)

files=$( { git diff --name-only "$BASE" -- lib/features 2>/dev/null
           git ls-files -o --exclude-standard -- lib/features 2>/dev/null; } \
         | grep -E '\.dart$' | grep -vE '\.(g|freezed|gr)\.dart$' | sort -u)
files=$(for f in $files; do [ -f "$f" ] && echo "$f"; done)
[ -z "$files" ] && exit 0

status=0

# 1. Golden-rule violations (comments ignored). core/ widgets are excluded by scope.
RAW='(^|[^A-Za-z_.])(Text|ElevatedButton|TextButton|OutlinedButton|TextFormField|DropdownButton|CircularProgressIndicator|AppBar)\('
CAST='[^A-Za-z_]as (String|int|double|bool|num)\??([^A-Za-z_]|$)'
MISC='Color\(0x|Image\.asset\(|showSnackBar\(|(^|[^A-Za-z_.])print\(|dotenv|String\.fromEnvironment'
hits=$(grep -nHE "$RAW|$CAST|$MISC" $files | grep -vE '^[^:]+:[0-9]+:[[:space:]]*//')
if [ -n "$hits" ]; then
    echo "Golden-rule violations (see AGENTS.md → Widget Substitution Table / Golden Rules):"
    echo "$hits"
    status=1
fi

# 2. Every changed UseCase / Provider / Bloc / Cubit needs a mirrored test file.
missing=""
for f in $files; do
    case "$f" in
        *_usecase.dart|*_provider.dart|*_bloc.dart|*_cubit.dart)
            t="test/${f#lib/}"; t="${t%.dart}_test.dart"
            [ -f "$t" ] || missing="${missing}  $f  →  expected $t\n"
            ;;
    esac
done
if [ -n "$missing" ]; then
    echo "Missing tests (use the test-writer subagent):"
    printf '%b' "$missing"
    status=1
fi

# 3. Test integrity — the agent must fix code, never weaken tests.
if git rev-parse --verify -q HEAD >/dev/null 2>&1; then
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
