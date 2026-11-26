import 'package:permission_handler/permission_handler.dart';

import '../application/microphone_permission.dart';

class SystemMicrophonePermission implements MicrophonePermission {
  const SystemMicrophonePermission();

  @override
  Future<bool> request() async => (await ask()) == MicrophoneAccess.granted;

  @override
  Future<MicrophoneAccess> ask() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) return MicrophoneAccess.granted;
    return status.isPermanentlyDenied ? MicrophoneAccess.blocked : MicrophoneAccess.denied;
  }

  @override
  Future<void> openSettings() => openAppSettings();
}
