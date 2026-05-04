# Code Templates — Domain, Data & Presentation Layers

> **Purpose:** Copy-paste templates for every layer. All code generation MUST follow these patterns.

---

## Domain Layer Templates

### Entity Template

```dart
// lib/features/{feature}/domain/entities/{entity_name}_entity.dart
import 'package:equatable/equatable.dart';

class {EntityName}Entity extends Equatable {
  final String id;
  final String name;

  const {EntityName}Entity({
    required this.id,
    required this.name,
  });

  @override
  List<Object?> get props => [id, name];
}
```

**Rules:**
- ✅ MUST extend `Equatable`
- ✅ MUST be immutable (`const` constructor, `final` fields)
- ✅ NO Flutter imports
- ✅ NO external package dependencies (except `equatable`, `dartz`)

### Repository Contract Template

```dart
// lib/features/{feature}/domain/repositories/{feature}_repository.dart
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/{entity_name}_entity.dart';

abstract class {Feature}Repository {
  Future<Either<Failure, {Entity}Entity>> get{Entity}(String id);
  Future<Either<Failure, List<{Entity}Entity>>> get{Entity}List();
  Future<Either<Failure, void>> create{Entity}({Entity}Entity entity);
  Future<Either<Failure, void>> update{Entity}({Entity}Entity entity);
  Future<Either<Failure, void>> delete{Entity}(String id);
}
```

### UseCase Template

```dart
// lib/features/{feature}/domain/usecases/{action}_usecase.dart
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/{entity_name}_entity.dart';
import '../repositories/{feature}_repository.dart';

class {Action}UseCase implements UseCase<{Return}Entity, {Action}Params> {
  final {Feature}Repository repository;

  {Action}UseCase({required this.repository});

  @override
  Future<Either<Failure, {Return}Entity>> call({Action}Params params) async {
    return await repository.{action}(params);
  }
}

class {Action}Params extends Equatable {
  final String id;

  const {Action}Params({required this.id});

  @override
  List<Object?> get props => [id];
}
```

---

## Data Layer Templates

### 🛡️ autosafe_json — Mandatory Safe JSON Parsing

> **All models MUST use `autosafe_json`. Raw `as` casting is strictly forbidden.**

#### Helper Methods Reference

| Helper | Input type | Safe output |
|--------|-----------|-------------|
| `SafeJson.asInt(v)` | any | `int` (0 if null/invalid) |
| `SafeJson.asString(v)` | any | `String` ('' if null) |
| `SafeJson.asBool(v)` | any | `bool` (false if null) |
| `SafeJson.asDouble(v)` | any | `double` (0.0 if null) |
| `SafeJson.asNum(v)` | any | `num` (0 if null) |
| `SafeJson.asMap(v)` | list/map/null | `Map<String, dynamic>` |
| `SafeJson.asList(v)` | list/map/null | `List<dynamic>` |
| `json.autoSafe.raw` | raw json map | sanitized `Map<String, dynamic>` |

#### Integration Rule

- `json = json.autoSafe.raw;` → **ONLY in the top-level / base response model**
- **Nested models** receive the pre-sanitized map → no need to call `autoSafe.raw` again
- Use `SafeJson.as*()` helpers for every primitive field in every model

### Model Template

```dart
// lib/features/{feature}/data/models/{model_name}_model.dart
import 'package:autosafe_json/autosafe_json.dart';
import '../../domain/entities/{entity_name}_entity.dart';

class {Model}Model extends {Entity}Entity {
  const {Model}Model({
    required super.id,
    required super.name,
  });

  factory {Model}Model.fromJson(Map<String, dynamic> json) {
    json = json.autoSafe.raw; // top-level only
    return {Model}Model(
      id: SafeJson.asString(json['id']),
      name: SafeJson.asString(json['name']),
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}
```

**Rules:**
- ✅ MUST import `package:autosafe_json/autosafe_json.dart`
- ✅ MUST use `SafeJson.as*()` for every primitive field — no raw `as` casting
- ✅ MUST call `json.autoSafe.raw` only in top-level response model
- ✅ MUST extend corresponding entity
- ❌ NEVER use `json['field'] as String` — always use `SafeJson.asString(json['field'])`
- ❌ NEVER use `json['field'] ?? ''` alone — SafeJson handles nulls internally

---

## Presentation Layer Templates

### Provider Template (Riverpod)

```dart
// lib/features/{feature}/presentation/providers/{feature}_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/service_locator.dart';
import '../../domain/usecases/{action}_usecase.dart';
import 'state/{feature}_state.dart';

final {Feature}Provider = NotifierProvider<{Feature}Notifier, {Feature}State>(
  {Feature}Notifier.new,
);

class {Feature}Notifier extends Notifier<{Feature}State> {
  @override
  {Feature}State build() => const {Feature}State();

  Future<void> {action}({required String param}) async {
    final useCase = sl<{Action}UseCase>();
    final result = await useCase({Action}Params(param: param));
    result.fold(
      (failure) => state = state.copyWith(failure: failure),
      (entity) => state = state.copyWith(entity: entity),
    );
  }
}
```

### Page Template

```dart
// lib/features/{feature}/presentation/pages/{page_name}_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/presentation/widgets/global_text.dart';
import '../../../../core/presentation/widgets/global_button.dart';
import '../../../../core/presentation/widgets/global_loader.dart';
import '../providers/{feature}_provider.dart';

class {Page}Page extends ConsumerWidget {
  const {Page}Page({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch({feature}Provider);
    return Scaffold(
      appBar: AppBar(title: const GlobalText(str: '{Page}')),
      body: const Center(child: GlobalText(str: 'Content here')),
    );
  }
}
```

**Rules:**
- ✅ MUST use `ConsumerWidget` for Riverpod; `ConsumerStatefulWidget` if stateful
- ✅ MUST use `ref.watch()` for state; `ref.read().notifier` for actions
- ✅ MUST use global widgets (GlobalText, GlobalButton, etc.)
- ✅ MUST use ScreenUtil (.w, .h, .sp, .r)

---

## Common Code Mistakes

**autosafe_json:**
- ❌ Using raw `as` casting: `json['id'] as String`
- ❌ Adding `json.autoSafe.raw` to nested models (only in top-level)
- ❌ Forgetting to run `autosafe /path/to/model.dart` after modifying `fromJson`

**Security:**
- ❌ Hardcoding API keys, tokens, or passwords in any Dart file
- ❌ Committing `google-services.json` or `GoogleService-Info.plist`
- ❌ Using `flutter_dotenv` or `String.fromEnvironment` for secrets — use envied only
- ❌ Editing `key.properties` or `Secret.xcconfig` manually — auto-generated by script
