enum ConnectionKind { unmetered, mobile, none }

abstract interface class DeviceFacts {
  /// Android marks some devices as low-RAM regardless of their free memory.
  Future<bool> isLowRam();

  Future<int> freeBytes();

  Future<ConnectionKind> connection();

  /// Changes after a device or OS update so the model is benchmarked again.
  Future<String> fingerprint();
}
