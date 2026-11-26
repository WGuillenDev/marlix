import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/api_providers.dart';
import '../../../bootstrap/storage_providers.dart';
import '../../../shared/application/api_exception.dart';
import '../domain/help_resource.dart';

/// Show cached help offline and fall back to the bundled emergency line.
class HelpResourcesController extends Notifier<HelpResources> {
  static const cacheKey = 'help_resources';

  @override
  HelpResources build() =>
      _cached() ?? HelpResources(updatedAt: DateTime.utc(2026), resources: const [emergencyLine]);

  Future<void> refresh() async {
    try {
      final fresh = await ref.read(helpResourcesGatewayProvider).helpResources();
      if (fresh.resources.isEmpty || !ref.mounted) return;
      state = fresh;
      await ref.read(preferencesProvider).setString(cacheKey, jsonEncode(fresh.toJson()));
    } on ApiException {
      // Keep showing cached or bundled help if the refresh fails.
    }
  }

  HelpResources? _cached() {
    final raw = ref.read(preferencesProvider).getString(cacheKey);
    if (raw == null) return null;
    try {
      return HelpResources.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on Object catch (_) {
      // Ignore a cache that uses an older schema.
      return null;
    }
  }
}

final helpResourcesProvider = NotifierProvider<HelpResourcesController, HelpResources>(
  HelpResourcesController.new,
);
