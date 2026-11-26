import '../domain/memory.dart';

abstract interface class MemoryGateway {
  Future<List<Memory>> memories();
  Future<Memory> editMemory(String id, String fact);
  Future<void> deleteMemory(String id);
  Future<void> deleteAllMemories();
}
