# Project Conventions — ssl profile

> Installed by `install.sh` (profile **ssl**): projects created with `ssl_cli` using the Mobile Team house style.
> Managed file — replaced on upgrade. Put project-specific additions in `.claude/rules/PROJECT_NOTES.md`.

## Stack (Always Active)

| Concern | Choice |
|---------|--------|
| Language | Dart / Flutter (3.11+) |
| Architecture | Clean Architecture — feature-based |
| State | **Riverpod or flutter_bloc** — chosen at `ssl_cli create`; the active one is in `.claude/rules/STATE_MANAGEMENT.md` |
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

### Data → Domain mapping pattern (mandatory read)

Before writing **any** model, entity, or repository:

> **Read `.claude/skills/clean_architecture_pattern.md` first.**

It documents the non-negotiable layering this codebase uses: nullable `*_response.dart` DTOs decoded with `SafeJson.as*`, non-nullable `*_entity.dart` value objects with **default values for every field**, and explicit field-by-field model → entity mapping inside `*_repository_impl.dart` with `?? defaultValue` fallbacks. Models **do not** extend entities. Ground-truth reference: the templates in that file (adapt the `Home*` example to your feature).

---

## Agent Decision Flow (Run Every Task)

```
Received a task?
  ↓
ssl_cli help --all       → not found? → dart pub global activate ssl_cli
  ↓
autosafe --version       → not found? → dart pub global activate autosafe_json
  ↓
New project?    → Yes → ssl_cli create <name>   (pattern 4 · state mgmt 1 Riverpod / 2 Bloc)
New feature?    → Yes → ssl_cli module <name>   (pattern 3 · SAME state mgmt as STATE_MANAGEMENT.md)
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
| **Data → Domain mapping (autosafe_json, entity defaults, repo bridge)** | `.claude/skills/clean_architecture_pattern.md` |
| Architecture, folder structure, naming, DI patterns | `.claude/rules/ARCHITECTURE.md` |
| CLI usage, ssl_cli & autosafe step-by-step workflow | `.claude/rules/CLI_WORKFLOW.md` |
| Domain templates (Repository contract, UseCase) | `.claude/rules/CODE_TEMPLATES.md` |
| **State management** — folders, Notifier/Bloc, Page, tests | `.claude/rules/STATE_MANAGEMENT.md` |
| UI rules, global widgets, responsive sizing | `.claude/rules/UI_RULES.md` |
| Security rules, forbidden files, envied setup, .gitignore | `.claude/docs/SECURITY.md` |
| QA & testing guidance | `.claude/skills/qa_test.md` |

> **AI agents:** Read the relevant reference file before generating any code for that topic.

---

## Secrets

Read secrets only through **envied** → `Env.*` (declared in `lib/core/config/env.dart`, generated into `env.g.dart`).
Never `flutter_dotenv`, never `String.fromEnvironment`, never hardcoded values.

---

## New Feature Checklist (used by `/feature`)

1. `ssl_cli module <feature>` — pattern **3** + the state management in `.claude/rules/STATE_MANAGEMENT.md`
2. Data + domain per `.claude/skills/clean_architecture_pattern.md` (response DTO → entity with defaults → repository impl with `handleException`)
3. Presentation per `.claude/rules/STATE_MANAGEMENT.md`
4. `autosafe <path>/<name>_response.dart` after every `fromJson` change
5. Register DI in `service_locator.dart` (datasource/repo lazy singleton, usecase factory)
6. New assets → `ssl_cli generate k_assets.dart`
