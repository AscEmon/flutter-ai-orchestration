#!/usr/bin/env bash
# Shared loader for stop_gate.sh / check_rules.sh.
# Order: built-in defaults → .claude/gate.conf (profile, managed) → .claude/gate.local.conf (team overrides, yours)
PROFILE=generic
RULES_SCOPE="lib"
BANNED_PATTERNS='
(^|[^A-Za-z_.])print\(|||No print() in lib/
'
REQUIRE_TESTS_FOR="*_usecase.dart *_bloc.dart *_cubit.dart *_notifier.dart *_provider.dart *_controller.dart *_viewmodel.dart *_view_model.dart"
ANALYZE_SCOPE=changed
TEST_SCOPE=all
EXTRA_BANNED_PATTERNS=''
for _conf in .claude/gate.conf .claude/gate.local.conf; do
    # shellcheck disable=SC1090
    [ -f "$_conf" ] && . "$_conf"
done
BANNED_PATTERNS="${BANNED_PATTERNS}
${EXTRA_BANNED_PATTERNS}"

# Base for "changed": HEAD locally; CHECK_RULES_BASE=origin/<branch> in CI
BASE_REF="${CHECK_RULES_BASE:-HEAD}"
if git rev-parse --verify -q HEAD >/dev/null 2>&1; then
    BASE=$(git merge-base "$BASE_REF" HEAD 2>/dev/null || echo HEAD)
else
    BASE=""   # no commits yet — everything is "changed"
fi

# changed_files <dirs...> → changed + untracked .dart files (existing, non-generated)
changed_files() {
    { if [ -n "$BASE" ]; then git diff --name-only "$BASE" -- "$@" 2>/dev/null
      else git ls-files -- "$@" 2>/dev/null; fi
      git ls-files -o --exclude-standard -- "$@" 2>/dev/null; } \
    | grep -E '\.dart$' | grep -vE '\.(g|freezed|gr|mocks|config)\.dart$' | sort -u \
    | while read -r f; do [ -f "$f" ] && echo "$f"; done
}
