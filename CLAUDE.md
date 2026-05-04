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
| `PostToolUse` | `Write\|Edit` | `post_write.sh` | Scans the file just written for leaked secret patterns. Informational. |
| `Stop` | — | `on_stop.sh` | Appends session-end timestamp to `.claude/audit.log`. |

**Shared library:** `.claude/hooks/_secret_patterns.sh` — single source of secret regexes, sourced by all guard hooks.

**Manual scans:**
```bash
bash .claude/hooks/pre_commit.sh         # Run secret-leak scan on staged files manually
bash .claude/hooks/scan_git_history.sh   # Scan ENTIRE git history for past secret leaks
bash .claude/hooks/scan_git_history.sh --fix   # Auto-add findings to .gitignore
```

**Hook exit codes:** Exit `0` allows the operation, exit `2` blocks it. Post hooks can never block.

---

### MCP Server — `flutter-skill`

`.mcp.json` at project root → Claude Code auto-discovers on every session.

```json
{
  "mcpServers": {
    "flutter-skill": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-flutter-skill", "server"]
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
Bash(sh .claude/scripts/setup_secrets.sh) · Bash(python3:*)
```

Anything outside this list will trigger a permission prompt.

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
- **Do NOT write any fix.** Pause and ask: *"Which of these would you like me to resolve using the ssl_cli architecture?"*
- Only proceed to write code after user explicitly approves.

---

### Scripts — Quick Reference

| Script | Purpose |
|--------|---------|
| `.claude/scripts/setup_secrets.sh` | Reads `.env` → decodes JKS, Firebase configs → generates `key.properties` + `Secret.xcconfig`. Re-run whenever `.env` changes. |
| `.claude/scripts/launch_for_testing.sh <DEVICE_ID>` | Starts `flutter run` in background, captures VM URL to `.claude/tmp/vm_url.txt` for MCP testing. |
| `.claude/scripts/setup_ide.sh` | Interactive IDE setup — choose your IDE, generates only the needed config files. Also offers universal git pre-commit hook. |

---

### Modular Rules (`.claude/rules/`)

Claude Code auto-includes every `.md` file in this folder as additional context. Currently:

- `ARCHITECTURE.md` — Clean Architecture deep-dive (folder rules, layer constraints)
- `CLI_WORKFLOW.md` — Step-by-step `ssl_cli` & `autosafe_json` workflow
- `CODE_TEMPLATES.md` — Copy-paste templates (entity, model, repo, usecase, provider, page)
- `UI_RULES.md` — Global widgets + responsive sizing details

Edit these for Claude-specific deep dives. Universal rules belong in `AGENTS.md`.

---

### Extended Docs (`.claude/docs/`)

- `SECURITY.md` — Full secret management runbook: forbidden file list, JKS placement, `.gitignore` validation, emergency response when a secret is leaked.

---

### Audit Log

`.claude/audit.log` — append-only log written by `on_stop.sh`. Records every Claude session end timestamp. Useful for compliance and incident review.

---

## How to Update This Setup

1. **Universal rule changes** → edit `AGENTS.md` (every IDE benefits)
2. **Claude-specific changes** → edit this file or `.claude/rules/*.md`
3. **Distribute to other IDEs** → `sh .claude/scripts/setup_ide.sh` (choose your IDE)
4. **Restart IDE** if you changed `.mcp.json` or `.claude/settings.json`

---

*Mobile Team · Claude Code orchestration v1*
