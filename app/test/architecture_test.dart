import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Rules that keep the network layer in one place and keys out of the app.
void main() {
  final sources = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList();

  String relative(File file) => file.path.replaceAll(r'\', '/');

  test('only infrastructure imports package:http', () {
    final offenders = [
      for (final file in sources)
        if (!relative(file).contains('/infrastructure/') &&
            !relative(file).contains('/composition/') &&
            !relative(file).startsWith('lib/bootstrap/') &&
            file.readAsStringSync().contains('package:http/'))
          relative(file),
    ];

    expect(offenders, isEmpty, reason: 'Screens and widgets must go through MarlixApi');
  });

  test('only infrastructure uses Supabase, and only for sign-up and sign-in', () {
    final offenders = [
      for (final file in sources)
        if (!relative(file).contains('/infrastructure/') &&
            file.readAsStringSync().contains('package:supabase_flutter/'))
          relative(file),
    ];
    expect(offenders, isEmpty, reason: 'Screens go through AuthService');

    // The app reads and writes data through the backend, never the database
    // directly (docs/architecture.md).
    final queries = RegExp(r'\.(from|rpc|storage|functions|channel)\(');
    final directAccess = [
      for (final file in sources)
        if (queries.hasMatch(file.readAsStringSync()) &&
            file.readAsStringSync().contains('package:supabase_flutter/'))
          relative(file),
    ];
    expect(directAccess, isEmpty);
  });

  test('only infrastructure talks to the notification plugin', () {
    final offenders = [
      for (final file in sources)
        if (!relative(file).contains('/infrastructure/') &&
            file.readAsStringSync().contains('package:flutter_local_notifications/'))
          relative(file),
    ];

    expect(offenders, isEmpty, reason: 'Screens go through ReminderScheduler');
  });

  test('only infrastructure asks the system for permissions', () {
    final offenders = [
      for (final file in sources)
        if (!relative(file).contains('/infrastructure/') &&
            file.readAsStringSync().contains('package:permission_handler/'))
          relative(file),
    ];

    expect(offenders, isEmpty, reason: 'Screens go through MicrophonePermission');
  });

  test(
    'only lib/features/voice/infrastructure/ talks to the voice engines and the network checks',
    () {
      // The screens speak through VoiceController (S6-2): none names an engine, so
      // a new engine changes one folder.
      const voicePackages = [
        'package:flutter_tts/',
        'package:supertonic_flutter/',
        'package:audioplayers/',
        'package:device_info_plus/',
        'package:connectivity_plus/',
        'package:vad_plus/',
        'package:record/',
      ];
      final offenders = [
        for (final file in sources)
          if (!relative(file).startsWith('lib/features/voice/infrastructure/') &&
              voicePackages.any(file.readAsStringSync().contains))
            relative(file),
      ];

      expect(offenders, isEmpty, reason: 'Screens go through VoiceController');
    },
  );

  test('no screen imports a concrete voice engine or the model store', () {
    final engines = RegExp(
      r"import '[^']*infrastructure/((native|supertonic)_voice_engine|voice_model_store)\.dart'",
    );
    final offenders = [
      for (final file in sources)
        if (relative(file).contains('/presentation/') && engines.hasMatch(file.readAsStringSync()))
          relative(file),
    ];

    expect(offenders, isEmpty, reason: 'Screens only know VoiceController and VoiceStatus');
  });

  test('only the voice model store downloads the model: the engines close the network', () {
    final offenders = [
      for (final file in sources)
        if (relative(file).startsWith('lib/features/voice/infrastructure/') &&
            !relative(file).endsWith('voice_model_store.dart') &&
            file.readAsStringSync().contains('preDownloadModels'))
          relative(file),
    ];

    expect(offenders, isEmpty, reason: 'The package downloads from main without checking');
  });

  test('feature dependencies point inward', () {
    final imports = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''', multiLine: true);
    final outer = RegExp(r'/(?:infrastructure|presentation|composition|bootstrap)/');
    final offenders = <String>[];

    for (final file in sources) {
      final from = relative(file);
      final isDomain = from.contains('/domain/');
      final isInner = isDomain || from.contains('/application/');
      final isPresentation = from.contains('/presentation/');
      if (!isInner && !isPresentation) continue;

      for (final match in imports.allMatches(file.readAsStringSync())) {
        final ref = match[1]!;
        if (ref.startsWith('dart:')) continue;
        const local = 'package:marlix/';
        if (ref.startsWith('package:') && !ref.startsWith(local)) {
          if (isInner) offenders.add('$from imports $ref');
          continue;
        }
        final target = ref.startsWith(local)
            ? 'lib/${ref.substring(local.length)}'
            : Uri.parse(from).resolve(ref).path;
        if ((isInner && outer.hasMatch(target)) ||
            (isDomain && target.contains('/application/')) ||
            (isPresentation && target.contains('/infrastructure/'))) {
          offenders.add('$from imports $target');
        }
      }
    }

    expect(offenders, isEmpty);
  });

  test('the app holds no API key', () {
    // Groq keys, Supabase secret keys and JWTs such as the service_role key.
    final keyPattern = RegExp(r'gsk_[A-Za-z0-9]{20,}|sb_secret_|eyJ[A-Za-z0-9_-]{20,}\.');
    final offenders = [
      for (final file in [...sources, ...Directory('config').listSync().whereType<File>()])
        if (keyPattern.hasMatch(file.readAsStringSync())) relative(file),
    ];

    expect(offenders, isEmpty);
  });
}
