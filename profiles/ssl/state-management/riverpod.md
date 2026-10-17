# State Management — Riverpod

> **Active state management for this project: Riverpod (`flutter_riverpod` 3.x).**
> Installed by `install.sh` as `.claude/rules/STATE_MANAGEMENT.md`. Must match what `ssl_cli` generated (option **1 for Riverpod**).
> Data and domain layers are identical for every state management — see `.claude/skills/clean_architecture_pattern.md`.

---

## Folder structure (presentation layer)

```
lib/features/{feature}/presentation/
├── pages/
│   └── {page_name}_page.dart
├── providers/
│   ├── {feature}_provider.dart        ← Notifier + NotifierProvider
│   └── state/
│       └── {feature}_state.dart       ← immutable state holding the entity
└── widgets/
    └── {widget_name}.dart
```

| Type | File | Example |
|------|------|---------|
| Provider + Notifier | `{feature}_provider.dart` | `login_provider.dart` |
| State | `{feature}_state.dart` | `login_state.dart` |

---

## State Template — `providers/state/{feature}_state.dart`

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

## Provider Template — `providers/{feature}_provider.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/core/di/service_locator.dart';
import '../../domain/usecases/{action}_usecase.dart';
import 'state/{feature}_state.dart';

final {feature}Provider = NotifierProvider<{Feature}Notifier, {Feature}State>(
  {Feature}Notifier.new,
);

class {Feature}Notifier extends Notifier<{Feature}State> {
  @override
  {Feature}State build() => const {Feature}State();

  Future<void> {action}({required String id}) async {
    state = state.copyWith(isLoading: true);
    final result = await sl<{Action}UseCase>()({Action}Params(id: id));
    result.fold(
      (failure) => state = state.copyWith(isLoading: false, failure: failure),
      (entity) => state = state.copyWith(isLoading: false, {entity}Data: entity),
    );
  }
}
```

---

## Page Template — `pages/{page_name}_page.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/core/presentation/widgets/global_appbar.dart';
import '/core/presentation/widgets/global_loader.dart';
import '/core/presentation/widgets/global_text.dart';
import '../providers/{feature}_provider.dart';

class {Page}Page extends ConsumerWidget {
  const {Page}Page({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch({feature}Provider);

    return Scaffold(
      appBar: const GlobalAppBar(title: '{Page}'),
      body: state.isLoading
          ? const Center(child: GlobalLoader())
          : const Center(child: GlobalText(str: 'Content here')),
    );
  }
}
```

**Rules:**
- ✅ `ConsumerWidget` (or `ConsumerStatefulWidget` if stateful)
- ✅ `ref.watch({feature}Provider)` to read state; `ref.read({feature}Provider.notifier).{action}(...)` for actions
- ✅ Notifier calls the UseCase via `sl<...>()` and folds `Either` into state — no business logic in widgets
- ❌ Never call repositories or datasources from a Notifier — always through a UseCase

---

## Testing

| What | File | How |
|------|------|-----|
| UseCase | `test/features/{feature}/domain/usecases/{action}_usecase_test.dart` | Mock the repository with `mocktail` |
| Notifier | `test/features/{feature}/presentation/providers/{feature}_provider_test.dart` | `ProviderContainer` + mocked UseCase registered in `sl`; assert loading → data / failure |
| Page | `test/features/{feature}/presentation/pages/{page_name}_page_test.dart` | `ProviderScope(overrides: [...])` + `pumpWidget` |

```dart
test('AC-01: loads entity on success', () async {
  when(() => mockUseCase(any())).thenAnswer((_) async => const Right({Entity}Entity()));
  final container = ProviderContainer();
  addTearDown(container.dispose);

  await container.read({feature}Provider.notifier).{action}(id: '1');

  expect(container.read({feature}Provider).isLoading, false);
  expect(container.read({feature}Provider).failure, isNull);
});
```

Dev dependencies: `mocktail`. Lint plugin: `riverpod_lint`.
