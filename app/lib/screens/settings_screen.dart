import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/reminder_config.dart';
import '../services/auth_service.dart';
import '../services/reminders.dart';
import '../theme/app_theme.dart';
import 'account/delete_account.dart';
import 'avatar_test_screen.dart';
import 'help_screen.dart';
import 'memories/memories_screen.dart';

/// Settings (wireframe docs/diagrams/wireframes/screens/07a-settings.png).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const SettingsScreen());

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar sesión?', style: AppText.title),
        content: const Text(
          'Para volver a conversar con marlix vas a tener que entrar con tu correo '
          'y tu contraseña.',
          style: AppText.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    // The app returns to the sign-in screen on its own when the session ends.
    if (confirmed == true) await ref.read(authServiceProvider).signOut();
  }

  Future<void> _toggleReminders(BuildContext context, WidgetRef ref, bool on) async {
    final reminders = ref.read(remindersProvider.notifier);
    if (!on) return reminders.disable();
    final messenger = ScaffoldMessenger.of(context);
    if (!await reminders.enable()) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Para recibir recordatorios, permite las notificaciones de marlix en los '
            'ajustes del teléfono.',
          ),
        ),
      );
    }
  }

  Future<void> _pickReminderTime(BuildContext context, WidgetRef ref, ReminderTime time) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: time.hour, minute: time.minute),
      helpText: '¿A qué hora te saludo?',
      cancelText: 'Cancelar',
      confirmText: 'Listo',
      hourLabelText: 'Hora',
      minuteLabelText: 'Minutos',
      errorInvalidText: 'Escribe una hora válida',
      // The app has no Spanish localizations, so the 24-hour clock avoids
      // showing AM and PM in English.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    await ref.read(remindersProvider.notifier).setTime((hour: picked.hour, minute: picked.minute));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(remindersProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes', style: AppText.title),
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _SettingsCard(
              title: 'Lo que marlix sabe de mí',
              subtitle: 'Ver, editar o borrar recuerdos',
              onTap: () => Navigator.of(context).push(MemoriesScreen.route()),
            ),
            const SizedBox(height: 10),
            // Policy of S4-10 (docs/memory.md); keep the days in step with the backend's
            // MESSAGE_RETENTION_DAYS.
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Tus mensajes se borran solos a los 90 días. Lo que marlix recuerda de ti '
                'se queda mientras tengas cuenta, y puedes borrarlo cuando quieras.',
                style: AppText.caption,
              ),
            ),
            const SizedBox(height: 12),
            _SettingsCard(
              title: 'Ayuda',
              subtitle: '9-1-1 y otros recursos',
              onTap: () => Navigator.of(context).push(HelpScreen.route()),
            ),
            const SizedBox(height: 12),
            _SettingsCard(
              title: 'Recordatorios',
              subtitle: 'Un saludo de marlix todos los días',
              onTap: () => _toggleReminders(context, ref, !reminders.enabled),
              trailing: Switch(
                value: reminders.enabled,
                activeThumbColor: AppColors.tan,
                onChanged: (on) => _toggleReminders(context, ref, on),
              ),
            ),
            if (reminders.enabled) ...[
              const SizedBox(height: 12),
              _SettingsCard(
                title: 'Hora del saludo',
                subtitle: ReminderConfig.formatTime(reminders.time),
                onTap: () => _pickReminderTime(context, ref, reminders.time),
              ),
            ],
            if (kDebugMode) ...[
              const SizedBox(height: 12),
              _SettingsCard(
                title: 'Probar el avatar',
                subtitle: 'Solo en desarrollo',
                onTap: () => Navigator.of(context).push(AvatarTestScreen.route()),
              ),
            ],
            const SizedBox(height: 12),
            _SettingsCard(title: 'Cerrar sesión', onTap: () => _signOut(context, ref)),
            const SizedBox(height: 28),
            _SettingsCard(
              title: 'Eliminar mi cuenta',
              subtitle: 'Borra todos tus datos para siempre',
              destructive: true,
              onTap: () => deleteAccount(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.destructive = false,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  /// Replaces the chevron, for a row that holds its own control.
  final Widget? trailing;

  /// For what cannot be undone: red, like the other irreversible actions.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.line, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppText.heading.copyWith(
                        fontSize: 19,
                        color: destructive ? AppColors.crisis : null,
                      ),
                    ),
                    if (subtitle case final subtitle?) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: AppText.body.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              trailing ??
                  Icon(
                    Icons.chevron_right_rounded,
                    color: destructive ? AppColors.crisis : AppColors.textSecondary,
                    size: 28,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
