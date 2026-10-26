import 'json_reader.dart';

/// Today's interactions. [resetsAt] is the next midnight in Costa Rica, in UTC.
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

  /// Only `GET /v1/usage` sends it; the chat reply leaves it out.
  final String? plan;
  final int used;
  final int limit;
  final int remaining;
  final DateTime resetsAt;

  /// The share of the cap that is left when the app starts warning (S6-6).
  static const lowShare = 0.1;

  /// Few are left but not none: time to warn. It follows the cap of the plan.
  bool get isLow => limit > 0 && remaining > 0 && remaining <= (limit * lowShare).ceil();
}
