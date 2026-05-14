# Clean Architecture Data → Domain Pattern

**Read this BEFORE writing any model, entity, or repository in this codebase.**

This is the canonical pattern used across all features. The pattern is non-negotiable — deviating will create review churn.

---

## TL;DR — Three Layers, Three Roles

| File | Purpose | Field shape | Null handling |
|------|---------|-------------|---------------|
| `data/models/*_response.dart` | Wire-shape DTO. Mirrors API JSON 1:1. | All fields **nullable** (`String?`, `int?`, `List<X>?`) | Decoded with `SafeJson.as*` |
| `domain/entities/*_entity.dart` | UI-facing immutable value object. Has **defaults**. | All fields **non-nullable** with defaults (`this.id = 0`, `this.items = const []`) | Cannot be null at use site |
| `data/repositories/*_repository_impl.dart` | Bridge. Maps model → entity with `?? defaultValue` fallbacks. | — | Coalesces every nullable model field into an entity default |

**Golden rule:** Models DO NOT `extend` entities. They are two independent class hierarchies that the repository wires together.

---

## Required package

```yaml
# pubspec.yaml
dependencies:
  autosafe_json: ^1.0.0
```

`autosafe_json` exposes:
- `SafeJson.asString(dynamic)` → `String?`
- `SafeJson.asInt(dynamic)` → `int?`
- `SafeJson.asDouble(dynamic)` → `double?`
- `SafeJson.asBool(dynamic)` → `bool?`
- `SafeJson.asMap(dynamic)` → `Map<String, dynamic>`
- `SafeJson.asList(dynamic)` → `List<dynamic>`
- `json.autoSafe.raw` extension on `Map<String, dynamic>` — sanitises the top-level map before parsing.

Use these everywhere you cross a JSON boundary. **Never** raw-cast (`json['x'] as String`).

---

## Template — `*_response.dart` (data/models)

Mirror the JSON shape exactly. Every field is nullable. Use defensive `null`/`""` checks before recursing into nested objects.

```dart
import 'package:autosafe_json/autosafe_json.dart';

class HomeResponse {
  final HomeResponseData? data;

  HomeResponse({this.data});

  factory HomeResponse.fromJson(Map<String, dynamic> json) {
    json = json.autoSafe.raw;                              // ← top-level sanitise
    return HomeResponse(
      data: json["data"] == null || json["data"] == ""    // ← defensive check
          ? null
          : HomeResponseData.fromJson(SafeJson.asMap(json["data"])),
    );
  }

  Map<String, dynamic> toJson() => {"data": data?.toJson()};
}

class HomeResponseData {
  final TotalData? totalData;
  final List<History>? history;

  HomeResponseData({this.totalData, this.history});

  factory HomeResponseData.fromJson(Map<String, dynamic> json) => HomeResponseData(
        totalData: json["total_data"] == null || json["total_data"] == ""
            ? null
            : TotalData.fromJson(SafeJson.asMap(json["total_data"])),
        history: json["history"] == null || json["history"] == ""
            ? []
            : List<History>.from(
                SafeJson.asList(json["history"])
                    .map((x) => History.fromJson(SafeJson.asMap(x))),
              ),
      );

  Map<String, dynamic> toJson() => {
        "total_data": totalData?.toJson(),
        "history": history == null
            ? []
            : List<dynamic>.from(history!.map((x) => x.toJson())),
      };
}

class History {
  final int? id;
  final String? deliveryDate;

  History({this.id, this.deliveryDate});

  factory History.fromJson(Map<String, dynamic> json) => History(
        id: SafeJson.asInt(json["id"]),                    // ← SafeJson.as*
        deliveryDate: SafeJson.asString(json["delivery_date"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "delivery_date": deliveryDate,                     // ← snake_case keys
      };
}
```

### Conventions inside response files

- Class names: PascalCase (no `Model` suffix on inner classes — only the outer wrapper is `*Response`).
- Field names: camelCase in Dart, `snake_case` in JSON.
- Every constructor parameter is **named, optional, nullable** — no `required`.
- `fromJson` is a `factory` constructor.
- `toJson` is a regular method returning `Map<String, dynamic>`.
- Lists: default to `[]` on null/"", but the field type stays `List<X>?` (Dart nullable).
- Nested objects: defensive `json["x"] == null || json["x"] == ""` ternary before recursing.

### Generating these files

If `autosafe_json` CLI is available locally:

```bash
autosafe /path/to/raw_response.json
```

…produces the file with the exact shape above. Otherwise write by hand following the template.

---

## Template — `*_entity.dart` (domain/entities)

Pure value objects. **All fields non-nullable**. Every constructor parameter has a default. Extend `Equatable`. No `SafeJson`, no `fromJson` — entities never see raw JSON.

```dart
import 'package:equatable/equatable.dart';

class HomeEntity extends Equatable {
  final TotalDataEntity totalData;
  final List<HistoryEntity> history;
  final int historyCount;

  const HomeEntity({
    this.totalData = const TotalDataEntity(),             // ← nested entity default
    this.history = const [],                              // ← list default
    this.historyCount = 0,                                // ← primitive default
  });

  @override
  List<Object?> get props => [totalData, history, historyCount];
}

class TotalDataEntity extends Equatable {
  final int total;
  final int running;
  final int completed;

  const TotalDataEntity({this.total = 0, this.running = 0, this.completed = 0});

  @override
  List<Object?> get props => [total, running, completed];
}

class HistoryEntity extends Equatable {
  final int id;
  final String deliveryDate;
  final String quantity;

  const HistoryEntity({
    this.id = 0,
    this.deliveryDate = "",
    this.quantity = "",
  });

  @override
  List<Object?> get props => [id, deliveryDate, quantity];
}
```

### Conventions inside entity files

- Class names: PascalCase with `Entity` suffix.
- Constructor: `const`, all named, all optional with a default.
- `String` default → `""`. `int`/`double` → `0`. `bool` → `false`. `List<X>` → `const []`. Nested entity → `const FooEntity()`.
- **No nullable fields.** If the wire field is genuinely optional, give the entity a sensible empty default.
- `props` enumerates every field (Equatable).

---

## Template — `*_repository_impl.dart` (data/repositories)

This is where models become entities. Field-by-field mapping with `?? defaultValue` to coalesce model nullables. Wrap the whole thing in `handleException()`.

```dart
import 'package:dartz/dartz.dart';
import '/core/error/exception_handler.dart';
import '/core/error/failures.dart';
import '../../domain/entities/home_entity.dart';
import '../../domain/repositories/home_repository.dart';
import '../datasources/home_remote_datasource.dart';

class HomeRepositoryImpl implements HomeRepository {
  final HomeRemoteDataSource _remoteDataSource;

  HomeRepositoryImpl({required HomeRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  @override
  Future<Either<Failure, HomeEntity>> getHomes() async {
    return handleException(() async {
      final response = await _remoteDataSource.getHomes();

      // Explicit data-model → domain-entity mapping. Every nullable model
      // field gets coalesced to the entity's default.
      return HomeEntity(
        totalData: TotalDataEntity(
          total: response.data?.totalData?.total ?? 0,
          running: response.data?.totalData?.running ?? 0,
          completed: response.data?.totalData?.completed ?? 0,
        ),
        history: (response.data?.history ?? [])
            .map((item) => HistoryEntity(
                  id: item.id ?? 0,
                  deliveryDate: item.deliveryDate ?? "",
                  quantity: item.quantity ?? "",
                ))
            .toList(),
        historyCount: response.data?.history?.length ?? 0,
      );
    });
  }
}
```

### Conventions inside repository impl

- One repository method per use case.
- Always wrap in `handleException(() async { ... })`.
- Build the entity inline — do not put a `.toEntity()` helper on the model. The mapping lives explicitly in the repository so it's auditable in one place.
- Use `??` for every primitive, `?? ""` for every string, `?? []` for every list, `?? const FooEntity()` for nested entities.

---

## Template — `*_remote_datasource.dart` (data/datasources)

Returns the **model/response type**, not the entity. Translates `_apiClient.request(...)` → typed response.

```dart
abstract class HomeRemoteDataSource {
  Future<HomeResponse> getHomes();
}

class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  final ApiClient _apiClient;
  HomeRemoteDataSourceImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  Future<HomeResponse> getHomes() async {
    try {
      final response = await _apiClient.request(
        endpoint: ApiUrl.getHomes.url,
        method: HttpMethod.get,
      );
      return HomeResponse.fromJson(response);
    } catch (e) {
      rethrow;                                            // ← let handleException catch it
    }
  }
}
```

---

## Template — `*_repository.dart` (domain/repositories)

Interface returns `Either<Failure, Entity>` — never the model.

```dart
abstract class HomeRepository {
  Future<Either<Failure, HomeEntity>> getHomes();
}
```

---

## Template — `*_state.dart` (presentation/providers/state)

State holds the **entity directly with a default**. UI never has to null-check the data field.

```dart
@immutable
class HomeState extends Equatable {
  final bool isLoading;
  final Failure? failure;
  final HomeEntity homeData;                              // ← entity, non-nullable
  final bool? isHomeDataEmpty;

  const HomeState({
    this.isLoading = true,
    this.failure,
    this.homeData = const HomeEntity(),                   // ← entity default
    this.isHomeDataEmpty = false,
  });

  HomeState copyWith({
    bool? isLoading,
    Failure? failure,
    HomeEntity? homeData,
    bool? isHomeDataEmpty,
  }) {
    return HomeState(
      isLoading: isLoading ?? this.isLoading,
      failure: failure,
      homeData: homeData ?? this.homeData,
      isHomeDataEmpty: isHomeDataEmpty,
    );
  }

  @override
  List<Object?> get props => [isLoading, failure, homeData, isHomeDataEmpty];
}
```

---

## Anti-patterns — Common Mistakes

| ❌ Don't | ✅ Do |
|---------|------|
| `class HomeModel extends Home` | Keep models and entities completely separate |
| `class Home { required this.id }` (entity) | `class HomeEntity { this.id = 0 }` (defaults) |
| `int id = json['id'] is int ? json['id'] : 0` | `int? id = SafeJson.asInt(json['id'])` (in model) |
| Inline mapping inside data source | Explicit mapping inside repository impl |
| Manual `try { } catch (e) { return Left(...) }` in repo | Wrap in `handleException()` |
| `homeData: HomeEntity?` in state | `homeData: HomeEntity = const HomeEntity()` |
| `json['x'] as Map<String, dynamic>` | `SafeJson.asMap(json['x'])` |
| Mixing `.toEntity()` helpers on models | Map field-by-field in repository |

---

## End-to-End Checklist

When adding a new feature endpoint, work top-down:

- [ ] **JSON sample** — copy the raw success response into your scratchpad.
- [ ] **Response model** (`data/models/*_response.dart`) — wire-shape DTO, all nullable, `SafeJson.as*`.
- [ ] **Entity** (`domain/entities/*_entity.dart`) — non-null with defaults, Equatable.
- [ ] **Repository interface** (`domain/repositories/*_repository.dart`) — returns `Either<Failure, Entity>`.
- [ ] **Remote datasource** (`data/datasources/*_remote_datasource.dart`) — returns the response type, `rethrow` on catch.
- [ ] **Repository impl** (`data/repositories/*_repository_impl.dart`) — `handleException` + explicit model→entity mapping with `??` fallbacks.
- [ ] **Use case** (`domain/usecases/*_usecase.dart`) — `implements UseCase<Entity, Params>`.
- [ ] **State** (`presentation/providers/state/*_state.dart`) — entity with `const FooEntity()` default.
- [ ] **Notifier** (`presentation/providers/*_provider.dart`) — Riverpod `Notifier`, calls use case, folds into state.
- [ ] **DI** (`core/di/service_locator.dart`) — register datasource (lazy singleton), repo (lazy singleton), use case (factory).

---

*If anything in this skill conflicts with newer guidance in `.claude/rules/` or `AGENTS.md`, ask the user before deviating. Treat the heidelberg `lib/features/homes/` implementation as the ground-truth reference.*
