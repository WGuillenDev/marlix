import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// The microphone permission, asked once during onboarding (S5-5) and again
/// when voice mode opens (Sprint 6) if the person said "Ahora no".
class MicrophonePermission {
  const MicrophonePermission();

  /// Shows the system dialog if it was not answered yet. True when allowed.
  Future<bool> request() async => (await Permission.microphone.request()).isGranted;
}

/// Overridden in tests: the system dialog does not exist there.
final microphonePermissionProvider = Provider<MicrophonePermission>(
  (ref) => const MicrophonePermission(),
);
