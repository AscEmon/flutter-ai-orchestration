# AI Agent Context — Flutter

> **Canonical source of truth for every AI coding tool** (Claude Code · Copilot · Codex · Cursor · Aider · Gemini).
> This file holds the rules that apply to **every** project. Project-specific rules live in `.claude/rules/`.

---

## Read First (every task)

| File | What it tells you |
|------|-------------------|
| `.claude/rules/PROJECT_CONVENTIONS.md` | **This project's** stack, architecture, folder layout, naming, DI, shared widgets, error handling, secrets, new-feature checklist |
| `.claude/rules/STATE_MANAGEMENT.md` | **This project's** state management pattern + how to test it |
| `.claude/docs/SECURITY.md` | Secret files you must never read or write, logging rules |
| `.claude/rules/*.md`, `.claude/skills/*.md` | Deeper references linked from the files above |

If `PROJECT_CONVENTIONS.md` says **"NOT LEARNED YET"**, stop and ask the user to run `/bootstrap` (Claude Code) before writing feature code.

---

## Universal Rules (every project, every profile)

1. **Match the codebase.** Before writing a file, open 1–2 existing files of the same kind and follow their structure, naming and imports. Conventions in `PROJECT_CONVENTIONS.md` win over your defaults.
2. **No secrets in code, logs or prompts.** Never read the files listed in `SECURITY.md`. Never hardcode keys, tokens or URLs with credentials.
3. **No PII in logs.** Never log national IDs, phone numbers, account/card numbers, tokens or full API responses. No `print()` in `lib/`.
4. **Never edit generated files** (`*.g.dart`, `*.freezed.dart`, `*.gr.dart`, `env.g.dart`, `key.properties`, `Secret.xcconfig`) — regenerate them.
5. **Tests are the contract.** Never weaken, skip or delete a test to make the gate pass, and never add `// ignore:` to silence the analyzer. Fix the code.
6. **Small, focused changes.** No unrelated refactors, no new packages unless the spec asks for them.

---

## Development Pipeline (spec → tests → code → gate loop → review → QA)

```
1 Spec ─► 2 Tests first ─► 3 Code ─► 4 Gate ──fail──► back to 3 (max 3 tries, then ask user)
                                         │ pass
                                         ▼
                                     5 Review ──fail──► back to 3
                                         │ pass
                                         ▼
                                      6 QA ─► 7 Done report
```

1. **Spec** → write `docs/specs/<feature>.md` with numbered acceptance criteria (`AC-01`…, Given/When/Then), API contract, PII/compliance flags and open questions. **Stop and get the user's approval.** (Claude Code: `/spec`)
2. **Tests first** → one test per acceptance criterion, named with its ID: `test('AC-01: ...')`. Every business-logic file (use case, notifier, bloc, cubit, controller, view model) needs a test. (Claude Code: `test-writer` subagent)
3. **Code** → follow the **New Feature Checklist** in `PROJECT_CONVENTIONS.md`. Fix the code to satisfy the tests.
4. **Gate** → must pass before you say "done":
   `bash .claude/hooks/check_rules.sh` · analyzer (no errors anywhere, no warnings in changed files) · tests
   (Claude Code runs this automatically via the Stop hook and loops until green, max 3 attempts. Other IDEs: run `bash .claude/hooks/stop_gate.sh --manual`.)
5. **Review** → acceptance criteria, conventions, security (no PII/secrets in logs). (Claude Code: `reviewer` subagent)
6. **QA** → manual run on device with flutter-skill (`/qa_test`). List bugs and ask the user what to do.
7. **Done** → report a table of AC-ID → test → status, plus files changed.

**Definition of Done:** every acceptance criterion has a passing test, the gate is green, and the review passed.

---

*flutter-ai-orchestration · core rules — profile rules in `.claude/rules/`*
