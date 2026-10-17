# State Management — flutter_bloc (generic)

> Active state management: **flutter_bloc** (Bloc or Cubit). Folder layout, DI, shared widgets and naming come from
> `.claude/rules/PROJECT_CONVENTIONS.md` — **where the codebase already does something differently, follow the codebase.**

## Pattern
- Use whichever the project already uses: **Cubit** (methods → `emit`) or **Bloc** (events → `on<Event>` → `emit`).
- Events and states are immutable — `sealed` classes (Dart 3) or the project's existing style (`freezed`, `Equatable`).
- One handler per event; call use cases / repositories, never HTTP clients from widgets.
- UI: `BlocBuilder` / `BlocSelector` for rendering, `BlocListener` for side effects (navigation, snackbars), `BlocProvider` to provide.

```dart
sealed class TodoState {}
final class TodoLoading extends TodoState {}
final class TodoLoaded extends TodoState { TodoLoaded(this.todos); final List<Todo> todos; }
final class TodoError extends TodoState { TodoError(this.message); final String message; }

class TodoCubit extends Cubit<TodoState> {
  TodoCubit(this._repo) : super(TodoLoading());
  final TodoRepository _repo;

  Future<void> load() async {
    emit(TodoLoading());
    try {
      emit(TodoLoaded(await _repo.fetchAll()));
    } catch (_) {
      emit(TodoError('Could not load todos'));   // never put raw exception text with PII in UI state
    }
  }
}
```

```dart
BlocBuilder<TodoCubit, TodoState>(
  builder: (context, state) => switch (state) {
    TodoLoading() => const Center(child: CircularProgressIndicator()), // or the project's loader widget
    TodoError(:final message) => Center(child: Text(message)),
    TodoLoaded(:final todos) => ListView(children: [for (final t in todos) Text(t.title)]),
  },
)
```

## Testing
- `blocTest` from `bloc_test` with a mocked repository / use case (`mocktail`); assert the emitted state sequence.
- Widget: `BlocProvider.value(value: mockCubit)` + `whenListen`.
- Name tests with acceptance IDs: `blocTest('AC-01: ...')`.

```dart
blocTest<TodoCubit, TodoState>(
  'AC-01: emits [Loading, Loaded] on success',
  setUp: () => when(() => repo.fetchAll()).thenAnswer((_) async => [Todo(title: 'a')]),
  build: () => TodoCubit(repo),
  act: (cubit) => cubit.load(),
  expect: () => [isA<TodoLoading>(), isA<TodoLoaded>()],
);
```
