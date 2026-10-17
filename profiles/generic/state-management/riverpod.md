# State Management — Riverpod (generic)

> Active state management: **Riverpod**. Folder layout, DI, shared widgets and naming come from
> `.claude/rules/PROJECT_CONVENTIONS.md` — **where the codebase already does something differently, follow the codebase.**

## Pattern
- Logic lives in a `Notifier` / `AsyncNotifier` (or the provider style the project already uses — check existing files first).
- UI reads with `ref.watch(...)`; actions go through `ref.read(provider.notifier).method(...)`.
- Prefer `AsyncValue` (`AsyncNotifier`) for loading / data / error when the project has no custom state class.
- Notifiers call use cases / repositories as the project does — never HTTP clients directly from widgets.

```dart
final todoListProvider = AsyncNotifierProvider<TodoListNotifier, List<Todo>>(TodoListNotifier.new);

class TodoListNotifier extends AsyncNotifier<List<Todo>> {
  @override
  Future<List<Todo>> build() => ref.read(todoRepositoryProvider).fetchAll();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(todoRepositoryProvider).fetchAll());
  }
}
```

```dart
class TodoListPage extends ConsumerWidget {
  const TodoListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(todoListProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()), // or the project's loader widget
          error: (e, _) => Center(child: Text('Something went wrong')),     // never show raw errors with PII
          data: (todos) => ListView(children: [for (final t in todos) Text(t.title)]),
        );
  }
}
```

## Testing
- Notifier: `ProviderContainer(overrides: [...])` with a mocked repository / use case (`mocktail`); assert state transitions.
- Widget: `ProviderScope(overrides: [...])` + `pumpWidget`.
- Name tests with acceptance IDs: `test('AC-01: ...')`.

```dart
test('AC-01: loads todos on success', () async {
  when(() => repo.fetchAll()).thenAnswer((_) async => [Todo(title: 'a')]);
  final container = ProviderContainer(overrides: [todoRepositoryProvider.overrideWithValue(repo)]);
  addTearDown(container.dispose);

  expect(await container.read(todoListProvider.future), hasLength(1));
});
```
