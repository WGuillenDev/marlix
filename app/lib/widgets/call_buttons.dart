import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/help_resource.dart';
import '../services/dialer.dart';
import '../theme/app_theme.dart';
import 'phone_format.dart';

/// Opens the dialer with [line]'s number. If the device cannot dial, it says
/// so and shows the number, so the person can dial it from another phone.
Future<void> callLine(BuildContext context, WidgetRef ref, HelpResource line) async {
  final opened = await ref.read(dialerProvider).dial(line.phone);
  if (opened || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('No se pudo abrir el teléfono. Marcá el ${formatPhone(line.phone)}.')),
  );
}

/// The big red button for the primary line (wireframes 03c and 06).
class EmergencyCallButton extends ConsumerWidget {
  const EmergencyCallButton({super.key, required this.line});

  final HelpResource line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FilledButton.icon(
      onPressed: () => callLine(context, ref, line),
      icon: const Icon(Icons.phone_rounded),
      label: Text('Llamar al ${formatPhone(line.phone)}'),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.crisis,
        foregroundColor: AppColors.white,
        textStyle: AppText.button.copyWith(fontSize: 18),
        minimumSize: const Size.fromHeight(56),
        shape: const StadiumBorder(),
      ),
    );
  }
}
