import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The message field and the send button, shared by the chat and the voice mode.
class Composer extends StatelessWidget {
  const Composer({
    super.key,
    required this.controller,
    required this.canSend,
    required this.enabled,
    required this.onSend,
    this.leading,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final bool canSend;

  /// False once the daily limit is reached.
  final bool enabled;
  final VoidCallback onSend;

  /// A button before the field, like the one that opens the voice mode.
  final Widget? leading;

  /// Opens the keyboard when it appears.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (leading case final leading?) ...[leading, const SizedBox(width: 8)],
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                autofocus: autofocus,
                minLines: 1,
                maxLines: 5,
                // Same limit as the API contract.
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                style: AppText.body,
                decoration: InputDecoration(
                  hintText: enabled ? 'Escribe un mensaje…' : 'Límite diario alcanzado',
                  hintStyle: AppText.body.copyWith(color: AppColors.textSecondary),
                  counterText: '',
                  filled: true,
                  fillColor: enabled ? AppColors.white : AppColors.line,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(color: AppColors.line, width: 1.5),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(color: AppColors.tanDark, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filled(
              onPressed: canSend ? onSend : null,
              tooltip: 'Enviar',
              iconSize: 24,
              style: IconButton.styleFrom(
                fixedSize: const Size(56, 56),
                backgroundColor: AppColors.tanDark,
                foregroundColor: AppColors.white,
                disabledBackgroundColor: AppColors.line,
                disabledForegroundColor: AppColors.textSecondary,
              ),
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
