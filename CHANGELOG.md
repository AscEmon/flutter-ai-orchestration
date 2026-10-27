# Changelog

Update an installed project: `bash .claude/scripts/update.sh` (v2.2.2+) — or see README → Updating.

## v2.3.0
- **New `ssl-repository` profile** for existing projects created with ssl_cli's Repository (2) or Bloc (3) pattern (`lib/modules/<m>/controller|repository|views`). Previously these got generic placeholder rules and nothing project-specific.
  - Auto-detected (`lib/modules/*/repository/*_interface.dart`, or `global_text.dart` + `api_client.dart`); choosing **1** routes there
  - Managed `PROJECT_CONVENTIONS.md` for the Repository pattern; gate bans raw `Text(`/`AppBar(`…, `Color(0x`, `Image.asset(`, `showSnackBar(`, `print(` in `lib/modules`; tests required for controllers/repositories/blocs
  - State: `bloc` when `flutter_bloc` is used, otherwise `custom` (learned by `/bootstrap`)
  - `/bootstrap` verifies the rules against the code and writes `.claude/rules/PROJECT_NOTES.md`
  - **`/migrate`** — resumable module-by-module migration to Clean Architecture; target rules shipped in `.claude/migration/target/`
- Profiles can ship their own slash commands (`profiles/<p>/commands/`)

## v2.2.4
- Subagent audit trail: every `test-writer` / `reviewer` (or other subagent) run is logged as `SUBAGENT_START <type> | <task>` and `SUBAGENT_STOP` in `.claude/audit.log` — check with `grep SUBAGENT .claude/audit.log`

## v2.2.3
- Running the plain install command on an already-installed project now **offers to update** (`Installed v2.2.1 → available v2.2.3 — Update now? [Y/n]`) instead of failing
- Same version → "Already up to date"; newer installed → refuses to downgrade unless `--force`

## v2.2.2
- **Easy updates:** `bash .claude/scripts/update.sh` (latest release, `--check`, or a specific tag) and `get.sh --update`
- `get.sh` works in an empty folder (creates the Flutter project) — the folder check now lives in `install.sh`
- Installed version is recorded correctly when installing through `get.sh` (was `dev`)
- `CHANGELOG.md` added

## v2.2.1
- Secret scanning works on macOS (portable `grep -E` patterns — `grep -P` silently found nothing on Macs)
- `post_write.sh` scans every file Claude writes and makes Claude remove secrets (`SECRET_WRITE_BLOCKED`)
- Secret labels fixed

## v2.2.0
- New project + ssl_cli pattern → installer runs `ssl_cli create` for you (Riverpod / Bloc), installs ssl_cli if missing
- Existing project + ssl_cli pattern → never overwritten; falls back to your own pattern unless you confirm
- Empty folder → offers `flutter create`; no terminal → nothing created without `--yes`

## v2.1.1
- First install asks which coding pattern to follow (ssl_cli with pub.dev links, or your own)

## v2.1.0
- **Profiles:** `ssl` (ssl_cli house style) and `generic` (any project — conventions learned by `/bootstrap`)
- Legacy-safe gate: warnings only in changed files, `TEST_SCOPE=related`, tests found anywhere under `test/`
- `gate.conf` / `gate.local.conf`, manifest-based safe upgrades, CI runs the same gate

## v2.0.1
- Fresh ssl_cli projects upgraded automatically; state-management prompt; `AI_ORCH_STATE`

## v2.0.0
- AI-native pipeline: `/spec` → tests first → code → Stop-gate loop → reviewer → `/qa_test`
- Riverpod and Bloc packs, one-line installer, CI templates, security hardening
