import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

enum MicrophoneAccess {
  granted,
  denied,

  /// The system will not show its dialog again: only the phone's settings can
  /// give the permission back.
  blocked,
}

/// The microphone permission, asked once during onboarding (S5-5) and again
/// when the person speaks in the voice mode (S6-8) if they said "Ahora no".
class MicrophonePermission {
  const MicrophonePermission();

  /// Shows the system dialog if it was not answered yet. True when allowed.
  Future<bool> request() async => (await ask()) == MicrophoneAccess.granted;

  Future<MicrophoneAccess> ask() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) return MicrophoneAccess.granted;
    return status.isPermanentlyDenied ? MicrophoneAccess.blocked : MicrophoneAccess.denied;
  }

  Future<void> openSettings() => openAppSettings();
}

/// Overridden in tests: the system dialog does not exist there.
final microphonePermissionProvider = Provider<MicrophonePermission>(
  (ref) => const MicrophonePermission(),
);
