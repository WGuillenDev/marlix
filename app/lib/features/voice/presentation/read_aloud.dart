import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/storage_providers.dart';

class ReadAloud extends Notifier<bool> {
  static const key = 'read_aloud';

  @override
  bool build() => ref.read(preferencesProvider).getBool(key) ?? false;

  Future<void> set(bool on) async {
    state = on;
    await ref.read(preferencesProvider).setBool(key, on);
  }
}

final readAloudProvider = NotifierProvider<ReadAloud, bool>(ReadAloud.new);

class VoiceMode extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool open) => state = open;
}

final voiceModeProvider = NotifierProvider<VoiceMode, bool>(VoiceMode.new);

final repliesAreSpokenProvider = Provider<bool>(
  (ref) => ref.watch(readAloudProvider) || ref.watch(voiceModeProvider),
);
