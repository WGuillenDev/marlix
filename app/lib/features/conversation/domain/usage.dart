import '../../../shared/json_reader.dart';

/// The daily reset is midnight in Costa Rica, represented in UTC.
class Usage {
  const Usage({
    required this.used,
    required this.limit,
    required this.remaining,
    required this.resetsAt,
    this.plan,
  });

  factory Usage.fromJson(Map<String, Object?> json) => Usage(
    plan: json.optionalString('plan'),
    used: json.requireInt('used'),
    limit: json.requireInt('limit'),
    remaining: json.requireInt('remaining'),
    resetsAt: json.requireDateTime('resetsAt'),
  );

  /// The chat response omits the warning threshold returned by GET /v1/usage.
  final String? plan;
  final int used;
  final int limit;
  final int remaining;
  final DateTime resetsAt;

  static const lowShare = 0.1;

  bool get isLow => limit > 0 && remaining > 0 && remaining <= (limit * lowShare).ceil();
}
