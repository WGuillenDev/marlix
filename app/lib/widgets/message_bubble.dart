import 'package:flutter/material.dart';

import '../models/chat.dart';
import '../theme/app_theme.dart';

/// The user's messages on the right in tan, marlix's on the left in white.
class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final fromUser = message.role == MessageRole.user;
    const corner = Radius.circular(20);
    const tail = Radius.circular(6);

    return Semantics(
      label: fromUser ? 'Vos' : 'marlix',
      child: Align(
        alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fromUser ? AppColors.tanLight : AppColors.white,
              border: fromUser ? null : Border.all(color: AppColors.line),
              borderRadius: BorderRadius.only(
                topLeft: corner,
                topRight: corner,
                bottomLeft: fromUser ? corner : tail,
                bottomRight: fromUser ? tail : corner,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SelectableText(message.content, style: AppText.body),
            ),
          ),
        ),
      ),
    );
  }
}
