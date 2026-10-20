import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/avatar_marlix.dart';

/// Development screen to watch every state of the avatar (S5-2). Only reachable
/// from Settings in debug builds.
class AvatarTestScreen extends StatefulWidget {
  const AvatarTestScreen({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const AvatarTestScreen());

  @override
  State<AvatarTestScreen> createState() => _AvatarTestScreenState();
}

class _AvatarTestScreenState extends State<AvatarTestScreen> {
  static const _labels = {
    AvatarState.idle: 'Reposo',
    AvatarState.listening: 'Escuchando',
    AvatarState.thinking: 'Pensando',
    AvatarState.speaking: 'Hablando',
    AvatarState.happy: 'Feliz',
  };

  var _state = AvatarState.idle;
  var _volume = 0.5;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Probar el avatar', style: AppText.title),
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: AvatarMarlix(
                  state: _state,
                  volume: _volume,
                  folder: 'assets/avatars/marlix',
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in _labels.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: _state == entry.key,
                    onSelected: (_) => setState(() => _state = entry.key),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Volumen: ${(_volume * 100).round()}%', style: AppText.bodyStrong),
            Slider(value: _volume, onChanged: (value) => setState(() => _volume = value)),
            const Text(
              'El volumen solo se nota en Hablando: mueve la boca.',
              style: AppText.caption,
            ),
          ],
        ),
      ),
    );
  }
}
