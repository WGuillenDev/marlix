import 'package:flutter/material.dart';

import '../../../../shared/presentation/app_theme.dart';
import '../../domain/usage.dart';

class UsageChip extends StatelessWidget {
  const UsageChip({super.key, required this.usage});

  final Usage usage;

  @override
  Widget build(BuildContext context) {
    final remaining = usage.remaining;
    final low = usage.isLow;
    final count = remaining == 1 ? 'Te queda 1 mensaje hoy' : 'Te quedan $remaining mensajes hoy';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      // Announce entry into the low-usage state once.
      child: Semantics(
        liveRegion: low,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: low ? AppColors.warningBackground : AppColors.white,
            border: Border.all(color: low ? AppColors.tan : AppColors.line),
            borderRadius: BorderRadius.circular(low ? 20 : 999),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              low ? '$count. Se renuevan a medianoche.' : count,
              textAlign: TextAlign.center,
              style: AppText.caption.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}
