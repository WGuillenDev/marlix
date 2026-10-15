/// Thrown when a response body does not match the API contract.
class InvalidJsonException implements Exception {
  const InvalidJsonException(this.message);

  final String message;

  @override
  String toString() => 'InvalidJsonException: $message';
}

/// Typed reads from a decoded JSON object. A missing field or a wrong type
/// fails with [InvalidJsonException] instead of a `TypeError` deep in a widget.
extension JsonReader on Map<String, Object?> {
  T _require<T>(String key) {
    final value = this[key];
    if (value is T) return value;
    throw InvalidJsonException('"$key" must be a $T, got ${value.runtimeType}');
  }

  T? _optional<T>(String key) => this[key] == null ? null : _require<T>(key);

  String requireString(String key) => _require<String>(key);

  String? optionalString(String key) => _optional<String>(key);

  bool? optionalBool(String key) => _optional<bool>(key);

  bool requireBool(String key) => _require<bool>(key);

  int requireInt(String key) => _require<int>(key);

  Map<String, Object?> requireObject(String key) => _require<Map<String, Object?>>(key);

  DateTime requireDateTime(String key) {
    final value = requireString(key);
    final parsed = DateTime.tryParse(value);
    if (parsed == null) throw InvalidJsonException('"$key" is not an ISO 8601 date: $value');
    return parsed;
  }

  List<T> requireList<T>(String key, T Function(Map<String, Object?> json) parse) {
    final items = _require<List<Object?>>(key);
    return [
      for (final item in items)
        if (item is Map<String, Object?>)
          parse(item)
        else
          throw InvalidJsonException('"$key" must only contain objects'),
    ];
  }
}
