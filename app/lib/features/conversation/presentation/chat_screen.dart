import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import '../../../shared/presentation/app_theme.dart';
import '../../avatar/presentation/avatar_controller.dart';
import '../../avatar/presentation/avatar_marlix.dart';
import '../../safety/presentation/help_resources.dart';
import '../../safety/presentation/help_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../voice/presentation/voice_mode_screen.dart';
import 'chat_controller.dart';
import 'reply_reader.dart';
import 'widgets/chat_states.dart';
import 'widgets/composer.dart';
import 'widgets/message_bubble.dart';
import 'widgets/typing_indicator.dart';
import 'widgets/usage_chip.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  // Show a cold-start hint only after the normal reply window.
  static const slowReplyAfter = Duration(seconds: 5);

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> with WidgetsBindingObserver {
  static const slowReplyAfter = ChatScreen.slowReplyAfter;

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

  // Pause reading when the app leaves the foreground.
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
    await ref.read(chatControllerProvider.notifier).send(text);
  }

  // In the reversed list the oldest messages are at the far end.
  void _loadOlderNearTop() {
    final chat = ref.read(chatControllerProvider);
    if (chat.historyStatus != HistoryStatus.idle || !chat.hasOlder) return;
    final position = _scroll.position;
    if (position.maxScrollExtent - position.pixels <= _loadOlderWithin) {
      ref.read(chatControllerProvider.notifier).loadHistory();
    }
  }

  void _openHelp() {
    unawaited(ref.read(replyReaderProvider.notifier).stop());
    Navigator.of(context).push(HelpScreen.route());
  }

  void _openVoiceMode() {
    Navigator.of(context).push(VoiceModeScreen.route());
  }

  void _openSettings() {
    unawaited(ref.read(replyReaderProvider.notifier).stop());
    Navigator.of(context).push(SettingsScreen.route());
  }

  void _scrollToLatest() {
    // Offset zero is the newest message because the list is reversed.
    if (_scroll.hasClients && _scroll.offset > 0) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

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
      // Keep the scroll anchored when older history is inserted.
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
              // Read keyboard insets outside the Scaffold body, which clears them.
              compact: MediaQuery.viewInsetsOf(context).bottom > 0,
              onHelp: _openHelp,
              onSettings: _openSettings,
            ),
            if (chat.usage case final usage?) UsageChip(usage: usage),
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
            Composer(
              controller: _input,
              canSend: canSend,
              enabled: !chat.limitReached,
              onSend: _send,
              leading: _input.text.isNotEmpty
                  ? null
                  : IconButton(
                      onPressed: chat.limitReached ? null : _openVoiceMode,
                      tooltip: 'Modo voz',
                      icon: const Icon(Icons.graphic_eq_rounded),
                      iconSize: 26,
                      style: IconButton.styleFrom(
                        fixedSize: const Size(48, 48),
                        foregroundColor: AppColors.tanDark,
                        backgroundColor: AppColors.white,
                        disabledForegroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.tanDark, width: 1.5),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Wait for history before displaying the empty state.
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

class _HeaderAvatar extends ConsumerWidget {
  const _HeaderAvatar({required this.compact});

  // Reduce header height while the keyboard is visible.
  final bool compact;

  static const size = 64.0;

  static const compactSize = 48.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ExcludeSemantics(
      child: Hero(
        tag: marlixAvatarHero,
        child: SizedBox.square(
          dimension: compact ? compactSize : size,
          child: AvatarMarlix(
            state: ref.watch(avatarStateProvider),
            volume: ref.watch(avatarVolumeProvider),
            folder: ref.watch(avatarFolderProvider),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onHelp, required this.onSettings, required this.compact});

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
                child: Text(switch (reading) {
                  Reading.paused => 'En pausa',
                  Reading.preparing => 'Preparando la voz…',
                  _ => 'marlix está hablando',
                }, style: AppText.caption.copyWith(fontWeight: FontWeight.w700)),
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
