enum MicrophoneAccess {
  granted,
  denied,

  /// The system will not show its dialog again: only the phone's settings can
  /// give the permission back.
  blocked,
}

abstract interface class MicrophonePermission {
  Future<bool> request();
  Future<MicrophoneAccess> ask();
  Future<void> openSettings();
}
