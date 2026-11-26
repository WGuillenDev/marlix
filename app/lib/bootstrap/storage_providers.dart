import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../shared/application/preferences.dart';
import '../shared/infrastructure/local/preferences.dart';

// Load preferences before the first frame so cached help is available offline.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

final preferencesProvider = Provider<Preferences>(
  (ref) => LocalPreferences(ref.watch(sharedPreferencesProvider)),
);
