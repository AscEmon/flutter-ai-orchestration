---
description: Resumable, module-by-module migration of this banking app from the ssl_cli Repository pattern to Clean Architecture — no business-logic changes
argument-hint: [status | analyze | foundation | <module-name> | final]
---
# Clean Architecture Migration — resumable protocol

You are migrating a **production banking app** from the ssl_cli *Repository module* pattern to **Clean Architecture**.

- **Current (source) conventions:** `.claude/rules/PROJECT_CONVENTIONS.md` + `.claude/rules/PROJECT_NOTES.md` — how the code is written today.
- **Target conventions:** `.claude/migration/target/` — `PROJECT_CONVENTIONS.md`, `ARCHITECTURE.md`, `CODE_TEMPLATES.md`, `UI_RULES.md`,
  `clean_architecture_pattern.md`, and `state-management/riverpod.md` or `state-management/bloc.md` (target state management is chosen in Phase A and recorded in the state file).
  New code goes in the target structure; never write new code in the old structure during migration.
This work spans many sessions. **The state file is your memory. Git is your safety net. The human signs off every module.**

Argument: `$ARGUMENTS` (empty = resume from the state file).

---

## 0. Non-negotiable rules

1. **Zero business-logic change.** Validation rules, limits, calculations, OTP/PIN flows, request payloads, headers, encryption, error messages and navigation outcomes must behave exactly as before. You move and restructure code — you do not "improve" logic. If you believe logic is wrong, write it in `Open questions` and keep it as-is.
2. **Security controls are frozen.** Never weaken or remove: certificate pinning, root/jailbreak/emulator detection, device binding, secure storage, encryption/hashing, session timeout, screenshot/screen-record blocking, app-switcher blur, logout data wipe. Moving them is allowed; changing their behavior requires explicit human approval in chat.
3. **Native code is read-only** (`android/`, `ios/`, MethodChannel/EventChannel handlers). If a Dart-side move needs a native change, STOP and ask.
4. **Never read or print secrets** (`.env`, keystores, `env.g.dart`, tokens). Use `[PLACEHOLDER]` in tests and docs. Never use real customer data; test with test accounts/fixtures only.
5. **Characterize before you change.** Every module gets characterization tests that pass on the OLD code first. After the refactor the same assertions must pass — only imports/constructors may change in those tests.
6. **Deduplicate only identical behavior.** Duplicate widgets → one `Global*`/shared widget; duplicate functions → one `core/` utility. If two "duplicates" differ in any way (padding, validation, error text, rounding), list the differences and ask before merging.
7. **One module per session.** After a module is migrated, STOP for human QA sign-off. Do not start the next module unless the human says so.
8. **Small commits.** One commit per step, message `migrate(<module>): <step>`. Never rewrite history, never force-push.

---

## 1. Session start (EVERY time — do this before anything else)

1. Read `docs/migration/MIGRATION_STATE.md`. If it doesn't exist → go to **Phase A (Analysis)**.
2. `git status` must be clean and the branch must be `migration/clean-arch`. If not, STOP and tell the human.
3. `git log --oneline -15` — confirm the last commits match the state file's "Last completed step". If they disagree, trust git, fix the state file, and tell the human.
4. Run `bash .claude/hooks/stop_gate.sh --manual` and the characterization tests listed in the state file. If anything is red, fixing it is the first task.
5. Print a 5-line **Resume summary**: current phase, current module, last completed step, next action, blockers. Then continue with "Next action" (or with `$ARGUMENTS` if the human gave one).

## 2. Session end (when a step finishes, the module needs sign-off, or context is getting long)

1. Update `MIGRATION_STATE.md`: step statuses, **Last completed step**, **Next action** (one precise sentence a new session can execute), new decisions, open questions.
2. Commit: `migrate(<module>): checkpoint — <what is done>`.
3. Tell the human: what's done, what's next, and whether they need to do QA. Suggest `/clear` before the next module.

---

## Phase A — Analysis (no code changes)

Create branch `migration/clean-arch` from the current main branch. Then produce:

**`docs/migration/ANALYSIS.md`**
- Current architecture: folder tree, how a module is wired (view → controller/provider → repository → API), state management, DI, routing, networking (Dio client, interceptors, base URLs per flavor), error handling.
- **Module inventory** table: module · files · screens · API endpoints · depends on · lines of code · test coverage · risk (High/Med/Low with reason).
- **Business-logic register**: every rule as `BL-<MODULE>-NN` with file:line — validations (amount, account number, phone, NID), limits, fee/charge calculations, OTP/PIN/biometric flows, retry/timeout rules, request payload construction, response codes handling, navigation decisions.
- **Security & native register**: `SEC-NN` for pinning, root detection, device binding, secure storage keys, encryption, session timeout, FLAG_SECURE, deep links, MethodChannels — file:line + current behavior.
- **Duplication report**: duplicate/near-duplicate widgets and functions (`DUP-NN`), with "identical" or "differs: …".
- **Dead code** candidates (list only — delete nothing yet).
- **Target state management**: Riverpod or Bloc — recommend one (match what the project already uses if it is one of them) and ask the human.
- **Migration order** (dependency-safe): Foundation → auth → dashboard → qr → my_account → … (adjust only with a reason).

**`docs/migration/MIGRATION_STATE.md`** using the template in §6.

STOP. Show the human the module order, the High-risk items and the open questions. Wait for "Plan approved".

## Phase B — Foundation (security, native bridges, core)

Order: networking → security → storage → shared widgets/utils → DI → routing.
1. Characterization tests first for every `SEC-NN` and for the Dio client/interceptors (headers, pinning config, token refresh, error mapping) — green on old code, commit.
2. Create `lib/core/` per `.claude/migration/target/PROJECT_CONVENTIONS.md` (error/failures + `handleException`, network/ApiClient, di/service_locator, security/, storage/, presentation/widgets, utils).
3. Move security & native-bridge Dart code behind interfaces in `core/security/` **without changing behavior**; old call sites temporarily delegate to the new location (adapter) so nothing breaks.
4. Build shared widgets/utilities from `DUP-NN` items marked *identical* only.
5. Gate green + characterization tests green + `reviewer` subagent pass → STOP for human sign-off (run the app: login, pinning, root detection, session timeout, screenshot block).

## Phase C — Per module (repeat for each, in the approved order)

| Step | Action | Done when |
|---|---|---|
| C1 Contract | Write `docs/migration/modules/<module>.md`: screens, user flows, endpoints with request/response shapes (redacted), its `BL-` and `SEC-` items, its `DUP-` items | Human-readable contract committed |
| C2 Characterize | `test-writer` writes characterization tests on the OLD code: each `BL-` rule, request payload/header building (mock Dio, assert exact body), response parsing, state transitions, error paths | Tests green on old code, committed |
| C3 Scaffold | `ssl_cli module <module>` (pattern 3 + project state management) | Structure created |
| C4 Data | per `.claude/migration/target/clean_architecture_pattern.md`: `*_response.dart` (SafeJson, nullable) · datasource (same endpoint, same payload) · repository impl with `handleException` + explicit model→entity mapping | Unit tests green |
| C5 Domain | Entities with defaults · repository contract · one UseCase per action | Unit tests green |
| C6 Presentation | State + Notifier/Bloc per `.claude/migration/target/state-management/<chosen>.md`; move existing screens, keep UI pixel-identical, swap duplicates for shared widgets | Widget tests green |
| C7 Wire | DI registration, routes point to the new module, remove adapters for this module | App builds, navigation unchanged |
| C8 Parity | Re-run C2 characterization tests against the NEW code (imports/constructors may change, assertions may NOT) | All green, `git diff` shows no assertion changes |
| C9 Clean | Delete the old module files only now; remove dead code listed for this module | No references to old paths (`grep`) |
| C10 Review | Gate green → `reviewer` subagent → fix → done report: every `BL-`/`SEC-` item of the module → new file:line → test name | Reviewer pass |
| C11 Sign-off | STOP. Give the human a manual QA checklist for this module (happy path, errors, offline, session timeout mid-flow, back navigation, rotation, deep link). Tag `migration/<module>-done` only after "Module approved" | Human approved |

## Phase D — Final verification

0. After the last module: tell the human to switch the project to the Clean Architecture rules — `bash .claude/scripts/update.sh` is NOT enough; they run the installer with `--profile=ssl --force` so `.claude/rules/` describes the new structure.
1. Full suite: all characterization + unit + widget tests, `stop_gate.sh --manual` with `ANALYZE_SCOPE=all`.
2. Cross-module flows as integration tests or scripted `/qa_test`: login → dashboard → QR payment → my account → logout; session expiry mid-payment; relaunch after kill.
3. Security re-check of every `SEC-` item; logout wipes storage; no PII/tokens in logs (`grep` for `print(`, `debugPrint(`, `log(` with sensitive fields).
4. Build release for every flavor; compare old vs new `AndroidManifest.xml` permissions, `Info.plist`, app size, and startup time.
5. `grep` that no old-pattern folders/imports remain; dead-code list resolved.
6. Final report in `docs/migration/REPORT.md`: modules, BL/SEC traceability, duplicates removed, files deleted, test counts before/after, known follow-ups. STOP for final human approval before merging.

---

## 6. `docs/migration/MIGRATION_STATE.md` template

```markdown
# Migration State — <app name>
Branch: migration/clean-arch · Started: <date> · Pattern: ssl_cli Repository → Clean Architecture · Target state management: <Riverpod|Bloc>

## Now
- Phase: A | B | C | D
- Current module: <name>
- Last completed step: <e.g. C4 Data — auth> (commit <sha>)
- Next action: <one precise sentence>
- Blockers / waiting on human: <none | ...>

## Phases
| Phase | Status | Notes |
|---|---|---|
| A Analysis | todo / in progress / done / approved | |
| B Foundation | | |
| D Final verification | | |

## Modules (in order)
| # | Module | C1 | C2 | C3 | C4 | C5 | C6 | C7 | C8 | C9 | C10 | Sign-off | Tag |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | auth | | | | | | | | | | | | |
| 2 | dashboard | | | | | | | | | | | | |
| 3 | qr | | | | | | | | | | | | |
| 4 | my_account | | | | | | | | | | | | |

## Characterization test commands
- `flutter test test/characterization/`

## Decisions log
- <date> — <decision> — <why> — <approved by>

## Open questions (do NOT guess — ask)
- [ ] <question> (blocks: <step>)

## Business-logic / security traceability
| ID | Old location | New location | Test | Status |
|---|---|---|---|---|
```

---

When `$ARGUMENTS` is `status`: only do §1 steps 1–3 and print the resume summary and the module table — change nothing.
