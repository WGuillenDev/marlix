import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/reminder_scheduler.dart';
import '../infrastructure/reminder_scheduler.dart';

final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) => LocalNotificationsScheduler(),
);
