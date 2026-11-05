import 'json_reader.dart';

/// A help line from `api/config/crisis.json`. Names, services and hours are
/// user-facing Spanish copy; [phone] holds digits only, ready to dial.
class HelpResource {
  const HelpResource({
    required this.id,
    required this.name,
    required this.phone,
    this.service,
    required this.hours,
    required this.primary,
  });

  factory HelpResource.fromJson(Map<String, Object?> json) => HelpResource(
    id: json.requireString('id'),
    name: json.requireString('name'),
    phone: json.requireString('phone'),
    service: json.optionalString('service'),
    hours: json.requireString('hours'),
    primary: json.requireBool('primary'),
  );

  final String id;
  final String name;
  final String phone;

  /// What the line offers. Null against a backend that does not send it yet.
  final String? service;
  final String hours;
  final bool primary;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    if (service != null) 'service': service,
    'hours': hours,
    'primary': primary,
  };
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

  Map<String, Object?> toJson() => {
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'resources': [for (final resource in resources) resource.toJson()],
  };

  /// The line shown first: the one marked primary, or [emergencyLine].
  HelpResource get primary =>
      resources.where((resource) => resource.primary).firstOrNull ?? emergencyLine;

  /// Every other line, in the backend's order.
  List<HelpResource> get others => [
    for (final resource in resources)
      if (resource.phone != primary.phone) resource,
  ];
}

/// Always available, even before the app ever reached the backend: the help
/// screen must never be empty. The rest of the list comes from configuration
/// (api/config/crisis.json).
const emergencyLine = HelpResource(
  id: '911',
  name: '9-1-1',
  phone: '911',
  service: 'Atención inmediata ante emergencias o situaciones de riesgo',
  hours: '24 horas, 7 días de la semana',
  primary: true,
);
