import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'config/app_config.dart';
import 'services/help_resources.dart';

Future<void> main() async {
  // Fails at startup, not on the first request, when the configuration is wrong.
  final config = AppConfig.fromEnvironment();
  WidgetsFlutterBinding.ensureInitialized();
  // Loaded before the first frame so the help lines are there offline at once.
  final preferences = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        sharedPreferencesProvider.overrideWithValue(preferences),
      ],
      child: const MarlixApp(),
    ),
  );
}
