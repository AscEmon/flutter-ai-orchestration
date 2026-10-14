---
description: One-time setup of a project right after install.sh — test deps, strict lints, safe logger, green gate
---
Bootstrap this project for the AI-native pipeline. Show the plan first, then do it step by step:

1. Verify tools: `flutter --version`, `ssl_cli help --all`, `autosafe --version`. Report anything missing with its install command.
2. If `test/widget_test.dart` is the default counter test, delete it.
3. Detect the state management from `pubspec.yaml` (`flutter_riverpod` or `flutter_bloc`) and confirm `.claude/rules/STATE_MANAGEMENT.md` matches it — if not, STOP and tell me to re-run `install.sh --state=<riverpod|bloc> --force`. Add test deps: `flutter pub add --dev mocktail` (+ `bloc_test` for Bloc).
4. `analysis_options.yaml`: keep `flutter_lints` (and `riverpod_lint` if Riverpod), set `avoid_print: true`.
5. If the project has no logger, add one in `lib/core/utils/` that is silent in release builds and never logs PII (NID, phone, account numbers) or tokens. Replace existing `print()` calls with it.
6. Confirm `.gitignore` contains every entry listed in `.claude/docs/SECURITY.md` → .gitignore Validation.
7. Run the gate: `flutter analyze --no-fatal-infos`, `bash .claude/hooks/check_rules.sh`, `flutter test`. Fix until green.
8. Confirm `/spec`, `/feature`, `/qa_test` and the `test-writer` / `reviewer` subagents are available.
9. Show a diff summary and propose one commit message. Do not commit until I approve.
