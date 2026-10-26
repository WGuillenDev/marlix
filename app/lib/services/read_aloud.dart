import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'help_resources.dart';

/// Whether marlix reads its replies aloud (S6-4). Saved on the phone and off
/// until the person turns it on in Settings. The voice mode (S6-7) reads them
/// too, without this switch.
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

/// The full-screen voice mode is open (S6-7). Not saved: it ends with the screen.
class VoiceMode extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool open) => state = open;
}

final voiceModeProvider = NotifierProvider<VoiceMode, bool>(VoiceMode.new);

/// Replies come short and clean and are read aloud: the switch of Settings or the
/// voice mode asks for it.
final repliesAreSpokenProvider = Provider<bool>(
  (ref) => ref.watch(readAloudProvider) || ref.watch(voiceModeProvider),
);
