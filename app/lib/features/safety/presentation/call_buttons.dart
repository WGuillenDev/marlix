import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import '../../../shared/presentation/app_theme.dart';
import '../composition/dialer_provider.dart';
import '../domain/help_resource.dart';
import 'phone_format.dart';

Future<void> callLine(BuildContext context, WidgetRef ref, HelpResource line) async {
  final opened = await ref.read(dialerProvider).dial(line.phone);
  if (opened || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('No se pudo abrir el teléfono. Marcá el ${formatPhone(line.phone)}.')),
  );
}

class EmergencyCallButton extends ConsumerWidget {
  const EmergencyCallButton({super.key, required this.line, this.label});

  final HelpResource line;
  final String? label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FilledButton.icon(
      onPressed: () => callLine(context, ref, line),
      icon: const Icon(Icons.phone_rounded),
      label: Text(label ?? 'Llamar al ${formatPhone(line.phone)}'),
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
