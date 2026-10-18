import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'account/delete_account.dart';
import 'help_screen.dart';
import 'memories/memories_screen.dart';

/// Settings (wireframe docs/diagrams/wireframes/screens/07a-settings.png).
/// Reminders add their row.
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    this.destructive = false,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onTap;

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
