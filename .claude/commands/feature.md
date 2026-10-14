---
description: Full AI-native pipeline for one feature — spec → tests → code → stop-gate loop → review → QA
argument-hint: <feature-name>
---
Implement feature `$1` using the pipeline in AGENTS.md → Development Pipeline.

1. **Spec** — `docs/specs/$1.md` must exist and be approved. If not, run the `/spec` flow first and stop.
2. **Tests first** — use the `test-writer` subagent to write failing tests from the spec's acceptance criteria.
3. **Code** — `ssl_cli module $1` (if new, pattern 3 + the state management in `.claude/rules/STATE_MANAGEMENT.md`) → fill data/domain per `.claude/skills/clean_architecture_pattern.md` and presentation per `.claude/rules/STATE_MANAGEMENT.md` → `autosafe` on models → register DI.
4. **Gate loop** — finish your turn; the Stop hook runs analyze + golden rules + tests. On failure, read the report, fix the CODE (never the tests), and finish again.
5. **Review** — use the `reviewer` subagent. If `pass` is false, fix and repeat from step 4. If `route` is "spec" or "human", stop and ask me.
6. **QA** — offer to run `/qa_test` on a device.
7. **Done report** — table of AC-ID → test name → pass/fail, files changed, and anything left open.
