---
description: One-time project setup after install — learn/confirm conventions, set a safe gate baseline, add test deps
---
Bootstrap this project for the AI-native pipeline. Read `.claude/ai-orchestration.version` (profile + state) first. Show the plan, then do it step by step and STOP where marked.

## 1. Conventions
- **Profile `ssl`:** verify `ssl_cli help --all` and `autosafe --version`; report missing tools with install commands. Conventions are already in `.claude/rules/PROJECT_CONVENTIONS.md` — skip to step 2.
- **Profile `ssl-repository`** (ssl_cli Repository / Bloc pattern, `lib/modules/…`): verify `ssl_cli help --all`. Then CHECK the rules against the code — do not change any code:
  1. Read `lib/data_provider/api_client.dart`, `lib/global/widget/`, `lib/utils/navigation.dart`, and 2–3 modules end to end (`views/` → `controller/` or `bloc/` → `repository/` → `*_api.dart`), plus existing tests.
  2. Write `.claude/rules/PROJECT_NOTES.md` with everything that differs from `PROJECT_CONVENTIONS.md`: the state management actually used in controllers (plain class, Riverpod `StateNotifier`/`Notifier`, Provider, GetX…), DI, secure storage vs `PrefHelper`, extra folders, renamed widgets, security/native code locations, anything the template doesn't mention. Use real paths and short snippets.
  3. If `.claude/rules/STATE_MANAGEMENT.md` contains `ai-orch:unlearned`, document the real controller/state pattern there and remove the marker.
  4. **STOP** and show me PROJECT_NOTES.md. Mention that `/migrate` exists if I want to move to Clean Architecture.
- **Profile `generic`:** if `.claude/rules/PROJECT_CONVENTIONS.md` contains `ai-orch:unlearned`, LEARN the conventions:
  1. Read `pubspec.yaml`, `analysis_options.yaml`, `lib/main.dart`, the folder tree of `lib/` (2–3 levels), and 2–3 representative features end to end (API → state → UI), plus 2–3 existing tests.
  2. Rewrite `PROJECT_CONVENTIONS.md` using exactly the sections listed in it. Use real paths and short real snippets from this repo; mark anything inconsistent in the codebase as "Mixed — prefer X (newer code)". Remove the `ai-orch:unlearned` line.
  3. If `.claude/rules/STATE_MANAGEMENT.md` contains `ai-orch:unlearned`, document the real state-management pattern there too (folders, naming, one real example, how it's tested) and remove the marker. Otherwise do not edit it — put project-specific state details in `PROJECT_CONVENTIONS.md`.
  4. If the project uses its own widgets instead of raw Flutter widgets (e.g. `AppText` instead of `Text`), propose `EXTRA_BANNED_PATTERNS` lines for `.claude/gate.local.conf` in the form `regex|||message`.
  5. **New / almost empty project** (fewer than ~10 Dart files in `lib/`): don't invent from nothing — propose a simple feature-first structure that fits the chosen state management and ask me to confirm.
  6. **STOP** and show me the conventions + proposed gate rules. Apply the `gate.local.conf` changes only after I approve.

## 2. State management package
Read `.claude/rules/STATE_MANAGEMENT.md`. If its package (`flutter_riverpod` / `flutter_bloc`) is missing from `pubspec.yaml`, add it with `flutter pub add`. If `pubspec.yaml` uses a different one, STOP and tell me to re-run the installer with `--state=<riverpod|bloc|custom> --force`.

## 3. Test tooling
`flutter pub add --dev mocktail` (+ `bloc_test` for Bloc). Don't remove existing test libraries.

## 4. Lints & logging
- `analysis_options.yaml`: keep existing includes; set `avoid_print: true` under `linter: rules:` (ask before changing anything else).
- If there is no logger, add one (silent in release, never logs PII or tokens). Do NOT mass-replace existing `print()` calls in legacy code — list how many exist and ask.

## 5. Gate baseline (legacy-safe)
1. Run `dart analyze` and `flutter test` once on the untouched code and report: number of analyzer errors / warnings, tests passing / failing.
2. If existing tests already fail, propose `TEST_SCOPE=related` in `.claude/gate.local.conf` (gate then runs only tests for changed files) and list the failing tests as tech debt. If there are analyzer *errors*, list them — the gate blocks on errors anywhere.
3. Confirm `.gitignore` contains every entry in `.claude/docs/SECURITY.md` → .gitignore Validation.
4. Run `bash .claude/hooks/stop_gate.sh --manual` and show the result.

## 6. Finish
Confirm `/spec`, `/feature`, `/qa_test` and the `test-writer` / `reviewer` subagents are available. Show a diff summary and propose one commit message. Do not commit until I approve.
