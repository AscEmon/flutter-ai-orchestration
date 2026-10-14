# State Management — flutter_bloc

> **Active state management for this project: flutter_bloc (Bloc + sealed Events/States).**
> Installed by `install.sh` as `.claude/rules/STATE_MANAGEMENT.md`. Must match what `ssl_cli` generated (option **2 for Bloc**).
> Data and domain layers are identical for every state management — see `.claude/skills/clean_architecture_pattern.md`.

---

## Folder structure (presentation layer)

```
lib/features/{feature}/presentation/
├── pages/
│   └── {page_name}_page.dart
├── bloc/
│   ├── {feature}_bloc.dart            ← Bloc with one on<Event> handler per event
│   ├── event/
│   │   └── {feature}_event.dart       ← sealed events
│   └── state/
│       └── {feature}_state.dart       ← sealed states
└── widgets/
    └── {widget_name}.dart
```

| Type | File | Example |
|------|------|---------|
| Bloc | `{feature}_bloc.dart` | `login_bloc.dart` |
| Event | `{feature}_event.dart` | `login_event.dart` |
| State | `{feature}_state.dart` | `login_state.dart` |

---

## Event Template — `bloc/event/{feature}_event.dart`

```dart
import 'package:equatable/equatable.dart';

sealed class {Feature}Event extends Equatable {
  const {Feature}Event();

  @override
  List<Object?> get props => [];
}

class Load{Feature}s extends {Feature}Event {
  const Load{Feature}s();
}

class Refresh{Feature}s extends {Feature}Event {
  const Refresh{Feature}s();
}
```

## State Template — `bloc/state/{feature}_state.dart`

The loaded state carries the **entity directly** — the UI never null-checks data.

```dart
import 'package:equatable/equatable.dart';
import '/features/{feature}/domain/entities/{entity_name}_entity.dart';

sealed class {Feature}State extends Equatable {
  const {Feature}State();

  @override
  List<Object?> get props => [];
}

class {Feature}Initial extends {Feature}State {
  const {Feature}Initial();
}

class {Feature}Loading extends {Feature}State {
  const {Feature}Loading();
}

class {Feature}Loaded extends {Feature}State {
  final {Entity}Entity data;

  const {Feature}Loaded(this.data);

  @override
  List<Object?> get props => [data];
}

class {Feature}Error extends {Feature}State {
  final String message;

  const {Feature}Error(this.message);

  @override
  List<Object?> get props => [message];
}
```

## Bloc Template — `bloc/{feature}_bloc.dart`

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '/core/di/service_locator.dart';
import '/core/usecases/usecase.dart';
import '../../domain/usecases/{action}_usecase.dart';
import 'event/{feature}_event.dart';
import 'state/{feature}_state.dart';

class {Feature}Bloc extends Bloc<{Feature}Event, {Feature}State> {
  {Feature}Bloc() : super(const {Feature}Initial()) {
    on<Load{Feature}s>(_onLoad);
    on<Refresh{Feature}s>(_onRefresh);
  }

  Future<void> _onLoad(Load{Feature}s event, Emitter<{Feature}State> emit) async {
    emit(const {Feature}Loading());
    final result = await sl<{Action}UseCase>()(NoParams());
    result.fold(
      (failure) => emit({Feature}Error(failure.message)),
      (data) => emit({Feature}Loaded(data)),
    );
  }

  Future<void> _onRefresh(Refresh{Feature}s event, Emitter<{Feature}State> emit) async {
    await _onLoad(const Load{Feature}s(), emit);
  }
}
```

**Rules:**
- ✅ `Event` and `State` are `sealed` classes extending `Equatable`
- ✅ One `on<Event>` handler per event, registered in the constructor
- ✅ Resolve UseCases via `sl<{Action}UseCase>()`, then `result.fold()` → `emit(...)`
- ❌ Never call repositories or datasources from a Bloc — always through a UseCase
- ❌ Never put business logic in the UI — widgets only dispatch events

---

## Page Template — `pages/{page_name}_page.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '/core/presentation/widgets/global_appbar.dart';
import '/core/presentation/widgets/global_loader.dart';
import '/core/presentation/widgets/global_text.dart';
import '../bloc/{feature}_bloc.dart';
import '../bloc/event/{feature}_event.dart';
import '../bloc/state/{feature}_state.dart';

class {Page}Page extends StatefulWidget {
  const {Page}Page({super.key});

  @override
  State<{Page}Page> createState() => _{Page}PageState();
}

class _{Page}PageState extends State<{Page}Page> {
  @override
  void initState() {
    super.initState();
    context.read<{Feature}Bloc>().add(const Load{Feature}s());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GlobalAppBar(title: '{Page}'),
      body: BlocBuilder<{Feature}Bloc, {Feature}State>(
        builder: (context, state) => switch (state) {
          {Feature}Initial() || {Feature}Loading() => const Center(child: GlobalLoader()),
          {Feature}Error(:final message) => Center(child: GlobalText(str: message)),
          {Feature}Loaded(:final data) => const Center(child: GlobalText(str: 'Content here')),
        },
      ),
    );
  }
}
```

**Providing the bloc** — wrap the page (or the app in `main.dart`):

```dart
BlocProvider(
  create: (_) => {Feature}Bloc(),
  child: const {Page}Page(),
)
// Multiple blocs → MultiBlocProvider(providers: [...], child: ...)
```

**Rules:**
- ✅ Rebuild with `BlocBuilder<{Feature}Bloc, {Feature}State>` + exhaustive `switch` over the sealed state
- ✅ Dispatch events with `context.read<{Feature}Bloc>().add(...)` (first load in `initState`)
- ✅ Side effects (navigation, snackbars) in `BlocListener`, not in `builder`
- ✅ Provide blocs with `BlocProvider` / `MultiBlocProvider`

---

## Testing

| What | File | How |
|------|------|-----|
| UseCase | `test/features/{feature}/domain/usecases/{action}_usecase_test.dart` | Mock the repository with `mocktail` |
| Bloc | `test/features/{feature}/presentation/bloc/{feature}_bloc_test.dart` | `blocTest` from `bloc_test` + mocked UseCase registered in `sl` |
| Page | `test/features/{feature}/presentation/pages/{page_name}_page_test.dart` | `BlocProvider.value` with a `MockBloc` + `whenListen` |

```dart
blocTest<{Feature}Bloc, {Feature}State>(
  'AC-01: emits [Loading, Loaded] on success',
  setUp: () => when(() => mockUseCase(any())).thenAnswer((_) async => const Right({Entity}Entity())),
  build: {Feature}Bloc.new,
  act: (bloc) => bloc.add(const Load{Feature}s()),
  expect: () => [const {Feature}Loading(), const {Feature}Loaded({Entity}Entity())],
);
```

Dev dependencies: `mocktail`, `bloc_test`.
