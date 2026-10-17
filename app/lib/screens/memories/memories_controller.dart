import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/memory.dart';
import '../../services/api_exception.dart';
import '../../services/auth_service.dart';
import '../../services/marlix_api.dart';

/// What marlix remembers about the person (US-08), always as the backend has
/// it: nothing changes on screen until the backend confirmed it, so a memory
/// that is still shown is one marlix still uses.
class MemoriesController extends AsyncNotifier<List<Memory>> {
  /// Starts over for every session: another account never sees these memories.
  @override
  Future<List<Memory>> build() {
    ref.watch(signedInUserProvider);
    return _guarded(_api.memories);
  }

  MarlixApi get _api => ref.read(marlixApiProvider);

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _guarded(_api.memories));
  }

  /// Each action throws the [ApiException] if the backend refused, and leaves
  /// the list as it was.
  Future<void> edit(Memory memory, String fact) => _guarded(() async {
    final saved = await _api.editMemory(memory.id, fact);
    _update((list) => [for (final m in list) m.id == memory.id ? saved : m]);
  }, gone: memory);

  Future<void> remove(Memory memory) => _guarded(() async {
    await _api.deleteMemory(memory.id);
    _update(_without(memory));
  }, gone: memory);

  Future<void> removeAll() => _guarded(() async {
    await _api.deleteAllMemories();
    _update((_) => const []);
  });

  /// A rejected session ends it, like the chat does. A memory that no longer
  /// exists (deleted from another phone, say) leaves the list too.
  Future<T> _guarded<T>(Future<T> Function() action, {Memory? gone}) async {
    try {
      return await action();
    } on NotFoundException {
      if (gone != null) _update(_without(gone));
      rethrow;
    } on UnauthorizedException {
      ref.read(sessionEndedProvider.notifier).set(true);
      await ref.read(authServiceProvider).signOut();
      rethrow;
    }
  }

  static List<Memory> Function(List<Memory>) _without(Memory memory) =>
      (list) => list.where((m) => m.id != memory.id).toList();

  void _update(List<Memory> Function(List<Memory> current) change) {
    if (!ref.mounted) return;
    if (state.value case final current?) state = AsyncData(change(current));
  }
}

final memoriesControllerProvider = AsyncNotifierProvider<MemoriesController, List<Memory>>(
  MemoriesController.new,
);
