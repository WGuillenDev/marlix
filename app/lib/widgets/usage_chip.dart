import 'package:flutter/material.dart';

import '../models/usage.dart';
import '../theme/app_theme.dart';

/// How many interactions are left today; it warns when few are (S6-6). Shared by
/// the chat and the voice mode, which count the same interactions.
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
      // Announced when it turns into a warning, not on every message.
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
