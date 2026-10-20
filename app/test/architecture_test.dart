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

  test('only lib/services/ imports package:http', () {
    final offenders = [
      for (final file in sources)
        if (!relative(file).startsWith('lib/services/') &&
            file.readAsStringSync().contains('package:http/'))
          relative(file),
    ];

    expect(offenders, isEmpty, reason: 'Screens and widgets must go through MarlixApi');
  });

  test('only lib/services/ uses Supabase, and only for sign-up and sign-in', () {
    final offenders = [
      for (final file in sources)
        if (!relative(file).startsWith('lib/services/') &&
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

  test('only lib/services/ talks to the notification plugin', () {
    final offenders = [
      for (final file in sources)
        if (!relative(file).startsWith('lib/services/') &&
            file.readAsStringSync().contains('package:flutter_local_notifications/'))
          relative(file),
    ];

    expect(offenders, isEmpty, reason: 'Screens go through ReminderScheduler');
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
