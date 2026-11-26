abstract interface class ReminderScheduler {
  Future<bool> requestPermission();

  Future<bool> hasPermission();

  /// The Android scheduler repeats each notification weekly at the selected local time.
  Future<void> scheduleWeekly({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  });

  Future<void> cancelAll();

  Stream<void> get taps;
}
