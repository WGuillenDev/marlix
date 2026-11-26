import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'bootstrap/app_config.dart';
import 'bootstrap/storage_providers.dart';
import 'features/account/infrastructure/auth_service.dart';
import 'features/account/presentation/session_state.dart';
import 'features/settings/domain/reminder_config.dart';
import 'features/settings/presentation/reminders.dart';
import 'features/voice/application/voice_model.dart';
import 'features/voice/composition/voice_providers.dart';
import 'features/voice/infrastructure/voice_model_store.dart';

Future<void> main() async {
  final config = AppConfig.fromEnvironment();
  WidgetsFlutterBinding.ensureInitialized();
  // Load the offline help cache before the first frame.
  final preferences = await SharedPreferences.getInstance();
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
