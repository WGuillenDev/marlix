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
