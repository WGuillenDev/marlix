import '../../../shared/json_reader.dart';

class Memory {
  const Memory({
    required this.id,
    required this.fact,
    required this.createdAt,
    required this.updatedAt,
    this.category,
  });

  factory Memory.fromJson(Map<String, Object?> json) => Memory(
    id: json.requireString('id'),
    fact: json.requireString('fact'),
    category: json.optionalString('category'),
    createdAt: json.requireDateTime('createdAt'),
    updatedAt: json.requireDateTime('updatedAt'),
  );

  final String id;
  final String fact;
  final String? category;
  final DateTime createdAt;
  final DateTime updatedAt;
}
