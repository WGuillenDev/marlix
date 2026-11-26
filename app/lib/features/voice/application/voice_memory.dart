abstract interface class VoiceMemory {
  String? get loadStarted;
  Future<void> beginLoad(String revision);
  Future<void> endLoad();
  bool failed(String revision);
  Future<void> markFailed(String revision);
  double? speed(String key);
  Future<void> saveSpeed(String key, double ratio);
}
