import 'json_reader.dart';

/// A help line from `api/config/crisis.json`. Names and hours are user-facing
/// Spanish copy; [phone] holds digits only, ready to dial.
class HelpResource {
  const HelpResource({
    required this.id,
    required this.name,
    required this.phone,
    required this.hours,
    required this.primary,
  });

  factory HelpResource.fromJson(Map<String, Object?> json) => HelpResource(
    id: json.requireString('id'),
    name: json.requireString('name'),
    phone: json.requireString('phone'),
    hours: json.requireString('hours'),
    primary: json.requireBool('primary'),
  );

  final String id;
  final String name;
  final String phone;
  final String hours;
  final bool primary;
}

/// Response of `GET /v1/help-resources`.
class HelpResources {
  const HelpResources({required this.updatedAt, required this.resources});

  factory HelpResources.fromJson(Map<String, Object?> json) => HelpResources(
    updatedAt: json.requireDateTime('updatedAt'),
    resources: json.requireList('resources', HelpResource.fromJson),
  );

  final DateTime updatedAt;
  final List<HelpResource> resources;
}
