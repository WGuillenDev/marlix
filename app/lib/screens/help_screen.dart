import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/help_resource.dart';
import '../services/help_resources.dart';
import '../theme/app_theme.dart';
import '../widgets/call_buttons.dart';
import '../widgets/phone_format.dart';

/// Help lines in Costa Rica (wireframe docs/diagrams/wireframes/screens/06-help.png).
/// Works offline: it shows the cached list and always 9-1-1.
class HelpScreen extends ConsumerStatefulWidget {
  const HelpScreen({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const HelpScreen());

  @override
  ConsumerState<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends ConsumerState<HelpScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(helpResourcesProvider.notifier).refresh(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final help = ref.watch(helpResourcesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayuda', style: AppText.title),
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _EmergencyCard(line: help.primary),
            if (help.others.isNotEmpty) ...[
              const SizedBox(height: 28),
              Semantics(
                header: true,
                child: const Text('Otros recursos en Costa Rica', style: AppText.heading),
              ),
              const SizedBox(height: 12),
              for (final line in help.others) ...[
                _ResourceCard(line: line),
                const SizedBox(height: 12),
              ],
            ],
            const SizedBox(height: 16),
            Text(
              'marlix es compañía para conversar. No reemplaza la atención de un profesional '
              'de la salud.',
              style: AppText.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.wifi_off_rounded, color: AppColors.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Esta pantalla funciona sin internet.',
                    style: AppText.caption.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard({required this.line});

  final HelpResource line;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.crisis, width: 2),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                '¿Estás en peligro o necesitas ayuda ya?',
                style: AppText.heading.copyWith(fontSize: 20, height: 28 / 20),
              ),
            ),
            const SizedBox(height: 20),
            EmergencyCallButton(line: line),
            const SizedBox(height: 12),
            Text(
              'Emergencias y crisis emocional',
              textAlign: TextAlign.center,
              style: AppText.caption.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResourceCard extends ConsumerWidget {
  const _ResourceCard({required this.line});

  final HelpResource line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final number = formatPhone(line.phone);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.line, width: 1.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(line.name, style: AppText.bodyStrong),
                  const SizedBox(height: 2),
                  Text(
                    '${line.hours} · $number',
                    style: AppText.caption.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => callLine(context, ref, line),
              tooltip: 'Llamar a ${line.name}, $number',
              icon: const Icon(Icons.phone_rounded),
              style: IconButton.styleFrom(
                fixedSize: const Size(56, 56),
                backgroundColor: AppColors.warningBackground,
                foregroundColor: AppColors.crisis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
