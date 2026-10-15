import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/usage.dart';
import '../../theme/app_theme.dart';
import '../../widgets/chat_states.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/typing_indicator.dart';
import 'chat_controller.dart';

/// Main screen (wireframes docs/diagrams/wireframes/screens/03a to 03d).
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  /// A normal reply takes a few seconds; past this, the backend is probably
  /// waking up.
  static const slowReplyAfter = Duration(seconds: 5);

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  static const slowReplyAfter = ChatScreen.slowReplyAfter;

  final _input = TextEditingController();
  final _scroll = ScrollController();
  Timer? _slowTimer;
  var _slow = false;

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
    _slowTimer?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text;
    _input.clear();
    // A failure keeps the message in the chat with a retry, so nothing is lost.
    await ref.read(chatControllerProvider.notifier).send(text);
  }

  void _scrollToLatest() {
    // The list is reversed, so offset 0 is the newest message.
    if (_scroll.hasClients && _scroll.offset > 0) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  /// The banner only appears when a reply takes longer than usual.
  void _watchSlowReply(bool sending) {
    _slowTimer?.cancel();
    if (sending) {
      _slowTimer = Timer(slowReplyAfter, () => setState(() => _slow = true));
    } else if (_slow) {
      setState(() => _slow = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatControllerProvider);
    ref.listen(chatControllerProvider, (previous, next) {
      if (previous?.entries.length != next.entries.length ||
          previous?.sending != next.sending ||
          previous?.limitReached != next.limitReached) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLatest());
      }
      if (previous?.sending != next.sending) _watchSlowReply(next.sending);
    });

    final controller = ref.read(chatControllerProvider.notifier);
    final items = <Widget>[
      if (chat.limitReached) const DailyLimitCard(),
      if (chat.sending) const TypingIndicator(),
      for (final entry in chat.entries.reversed) _entry(entry, controller, chat.sending),
    ];
    final canSend = _input.text.trim().isNotEmpty && !chat.sending && !chat.limitReached;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const _Header(),
            if (chat.usage case final usage?) _UsageChip(usage: usage),
            if (_slow)
              const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 0), child: WakingUpBanner()),
            Expanded(
              child: items.isEmpty
                  ? const _EmptyChat()
                  : ListView.separated(
                      controller: _scroll,
                      reverse: true,
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => items[index],
                    ),
            ),
            _Composer(
              controller: _input,
              canSend: canSend,
              enabled: !chat.limitReached,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }

  Widget _entry(ChatEntry entry, ChatController controller, bool sending) => switch (entry) {
    UserEntry(status: SendStatus.failed) => Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        MessageBubble(text: entry.text, fromUser: true, failed: true),
        SendFailedNotice(
          message: _failureText(entry),
          onRetry: entry.canRetry && !sending ? () => controller.retry(entry.id) : null,
        ),
      ],
    ),
    UserEntry() => MessageBubble(text: entry.text, fromUser: true),
    MarlixEntry(:final message) => MessageBubble(text: message.content, fromUser: false),
    CrisisEntry(:final message, :final resources) => CrisisCard(
      text: message.content,
      resources: resources,
    ),
  };

  static String _failureText(UserEntry entry) => switch (entry.failure) {
    SendFailure.network => 'No se pudo enviar. Revisá tu conexión a internet.',
    SendFailure.timeout => 'marlix tardó demasiado en responder. No se pudo enviar.',
    SendFailure.unavailable => 'marlix no puede responder en este momento. No se pudo enviar.',
    SendFailure.tooFast => switch (entry.retryAfter?.inSeconds) {
      final seconds? when seconds > 0 =>
        'Vas muy rápido. Esperá $seconds segundos y volvé a intentarlo.',
      _ => 'Vas muy rápido. Esperá un momento y volvé a intentarlo.',
    },
    SendFailure.dailyLimit => 'No se envió: llegamos al límite de hoy.',
    SendFailure.unexpected || null => 'No se pudo enviar.',
  };
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
  const _Composer({
    required this.controller,
    required this.canSend,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool canSend;

  /// False once the daily limit is reached.
  final bool enabled;
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
                enabled: enabled,
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
