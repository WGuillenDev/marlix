import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/help_resource.dart';
import 'api_exception.dart';
import 'marlix_api.dart';

/// Overridden in `main` with the instance loaded before the first frame, so
/// the help screen reads its cache synchronously.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

/// The help lines, available offline (US-15): the last list from the backend
/// is kept on the phone, and [emergencyLine] is there even before the first
/// successful request.
class HelpResourcesController extends Notifier<HelpResources> {
  static const cacheKey = 'help_resources';

  @override
  HelpResources build() =>
      _cached() ?? HelpResources(updatedAt: DateTime.utc(2026), resources: const [emergencyLine]);

  /// Best effort: without a connection the cached list stays.
  Future<void> refresh() async {
    try {
      final fresh = await ref.read(marlixApiProvider).helpResources();
      if (fresh.resources.isEmpty || !ref.mounted) return;
      state = fresh;
      await ref.read(sharedPreferencesProvider).setString(cacheKey, jsonEncode(fresh.toJson()));
    } on ApiException {
      // Keep what is on screen.
    }
  }

  HelpResources? _cached() {
    final raw = ref.read(sharedPreferencesProvider).getString(cacheKey);
    if (raw == null) return null;
    try {
      return HelpResources.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on Object catch (_) {
      // A cache from an older format is ignored, not trusted.
      return null;
    }
  }
}

final helpResourcesProvider = NotifierProvider<HelpResourcesController, HelpResources>(
  HelpResourcesController.new,
);
