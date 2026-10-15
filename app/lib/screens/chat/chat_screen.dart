import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/usage.dart';
import '../../theme/app_theme.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/typing_indicator.dart';
import 'chat_controller.dart';

/// Main screen (wireframe docs/diagrams/wireframes/screens/03a-chat.png).
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(chatControllerProvider.notifier).loadUsage(),
    );
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text;
    _input.clear();
    try {
      await ref.read(chatControllerProvider.notifier).send(text);
    } on Exception {
      // Error, limit and crisis states are S3-4; for now the text is kept.
      if (!mounted) return;
      _input.text = text;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No se pudo enviar. Intentá de nuevo.')));
    }
  }

  void _scrollToLatest() {
    // The list is reversed, so offset 0 is the newest message.
    if (_scroll.hasClients && _scroll.offset > 0) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatControllerProvider);
    ref.listen(chatControllerProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length || next.sending) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLatest());
      }
    });

    final items = [if (chat.sending) null, ...chat.messages.reversed];
    final canSend = _input.text.trim().isNotEmpty && !chat.sending;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const _Header(),
            if (chat.usage case final usage?) _UsageChip(usage: usage),
            Expanded(
              child: chat.messages.isEmpty && !chat.sending
                  ? const _EmptyChat()
                  : ListView.separated(
                      controller: _scroll,
                      reverse: true,
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => switch (items[index]) {
                        null => const TypingIndicator(),
                        final message => MessageBubble(message: message),
                      },
                    ),
            ),
            _Composer(controller: _input, canSend: canSend, onSend: _send),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            ExcludeSemantics(
              child: CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.tanLight,
                foregroundImage: const AssetImage('assets/avatar/marlix.png'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(header: true, child: const Text('marlix', style: AppText.heading)),
                  Text(
                    'Aquí para conversar',
                    style: AppText.caption.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsageChip extends StatelessWidget {
  const _UsageChip({required this.usage});

  final Usage usage;

  @override
  Widget build(BuildContext context) {
    final remaining = usage.remaining;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Text(
            remaining == 1 ? 'Te queda 1 mensaje hoy' : 'Te quedan $remaining mensajes hoy',
            style: AppText.caption.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Contale a marlix cómo te fue hoy.',
          textAlign: TextAlign.center,
          style: AppText.body.copyWith(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.canSend, required this.onSend});

  final TextEditingController controller;
  final bool canSend;
  final VoidCallback onSend;

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
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                // Same limit as the API contract.
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                style: AppText.body,
                decoration: InputDecoration(
                  hintText: 'Escribe un mensaje…',
                  hintStyle: AppText.body.copyWith(color: AppColors.textSecondary),
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(color: AppColors.line, width: 1.5),
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
