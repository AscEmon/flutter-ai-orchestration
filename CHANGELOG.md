# Changelog

Update an installed project: `bash .claude/scripts/update.sh` (v2.2.2+) — or see README → Updating.

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
