import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The user's messages on the right in tan, marlix's on the left in white.
/// A user message that could not be sent gets a red border.
class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.text, required this.fromUser, this.failed = false});

  final String text;
  final bool fromUser;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    const corner = Radius.circular(20);
    const tail = Radius.circular(6);
    final border = failed
        ? Border.all(color: AppColors.crisis, width: 2)
        : fromUser
        ? null
        : Border.all(color: AppColors.line);

    return Semantics(
      label: fromUser ? (failed ? 'Vos, no enviado' : 'Vos') : 'marlix',
      child: Align(
        alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fromUser ? AppColors.tanLight : AppColors.white,
              border: border,
              borderRadius: BorderRadius.only(
                topLeft: corner,
                topRight: corner,
                bottomLeft: fromUser ? corner : tail,
                bottomRight: fromUser ? tail : corner,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SelectableText(text, style: AppText.body),
            ),
          ),
        ),
      ),
    );
  }
}
