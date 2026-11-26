import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import '../domain/wav.dart';

abstract interface class AudioCapture {
  Future<Stream<Uint8List>> start();

  Future<void> stop();
}

class RecordAudioCapture implements AudioCapture {
  RecordAudioCapture({AudioRecorder? recorder}) : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  static const config = RecordConfig(
    encoder: AudioEncoder.pcm16bits,
    sampleRate: speechSampleRate,
    numChannels: 1,
    echoCancel: true,
    noiseSuppress: true,
    // Keep recording while playback holds audio focus so the user can interrupt.
    audioInterruption: AudioInterruptionMode.none,
    // Communication mode lets the device use playback as its echo reference.
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
