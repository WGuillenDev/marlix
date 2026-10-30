import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/read_aloud.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar_marlix.dart';
import '../../widgets/composer.dart';
import '../../widgets/usage_chip.dart';
import '../chat/avatar_controller.dart';
import '../chat/chat_controller.dart';
import '../chat/reply_reader.dart';
import '../help_screen.dart';
import 'conversation_controller.dart';
import 'speech_controller.dart';
import 'voice_controller.dart';
import 'voice_model_card.dart';

/// Shared by the avatar of the chat header and the one of the voice mode, so the
/// avatar grows from one to the other while the screen opens.
const marlixAvatarHero = 'marlix-avatar';

/// The full-screen voice mode (wireframes 04a and 04b, S6-7). Replies come short
/// and are read aloud. The person talks without buttons (S6-8, S6-9): marlix
/// listens, answers when they pause, and goes quiet if they speak over it. They
/// can also pause the conversation or write.
class VoiceModeScreen extends ConsumerStatefulWidget {
  const VoiceModeScreen({super.key});

  static const transition = Duration(milliseconds: 380);

  /// Fades in while it grows a little from the chat. The avatar flies between
  /// the two screens with a [Hero].
  static Route<void> route() => PageRouteBuilder<void>(
    settings: const RouteSettings(name: 'voice-mode'),
    opaque: true,
    transitionDuration: transition,
    reverseTransitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, _, _) => const VoiceModeScreen(),
    transitionsBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(curved), child: child),
      );
    },
  );

  @override
  ConsumerState<VoiceModeScreen> createState() => _VoiceModeScreenState();
}

class _VoiceModeScreenState extends ConsumerState<VoiceModeScreen> with WidgetsBindingObserver {
  final _input = TextEditingController();

  /// The small "Chat" button opens a field to write without leaving the mode.
  var _writing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _input.addListener(() => setState(() {}));
    // After the first frame: a provider cannot change while the tree builds.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(voiceModeProvider.notifier).set(true);
      // So the card knows whether the model is there before anything is said.
      if (ref.read(voiceControllerProvider) is VoiceIdle) {
        unawaited(ref.read(voiceControllerProvider.notifier).start());
      }
      ref.read(conversationControllerProvider.notifier).start();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _input.dispose();
    super.dispose();
  }

  /// The microphone never stays open behind another app or a locked screen: the
  /// conversation pauses and the person resumes it when they are back.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      unawaited(ref.read(conversationControllerProvider.notifier).pause());
    }
  }

  /// Any way out (the X, the back button or the gesture) ends the mode, cuts what
  /// is being said and closes the microphone.
  void _left(bool didPop, Object? result) {
    if (!didPop) return;
    ref.read(voiceModeProvider.notifier).set(false);
    unawaited(ref.read(conversationControllerProvider.notifier).end());
  }

  /// The line under the buttons: what to do, or what went wrong.
  String _hint(ConversationPhase phase, SpeechState speech, bool limitReached) {
    if (limitReached) return 'Mañana volvemos a hablar.';
    return switch (speech) {
      SpeechDenied(blocked: false) => 'Necesito el micrófono para escucharte. Toca el botón para permitirlo o escríbele con el botón Chat.',
      SpeechDenied(blocked: true) => 'El micrófono está bloqueado. Toca el botón para abrir los Ajustes o escríbele con el botón Chat.',
      SpeechProblem(failure: SpeechFailure.unavailable) =>
        'Este teléfono no puede reconocer la voz. Escríbele con el botón Chat.',
      SpeechProblem(failure: SpeechFailure.noSpeech) =>
        'No te escuché. Toca el micrófono para seguir hablando.',
      SpeechProblem() => 'No pude escucharte. Toca el micrófono para intentarlo otra vez o escríbele con el botón Chat.',
      _ => switch (phase) {
        ConversationPhase.paused => 'Toca el micrófono para seguir hablando.',
        ConversationPhase.speaking => 'Si hablas, marlix se detiene y te escucha.',
        _ => 'Habla con naturalidad; respondo cuando hagas una pausa.',
      },
    };
  }

  Future<void> _microphone(ConversationMode mode, SpeechState speech) async {
    final conversation = ref.read(conversationControllerProvider.notifier);
    if (mode == ConversationMode.on) return conversation.pause();
    if (speech is SpeechDenied && speech.blocked) {
      return ref.read(speechControllerProvider.notifier).openSettings();
    }
    conversation.resume();
  }

  Future<void> _send() async {
    final text = _input.text;
    _input.clear();
    // The keyboard hides the avatar and the field hides the voice buttons: both
    // go away once the message is sent.
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _writing = false);
    ref.read(conversationControllerProvider.notifier).resume();
    await ref.read(chatControllerProvider.notifier).send(text);
  }

  void _openHelp() {
    unawaited(ref.read(conversationControllerProvider.notifier).pause());
    Navigator.of(context).push(HelpScreen.route());
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatControllerProvider);
    final reading = ref.watch(replyReaderProvider);
    final speech = ref.watch(speechControllerProvider);
    final mode = ref.watch(conversationControllerProvider);
    final avatar = ref.watch(avatarStateProvider);
    final last = chat.entries.lastOrNull;
    final canSend = _input.text.trim().isNotEmpty && !chat.sending && !chat.limitReached;
    // Read here: the Scaffold hides the keyboard from its body. While typing the
    // avatar needs the room more than the last reply does.
    final typing = MediaQuery.viewInsetsOf(context).bottom > 0;
    final phase = conversationPhase(
      mode: mode,
      speech: speech,
      thinking: chat.sending,
      reading: reading,
    );
    final hint = _hint(phase, speech, chat.limitReached);

    final status = switch ((chat.limitReached, phase, avatar)) {
      (true, _, _) => 'Por hoy llegamos al límite',
      (_, ConversationPhase.paused, _) => 'En pausa',
      (_, ConversationPhase.thinking, _) => 'Pensando…',
      (_, ConversationPhase.listening, _) => 'Te escucho…',
      (_, ConversationPhase.speaking, AvatarState.speaking) => 'marlix está hablando',
      (_, ConversationPhase.speaking, _) => 'Preparando la voz…',
      _ => 'Aquí estoy',
    };
    // While the person talks, their words take the place of the last reply.
    final caption = chat.limitReached
        ? 'Los mensajes se renuevan a medianoche.'
        : switch (speech) {
            SpeechListening(:final heard) when heard.isNotEmpty => heard,
            _ => last is MarlixEntry ? last.message.content : null,
          };

    return PopScope(
      onPopInvokedWithResult: _left,
      child: Scaffold(
        backgroundColor: AppColors.cream,
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(onHelp: _openHelp),
              if (chat.usage case final usage?) UsageChip(usage: usage),
              const VoiceModelCard(),
              Expanded(
                child: Column(
                  children: [
                    const Expanded(child: _BigAvatar()),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(status, style: AppText.heading, textAlign: TextAlign.center),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(32, typing ? 0 : 8, 32, 0),
                      child: SizedBox(
                        height: typing ? 0 : 72,
                        child: caption == null || typing
                            ? null
                            : Text(
                                caption,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: AppText.body.copyWith(color: AppColors.textSecondary),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_writing)
                Composer(
                  controller: _input,
                  canSend: canSend,
                  enabled: !chat.limitReached,
                  autofocus: true,
                  onSend: _send,
                  leading: IconButton(
                    onPressed: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      setState(() => _writing = false);
                      ref.read(conversationControllerProvider.notifier).resume();
                    },
                    tooltip: 'Volver a la voz',
                    icon: const Icon(Icons.graphic_eq_rounded),
                    iconSize: 26,
                    style: IconButton.styleFrom(
                      fixedSize: const Size(48, 48),
                      foregroundColor: AppColors.tanDark,
                      backgroundColor: AppColors.white,
                      side: const BorderSide(color: AppColors.tanDark, width: 1.5),
                    ),
                  ),
                )
              else
                _Actions(
                  writeEnabled: !chat.limitReached,
                  onWrite: () {
                    unawaited(ref.read(conversationControllerProvider.notifier).pause());
                    setState(() => _writing = true);
                  },
                  onEnd: () => Navigator.of(context).maybePop(),
                  paused: mode != ConversationMode.on,
                  listening: phase == ConversationPhase.listening,
                  hint: hint,
                  micEnabled: !chat.limitReached,
                  onMicrophone: () => _microphone(mode, speech),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onHelp});

  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            tooltip: 'Volver al chat',
            icon: const Icon(Icons.close_rounded),
            iconSize: 28,
            style: IconButton.styleFrom(
              fixedSize: const Size(52, 52),
              foregroundColor: AppColors.charcoal,
              backgroundColor: AppColors.white,
              side: const BorderSide(color: AppColors.line, width: 1.5),
            ),
          ),
          Expanded(
            child: Semantics(
              header: true,
              child: const Text('Modo voz', style: AppText.title, textAlign: TextAlign.center),
            ),
          ),
          // Always visible, as in the chat.
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
    );
  }
}

/// The avatar as large as the space allows, on its pale circle.
class _BigAvatar extends ConsumerWidget {
  const _BigAvatar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = constraints.biggest.shortestSide;
          return Center(
            child: ExcludeSemantics(
              child: Hero(
                tag: marlixAvatarHero,
                child: SizedBox.square(
                  dimension: side,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.tanLight.withValues(alpha: 0.5),
                    ),
                    child: AvatarMarlix(
                      state: ref.watch(avatarStateProvider),
                      volume: ref.watch(avatarVolumeProvider),
                      folder: ref.watch(avatarFolderProvider),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The buttons of the wireframe: "Chat" and "Terminar" small at the sides and the
/// microphone big in the middle, so the voice is what stands out. The microphone
/// pauses the conversation and resumes it; it is blue while marlix listens.
class _Actions extends StatelessWidget {
  const _Actions({
    required this.writeEnabled,
    required this.onWrite,
    required this.onEnd,
    required this.paused,
    required this.listening,
    required this.hint,
    required this.micEnabled,
    required this.onMicrophone,
  });

  final bool writeEnabled;
  final VoidCallback onWrite;
  final VoidCallback onEnd;
  final bool paused;
  final bool listening;
  final String hint;
  final bool micEnabled;
  final VoidCallback onMicrophone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SmallAction(
                icon: Icons.keyboard_alt_outlined,
                label: 'Chat',
                onPressed: writeEnabled ? onWrite : null,
              ),
              IconButton(
                onPressed: micEnabled ? onMicrophone : null,
                tooltip: paused ? 'Seguir hablando' : 'Pausar la conversación',
                icon: Icon(paused ? Icons.mic_off_rounded : Icons.mic_rounded),
                iconSize: 40,
                style: IconButton.styleFrom(
                  fixedSize: const Size(88, 88),
                  foregroundColor: listening ? AppColors.white : AppColors.tanDark,
                  disabledForegroundColor: AppColors.textSecondary,
                  backgroundColor: listening ? AppColors.listening : AppColors.white,
                  side: BorderSide(
                    color: listening ? AppColors.listening : AppColors.line,
                    width: 2,
                  ),
                ),
              ),
              _SmallAction(
                icon: Icons.close_rounded,
                label: 'Terminar',
                color: AppColors.crisis,
                onPressed: onEnd,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: AppText.caption.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color = AppColors.charcoal,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      child: Column(
        children: [
          IconButton(
            onPressed: onPressed,
            tooltip: label,
            icon: Icon(icon),
            iconSize: 28,
            style: IconButton.styleFrom(
              fixedSize: const Size(60, 60),
              foregroundColor: color,
              disabledForegroundColor: AppColors.textSecondary,
              backgroundColor: AppColors.white,
              side: const BorderSide(color: AppColors.line, width: 1.5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppText.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
