import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'reminders.dart';

const remindersDeniedNotice =
    'Para recibir recordatorios, permite las notificaciones de marlix en los '
    'ajustes del teléfono.';

Future<bool> toggleReminders(WidgetRef ref, bool on) async {
  final reminders = ref.read(remindersProvider.notifier);
  if (!on) {
    await reminders.disable();
    return true;
  }
  return reminders.enable();
}
