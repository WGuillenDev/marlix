import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/api_providers.dart';
import '../../../shared/application/api_exception.dart';
import '../../account/presentation/session_state.dart';
import '../application/memory_gateway.dart';
import '../domain/memory.dart';

/// What marlix remembers about the person (US-08), always as the backend has
/// it: nothing changes on screen until the backend confirmed it, so a memory
/// that is still shown is one marlix still uses.
class MemoriesController extends AsyncNotifier<List<Memory>> {
  // Scope memory state to the current account.
  @override
  Future<List<Memory>> build() {
    ref.watch(signedInUserProvider);
    return _guarded(_api.memories);
  }

  MemoryGateway get _api => ref.read(memoryGatewayProvider);

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

  // Reload the list when another device deleted the memory.
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
