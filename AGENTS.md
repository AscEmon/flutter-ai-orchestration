# Mobile Team — AI Agent Context

> **Canonical source of truth for every AI coding tool.**
> Read natively by: GitHub Copilot · OpenAI Codex · Cursor · Aider · Claude Code

---

## Stack (Always Active)

| Concern | Choice |
|---------|--------|
| Language | Dart / Flutter (3.11+) |
| Architecture | Clean Architecture — feature-based |
| State | Riverpod (`flutter_riverpod` 3.x) |
| HTTP | Dio 5.x — `response.data` is already parsed |
| Error type | `Either<Failure, T>` via `dartz` |
| DI | GetIt (`sl` singleton) |
| Sizing | `flutter_screenutil` (`.w .h .sp .r`) |
| Scaffolding | `ssl_cli` (Dart global) |
| Safe JSON | `autosafe_json` → `SafeJson.as*()` |
| Secrets | `envied` → always read via `Env.*` |

---

## 5 Golden Rules (Never Break)

1. **Scaffold with CLI** — never create folders manually → `ssl_cli module <name>`
2. **Safe JSON only** — never raw-cast → `SafeJson.asString(json['x'])`, not `json['x'] as String`
3. **Secrets via envied** — never hardcode → `Env.apiKey`, never `dotenv` / `String.fromEnvironment`
4. **Global widgets only** — never raw Flutter → `GlobalText`, `GlobalButton`, `GlobalLoader`, etc.
5. **Never touch generated files** — `env.g.dart`, `key.properties`, `Secret.xcconfig` are auto-generated

---

## Agent Decision Flow (Run Every Task)

```
Received a task?
  ↓
ssl_cli help --all       → not found? → dart pub global activate ssl_cli
  ↓
autosafe --version       → not found? → dart pub global activate autosafe_json
  ↓
New project?    → Yes → ssl_cli create <name>   (pattern 4 · Riverpod)
New feature?    → Yes → ssl_cli module <name>   (pattern 3 · Riverpod)
Modified model? → Yes → autosafe /path/to/model.dart
Added assets?   → Yes → ssl_cli generate k_assets.dart
  ↓
Fill logic · Register DI in service_locator.dart · Verify .gitignore
```

---

## DI Registration Order (service_locator.dart)

```dart
// 1. DataSources    → registerLazySingleton
// 2. Repository     → registerLazySingleton
// 3. UseCases       → registerFactory   ← always Factory, never Singleton
```

---

## Widget Substitution Table

| ❌ Never | ✅ Always |
|---------|---------|
| `Text(...)` | `GlobalText(str: ...)` |
| `ElevatedButton(...)` | `GlobalButton(...)` |
| `TextFormField(...)` | `GlobalTextFormField(...)` |
| `DropdownButton(...)` | `GlobalDropdown(...)` |
| `Image.asset(...)` | `GlobalImageLoader(...)` |
| `CircularProgressIndicator()` | `GlobalLoader()` |
| `AppBar(...)` | `GlobalAppBar(...)` |
| `showSnackBar(...)` | `ViewUtil.snackbar(context, msg)` |
| `Color(0xFF...)` hardcoded | `AppColors.primary.color` |
| Asset path string | `ImageNamePng.x` / `SvgName.x` |
| `200` / `16` (raw numbers) | `200.w` / `16.sp` / `12.r` |

> **Note:** `GlobalText` handles `.sp` internally — pass `fontSize` as a plain `double`, not `16.sp`.

---

## Key Error Handling Rule

Every repository method MUST use `handleException()` — **never** manual try/catch:

```dart
@override
Future<Either<Failure, ProductEntity>> getProduct(String id) {
  return handleException(() async {
    final result = await remoteDataSource.getProduct(id);
    return result.toEntity();
  });
}
```

---

## Detailed References

Pull these files when you need full templates, patterns, or rules for a specific topic:

| Topic | File |
|-------|------|
| Architecture, folder structure, naming, DI patterns | `.claude/rules/ARCHITECTURE.md` |
| CLI usage, ssl_cli & autosafe step-by-step workflow | `.claude/rules/CLI_WORKFLOW.md` |
| Full code templates (Entity, Model, UseCase, Provider, Page) | `.claude/rules/CODE_TEMPLATES.md` |
| UI rules, global widgets, responsive sizing | `.claude/rules/UI_RULES.md` |
| Security rules, forbidden files, envied setup, .gitignore | `.claude/docs/SECURITY.md` |
| QA & testing guidance | `.claude/skills/qa_test.md` |

> **AI agents:** Read the relevant reference file before generating any code for that topic.

---

## Development Pipeline

```
Stage 1: User Prompt → Stage 2: Coding → Stage 3: Testing
```

- **User Prompt** → extract user demand and plan about the feature, and ask for any missing information from the user and confirm it with the user to make sure everything is correct
- **Coding** → ssl_cli → fill logic → autosafe → register DI and create test file for each usecase and notifier
- **Testing** → unit-test UseCases & Notifiers · widget-test components · ≥ 80% coverage- - and manual testing using flutter-skill and run the app to test the feature, if any bug found, list them and ask user what to do.

---

*Maintained by Mobile Team · See `.claude/` for all extended rules*
