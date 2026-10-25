import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'help_resources.dart';

/// Whether marlix reads its replies aloud (S6-4). Saved on the phone and off
/// until the person turns it on in Settings; S6-7 replaces it with the voice
/// button of the chat.
class ReadAloud extends Notifier<bool> {
  static const key = 'read_aloud';

  @override
  bool build() => ref.read(sharedPreferencesProvider).getBool(key) ?? false;

  Future<void> set(bool on) async {
    state = on;
    await ref.read(sharedPreferencesProvider).setBool(key, on);
  }
}

final readAloudProvider = NotifierProvider<ReadAloud, bool>(ReadAloud.new);
