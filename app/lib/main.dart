import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'config/app_config.dart';
import 'models/reminder_config.dart';
import 'services/auth_service.dart';
import 'services/help_resources.dart';
import 'services/reminders.dart';

Future<void> main() async {
  // Fails at startup, not on the first request, when the configuration is wrong.
  final config = AppConfig.fromEnvironment();
  WidgetsFlutterBinding.ensureInitialized();
  // Loaded before the first frame so the help lines are there offline at once.
  final preferences = await SharedPreferences.getInstance();
  // Restores the saved session, so a signed-in user opens straight to the chat.
  final auth = await SupabaseAuthService.initialize(config);
  final reminders = ReminderConfig.fromJson(
    jsonDecode(await rootBundle.loadString('assets/config/reminders.json')) as Map<String, Object?>,
  );
  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        sharedPreferencesProvider.overrideWithValue(preferences),
        authServiceProvider.overrideWithValue(auth),
        reminderConfigProvider.overrideWithValue(reminders),
      ],
      child: const MarlixApp(),
    ),
  );
}
