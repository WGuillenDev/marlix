import 'dart:typed_data';

abstract interface class TranscriptionGateway {
  Future<String> transcribe(Uint8List audio);
}
