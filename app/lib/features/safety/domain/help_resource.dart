import '../../../shared/json_reader.dart';

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

  /// Fall back to the emergency line when the backend has no primary resource.
  HelpResource get primary =>
      resources.where((resource) => resource.primary).firstOrNull ?? emergencyLine;

  List<HelpResource> get others => [
    for (final resource in resources)
      if (resource.phone != primary.phone) resource,
  ];
}

/// Keep the emergency line available before the first successful request.
const emergencyLine = HelpResource(
  id: '911',
  name: '9-1-1',
  phone: '911',
  service: 'Atención inmediata ante emergencias o situaciones de riesgo',
  hours: '24 horas, 7 días de la semana',
  primary: true,
);
