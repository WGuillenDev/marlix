import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'config/app_config.dart';
import 'models/reminder_config.dart';
import 'services/auth_service.dart';
import 'services/help_resources.dart';
import 'services/reminders.dart';
import 'services/voice/voice_model_store.dart';
import 'services/voice/voice_providers.dart';

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
  final voiceModel = VoiceModelManifest.fromJson(
    jsonDecode(await rootBundle.loadString('assets/config/voice-model.json'))
        as Map<String, Object?>,
  );
  final support = await getApplicationSupportDirectory();
  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        sharedPreferencesProvider.overrideWithValue(preferences),
        authServiceProvider.overrideWithValue(auth),
        reminderConfigProvider.overrideWithValue(reminders),
        voiceModelManifestProvider.overrideWithValue(voiceModel),
        voiceModelDirectoryProvider.overrideWithValue(
          Directory('${support.path}/${VoiceModelStore.packageFolder}'),
        ),
      ],
      child: const MarlixApp(),
    ),
  );
}
