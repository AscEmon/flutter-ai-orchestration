# 🤖 Flutter AI Orchestration

**An AI-native software engineering harness for any Flutter project — new or existing, any architecture, any state management. Built for Claude Code, usable from any AI IDE.**

Install it with one command. The AI agent then learns how *your* project is built, writes tests first, checks its own work in a loop, and stops to ask you when it is stuck — instead of telling you "done" when it isn't.

```
/bootstrap (once)  →  /spec community <Figma link>  →  you approve  →  /feature community  →  done report (every AC → passing test)
```

### ⚡ Install in one line (run inside your Flutter project)

```bash
curl -fsSL https://raw.githubusercontent.com/AscEmon/flutter-ai-orchestration/v2.2.2/get.sh | bash
```

On first install you choose **which coding pattern the AI should follow** — the installer recommends one based on your project:

```
  1) ssl_cli pattern — Clean Architecture scaffolded by ssl_cli
       • ssl_cli module <name> · Global widgets · autosafe_json · Either · GetIt · envied · Riverpod or Bloc
       Learn the pattern:  https://pub.dev/packages/ssl_cli
                           https://pub.dev/packages/autosafe_json
  2) Your own pattern (generic) — any architecture, any state management
       • The AI learns YOUR conventions from your code (/bootstrap) and you review them.

  Recommended: 1  (new project — ssl_cli generates a ready-made Clean Architecture structure for you)
  Choose 1 or 2 [Enter = 1]:
```

- **New project → recommends 1**, existing project → recommends 2 (or 1 if it was already created with ssl_cli).
- **New project + 1:** the installer asks *1 Riverpod / 2 Bloc*, installs `ssl_cli` if it's missing (with your OK), runs **`ssl_cli create <name>`** (pattern 4) for you, then installs the AI setup on top.
- **Existing project + 1:** `ssl_cli create` is **never** run (it would overwrite your code) — you're asked whether to use the ssl rules anyway, otherwise you get **2**.
- **Empty folder:** the installer offers to run `flutter create` first, so one command gives you a complete new project.

Not sure? Read the [ssl_cli page on pub.dev](https://pub.dev/packages/ssl_cli). If you don't create projects with `ssl_cli`, choose **2**. State management (Riverpod, Bloc, Provider, GetX…) is detected next. [More options ↓](#install-into-a-project)

| Your situation | Steps |
|---|---|
| **Already installed** | `bash .claude/scripts/update.sh` — [details ↓](#updating-an-existing-project) |
| **Existing project** (any pattern) | `git commit` your work → run the one-liner → choose **2** → `claude` → `/bootstrap` (learns your conventions, you review) |
| **New app with [`ssl_cli`](https://pub.dev/packages/ssl_cli)** (recommended) | `mkdir my_app && cd my_app && git init` → one-liner → **Enter** (creates the Flutter project) → **1** → pick Riverpod / Bloc → it runs `ssl_cli create` for you → `/bootstrap` |
| **New app, your own pattern** | same, but choose **2** and your state management → `/bootstrap` proposes a structure for you to confirm |
| **Already ran `ssl_cli create` yourself** | run the one-liner inside it → **1** is recommended (upgrades ssl_cli's v1 AI docs) → `/bootstrap` |

---

## Table of contents

1. [Why this exists](#-why-this-exists)
2. [Profiles — works with any Flutter project](#-profiles--works-with-any-flutter-project)
3. [How it works — the 4 layers of AI-native engineering](#-how-it-works--the-4-layers-of-ai-native-engineering)
4. [Quick start](#-quick-start)
5. [Existing & legacy projects](#-existing--legacy-projects)
6. [Daily workflow — building a feature](#-daily-workflow--building-a-feature)
7. [Who validates what](#-who-validates-what)
8. [What's inside](#-whats-inside)
9. [Security & compliance](#-security--compliance)
10. [CI — same gate for humans and agents](#-ci--same-gate-for-humans-and-agents)
11. [Measuring if it works](#-measuring-if-it-works)
12. [Other AI IDEs](#-other-ai-ides)
13. [Customizing](#-customizing)
14. [Limitations & FAQ](#-limitations--faq)

---

## 💡 Why this exists

AI coding agents are fast, but out of the box they:

| Problem | What this repo adds |
|---|---|
| Ignore your architecture and invent their own | **Context**: conventions learned from your code, loaded every session |
| Need long, perfect prompts | **Prompt**: commands that turn 3 lines of input into a full spec |
| Touch secrets, run risky commands | **Harness**: guard hooks, allow/deny permissions, scoped subagents |
| Say "done" when the code doesn't compile or tests fail | **Loop**: a Stop gate that blocks "done" until rules + analyzer + tests pass |
| Leak secrets or log customer data | Deny-listed secret files, secret scanners, PII rules |

---

## 🧭 Profiles — works with any Flutter project

```
CORE (every project)      loop gate · test integrity · /spec /feature /qa_test /bootstrap · subagents · security hooks · CI
   +
PROFILE                   ssl      → Mobile Team house style (ssl_cli, Global widgets, SafeJson, GetIt, envied)
                          generic  → ANY project: conventions are learned from your code by /bootstrap
   +
STATE MANAGEMENT          riverpod · bloc · custom (Provider, GetX, MobX, Redux, Signals… learned from your code)
```

| | **ssl** profile | **generic** profile |
|---|---|---|
| Choose it when | your project is (or will be) created with [ssl_cli](https://pub.dev/packages/ssl_cli) and follows its pattern | you have your own architecture, or don't use ssl_cli |
| Recommended automatically when | `autosafe_json` in pubspec, `lib/core/presentation/widgets/global_text.dart`, or ssl_cli's v1 AI docs | everything else |
| `PROJECT_CONVENTIONS.md` | Mobile Team rules (managed) | **written by `/bootstrap` from your code**, reviewed by you, kept on upgrades |
| `STATE_MANAGEMENT.md` | ssl_cli Riverpod / Bloc templates | neutral Riverpod / Bloc guide — or learned (`custom`) for anything else |
| Banned patterns in the gate | raw `Text(`/`AppBar(`…, raw casts, hardcoded colors, `print(`, dotenv | only `print(` — plus any project-widget rules you approve in `/bootstrap` |
| New Feature Checklist | `ssl_cli module` → SafeJson → DI | learned: "add a feature the way this codebase does it" |

You're asked on the **first** install; upgrades keep your choice. Skip the question with `--profile=ssl|generic` (or `AI_ORCH_PROFILE`). Without a terminal (CI) nothing is created or installed on its own — pass `--yes` (or `AI_ORCH_YES=1`) together with `--profile` and `--state`. State: `--state=riverpod|bloc|custom` (or `AI_ORCH_STATE`).

**ssl_cli resources:** [ssl_cli on pub.dev](https://pub.dev/packages/ssl_cli) (scaffolding, Clean Architecture modules, Riverpod/Bloc) · [autosafe_json on pub.dev](https://pub.dev/packages/autosafe_json) (safe JSON parsing).

---

## 🧠 How it works — the 4 layers of AI-native engineering

```
┌──────────────────────────────────────────────────────────────────────────┐
│ 1. PROMPT ENGINEERING   /bootstrap · /spec · /feature · /qa_test         │  what you type
├──────────────────────────────────────────────────────────────────────────┤
│ 2. CONTEXT ENGINEERING  AGENTS.md · PROJECT_CONVENTIONS.md ·             │  what the agent knows
│                         STATE_MANAGEMENT.md · SECURITY.md · MCP          │
├──────────────────────────────────────────────────────────────────────────┤
│ 3. HARNESS ENGINEERING  hooks · permissions · subagents ·                │  what the agent can
│                         project tools (e.g. ssl_cli in the ssl profile)  │  and cannot do
├──────────────────────────────────────────────────────────────────────────┤
│ 4. LOOP ENGINEERING     Stop gate → fix → retry (max 3) → reviewer →     │  how the agent proves
│                         human escalation · Definition of Done            │  its work is correct
└──────────────────────────────────────────────────────────────────────────┘
```

### 1. Prompt engineering — you write 3 lines, the command writes the real prompt

| Command | You type | It expands into |
|---|---|---|
| `/bootstrap` | `/bootstrap` | Once per project: learns (generic) or verifies (ssl) conventions, measures the gate baseline, adds test tooling — stops for your review |
| `/spec` | `/spec community <Figma link> Rules: users post, like, comment; only author edits` | Reads Figma + your notes → `docs/specs/community.md` with numbered acceptance criteria (`AC-01`…), API contract, PII flags, open questions — then **stops for your approval** |
| `/feature` | `/feature community` | The full pipeline: tests first → code per your conventions → gate loop → review → done report |
| `/qa_test` | `/qa_test` | Device QA via `flutter-skill` MCP — reports bugs, fixes nothing until you approve |

**Why a spec?** The agent understands the *design* from Figma but not the *business* (API, rules, error states). The spec captures both, and its acceptance criteria become the tests.

### 2. Context engineering — the agent always knows *this* project's rules

| File | Loaded | Contains |
|---|---|---|
| `AGENTS.md` | Every session, every AI IDE | Universal rules (match the codebase, no secrets, no PII logs, tests are the contract), pipeline, Definition of Done |
| `CLAUDE.md` | Every Claude Code session | Hooks, permissions, subagents, commands |
| `.claude/rules/PROJECT_CONVENTIONS.md` | Auto-loaded | **This project's** stack, folder layout, naming, DI, widgets, error handling, secrets, New Feature Checklist |
| `.claude/rules/STATE_MANAGEMENT.md` | Auto-loaded | **This project's** state pattern + how to test it |
| `.claude/rules/PROJECT_NOTES.md` | Auto-loaded (optional) | Your own extra rules — never touched by the installer |
| `.claude/docs/SECURITY.md` | On demand | Forbidden files, secret handling, `.gitignore` list |
| MCP servers | Live | Figma (design), `flutter-skill` (running app) |

**Rule:** one fact lives in one file. Other files link to it — rules never contradict each other.

### 3. Harness engineering — reliable tools and hard limits

| Part | What it does |
|---|---|
| `pre_edit_guard.sh` | **Blocks** writes to `.env`, keystores, generated secret files, Firebase configs |
| `pre_bash_git_guard.sh` + `pre_commit.sh` | **Blocks** commits that contain secrets (Claude and humans) |
| `post_write.sh` | Scans every written file for leaked secret patterns |
| `permissions.allow` / `deny` | Safe commands run without prompts; secret files, `curl`/`wget`, force-push and hard reset are never allowed |
| `test-writer` subagent | Writes tests only — cannot touch `lib/` |
| `reviewer` subagent | Read-only — can judge, cannot "fix" its way past a review |
| Project tools | ssl profile: `ssl_cli` scaffolding, `autosafe`; generic: whatever your checklist uses (`build_runner`, `mason`, …) |

### 4. Loop engineering — the agent proves its work

```
                Claude says "I'm done"
                         │
                         ▼
        ┌─────────── Stop gate (.claude/hooks/stop_gate.sh) ───────────┐
        │  1. check_rules.sh → profile rules · missing tests ·          │
        │                      deleted/skipped tests · new // ignore    │
        │  2. analyzer      → errors anywhere, warnings in changed files│
        │  3. tests         → full suite, or only related tests         │
        └──────────────────────────┬───────────────────────────────────┘
                 fail              │               pass
          ┌────────────────────────┴───────────────────────┐
          ▼                                                ▼
  error report sent back to Claude              reviewer subagent
  → it fixes the CODE (never the tests)         (spec · conventions · security)
  → says "done" again                                       │
          │                                                 ▼
  after 3 failures → STOP, escalate to you       /qa_test on device → done report
```

- **Retry budget:** 3 attempts (`STOP_GATE_MAX_RETRIES`), then it stops and reports.
- **Anti-cheating:** deleting tests, adding `skip:`, or adding `// ignore:` fails the gate.
- **Only what changed:** rules and warnings are checked on changed files only — legacy code doesn't block you.
- **Audit trail:** every PASS / FAIL / ESCALATED is written to `.claude/audit.log`.

**Definition of Done:** every acceptance criterion has a passing test, the gate is green, and the reviewer passed.

---

## 🚀 Quick start

### Prerequisites

| Tool | Needed for |
|---|---|
| Flutter SDK | everything |
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | the full loop (other AI IDEs get the rules — see below) |
| `git`, `bash`, `curl` | installer and hooks (Windows: use **WSL** or **Git Bash**) |
| [`ssl_cli`](https://pub.dev/packages/ssl_cli), [`autosafe_json`](https://pub.dev/packages/autosafe_json) | **ssl profile only** — `dart pub global activate ssl_cli` and `dart pub global activate autosafe_json` |
| `flutter-skill` (optional) | `/qa_test` — see [flutter_skill](https://pub.dev/packages/flutter_skill) |
| Figma MCP (optional) | `/spec` from a Figma link |

### Install into a project

**Option A — one line from GitHub (recommended).** Run inside the project folder:

```bash
git add -A && git commit -m "baseline"                        # gates compare against your last commit
curl -fsSL https://raw.githubusercontent.com/AscEmon/flutter-ai-orchestration/v2.2.2/get.sh | bash                                           # auto-detect everything
curl -fsSL https://raw.githubusercontent.com/AscEmon/flutter-ai-orchestration/v2.2.2/get.sh | AI_ORCH_STATE=bloc bash                        # force state: riverpod | bloc | custom
curl -fsSL https://raw.githubusercontent.com/AscEmon/flutter-ai-orchestration/v2.2.2/get.sh | AI_ORCH_PROFILE=generic bash                   # force profile: ssl | generic
curl -fsSL https://raw.githubusercontent.com/AscEmon/flutter-ai-orchestration/v2.2.2/get.sh | bash -s -- --profile=generic --state=riverpod  # same, flag form (note the -s --)
```

> ⚠ **`bash: --state=riverpod: invalid option`?** Options after `| bash` need `-s --` first. Easier: use the `AI_ORCH_*` variables, or just `| bash` and answer the prompt.
> Always use a **version tag** in the URL (`v2.2.2`), never `master`. Prefer to read first? `curl -fsSLO https://raw.githubusercontent.com/AscEmon/flutter-ai-orchestration/v2.2.2/get.sh`, open `get.sh`, then `bash get.sh`. Internal mirror: `AI_ORCH_TARBALL=<url> bash get.sh`.

**Option B — from a local clone** (contributors / offline):

```bash
git clone https://github.com/AscEmon/flutter-ai-orchestration.git
../flutter-ai-orchestration/install.sh /path/to/my_app [--profile=…] [--state=…] [--force]
```

The installer copies the core + profile files, merges secret entries into `.gitignore`, installs a git pre-commit secret scan, and records `.claude/ai-orchestration.version` (version, profile, state) and a manifest of the files it manages. It never touches `lib/`, `test/`, `pubspec.yaml`, `.env`, `.claude/settings.local.json` or `.claude/gate.local.conf`.

### First session

```bash
claude
> /bootstrap
```

### Updating an existing project

Already using it? Commit your work, then from the project root:

```bash
bash .claude/scripts/update.sh            # update to the latest release
bash .claude/scripts/update.sh --check    # just show installed vs latest
bash .claude/scripts/update.sh v2.2.2     # move to a specific release (also for rollback)
```

Installed before v2.2.2 (no `update.sh` yet)? Run this once — afterwards `update.sh` is there:

```bash
curl -fsSL https://raw.githubusercontent.com/AscEmon/flutter-ai-orchestration/v2.2.2/get.sh | bash -s -- --update
```

What an update does:

| Kept (yours) | Replaced (managed) |
|---|---|
| profile + state choice, learned `PROJECT_CONVENTIONS.md`, `PROJECT_NOTES.md`, `gate.local.conf`, `settings.local.json`, your own files in `.claude/` | core hooks, commands, agents, scripts, `AGENTS.md`, `CLAUDE.md`, profile rules, `gate.conf` |

Everything is backed up first to `.ai-orchestration-backup/<timestamp>/`. Review with `git diff`, then commit. What changed in each version: [CHANGELOG.md](CHANGELOG.md).

---

## 🏚️ Existing & legacy projects

It is designed to drop into a codebase that already exists — MVC, MVVM, Clean Architecture, feature-first or layer-first, with or without tests.

| Concern | How it's handled |
|---|---|
| "The agent will rewrite my app in its own style" | Generic profile has **no house style**. `/bootstrap` reads your code and documents *your* conventions; the agent must open similar existing files before writing new ones |
| Hundreds of existing analyzer warnings | Gate blocks on **errors anywhere** but **warnings only in files you changed** (`ANALYZE_SCOPE=changed`) |
| Some existing tests already fail | `/bootstrap` measures the baseline and proposes `TEST_SCOPE=related` — only tests for changed files run |
| No tests at all | Gate skips the test step until the first test exists; new business-logic files must come with a test |
| Tests not in a mirrored folder | A test anywhere under `test/` with the same base name counts |
| `print()` everywhere | Only *new or changed* files are checked — old code is listed as tech debt, not mass-rewritten |
| Your own widgets (`AppText`, `PrimaryButton`…) | `/bootstrap` proposes `EXTRA_BANNED_PATTERNS` (e.g. raw `Text(` → `AppText`) for `.claude/gate.local.conf` — applied only after you approve |
| GetX / Provider / MobX / custom | State is `custom`: `/bootstrap` documents the real pattern in `STATE_MANAGEMENT.md` |

---

## 🔁 Daily workflow — building a feature

| Step | You type | What happens | Your job |
|---|---|---|---|
| 1. Spec | `/spec community https://figma.com/design/… API sample: docs/api/community.json. Rules: post text + 4 images, like, comment; only author edits/deletes; 20 per page` | Agent writes `docs/specs/community.md` and lists open questions | Answer questions, fix wrong ACs (~5 min) |
| 2. Approve | `Spec approved` | — | Your most important decision |
| 3. Build | `/feature community` | test-writer → code per *your* New Feature Checklist → Stop-gate loop → reviewer | Read the done report |
| 4. QA | `/qa_test` | Agent taps through the app on a device and reports bugs | Choose which bugs to fix |
| 5. Ship | `Show the diff summary and propose a commit message` | — | 2-minute diff check, then commit |

Keep features small: one module, 3–8 acceptance criteria.

---

## ✅ Who validates what

| Checker | Checks | Can it be fooled? |
|---|---|---|
| **Stop gate** (machine) | Profile rules, business-logic files have tests, no weakened tests, analyzer, tests pass | No — but it only proves what the tests check |
| **reviewer** subagent | Every AC implemented + tested, your conventions, MASVS security, no PII in logs | Sometimes — it's a second opinion |
| **You** | Approve conventions and the spec before; review the diff and QA after | Final authority |

**2-minute diff check — reject if you see:** a file over ~300 lines or duplicated logic · a new package you didn't ask for · tests that only check "not null" · business logic in a widget · PII or tokens in logs.

---

## 📂 What's inside

```
flutter-ai-orchestration/
├── get.sh                    ← one-line installer (downloads a release tag, runs install.sh)
├── install.sh                ← detects profile + state, installs / upgrades safely (backup, manifest)
├── CHANGELOG.md              ← what changed in each release
├── AGENTS.md                 ← CORE universal rules + pipeline (every AI IDE)
├── CLAUDE.md                 ← Claude Code entry point (@imports AGENTS.md)
├── .mcp.json  .env.example
├── ci-templates/             ← GitLab + GitHub jobs running the same gate
├── docs/specs/               ← feature specs written by /spec
├── .claude/                  ← CORE (installed into every project)
│   ├── settings.json         ← hooks + allow/deny permissions
│   ├── commands/             ← bootstrap · spec · feature · qa_test
│   ├── agents/               ← test-writer · reviewer
│   ├── hooks/                ← stop_gate · check_rules · _gate_config · secret guards · audit
│   ├── skills/qa_test.md   docs/SECURITY.md   mcp/   scripts/
└── profiles/
    ├── ssl/                  ← Mobile Team house style (ssl_cli projects)
    │   ├── rules/            ← PROJECT_CONVENTIONS · ARCHITECTURE · CLI_WORKFLOW · CODE_TEMPLATES · UI_RULES
    │   ├── skills/           ← clean_architecture_pattern.md
    │   ├── state-management/ ← riverpod.md · bloc.md
    │   └── gate.conf
    └── generic/              ← any Flutter project
        ├── rules/            ← PROJECT_CONVENTIONS (placeholder → learned by /bootstrap)
        ├── state-management/ ← riverpod.md · bloc.md (neutral) · custom.md (learned)
        └── gate.conf
```

`claude-ai-mobile-session.html` — slides from the team's AI-native engineering session (not installed into projects).

---

## 🛡️ Security & compliance

Built with banking / fintech apps in mind (PCI-DSS, Bangladesh Bank ICT guidelines) — and safe defaults for everyone else.

- **Secrets never reach the AI:** secret files are deny-listed for reading and blocked for writing; `.env` is filled by humans only.
- **Secrets never reach git:** commit guard for Claude + git pre-commit hook for humans + `scan_git_history.sh` for past leaks.
- **No PII in logs:** `print()` banned in changed code, release-silent logger, reviewer checks for national IDs / phone / account data.
- **Least privilege:** no blanket `bash *` / `python3:*`; no `curl` / `wget`; no force-push.
- **Data leaving your machine:** prompts and the code the agent reads go to the AI provider. Confirm your contract and company AI policy allow it; never paste real customer data or credentials. `/bootstrap` reads code structure, never secret files.

---

## 🏗️ CI — same gate for humans and agents

| Platform | Template |
|---|---|
| GitLab | copy `ci-templates/gitlab-flutter-quality.yml` into your project and `include` it |
| GitHub | copy `ci-templates/github/flutter-quality.yml` into `.github/workflows/` |

Both run `stop_gate.sh --manual` — the same rules, analyzer scope and test scope as the Claude Code loop — against the target branch (`CHECK_RULES_BASE`).

---

## 📊 Measuring if it works

| Metric | How |
|---|---|
| Gate failures per success | `grep -c "STOP_GATE FAIL" .claude/audit.log` ÷ `grep -c "STOP_GATE PASS" .claude/audit.log` — lower is better |
| Escalations (agent got stuck) | `grep -c ESCALATED .claude/audit.log` |
| Cost per feature | `/cost` in Claude Code |
| Quality | bugs found in QA / production per feature, before vs after |

A feature that keeps needing 3 attempts means the **spec or the conventions** need improving — not more retries.

---

## 🧩 Other AI IDEs

Claude Code gets the full harness (hooks, loop, subagents, commands). Other IDEs get the same **rules** via `sh .claude/scripts/setup_ide.sh` (Cursor, Windsurf, Copilot, Gemini CLI, Codex / Aider). Before calling a task done there, run:

```bash
bash .claude/hooks/stop_gate.sh --manual
```

---

## 🎨 Customizing

| Change | Edit |
|---|---|
| This project's conventions | `.claude/rules/PROJECT_CONVENTIONS.md` (generic: yours) · or add `.claude/rules/PROJECT_NOTES.md` |
| Gate rules for this project | `.claude/gate.local.conf` — `EXTRA_BANNED_PATTERNS`, `REQUIRE_TESTS_FOR`, `ANALYZE_SCOPE`, `TEST_SCOPE` |
| Universal rules, pipeline | `AGENTS.md` (in this repo) |
| A whole team style | add `profiles/<your-team>/` (rules, skills, state-management, gate.conf) → `--profile=<your-team>` |
| A new state management pack | `profiles/<profile>/state-management/<name>.md` → `--state=<name>` |
| Forbidden secret files | `.claude/docs/SECURITY.md` + `pre_edit_guard.sh` + `permissions.deny` |

`.claude/gate.local.conf` example:

```bash
TEST_SCOPE=related
REQUIRE_TESTS_FOR="*_controller.dart *_service.dart"
EXTRA_BANNED_PATTERNS='
(^|[^A-Za-z_.])Text\(|||Use AppText (lib/shared/widgets/app_text.dart)
'
```

| Setting | Default | Purpose |
|---|---|---|
| `STOP_GATE_MAX_RETRIES` | `3` | Loop attempts before escalating (`0` = skip gate temporarily) |
| `CHECK_RULES_BASE` | `HEAD` | Compare against a branch (CI mode) |
| `LAUNCH_TIMEOUT` | `300` | Seconds `launch_for_testing.sh` waits for the app |

---

## ❓ Limitations & FAQ

**Does it depend on `ssl_cli`?** No. `ssl_cli` is only used by the **ssl** profile. Every other project uses the **generic** profile.

**Will it work on my existing project?** Yes — that's what the generic profile and `/bootstrap` are for. The better your existing code is organised, the better the learned conventions. Always review `PROJECT_CONVENTIONS.md` before the first feature.

**Does the agent understand Figma automatically?** The visual design, yes (via Figma MCP). Business rules, API and error states, no — that's why `/spec` asks you.

**The gate passed but the feature is wrong?** The gate proves the tests pass. If the acceptance criteria were wrong, the tests are wrong. Spend your time on the spec.

**Monorepo / melos?** Install into each Flutter package that the agent works in.

**A spec change really requires removing a test?** The human removes it and commits — the agent may not.

---

## 🏷️ Releasing (maintainers)

1. Merge changes to `master`.
2. Bump the default `VERSION` in `get.sh`, the tag in this README's install URLs, and add a `CHANGELOG.md` entry.
3. Commit, then: `git tag -a vX.Y.Z -m "vX.Y.Z" && git push origin master --follow-tags`.
4. Add the release notes to `CHANGELOG.md`. Projects update with `bash .claude/scripts/update.sh`.

## 🤝 Contributing

1. Fork, branch, and change one thing.
2. Keep "one fact, one file" — link, don't copy.
3. Core changes go in `.claude/` / `AGENTS.md`; house style goes in a profile.
4. Test hooks with `bash -n` and a scratch Flutter project; open a PR describing which layer (prompt / context / harness / loop) changed and why.

## 📜 License

MIT — use it, fork it, share it. ⭐ the repo if it helps your team.

*Built by Abu Sayed Chowdhury*
