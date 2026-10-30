import 'package:flutter_test/flutter_test.dart';
import 'package:marlix/screens/chat/reply_reader.dart';
import 'package:marlix/screens/voice/conversation_controller.dart';
import 'package:marlix/screens/voice/speech_controller.dart';

ConversationPhase _phase({
  ConversationMode mode = ConversationMode.on,
  SpeechState speech = const SpeechIdle(),
  bool thinking = false,
  Reading reading = Reading.idle,
}) => conversationPhase(mode: mode, speech: speech, thinking: thinking, reading: reading);

void main() {
  group('conversationPhase', () {
    test('a paused or ended conversation is paused whatever else happens', () {
      expect(_phase(mode: ConversationMode.paused), ConversationPhase.paused);
      expect(_phase(mode: ConversationMode.off, thinking: true), ConversationPhase.paused);
    });

    test('follows the turns', () {
      expect(_phase(speech: const SpeechListening()), ConversationPhase.listening);
      expect(_phase(thinking: true), ConversationPhase.thinking);
      expect(_phase(reading: Reading.speaking), ConversationPhase.speaking);
      expect(_phase(), ConversationPhase.ready);
    });

    test('the person speaking wins over marlix: it is an interruption', () {
      expect(
        _phase(speech: const SpeechListening('espera'), reading: Reading.speaking),
        ConversationPhase.listening,
      );
    });

    test('an open microphone with no words does not hide marlix speaking or thinking', () {
      expect(
        _phase(speech: const SpeechListening(), reading: Reading.speaking),
        ConversationPhase.speaking,
      );
      expect(_phase(speech: const SpeechListening(), thinking: true), ConversationPhase.thinking);
    });
  });
}
