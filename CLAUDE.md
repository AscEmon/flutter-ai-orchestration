# Claude Code — Mobile Team Entry Point

> **Universal rules live in `AGENTS.md`** (read by Copilot, Codex, Cursor fallback, etc.).
> Claude Code imports it below, then layers on Claude-specific automation (hooks, MCP, skills).

@AGENTS.md

---

## Claude-Specific Extensions

The sections below apply ONLY when working through Claude Code. Other IDEs ignore them.

---

### Hooks (`.claude/settings.json`)

These run automatically on every Claude Code session. They protect the codebase from accidental secret leaks and destructive operations.

| Event | Matcher | Hook script | Purpose |
|-------|---------|-------------|---------|
| `PreToolUse` | `Bash` | `pre_bash_git_guard.sh` | Intercepts every Bash call. Blocks destructive `git` ops; delegates `git commit` / `git push` to `pre_commit.sh` for full secret scan. |
| `PreToolUse` | `Write\|Edit` | `pre_edit_guard.sh` | Blocks any write to forbidden secret files (`.env`, `*.jks`, `env.g.dart`, etc.). |
| `PostToolUse` | `Write\|Edit` | `post_write.sh` | Scans the file just written for secret patterns — on a hit exits `2`, so Claude is told to remove it (logged as `SECRET_WRITE_BLOCKED`). Also reminds about asset / `autosafe` / `build_runner` steps. |
| `Stop` | — | `stop_gate.sh` | **Loop gate.** If `lib/` or `test/` changed, runs `check_rules.sh` → analyzer (errors anywhere, warnings in changed files) → tests (all or related). On failure exits `2` so Claude keeps working with the failure report. Max 3 retries (`STOP_GATE_MAX_RETRIES`), then escalates to you. Scopes in `.claude/gate.conf` / `.claude/gate.local.conf`. |
| `Stop` | — | `on_stop.sh` | Appends session-end timestamp to `.claude/audit.log` and warns if a secret file is tracked. |
| `PreToolUse` | `Task\|Agent` | `log_subagent.sh` | Logs every subagent start (`SUBAGENT_START test-writer \| <task>`) to `.claude/audit.log`. Never blocks. |
| `SubagentStop` | — | `log_subagent.sh --stop` | Logs `SUBAGENT_STOP` when a subagent finishes. |

**Shared library:** `.claude/hooks/_secret_patterns.sh` — single source of secret regexes, sourced by all guard hooks.

**Manual scans:**
```bash
bash .claude/hooks/pre_commit.sh         # Run secret-leak scan on staged files manually
bash .claude/hooks/scan_git_history.sh   # Scan ENTIRE git history for past secret leaks
bash .claude/hooks/scan_git_history.sh --fix   # Auto-add findings to .gitignore
bash .claude/hooks/check_rules.sh        # Golden rules + missing tests + test integrity (no deleted/skipped tests) on changed files
CHECK_RULES_BASE=origin/main bash .claude/hooks/check_rules.sh   # Same, for the whole branch (CI mode)
```

**Hook exit codes:** Exit `0` allows the operation, exit `2` blocks it. Post hooks can never block.

---

### MCP Server — `flutter-skill`

`.mcp.json` at project root → Claude Code auto-discovers on every session.

```json
{
  "mcpServers": {
    "flutter-skill": {
      "command": "flutter-skill",
      "args": ["server"]
    }
  }
}
```

Connects to a running Flutter app via Dart VM Service URL. Used for:
- Live UI inspection (semantic snapshots of running screens)
- Automated tap / type / scroll for QA testing
- Bug detection on real devices

**MCP changes require an IDE restart.**

---

### Permissions Pre-Approved (`.claude/settings.json`)

Claude Code can run these without user prompt:

```
Bash(ssl_cli help:*) · Bash(ssl_cli create:*) · Bash(ssl_cli module:*)
Bash(ssl_cli generate:*) · Bash(ssl_cli build:*)
Bash(autosafe:*)
Bash(flutter --version) · Bash(flutter create:*) · Bash(flutter pub:*)
Bash(dart pub:*) · Bash(dart run build_runner:*)
Bash(sh .claude/scripts/setup_secrets.sh)
Bash(flutter analyze:*) · Bash(flutter test:*) · Bash(flutter devices)
Bash(bash .claude/scripts/launch_for_testing.sh:*) · Bash(bash .claude/hooks/check_rules.sh)
Bash(git status:*) · Bash(git diff:*) · Bash(git log:*)
Bash(dart analyze:*) · Bash(bash .claude/hooks/stop_gate.sh --manual)
(ssl_cli / autosafe entries are harmless in non-ssl projects — the commands simply don't exist there)
```

Anything outside this list will trigger a permission prompt. `python3:*` and `bash *` are intentionally **not** pre-approved — they would allow arbitrary code (e.g. reading `.env`) without your review.

**Denied** (`permissions.deny`, cannot be approved by the agent): reading `.env*`, keystores, `key.properties`, `env.g.dart`, `Secret.xcconfig`, Firebase configs; `curl`/`wget`; `git push --force`, `git reset --hard`.

---

### Subagents (`.claude/agents/`)

| Agent | Tools | Use |
|-------|-------|-----|
| `test-writer` | Read, Glob, Grep, Write, Edit | Writes tests from the spec's acceptance criteria (or backfills missing ones). Never edits `lib/`. |
| `reviewer` | Read, Glob, Grep (read-only) | Reviews the change against spec, architecture, golden rules, and OWASP MASVS. Returns a JSON verdict. |

### Slash Commands (`.claude/commands/`)

| Command | Purpose |
|---------|---------|
| `/bootstrap` | One-time project setup after install: mocktail, strict lints, safe logger, green gate. |
| `/spec <feature> <request\|BRD\|Figma>` | Creates `docs/specs/<feature>.md` with numbered acceptance criteria and stops for your approval. |
| `/feature <feature>` | Runs the full pipeline: spec → test-writer → code → stop-gate loop → reviewer → QA → done report. |
| `/qa_test` | Runs the QA protocol in `.claude/skills/qa_test.md`. |

---

### Skills — `/qa_test`

`.claude/skills/qa_test.md` — invoke via `/qa_test` to run the **Senior QA Automation Protocol**.

**Phase 1: Device discovery & connection**
1. `flutter devices` → identify attached device ID
2. `bash .claude/scripts/launch_for_testing.sh <DEVICE_ID>` → starts app, writes VM URL to `.claude/tmp/vm_url.txt`
3. Connect `flutter-skill` MCP to the VM URL

**Phase 2: Semantic discovery**
- `snapshot` / `inspect_interactive` → map every tappable & typeable element
- Build internal mental model of the UI

**Phase 3: Edge-case matrix**
| Test | Action | Looking for |
|------|--------|-------------|
| Empty state | Submit form with zero input | Required-field validation messages |
| Boundary value | Paste 200+ chars into text field | TextOverflow / RenderFlex overflow |
| Special chars | Input `🔥DROP TABLE;` | Crash / improper escaping |
| Keyboard layout | Tap input near bottom of screen | Keyboard hides submit button (BottomInset overflow) |
| Fast double-tap | Tap submit twice rapidly | Duplicate API calls |

**Phase 4: Bug report → STOP**
- Output structured markdown report with: bug, trigger sequence, suspected root cause
- **Do NOT write any fix.** Pause and ask: *"Which of these would you like me to resolve?"* (fixes follow `PROJECT_CONVENTIONS.md`)
- Only proceed to write code after user explicitly approves.

---

### Scripts — Quick Reference

| Script | Purpose |
|--------|---------|
| `.claude/scripts/setup_secrets.sh` | Reads `.env` → decodes JKS, Firebase configs → generates `key.properties` + `Secret.xcconfig`. Re-run whenever `.env` changes. |
| `.claude/scripts/launch_for_testing.sh <DEVICE_ID>` | Starts `flutter run` in background, captures VM URL to `.claude/tmp/vm_url.txt` for MCP testing. |
| `.claude/scripts/update.sh [--check \| vX.Y.Z]` | Updates this project's orchestration to the latest (or given) release — backs up first, keeps learned conventions and local overrides. Run by humans, not the agent. |
| `.claude/scripts/setup_ide.sh` | Interactive IDE setup — choose your IDE, generates only the needed config files. Also offers universal git pre-commit hook. |

---

### Modular Rules (`.claude/rules/`) — installed per profile

Claude Code auto-includes every `.md` file in this folder. `install.sh` fills it from `profiles/<profile>/`:

| File | ssl profile | generic profile |
|------|-------------|-----------------|
| `PROJECT_CONVENTIONS.md` | Mobile Team house style (managed) | **Learned from your code** by `/bootstrap` — yours to edit, kept on upgrade |
| `STATE_MANAGEMENT.md` | ssl_cli Riverpod / Bloc templates | Neutral Riverpod / Bloc guide, or learned (`custom`) for Provider, GetX, MobX… |
| `ARCHITECTURE.md`, `CLI_WORKFLOW.md`, `CODE_TEMPLATES.md`, `UI_RULES.md` | ✔ | — |
| `PROJECT_NOTES.md` (optional) | your own additions — never touched by the installer | same |

Gate settings: `.claude/gate.conf` (profile, managed) + `.claude/gate.local.conf` (your overrides: `EXTRA_BANNED_PATTERNS`, `REQUIRE_TESTS_FOR`, `ANALYZE_SCOPE`, `TEST_SCOPE`).

---

### Extended Docs (`.claude/docs/`)

- `SECURITY.md` — Full secret management runbook: forbidden file list, JKS placement, `.gitignore` validation, emergency response when a secret is leaked.

---

### Audit Log

`.claude/audit.log` — append-only log written by `on_stop.sh` and `stop_gate.sh`. Records session ends, git commands, and every gate PASS / FAIL / ESCALATED — use it to measure first-try pass rate. Useful for compliance and incident review.

---

## How to Update This Setup

1. **Universal rule changes** → edit `AGENTS.md` (every IDE benefits)
2. **Claude-specific changes** → edit this file or `.claude/rules/*.md`
3. **Distribute to other IDEs** → `sh .claude/scripts/setup_ide.sh` (choose your IDE)
4. **Restart IDE** if you changed `.mcp.json` or `.claude/settings.json`

---

*Mobile Team · Claude Code orchestration v2 (spec → tests → code → gate loop → review → QA)*
