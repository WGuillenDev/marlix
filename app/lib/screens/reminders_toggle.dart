import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/reminders.dart';

/// What to tell the person when the notification permission was refused.
const remindersDeniedNotice =
    'Para recibir recordatorios, permite las notificaciones de marlix en los '
    'ajustes del teléfono.';

/// Turns the daily reminders on or off from a switch (settings and
/// onboarding). Turning them on asks for the system permission. False when the
/// person did not allow it: the switch stays off and the screen shows
/// [remindersDeniedNotice].
Future<bool> toggleReminders(WidgetRef ref, bool on) async {
  final reminders = ref.read(remindersProvider.notifier);
  if (!on) {
    await reminders.disable();
    return true;
  }
  return reminders.enable();
}
