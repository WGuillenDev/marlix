import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/usage.dart';
import '../../services/help_resources.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar_marlix.dart';
import '../../widgets/chat_states.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/typing_indicator.dart';
import '../help_screen.dart';
import '../settings_screen.dart';
import 'avatar_controller.dart';
import 'chat_controller.dart';
import 'reply_reader.dart';

/// Main screen (wireframes docs/diagrams/wireframes/screens/03a to 03d).
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  /// A normal reply takes a few seconds; past this, the backend is probably
  /// waking up.
  static const slowReplyAfter = Duration(seconds: 5);

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> with WidgetsBindingObserver {
  static const slowReplyAfter = ChatScreen.slowReplyAfter;

  /// How close to the oldest loaded message the scroll gets before the next
  /// page is requested.
  static const _loadOlderWithin = 400.0;

  final _input = TextEditingController();
  final _scroll = ScrollController();
  Timer? _slowTimer;
  var _slow = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _input.addListener(() => setState(() {}));
    _scroll.addListener(_loadOlderNearTop);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatControllerProvider.notifier)
        ..loadHistory()
        ..loadUsage();
      // So the help screen has the full list if the connection drops later.
      ref.read(helpResourcesProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _slowTimer?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // With the screen locked or the app in the background the voice waits, and
  // it goes on when the person comes back (docs/decisions.md, S6-4).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final reader = ref.read(replyReaderProvider.notifier);
    switch (state) {
      case AppLifecycleState.paused || AppLifecycleState.hidden:
        unawaited(reader.pause(byApp: true));
      case AppLifecycleState.resumed:
        unawaited(reader.resumeAfterBackground());
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _send() async {
    final text = _input.text;
    _input.clear();
    // A failure keeps the message in the chat with a retry, so nothing is lost.
    await ref.read(chatControllerProvider.notifier).send(text);
  }

  /// The list is reversed: the end of the scroll is the oldest message. After
  /// a failure it waits for the retry button instead of asking again by itself.
  void _loadOlderNearTop() {
    final chat = ref.read(chatControllerProvider);
    if (chat.historyStatus != HistoryStatus.idle || !chat.hasOlder) return;
    final position = _scroll.position;
    if (position.maxScrollExtent - position.pixels <= _loadOlderWithin) {
      ref.read(chatControllerProvider.notifier).loadHistory();
    }
  }

  /// Leaving the chat for another screen ends the reading.
  void _openHelp() {
    unawaited(ref.read(replyReaderProvider.notifier).stop());
    Navigator.of(context).push(HelpScreen.route());
  }

  void _openSettings() {
    unawaited(ref.read(replyReaderProvider.notifier).stop());
    Navigator.of(context).push(SettingsScreen.route());
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
      // Older pages are added at the top: they must not pull the chat down.
      if (previous?.entries.lastOrNull?.id != next.entries.lastOrNull?.id ||
          previous?.sending != next.sending ||
          previous?.limitReached != next.limitReached) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLatest());
      }
      if (previous?.sending != next.sending) _watchSlowReply(next.sending);
    });

    final reading = ref.watch(replyReaderProvider);
    final controller = ref.read(chatControllerProvider.notifier);
    final items = <Widget>[
      if (chat.limitReached) DailyLimitCard(onHelp: _openHelp),
      if (chat.sending) const TypingIndicator(),
      for (final entry in chat.entries.reversed) _entry(entry, controller, chat.sending),
      // The last item is the top of the chat.
      if (chat.historyStatus == HistoryStatus.loading && chat.entries.isNotEmpty)
        const HistoryLoadingNotice(),
      if (chat.historyStatus == HistoryStatus.failed && chat.entries.isNotEmpty)
        HistoryFailedNotice(onRetry: controller.loadHistory),
    ];
    final canSend = _input.text.trim().isNotEmpty && !chat.sending && !chat.limitReached;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              // Read here: the Scaffold hides the keyboard from its body.
              compact: MediaQuery.viewInsetsOf(context).bottom > 0,
              onHelp: _openHelp,
              onSettings: _openSettings,
            ),
            if (chat.usage case final usage?) _UsageChip(usage: usage),
            if (reading != Reading.idle) _ReadingBar(reading: reading),
            if (_slow)
              const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 0), child: WakingUpBanner()),
            Expanded(
              child: items.isEmpty
                  ? _emptyChat(chat.historyStatus, controller)
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

  /// Nothing to show yet: wait for the history before saying the chat is empty.
  Widget _emptyChat(HistoryStatus status, ChatController controller) => switch (status) {
    HistoryStatus.pending || HistoryStatus.loading => const Center(
      child: HistoryLoadingNotice(message: 'Cargando tu conversación…'),
    ),
    HistoryStatus.failed => Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: HistoryFailedNotice(onRetry: controller.loadHistory),
      ),
    ),
    HistoryStatus.idle => const _EmptyChat(),
  };

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
      onMoreHelp: _openHelp,
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
    SendFailure.sessionEnded => 'No se envió: tu sesión terminó.',
    SendFailure.unexpected || null => 'No se pudo enviar.',
  };
}

/// The animated avatar; the name next to it already says who it is.
class _HeaderAvatar extends ConsumerWidget {
  const _HeaderAvatar({required this.compact});

  /// With the keyboard open there is little height left for the messages.
  final bool compact;

  static const size = 64.0;

  static const compactSize = 48.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: compact ? compactSize : size,
        child: AvatarMarlix(
          state: ref.watch(avatarStateProvider),
          volume: ref.watch(avatarVolumeProvider),
          folder: ref.watch(avatarFolderProvider),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onHelp, required this.onSettings, required this.compact});

  /// Smaller avatar, for when the keyboard is open.
  final bool compact;

  final VoidCallback onHelp;
  final VoidCallback onSettings;

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
            _HeaderAvatar(compact: compact),
            const SizedBox(width: 8),
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
            IconButton(
              onPressed: onSettings,
              tooltip: 'Ajustes',
              icon: const Icon(Icons.settings_rounded),
              iconSize: 28,
              color: AppColors.textSecondary,
              style: IconButton.styleFrom(fixedSize: const Size(48, 48)),
            ),
            const SizedBox(width: 4),
            // Always visible, so help is one tap away from the chat.
            IconButton(
              onPressed: onHelp,
              tooltip: 'Ayuda',
              icon: const Icon(Icons.support_rounded),
              iconSize: 28,
              style: IconButton.styleFrom(
                fixedSize: const Size(52, 52),
                foregroundColor: AppColors.crisis,
                backgroundColor: AppColors.white,
                side: const BorderSide(color: AppColors.crisis, width: 2.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pause, resume and stop for the reply being read aloud.
class _ReadingBar extends ConsumerWidget {
  const _ReadingBar({required this.reading});

  final Reading reading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reader = ref.read(replyReaderProvider.notifier);
    final paused = reading == Reading.paused;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 4, 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  paused ? 'En pausa' : 'marlix está hablando',
                  style: AppText.caption.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: paused ? reader.resume : reader.pause,
                tooltip: paused ? 'Continuar' : 'Pausar',
                icon: Icon(paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                iconSize: 28,
                color: AppColors.textSecondary,
                style: IconButton.styleFrom(fixedSize: const Size(48, 48)),
              ),
              IconButton(
                onPressed: reader.stop,
                tooltip: 'Detener',
                icon: const Icon(Icons.stop_rounded),
                iconSize: 28,
                color: AppColors.textSecondary,
                style: IconButton.styleFrom(fixedSize: const Size(48, 48)),
              ),
            ],
          ),
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
