# 🤖 Flutter AI Orchestration

**An AI-native software engineering harness for Flutter — Clean Architecture with Riverpod or flutter_bloc (whichever you pick in `ssl_cli`), built for Claude Code, usable from any AI IDE.**

Drop it into any Flutter project with one command. The AI agent then knows your architecture, uses your tools, writes tests first, checks its own work in a loop, and stops to ask you when it is stuck — instead of telling you "done" when it isn't.

```
/spec community <Figma link>   →   you approve   →   /feature community   →   done report (every AC → passing test)
```

### ⚡ Install in one line (run inside your Flutter project)

```bash
curl -fsSL https://raw.githubusercontent.com/AscEmon/flutter-ai-orchestration/v2.0.1/get.sh | bash
```

State management (Riverpod / Bloc) is detected from `pubspec.yaml` — or you're asked to pick 1 / 2. [More options ↓](#install-into-a-project)

**Brand-new app — the whole process:**

```bash
ssl_cli create my_app          # pattern 4 → 1 Riverpod / 2 Bloc
cd my_app && git init
curl -fsSL https://raw.githubusercontent.com/AscEmon/flutter-ai-orchestration/v2.0.1/get.sh | bash
claude                          # then: /bootstrap
```

`ssl_cli create` writes the v1 AI docs; the installer detects them and upgrades to v2 automatically (backup kept in `.ai-orchestration-backup/`).

---

## Table of contents

1. [Why this exists](#-why-this-exists)
2. [How it works — the 4 layers of AI-native engineering](#-how-it-works--the-4-layers-of-ai-native-engineering)
3. [Quick start (5 minutes)](#-quick-start-5-minutes)
4. [Daily workflow — building a feature](#-daily-workflow--building-a-feature)
5. [Who validates what](#-who-validates-what)
6. [What's inside](#-whats-inside)
7. [Security & compliance](#-security--compliance)
8. [CI — same gate for humans and agents](#-ci--same-gate-for-humans-and-agents)
9. [Measuring if it works](#-measuring-if-it-works)
10. [Other AI IDEs](#-other-ai-ides)
11. [Customizing for your team](#-customizing-for-your-team)
12. [Limitations & FAQ](#-limitations--faq)

---

## 💡 Why this exists

AI coding agents are fast, but out of the box they:

| Problem                                                | What this repo adds                                                         |
| ------------------------------------------------------ | --------------------------------------------------------------------------- |
| Forget your architecture and widgets every session     | **Context** files loaded automatically every session                        |
| Need long, perfect prompts                             | **Prompt** commands that turn 3 lines of input into a full spec             |
| Invent folder structures and unsafe JSON parsing       | **Harness**: `ssl_cli` scaffolding, `autosafe_json`, guard hooks            |
| Say "done" when the code doesn't compile or tests fail | **Loop**: a Stop gate that blocks "done" until analyze + rules + tests pass |
| Can leak secrets or log customer data                  | Deny-listed secret files, secret scanners, PII rules                        |

---

## 🧠 How it works — the 4 layers of AI-native engineering

```
┌──────────────────────────────────────────────────────────────────────────┐
│ 1. PROMPT ENGINEERING   /spec · /feature · /qa_test · /bootstrap         │  what you type
├──────────────────────────────────────────────────────────────────────────┤
│ 2. CONTEXT ENGINEERING  AGENTS.md · CLAUDE.md · rules/ · skills/ · MCP   │  what the agent knows
├──────────────────────────────────────────────────────────────────────────┤
│ 3. HARNESS ENGINEERING  ssl_cli · autosafe · hooks · permissions ·       │  what the agent can
│                         subagents (test-writer, reviewer)                │  and cannot do
├──────────────────────────────────────────────────────────────────────────┤
│ 4. LOOP ENGINEERING     Stop gate → fix → retry (max 3) → reviewer →     │  how the agent proves
│                         human escalation · Definition of Done            │  its work is correct
└──────────────────────────────────────────────────────────────────────────┘
```

### 1. Prompt engineering — you write 3 lines, the command writes the real prompt

You don't write long prompts. Slash commands in `.claude/commands/` are reusable, version-controlled prompts:

| Command      | You type                                                                           | It expands into                                                                                                                                                                               |
| ------------ | ---------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/spec`      | `/spec community <Figma link> Rules: users post, like, comment; only author edits` | Reads Figma + your notes → `docs/specs/community.md` with numbered acceptance criteria (`AC-01`… Given/When/Then), API contract, PII flags, open questions — then **stops for your approval** |
| `/feature`   | `/feature community`                                                               | The full pipeline below, step by step                                                                                                                                                         |
| `/qa_test`   | `/qa_test`                                                                         | Device QA protocol via `flutter-skill` MCP — reports bugs, fixes nothing until you approve                                                                                                    |
| `/bootstrap` | `/bootstrap`                                                                       | One-time project setup: test deps, strict lints, safe logger, green gate                                                                                                                      |

**Why a spec?** The agent understands the _design_ from Figma (layout, colors, text) but not the _business_ (API, rules, error states). The spec captures both, and its acceptance criteria become the tests. A good spec is ~80% of a good result.

### 2. Context engineering — the agent always knows your rules

| File                                           | Loaded                                             | Contains                                                                                                                                         |
| ---------------------------------------------- | -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| `AGENTS.md`                                    | Every session, every AI IDE                        | Stack, 5 golden rules, widget table, pipeline, Definition of Done (kept lean to save context)                                                    |
| `CLAUDE.md`                                    | Every Claude Code session (imports `AGENTS.md`)    | Hooks, permissions, subagents, commands                                                                                                          |
| `.claude/rules/*.md`                           | Auto-loaded by Claude Code                         | Architecture, CLI workflow, domain templates, UI rules                                                                                           |
| `.claude/rules/STATE_MANAGEMENT.md`            | Auto-loaded by Claude Code                         | **Your** state management (Riverpod **or** Bloc): presentation folders, Notifier/Bloc, Page and test templates — installed to match your project |
| `.claude/skills/clean_architecture_pattern.md` | Read on demand, before any model/entity/repository | **Single source of truth** for Response → Entity → Repository mapping                                                                            |
| `.claude/docs/SECURITY.md`                     | Read on demand                                     | Secret handling, forbidden files, `.gitignore` list                                                                                              |
| MCP servers                                    | Live, on demand                                    | Figma (design), `flutter-skill` (running app)                                                                                                    |

**Rule:** one fact lives in one file. Other files link to it, never copy it — so rules never contradict each other.

### 3. Harness engineering — reliable tools and hard limits

| Part                                      | What it does                                                                                         |
| ----------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `ssl_cli`                                 | Scaffolds every feature with the same Clean Architecture structure — the agent never invents folders |
| `autosafe_json`                           | Safe JSON decoding — no raw `as` casts                                                               |
| `pre_edit_guard.sh`                       | **Blocks** writes to `.env`, keystores, `env.g.dart`, Firebase configs                               |
| `pre_bash_git_guard.sh` + `pre_commit.sh` | **Blocks** commits that contain secrets                                                              |
| `post_write.sh`                           | Scans every written file for leaked secret patterns                                                  |
| `permissions.allow`                       | Safe commands run without prompts (`ssl_cli`, `flutter analyze/test`, `git status/diff`)             |
| `permissions.deny`                        | Agent can never read secret files, run `curl`/`wget`, force-push, or hard-reset                      |
| `test-writer` subagent                    | Writes tests only — cannot touch `lib/`                                                              |
| `reviewer` subagent                       | Read-only — can judge, cannot "fix" its way past a review                                            |

### 4. Loop engineering — the agent proves its work

```
                Claude says "I'm done"
                         │
                         ▼
        ┌─────────── Stop gate (.claude/hooks/stop_gate.sh) ───────────┐
        │  1. flutter analyze --no-fatal-infos                          │
        │  2. check_rules.sh  → golden rules · missing tests ·          │
        │                       deleted/skipped tests · new // ignore    │
        │  3. flutter test                                              │
        └──────────────────────────┬───────────────────────────────────┘
                 fail              │               pass
          ┌────────────────────────┴───────────────────────┐
          ▼                                                ▼
  error report sent back to Claude              reviewer subagent
  → it fixes the CODE (never the tests)         (spec · architecture · security)
  → says "done" again                                       │
          │                                                 ▼
  after 3 failures → STOP, escalate to you       /qa_test on device → done report
```

- **Retry budget:** 3 attempts (`STOP_GATE_MAX_RETRIES`), then it stops and reports — no infinite loops, no wasted tokens.
- **Anti-cheating:** deleting tests, adding `skip:`, or adding `// ignore:` fails the gate.
- **Only when needed:** the gate runs only if `lib/` or `test/` changed.
- **Audit trail:** every PASS / FAIL / ESCALATED is written to `.claude/audit.log`.

**Definition of Done:** every acceptance criterion has a passing test, the gate is green, and the reviewer passed.

---

## 🚀 Quick start (5 minutes)

### Prerequisites

| Tool                                         | Install                                                                                                        |
| -------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| Flutter SDK (3.11+)                          | [flutter.dev](https://docs.flutter.dev/get-started/install)                                                    |
| Claude Code                                  | [Claude Code docs](https://docs.anthropic.com/en/docs/claude-code)                                             |
| `ssl_cli`                                    | `dart pub global activate ssl_cli`                                                                             |
| `autosafe_json`                              | `dart pub global activate autosafe_json`                                                                       |
| `flutter-skill` (optional, for `/qa_test`)   | See [flutter_skill](https://pub.dev/packages/flutter_skill) — the `flutter-skill` command must be on your PATH |
| Figma MCP (optional, for `/spec` from Figma) | Connect Figma in Claude Code                                                                                   |

> Windows: hooks are bash scripts — use **WSL** or **Git Bash**.

### Install into a project

**Option A — one line from GitHub (recommended).** Run inside the project folder:

```bash
cd my_flutter_app && git init                       # if it's not a git repo yet
curl -fsSL https://raw.githubusercontent.com/AscEmon/flutter-ai-orchestration/v2.0.1/get.sh | bash                              # auto-detect Riverpod / Bloc
curl -fsSL https://raw.githubusercontent.com/AscEmon/flutter-ai-orchestration/v2.0.1/get.sh | AI_ORCH_STATE=bloc bash      # force: riverpod | bloc
curl -fsSL https://raw.githubusercontent.com/AscEmon/flutter-ai-orchestration/v2.0.1/get.sh | bash -s -- --state=bloc     # same, flag form
```

> ⚠ **`bash: --state=riverpod: invalid option`?** Options after `| bash` need `-s --` first (`| bash -s -- --state=riverpod`). Easier: use `| AI_ORCH_STATE=riverpod bash`, or just `| bash` and pick 1 / 2 when asked.

> Always use a **version tag** in the URL (`v2.0.1`), never `master` — everyone gets the exact same files.
> Prefer to read before running? `curl -fsSLO https://raw.githubusercontent.com/AscEmon/flutter-ai-orchestration/v2.0.1/get.sh`, open `get.sh`, then `bash get.sh`.
> Behind a firewall / internal mirror: `AI_ORCH_TARBALL=<mirror-tarball-url> bash get.sh`.

**Option B — from a local clone** (for contributors or offline use):

```bash
git clone https://github.com/AscEmon/flutter-ai-orchestration.git
cd my_flutter_app
../flutter-ai-orchestration/install.sh .                 # auto-detect
../flutter-ai-orchestration/install.sh . --state=bloc    # or force
```

The installed version is recorded in `.claude/ai-orchestration.version`.

`install.sh` copies `AGENTS.md`, `CLAUDE.md`, `.mcp.json`, `.claude/`, `docs/specs/` and `.env.example`, appends the required secret entries to `.gitignore`, installs a git pre-commit secret scan, and checks your tools. It never touches `lib/`, `test/`, `pubspec.yaml` or `.env`.

New project? Create it first with `ssl_cli create my_app` (pattern **4**, then **1 Riverpod** or **2 Bloc**), then run `install.sh . --force` — `ssl_cli create` already writes the v1 AI docs, and `--force` upgrades them to v2 (with a backup).

### Secrets (you, not the AI)

```bash
cp .env.example .env                       # fill real values from the team vault
sh .claude/scripts/setup_secrets.sh        # → key.properties, Secret.xcconfig, Firebase files
dart run build_runner build --delete-conflicting-outputs   # → env.g.dart
```

### First session

```bash
claude
> /bootstrap
```

### Upgrade later

```bash
curl -fsSL https://raw.githubusercontent.com/AscEmon/flutter-ai-orchestration/<new-tag>/get.sh \
  | AI_ORCH_VERSION=<new-tag> bash -s -- --force       # backs up current files to .ai-orchestration-backup/ first
# or, from a local clone:  ../flutter-ai-orchestration/install.sh . --force
```

---

## 🔁 Daily workflow — building a feature

Example: a **community** module from Figma.

| Step       | You type                                                                                                                                                             | What happens                                                      | Your job                                 |
| ---------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------- | ---------------------------------------- |
| 1. Spec    | `/spec community https://figma.com/design/… API sample: docs/api/community.json. Rules: post text + 4 images, like, comment; only author edits/deletes; 20 per page` | Agent writes `docs/specs/community.md` and lists open questions   | Answer questions, fix wrong ACs (~5 min) |
| 2. Approve | `Spec approved`                                                                                                                                                      | —                                                                 | This is your most important decision     |
| 3. Build   | `/feature community`                                                                                                                                                 | test-writer → `ssl_cli module` → code → Stop-gate loop → reviewer | Wait; read the done report               |
| 4. QA      | `/qa_test`                                                                                                                                                           | Agent taps through the app on a device and reports bugs           | Choose which bugs to fix                 |
| 5. Ship    | `Show the diff summary and propose a commit message`                                                                                                                 | —                                                                 | 2-minute diff check (below), then commit |

Keep features small: one module, 3–8 acceptance criteria. Big features → split into several specs.

---

## ✅ Who validates what

| Checker                 | Checks                                                                                            | Can it be fooled?                            |
| ----------------------- | ------------------------------------------------------------------------------------------------- | -------------------------------------------- |
| **Stop gate** (machine) | Compiles, golden rules, every UseCase / Provider / Bloc has a test, no weakened tests, tests pass | No — but it only proves what the tests check |
| **reviewer** subagent   | Every AC implemented + tested, Clean Architecture, MASVS security, no PII in logs                 | Sometimes — it's a second opinion            |
| **You** (human)         | Approve the spec before; review the diff and QA after                                             | Final authority                              |

**2-minute diff check — reject if you see:**

- A file over ~300 lines, or the same logic copied in two places
- A new package in `pubspec.yaml` you didn't ask for
- Tests that only check "not null" or mock everything
- Business logic in a page instead of the UseCase / Notifier / Bloc
- PII (NID, phone, account numbers) or tokens in logs

---

## 📂 What's inside

```
flutter-ai-orchestration/
├── get.sh                         ← one-line installer: downloads a release tag, runs install.sh
├── install.sh                     ← installs / upgrades into a project (state mgmt, .gitignore, git hook)
├── .env.example                   ← secret keys with [PLACEHOLDER] values
├── AGENTS.md                      ← universal rules + pipeline (every AI IDE)
├── CLAUDE.md                      ← Claude Code entry point (@imports AGENTS.md)
├── .mcp.json                      ← flutter-skill MCP (auto-discovered)
├── ci-templates/                  ← GitLab + GitHub jobs running the same gate
├── docs/specs/                    ← feature specs written by /spec
└── .claude/
    ├── settings.json              ← hooks + allow/deny permissions
    ├── commands/                  ← PROMPT layer
    │   ├── spec.md  feature.md  qa_test.md  bootstrap.md
    ├── rules/                     ← CONTEXT layer (auto-loaded)
    │   ├── ARCHITECTURE.md  CLI_WORKFLOW.md  CODE_TEMPLATES.md  UI_RULES.md
    │   └── STATE_MANAGEMENT.md     ← created in the project by install.sh (not in this repo)
    ├── state-management/          ← one pack per state management (copied as STATE_MANAGEMENT.md)
    │   ├── riverpod.md            ← providers/ + state/, Notifier, ConsumerWidget, ProviderContainer tests
    │   └── bloc.md                ← bloc/ + event/ + state/, sealed classes, BlocBuilder, blocTest tests
    ├── skills/                    ← CONTEXT layer (on demand)
    │   ├── clean_architecture_pattern.md   ← single source of truth for data → domain
    │   └── qa_test.md
    ├── docs/SECURITY.md
    ├── agents/                    ← HARNESS layer
    │   ├── test-writer.md  reviewer.md
    ├── hooks/                     ← HARNESS + LOOP layers
    │   ├── stop_gate.sh           ← the loop: analyze → rules → tests, max 3 retries
    │   ├── check_rules.sh         ← golden rules · missing tests · test integrity
    │   ├── pre_edit_guard.sh  pre_bash_git_guard.sh  pre_commit.sh  post_write.sh
    │   ├── on_stop.sh  scan_git_history.sh  _secret_patterns.sh
    ├── mcp/mcp.json               ← MCP source for other IDEs
    └── scripts/
        ├── setup_secrets.sh  launch_for_testing.sh  setup_ide.sh
```

`claude-ai-mobile-session.html` — slides from the team's AI-native engineering session (not installed into projects).

---

## 🛡️ Security & compliance

Built for banking / fintech apps (PCI-DSS, Bangladesh Bank ICT guidelines).

- **Secrets never reach the AI:** secret files are deny-listed for reading and blocked for writing; `.env` is filled by humans only.
- **Secrets never reach git:** Claude's commit guard + a git pre-commit hook for human commits + `scan_git_history.sh` for past leaks.
- **No PII in logs:** `avoid_print: true`, a release-silent logger, and reviewer checks for NID / phone / account data.
- **Least privilege:** no blanket `bash *` / `python3:*` approval; no `curl` / `wget`; no force-push.
- **Data leaving your machine:** your prompts and the code the agent reads go to the AI provider. Confirm your client contract and company AI policy allow it, and never paste real customer data, BRDs with personal data, or credentials. Third-party AI testing clouds need a separate security/compliance review before use.

---

## 🏗️ CI — same gate for humans and agents

| Platform | Template                                                                                                                                                       |
| -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| GitLab   | copy `ci-templates/gitlab-flutter-quality.yml` into your project, then add `include: { local: 'ci-templates/gitlab-flutter-quality.yml' }` to `.gitlab-ci.yml` |
| GitHub   | copy `ci-templates/github/flutter-quality.yml` into your project's `.github/workflows/`                                                                        |

Both run `flutter analyze`, `check_rules.sh` against the target branch (`CHECK_RULES_BASE`), and `flutter test --coverage`.

---

## 📊 Measuring if it works

| Metric                        | How                                                                                                           |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------- |
| Gate failures per success     | `grep -c "STOP_GATE FAIL" .claude/audit.log` ÷ `grep -c "STOP_GATE PASS" .claude/audit.log` — lower is better |
| Escalations (agent got stuck) | `grep -c ESCALATED .claude/audit.log`                                                                         |
| Cost per feature              | `/cost` in Claude Code at the end of a feature                                                                |
| Quality                       | bugs found in QA / production per feature, before vs after                                                    |

A feature that keeps needing 3 attempts means the **spec or the rules** need improving — not more retries.

---

## 🧩 Other AI IDEs

Claude Code gets the full harness (hooks, loop, subagents, commands). Other IDEs get the same **rules** via `setup_ide.sh`:

```bash
sh .claude/scripts/setup_ide.sh
```

| IDE            | Generated file                                                         |
| -------------- | ---------------------------------------------------------------------- |
| Cursor         | `.cursorrules` · `.cursor/rules/flutter_rules.md` · `.cursor/mcp.json` |
| Windsurf       | `.windsurfrules`                                                       |
| GitHub Copilot | `.github/copilot-instructions.md` · `.vscode/mcp.json`                 |
| Gemini CLI     | `GEMINI.md`                                                            |
| Codex / Aider  | self-contained `AGENTS.md`                                             |

In other IDEs, run the gate yourself before you call a task done: `flutter analyze --no-fatal-infos && bash .claude/hooks/check_rules.sh && flutter test`.

---

## 🎨 Customizing for your team

| Change                                                         | Edit                                                                                |
| -------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| Golden rules, stack, pipeline                                  | `AGENTS.md`                                                                         |
| Folder structure, naming                                       | `.claude/rules/ARCHITECTURE.md`                                                     |
| Data → domain pattern                                          | `.claude/skills/clean_architecture_pattern.md` (only here)                          |
| Repository contract / UseCase templates                        | `.claude/rules/CODE_TEMPLATES.md`                                                   |
| Riverpod or Bloc templates (state, Notifier/Bloc, Page, tests) | `.claude/state-management/<riverpod\|bloc>.md`, then re-run `install.sh --force`    |
| Add another state management (e.g. Cubit)                      | add `.claude/state-management/<name>.md` and use `install.sh --state=<name>`        |
| Global widgets                                                 | `.claude/rules/UI_RULES.md` **and** the regex in `.claude/hooks/check_rules.sh`     |
| Forbidden secret files                                         | `.claude/docs/SECURITY.md` + `.claude/hooks/pre_edit_guard.sh` + `permissions.deny` |

| Setting                 | Default | Purpose                                                       |
| ----------------------- | ------- | ------------------------------------------------------------- |
| `STOP_GATE_MAX_RETRIES` | `3`     | Loop attempts before escalating (`0` = skip gate temporarily) |
| `CHECK_RULES_BASE`      | `HEAD`  | Compare against a branch (CI mode)                            |
| `LAUNCH_TIMEOUT`        | `300`   | Seconds `launch_for_testing.sh` waits for the app             |

---

## ❓ Limitations & FAQ

**Does the agent understand Figma automatically?** The visual design, yes (via Figma MCP). Business rules, API and error states, no — that's why `/spec` asks you.

**Riverpod or Bloc?** Both are first-class. `ssl_cli` asks when you create the project (1 Riverpod, 2 Bloc); `install.sh` reads `pubspec.yaml` and installs the matching `STATE_MANAGEMENT.md`, so the agent only ever sees one pattern. Data and domain layers are identical for both.

**Old code breaks the rules check?** `check_rules.sh` only checks changed files, so legacy code is fine until you touch it — then fix it in the same change.

**The gate passed but the feature is wrong?** The gate proves the tests pass. If the acceptance criteria were wrong, the tests are wrong. Spend your time on the spec.

**Can I use TestSprite / other AI testing clouds?** Most target web apps and APIs, and run in their cloud. For native Flutter, local tools fit better: `flutter_test`, golden tests, `integration_test`, Patrol or Maestro, and `flutter-skill`.

**A spec change really requires removing a test?** The human removes it and commits — the agent may not.

---

## 🏷️ Releasing (maintainers)

1. Merge changes to `master`.
2. Bump the default `VERSION` in `get.sh` and the tag in this README's install URLs (e.g. `v2.0.0` → `v2.1.0`).
3. Commit, then tag and push: `git tag -a v2.1.0 -m "v2.1.0" && git push origin master --follow-tags`.
4. Projects upgrade with the one-liner for the new tag plus `--force`.

---

## 🤝 Contributing

1. Fork, branch, and change one thing.
2. Keep the "one fact, one file" rule — link, don't copy.
3. Test hooks with `bash -n` and a scratch Flutter project.
4. Open a PR describing which layer (prompt / context / harness / loop) changed and why.

## 📜 License

MIT — use it, fork it, share it. ⭐ the repo if it helps your team.

_Built by Abu Sayed Chowdhury_
