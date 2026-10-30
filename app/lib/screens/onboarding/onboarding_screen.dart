import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/api_exception.dart';
import '../../services/auth_service.dart';
import '../../services/microphone_permission.dart';
import '../../services/reminders.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar_marlix.dart';
import '../chat/avatar_controller.dart';
import '../reminders_toggle.dart';
import 'profile_controller.dart';

/// What the person answered about the microphone.
enum _Microphone { unasked, allowed, later }

/// First-time onboarding, once per account (wireframes
/// docs/diagrams/wireframes/screens/02a to 02d): the avatar introduces
/// itself, then the notice and the data consent, the permissions, and where
/// help is. The consent step cannot be skipped: the pages do not swipe.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  static const steps = 4;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _pageDuration = Duration(milliseconds: 300);

  final _pages = PageController();
  var _page = 0;
  var _consent = false;
  var _microphone = _Microphone.unasked;
  var _finishing = false;
  var _saveFailed = false;
  var _remindersDenied = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() => _pages.nextPage(duration: _pageDuration, curve: Curves.easeInOut);

  void _back() => _pages.previousPage(duration: _pageDuration, curve: Curves.easeInOut);

  Future<void> _allowMicrophone() async {
    final allowed = await ref.read(microphonePermissionProvider).request();
    if (mounted) setState(() => _microphone = allowed ? _Microphone.allowed : _Microphone.later);
  }

  Future<void> _toggleReminders(bool on) async {
    final done = await toggleReminders(ref, on);
    if (mounted) setState(() => _remindersDenied = !done);
  }

  Future<void> _finish() async {
    setState(() {
      _finishing = true;
      _saveFailed = false;
    });
    try {
      // The chat opens by itself when the profile says onboarding is done.
      await ref
          .read(profileControllerProvider.notifier)
          .completeOnboarding(remindersEnabled: ref.read(remindersProvider).enabled);
    } on ApiException {
      // Said on the step itself: a snackbar would cover the button to retry.
      if (mounted) setState(() => _saveFailed = true);
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Back goes to the previous step; on the first one it leaves the app.
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 8),
                child: _Progress(page: _page),
              ),
              Expanded(
                child: PageView(
                  controller: _pages,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (page) => setState(() => _page = page),
                  children: [
                    _Welcome(onContinue: _next),
                    _Consent(
                      accepted: _consent,
                      onChanged: (value) => setState(() => _consent = value),
                      onContinue: _next,
                      onDecline: () => ref.read(authServiceProvider).signOut(),
                    ),
                    _Permissions(
                      microphone: _microphone,
                      onAllowMicrophone: _allowMicrophone,
                      onLaterMicrophone: () => setState(() => _microphone = _Microphone.later),
                      onContinue: _next,
                      remindersDenied: _remindersDenied,
                      onToggleReminders: _toggleReminders,
                    ),
                    _Help(finishing: _finishing, failed: _saveFailed, onFinish: _finish),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.page});

  final int page;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Paso ${page + 1} de ${OnboardingScreen.steps}',
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var step = 0; step < OnboardingScreen.steps; step++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: step == page ? 28 : 14,
                height: 10,
                decoration: BoxDecoration(
                  color: step == page ? AppColors.tanDark : AppColors.line,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The layout every step shares: the content scrolls on a small screen, and
/// the actions stay at the bottom.
class _Step extends StatelessWidget {
  const _Step({required this.children, required this.actions});

  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
            ),
          ),
          const SizedBox(height: 16),
          ...actions,
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed, this.busy = false});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        backgroundColor: AppColors.tanDark,
        foregroundColor: AppColors.white,
        disabledBackgroundColor: AppColors.tanDark.withValues(alpha: 0.4),
        disabledForegroundColor: AppColors.white,
        textStyle: AppText.button.copyWith(fontSize: 18),
      ),
      child: busy
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.white),
            )
          : Text(label),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.color = AppColors.white});

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: AppColors.line, width: 1.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    );
  }
}

/// 02a: the avatar introduces itself, bouncing with joy.
class _Welcome extends ConsumerWidget {
  const _Welcome({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Step(
      actions: [_PrimaryButton(label: 'Continuar', onPressed: onContinue)],
      children: [
        Center(
          child: DecoratedBox(
            decoration: const BoxDecoration(color: AppColors.tanLight, shape: BoxShape.circle),
            child: SizedBox.square(
              dimension: 260,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: AvatarMarlix(
                  state: AvatarState.happy,
                  folder: ref.watch(avatarFolderProvider),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text('¡Hola! Soy marlix', style: AppText.display, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        const Text(
          'Estoy aquí para conversar contigo y acompañarte en tu día, por texto o por voz. '
          'Me inspiré en Marley, una perrita muy querida.',
          style: AppText.body,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        const _Card(
          color: AppColors.tanLight,
          child: Text(
            'Soy una inteligencia artificial, no una persona. '
            'Mi voz también la genera una máquina.',
            style: AppText.bodyStrong,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Te voy a contar cómo funciono antes de empezar.',
          style: AppText.body.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// 02b: the notice and the explicit consent. The button waits for the checkbox.
class _Consent extends StatelessWidget {
  const _Consent({
    required this.accepted,
    required this.onChanged,
    required this.onContinue,
    required this.onDecline,
  });

  final bool accepted;
  final ValueChanged<bool> onChanged;
  final VoidCallback onContinue;
  final VoidCallback onDecline;

  // What is stored: keep it in step with docs/memory.md and the retention
  // days of the backend (MESSAGE_RETENTION_DAYS).
  static const _data = [
    'Guardo tus mensajes 90 días para seguir la conversación.',
    'Guardo datos clave que me cuentes para conocerte. Puedes verlos, editarlos y borrarlos.',
    'Nunca guardo cédula, tarjetas ni diagnósticos.',
    'Puedes eliminar tu cuenta y todo se borra.',
  ];

  @override
  Widget build(BuildContext context) {
    return _Step(
      actions: [
        // Pinned with the button, so the choice is always in sight.
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onChanged(!accepted),
          child: Row(
            children: [
              Checkbox(
                value: accepted,
                onChanged: (value) => onChanged(value ?? false),
                activeColor: AppColors.tanDark,
              ),
              const Expanded(
                child: Text(
                  'Entiendo y acepto cómo marlix usa mis datos.',
                  style: AppText.bodyStrong,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _PrimaryButton(label: 'Aceptar y continuar', onPressed: accepted ? onContinue : null),
        TextButton(onPressed: onDecline, child: const Text('No acepto, cerrar sesión')),
      ],
      children: [
        Semantics(header: true, child: const Text('Antes de empezar', style: AppText.title)),
        const SizedBox(height: 16),
        _Card(
          color: AppColors.warningBackground,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('No soy terapia', style: AppText.heading),
              const SizedBox(height: 8),
              const Text(
                'Soy compañía para conversar. No doy diagnósticos ni reemplazo a un '
                'profesional de la salud.',
                style: AppText.body,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tus datos', style: AppText.heading),
              const SizedBox(height: 12),
              for (final line in _data)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 8, right: 12),
                        child: Icon(Icons.circle, size: 8, color: AppColors.tanDark),
                      ),
                      Expanded(child: Text(line, style: AppText.body)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 02c: the microphone, and the offer of the daily reminders. Neither is required.
class _Permissions extends ConsumerWidget {
  const _Permissions({
    required this.microphone,
    required this.onAllowMicrophone,
    required this.onLaterMicrophone,
    required this.onContinue,
    required this.remindersDenied,
    required this.onToggleReminders,
  });

  final _Microphone microphone;
  final VoidCallback onAllowMicrophone;
  final VoidCallback onLaterMicrophone;
  final VoidCallback onContinue;
  final bool remindersDenied;
  final ValueChanged<bool> onToggleReminders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersOn = ref.watch(remindersProvider).enabled;
    return _Step(
      actions: [_PrimaryButton(label: 'Continuar', onPressed: onContinue)],
      children: [
        Semantics(
          header: true,
          child: const Text('Hablemos también por voz', style: AppText.title),
        ),
        const SizedBox(height: 16),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.tanLight,
                    child: Icon(Icons.mic_rounded, size: 30, color: AppColors.tanDark),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(child: Text('Micrófono', style: AppText.heading)),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Lo uso solo cuando estás en modo voz, para escucharte y responderte con mi voz.',
                style: AppText.body,
              ),
              const SizedBox(height: 8),
              Text(
                'Lo que dices viaja a nuestro servidor para pasarlo a texto y no se guarda.',
                style: AppText.caption.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              switch (microphone) {
                // A Wrap, so a large font size moves the second button down instead of overflowing.
                _Microphone.unasked => Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton(
                      onPressed: onAllowMicrophone,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        backgroundColor: AppColors.tanDark,
                        foregroundColor: AppColors.white,
                        textStyle: AppText.button,
                      ),
                      child: const Text('Permitir'),
                    ),
                    TextButton(onPressed: onLaterMicrophone, child: const Text('Ahora no')),
                  ],
                ),
                _Microphone.allowed => const _Answer(
                  icon: Icons.check_circle_rounded,
                  color: AppColors.success,
                  text: 'Micrófono permitido.',
                ),
                _Microphone.later => const _Answer(
                  icon: Icons.schedule_rounded,
                  color: AppColors.textSecondary,
                  text: 'Sin problema: te lo pido cuando abras el modo voz.',
                ),
              },
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: Text('¿Te saludo todos los días?', style: AppText.heading)),
                  Switch(
                    value: remindersOn,
                    activeThumbColor: AppColors.tan,
                    onChanged: onToggleReminders,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Te escribo una vez al día, a la hora que elijas, para charlar un ratito. '
                'Sin culpas ni rachas.',
                style: AppText.body,
              ),
              const SizedBox(height: 12),
              Text(
                'Si dices que no, no pasa nada. Puedes cambiarlo en Ajustes.',
                style: AppText.caption.copyWith(color: AppColors.textSecondary),
              ),
              if (remindersDenied) ...[
                const SizedBox(height: 12),
                const Text(remindersDeniedNotice, style: AppText.bodyStrong),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Answer extends StatelessWidget {
  const _Answer({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: AppText.bodyStrong)),
      ],
    );
  }
}

/// 02d: where help is, always one tap away.
class _Help extends ConsumerWidget {
  const _Help({required this.finishing, required this.failed, required this.onFinish});

  final bool finishing;
  final bool failed;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Step(
      actions: [
        if (failed) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              'No se pudo guardar. Revisa tu conexión e inténtalo de nuevo.',
              style: AppText.bodyStrong.copyWith(color: AppColors.crisis),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
        ],
        _PrimaryButton(label: '¡Empecemos!', onPressed: onFinish, busy: finishing),
      ],
      children: [
        Semantics(
          header: true,
          child: const Text('Si no estás bien, aquí hay ayuda', style: AppText.title),
        ),
        const SizedBox(height: 16),
        _Card(
          child: Row(
            children: [
              const Expanded(child: Text('marlix', style: AppText.heading)),
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.crisis, width: 2.5),
                  color: AppColors.white,
                ),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.support_rounded, size: 28, color: AppColors.crisis),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Toca el salvavidas en cualquier momento, en el chat o en modo voz. Ahí verás el '
          '9-1-1 y otros números de apoyo en Costa Rica.',
          style: AppText.body,
        ),
        const SizedBox(height: 12),
        const Text('También funciona sin internet.', style: AppText.bodyStrong),
        const SizedBox(height: 16),
        Center(
          child: SizedBox.square(
            dimension: 180,
            child: AvatarMarlix(state: AvatarState.idle, folder: ref.watch(avatarFolderProvider)),
          ),
        ),
      ],
    );
  }
}
