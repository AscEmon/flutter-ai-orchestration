# 🤖 Flutter AI Orchestration

**AI-powered Flutter development with Clean Architecture — built for Claude Code.**

This is a complete AI agent orchestration setup for Flutter projects. It teaches your AI assistant how to write code following Clean Architecture, handle secrets safely, and even test your app on real devices.

> **Built for Claude Code.** But we know many developers use different IDEs — Cursor, Windsurf, Copilot, Gemini, Codex, Aider. That's why we include `setup_ide.sh` — a one-command script that generates the right config for your IDE so it gets the same rules.

---

## 🤔 What Is This?

When you use an AI coding assistant, it doesn't know your project's rules — your folder structure, naming conventions, which widgets to use, how to handle errors. You end up repeating the same instructions every time.

**This project solves that.** You drop these files into your Flutter project and the AI instantly knows:

- ✅ Your architecture pattern (Clean Architecture, feature-based)
- ✅ Your state management (Riverpod)
- ✅ Your coding templates (entities, models, use cases, providers)
- ✅ Your UI rules (global widgets, responsive sizing)
- ✅ Your security rules (never hardcode secrets, never touch generated files)
- ✅ How to scaffold new features (`ssl_cli`)
- ✅ How to parse JSON safely (`autosafe_json`)

### Why Claude Code First?

Claude Code has the **richest** orchestration support — it reads `CLAUDE.md`, auto-loads `.claude/rules/`, runs security hooks, connects to MCP servers, and supports invokable skills. This project takes full advantage of all those features.

**Using a different IDE?** No problem. Every AI IDE reads its rules from a different file:

| IDE | Where it reads rules |
|-----|---------------------|
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | `CLAUDE.md` + `.claude/rules/` ← **full support** |
| [Cursor](https://docs.cursor.com/context/rules) | `.cursor/rules/` or `.cursorrules` |
| [Windsurf](https://docs.windsurf.com/windsurf/memories#rules) | `.windsurfrules` |
| [GitHub Copilot](https://docs.github.com/en/copilot/customizing-copilot/adding-repository-custom-instructions) | `.github/copilot-instructions.md` |
| [Gemini CLI / Antigravity](https://github.com/google-gemini/gemini-cli) | `GEMINI.md` |
| [OpenAI Codex](https://github.com/openai/codex) | `AGENTS.md` |
| [Aider](https://aider.chat/docs/config/conventions.html) | `AGENTS.md` |

Just run `sh .claude/scripts/setup_ide.sh`, pick your IDE, and it generates the right file with all the rules baked in.

---

## 📂 What's Inside

```
your-flutter-project/
├── AGENTS.md                    ← Universal rules (lean index)
├── CLAUDE.md                    ← Claude Code entry point (@imports AGENTS.md)
├── .mcp.json                    ← MCP server config (auto-discovered)
│
└── .claude/                     ← The brain — single source of truth
    ├── settings.json            ← Hooks + auto-approved commands
    ├── rules/                   ← Deep-dive rule files
    │   ├── ARCHITECTURE.md      ← Folder structure, naming, layer constraints
    │   ├── CLI_WORKFLOW.md      ← ssl_cli & autosafe_json step-by-step
    │   ├── CODE_TEMPLATES.md    ← Copy-paste templates for every layer
    │   └── UI_RULES.md          ← Global widgets, responsive sizing
    ├── docs/
    │   └── SECURITY.md          ← Secret management, forbidden files
    ├── hooks/                   ← Security guardrails (Claude Code)
    │   ├── pre_bash_git_guard.sh    ← Blocks commits with leaked secrets
    │   ├── pre_edit_guard.sh        ← Blocks writes to secret files
    │   ├── post_write.sh            ← Scans written files for secrets
    │   ├── pre_commit.sh            ← Full secret leak scanner
    │   ├── on_stop.sh               ← Audit log on session end
    │   ├── scan_git_history.sh      ← Scan entire git history for leaks
    │   └── _secret_patterns.sh      ← Shared regex library
    ├── mcp/
    │   └── mcp.json             ← MCP config source (distributed by setup_ide.sh)
    ├── scripts/
    │   ├── setup_ide.sh         ← Interactive IDE setup (the star of the show)
    │   ├── setup_secrets.sh     ← .env → native secret files
    │   └── launch_for_testing.sh ← Start app for AI QA testing
    └── skills/
        └── qa_test.md           ← Automated QA testing protocol
```

---

## 🚀 Quick Start

### 1. Copy to Your Project

Copy the `.claude/` folder, `AGENTS.md`, `CLAUDE.md`, and `.mcp.json` into your Flutter project root.

### 2. Run the IDE Setup

```bash
sh .claude/scripts/setup_ide.sh
```

You'll see an interactive menu:

```
  Flutter AI Agent — IDE Setup
  ═══════════════════════════════════

  Which IDE do you use?

  1)  Claude Code          (default — already configured)
  2)  Cursor
  3)  Windsurf
  4)  VS Code Copilot
  5)  Gemini CLI / Antigravity
  6)  OpenAI Codex / Aider
  7)  All of the above
  0)  Exit

  Choose [1-7, or comma-separated e.g. 1,2,5]:
```

Pick your IDE. The script generates **only** the files that IDE needs. Done.

### 3. Customize the Rules

Edit the files in `.claude/rules/` to match **your** project's architecture. The defaults are set for:

- Flutter + Clean Architecture (feature-based)
- Riverpod for state management
- Dio for HTTP
- GetIt for dependency injection

But you can change everything to match your stack.

---

## 🧠 How It Works

### The Layered Design

```
┌─────────────────────────────────────────────────┐
│  AGENTS.md  (lean index — ~130 lines)           │ ← Every IDE reads this
│  Stack, golden rules, decision flow, widgets    │
├─────────────────────────────────────────────────┤
│  CLAUDE.md  (Claude-specific extensions)        │ ← Only Claude Code
│  Hooks, MCP, permissions, skills                │
├─────────────────────────────────────────────────┤
│  .claude/rules/*.md  (deep-dive docs)           │ ← Auto-loaded by Claude
│  Architecture, templates, CLI workflow, UI      │    Inlined for others
├─────────────────────────────────────────────────┤
│  .claude/docs/SECURITY.md                       │ ← Secret management
│  .claude/hooks/*.sh                             │ ← Runtime guardrails
│  .claude/skills/*.md                            │ ← Invokable protocols
└─────────────────────────────────────────────────┘
```

**Why layered?**

- `AGENTS.md` is lean (~130 lines) so AI context windows aren't wasted
- Claude Code auto-loads `.claude/rules/` for deep detail on demand
- Other IDEs get a **combined** version (all rules inlined) generated by the setup script

### What setup_ide.sh Does

It takes your lean `AGENTS.md` + all `.claude/rules/*.md` + `SECURITY.md`, combines them into one self-contained document, and writes it to the correct path for your chosen IDE:

| You choose | Script generates |
|-----------|-----------------|
| Claude Code | Validates existing setup, copies `.mcp.json` |
| Cursor | `.cursorrules` + `.cursor/rules/flutter_rules.md` + `.cursor/mcp.json` |
| Windsurf | `.windsurfrules` |
| VS Code Copilot | `.github/copilot-instructions.md` + `.vscode/mcp.json` |
| Gemini / Antigravity | `GEMINI.md` |
| Codex / Aider | Makes `AGENTS.md` self-contained (rules inlined) |

Generated files are auto-added to `.gitignore` so they're never committed. The source of truth stays in `.claude/`.

---

## 🛡️ Security Hooks

One of the most powerful features. These hooks **prevent your AI from leaking secrets**.

### What They Do

| Hook | Trigger | Action |
|------|---------|--------|
| `pre_bash_git_guard.sh` | AI tries `git commit` or `git push` | Scans staged files for API keys, tokens, passwords. **Blocks** if found. |
| `pre_edit_guard.sh` | AI tries to write a file | **Blocks** writes to `.env`, `release.jks`, `google-services.json`, etc. |
| `post_write.sh` | AI finishes writing a file | Scans the written file for leaked secret patterns. Warns if found. |
| `on_stop.sh` | AI session ends | Logs timestamp to `audit.log` for compliance tracking. |

### Works in Claude Code. What About Other IDEs?

Hooks are Claude Code exclusive. **But** the setup script offers to install a **git pre-commit hook** that works universally — any IDE, any terminal. It wires `.git/hooks/pre-commit` → `.claude/hooks/pre_commit.sh` so the secret scanner runs before every commit regardless of which IDE you use.

### Secret Patterns Detected

The shared library (`_secret_patterns.sh`) catches:

- Google API keys (`AIza...`)
- AWS access keys (`AKIA...`)
- Stripe keys (`sk_live_...`, `sk_test_...`)
- GitHub tokens (`ghp_...`)
- Slack tokens (`xox...`)
- Generic patterns: `api_key = "..."`, `password = "..."`, `token = "..."`, `Bearer ...`
- Firebase URLs, OAuth client IDs, and more

---

## 🔌 MCP (Model Context Protocol)

[MCP](https://modelcontextprotocol.io/) lets AI IDEs interact with external tools. This setup includes [`flutter_skill`](https://pub.dev/packages/flutter_skill) — an MCP server that connects to your running Flutter app.

### What It Enables

- **Live UI inspection** — AI can see what's on screen
- **Automated interaction** — tap buttons, type in fields, scroll
- **QA testing** — AI can test your app for edge cases on real devices

### How It's Configured

The config lives in `.claude/mcp/mcp.json` and gets copied to the right location per IDE:

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

**Supported MCP IDEs:** Claude Code (`.mcp.json`), Cursor (`.cursor/mcp.json`), VS Code (`.vscode/mcp.json`)

Learn more: [flutter_skill on pub.dev](https://pub.dev/packages/flutter_skill) · [MCP Specification](https://spec.modelcontextprotocol.io/) · [MCP Servers Directory](https://github.com/modelcontextprotocol/servers)

---

## 🧪 AI QA Testing

The `qa_test.md` skill turns your AI into a **Senior QA Engineer**. When invoked (in Claude Code via `/qa_test`), it:

1. **Discovers devices** — finds your connected phone/emulator
2. **Launches the app** — starts Flutter, captures the VM Service URL
3. **Connects MCP** — links the AI to your running app
4. **Maps the UI** — inspects every tappable/typeable element
5. **Runs edge-case tests:**
   - Empty form submission → checks for validation messages
   - 200+ character input → checks for overflow
   - Special characters (`🔥DROP TABLE;`) → checks for crashes
   - Bottom-of-screen input → checks keyboard hides submit button
   - Rapid double-tap → checks for duplicate API calls
6. **Reports bugs** — structured markdown report with trigger steps and suspected cause
7. **STOPS** — asks you which bugs to fix before writing any code

---

## 🎨 Customizing for Your Project

### Change the Architecture Rules

Edit `.claude/rules/ARCHITECTURE.md` to match your folder structure. The defaults follow:

```
lib/features/{feature}/
├── data/           (models, datasources, repository implementation)
├── domain/         (entities, repository contracts, use cases)
└── presentation/   (pages, providers, widgets)
```

### Change the Code Templates

Edit `.claude/rules/CODE_TEMPLATES.md` with your team's patterns for entities, models, providers, pages.

### Change the Widget Rules

Edit `.claude/rules/UI_RULES.md` to list your project's custom widgets.

### Change the Security Rules

Edit `.claude/docs/SECURITY.md` to add/remove files from the forbidden list.

### After Any Change

Re-run the setup script to push changes to other IDEs:

```bash
sh .claude/scripts/setup_ide.sh
```

---

## 📚 Learn More

### AI IDE Documentation

| IDE | Docs link |
|-----|-----------|
| Claude Code | [docs.anthropic.com/en/docs/claude-code](https://docs.anthropic.com/en/docs/claude-code) |
| Cursor Rules | [docs.cursor.com/context/rules](https://docs.cursor.com/context/rules) |
| Windsurf Rules | [docs.windsurf.com/windsurf/memories#rules](https://docs.windsurf.com/windsurf/memories#rules) |
| GitHub Copilot Instructions | [docs.github.com — custom instructions](https://docs.github.com/en/copilot/customizing-copilot/adding-repository-custom-instructions) |
| Gemini CLI | [github.com/google-gemini/gemini-cli](https://github.com/google-gemini/gemini-cli) |
| OpenAI Codex | [github.com/openai/codex](https://github.com/openai/codex) |
| Aider Conventions | [aider.chat/docs/config/conventions](https://aider.chat/docs/config/conventions.html) |

### Concepts Used

| Concept | What it is | Link |
|---------|-----------|------|
| MCP | Standard protocol connecting AI to external tools | [modelcontextprotocol.io](https://modelcontextprotocol.io/) |
| Clean Architecture | Layered separation: Domain → Data → Presentation | [blog.cleancoder.com](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html) |
| Riverpod | Reactive state management for Flutter | [riverpod.dev](https://riverpod.dev/) |
| GetIt | Service locator / dependency injection | [pub.dev/packages/get_it](https://pub.dev/packages/get_it) |
| envied | Build-time secret obfuscation for Flutter | [pub.dev/packages/envied](https://pub.dev/packages/envied) |
| Equatable | Value equality for Dart classes | [pub.dev/packages/equatable](https://pub.dev/packages/equatable) |
| dartz | Functional programming (Either type) for Dart | [pub.dev/packages/dartz](https://pub.dev/packages/dartz) |

### Tools Used

| Tool | What it does | Link |
|------|-------------|------|
| `ssl_cli` | Scaffolds Clean Architecture folders & files | `dart pub global activate ssl_cli` |
| `autosafe_json` | Safe JSON parsing — no raw `as` casts | `dart pub global activate autosafe_json` |
| `flutter_skill` | MCP server — AI ↔ running Flutter app | [pub.dev/packages/flutter_skill](https://pub.dev/packages/flutter_skill) |

---

## 🤝 Contributing

1. Fork this repo
2. Edit rules in `.claude/rules/` or `.claude/docs/`
3. Test with your IDE: `sh .claude/scripts/setup_ide.sh`
4. Submit a PR with clear description of what rule changed and why

**Rule of thumb:** If a rule applies to **all IDEs**, put it in `AGENTS.md` or `.claude/rules/`. If it's **Claude Code specific** (hooks, permissions, skills), put it in `CLAUDE.md` or `.claude/settings.json`.

---

## 📜 License

MIT — use it, fork it, share it. If it helps you or your team, star the repo ⭐

---

*Built by Abu Sayed Chowdhury 🤖*
