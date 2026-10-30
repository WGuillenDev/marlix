import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import 'wav.dart';

/// The microphone as a stream of 16 kHz mono 16-bit PCM (S6-9).
abstract interface class AudioCapture {
  /// Opens the microphone. The stream ends when [stop] is called.
  Future<Stream<Uint8List>> start();

  Future<void> stop();
}

/// The phone's microphone through the `record` package, with the platform's
/// echo cancellation and noise suppression on: marlix speaks through the
/// speaker and the microphone must not take that for the person talking. On
/// Android the voice-communication source is the one the phones tune for it.
class RecordAudioCapture implements AudioCapture {
  RecordAudioCapture({AudioRecorder? recorder}) : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  static const config = RecordConfig(
    encoder: AudioEncoder.pcm16bits,
    sampleRate: speechSampleRate,
    numChannels: 1,
    echoCancel: true,
    noiseSuppress: true,
    // Marlix's own voice takes the audio focus, and by default that pauses the
    // microphone: the person could not interrupt it.
    audioInterruption: AudioInterruptionMode.none,
    // The call mode makes the phone use what it plays as the reference to cancel
    // the echo: without it marlix's voice comes back as loud as a person.
    androidConfig: AndroidRecordConfig(
      audioSource: AndroidAudioSource.voiceCommunication,
      audioManagerMode: AudioManagerMode.modeInCommunication,
      speakerphone: true,
    ),
  );

  @override
  Future<Stream<Uint8List>> start() => _recorder.startStream(config);

  @override
  Future<void> stop() async {
    if (await _recorder.isRecording()) await _recorder.stop();
  }
}
