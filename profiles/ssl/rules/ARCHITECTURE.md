# Architecture Rules — Clean Architecture (Feature Based)

> **Purpose:** Strict structure and dependency rules for Flutter Clean Architecture (Riverpod or flutter_bloc).

## Core Architecture Pattern

This project follows **Clean Architecture**. State management is **Riverpod or flutter_bloc** — the active one, with its presentation folders and templates, is defined in `.claude/rules/STATE_MANAGEMENT.md`. All code MUST follow this three-layer structure:

```
Domain Layer (Business Logic) → Data Layer (Data Management) → Presentation Layer (UI)
```

**Dependency Rule:** Dependencies ONLY point inward. Domain has NO dependencies on outer layers.

```
┌──────────────────────────┐
│ Presentation Layer       │  State mgmt, Pages, Widgets
├──────────────────────────┤
│ Domain Layer             │  UseCases, Entities, Repository Contracts
├──────────────────────────┤
│ Data Layer               │  Models, Repository Impl, Remote/Local DataSources
└──────────────────────────┘
```

---

## Mandatory Feature Module Structure

When creating ANY new feature, this exact folder structure is required:

```
lib/features/{feature_name}/
├── data/
│   ├── datasources/
│   │   ├── {feature}_remote_datasource.dart
│   │   └── {feature}_local_datasource.dart
│   ├── models/
│   │   └── {name}_response.dart      ← nullable DTO (see clean_architecture_pattern.md)
│   └── repositories/
│       └── {feature}_repository_impl.dart
├── domain/
│   ├── entities/
│   │   └── {entity_name}_entity.dart   ← non-null with defaults
│   ├── repositories/
│   │   └── {feature}_repository.dart
│   └── usecases/
│       └── {action}_usecase.dart
└── presentation/
    ├── pages/
    │   └── {page_name}_page.dart
    ├── providers/                       ← Riverpod: {feature}_provider.dart + state/{feature}_state.dart
    │   OR
    ├── bloc/                            ← Bloc: {feature}_bloc.dart + event/ + state/
    └── widgets/        (exact layout: .claude/rules/STATE_MANAGEMENT.md)
        └── {widget_name}.dart
```

## Core Structure (Shared Infrastructure)

```
lib/core/
├── config/            # env.dart (envied secrets)
├── constants/         # API URLs, app constants
├── di/                # Dependency injection (GetIt)
├── entities/          # Base entities
├── error/             # Exceptions and failures
├── models/            # Global models
├── network/           # API client, network info
├── presentation/
│   ├── widgets/       # Global reusable widgets
│   └── mixins/        # Shared presentation logic
├── routes/            # Navigation
├── theme/             # Theme, colors
├── usecases/          # Base UseCase interface
└── utils/             # Helpers, extensions
```

---

## Dependency Injection Rules

```dart
// 1. Data Sources
sl.registerLazySingleton<{Feature}RemoteDataSource>(
  () => {Feature}RemoteDataSourceImpl(apiClient: sl()),
);

// 2. Repository
sl.registerLazySingleton<{Feature}Repository>(
  () => {Feature}RepositoryImpl(remoteDataSource: sl(), localDataSource: sl()),
);

// 3. Use Cases (Factory)
sl.registerFactory(() => {Action}UseCase(repository: sl()));
```

---

## Error Handling Pattern (MANDATORY)

```dart
// core/error/failures.dart
abstract class Failure extends Equatable {
  final String message;
  const Failure({required this.message});
  @override
  List<Object> get props => [message];
}

class NetworkFailure extends Failure {
  const NetworkFailure({required super.message});
}
```

**Error Flow:**
1. **Data Source:** Throw exceptions
2. **Repository:** Catch exceptions → Return `Left(Failure)`
3. **Use Case:** Pass through `Either<Failure, Data>`
4. **Notifier / Bloc:** `result.fold()` → update state (Riverpod) or `emit()` a state (Bloc)

---

## Naming Conventions (STRICT)

| Type | Pattern | Example |
|------|---------|---------|
| Entity | `{name}_entity.dart` | `user_entity.dart` |
| Response model | `{name}_response.dart` | `user_response.dart` |
| UseCase | `{action}_usecase.dart` | `get_user_usecase.dart` |
| Repository | `{feature}_repository.dart` | `auth_repository.dart` |
| Provider (Riverpod) | `{feature}_provider.dart` | `login_provider.dart` |
| Bloc / Event / State (Bloc) | `{feature}_bloc.dart` · `{feature}_event.dart` · `{feature}_state.dart` | `login_bloc.dart` |
| Page | `{name}_page.dart` | `login_page.dart` |

---

## Common Architecture Mistakes

1. ❌ NOT checking ssl_cli before scaffolding
2. ❌ Manually creating folders/files instead of using ssl_cli
3. ❌ Skipping layers (always domain → data → presentation)
4. ❌ Domain layer importing Flutter or data layer packages
5. ❌ Not registering dependencies in service_locator.dart
