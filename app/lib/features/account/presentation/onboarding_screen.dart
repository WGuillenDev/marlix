import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/application/api_exception.dart';
import '../../../shared/presentation/app_theme.dart';
import '../../settings/presentation/reminders.dart';
import '../../settings/presentation/reminders_toggle.dart';
import '../../voice/composition/microphone_provider.dart';
import 'onboarding/consent_step.dart';
import 'onboarding/help_step.dart';
import 'onboarding/permissions_step.dart';
import 'onboarding/welcome_step.dart';
import 'profile_controller.dart';
import 'session_state.dart';

/// Disable swiping so the consent step cannot be skipped.
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
  var _microphone = MicrophoneChoice.unasked;
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
    if (mounted) {
      setState(() => _microphone = allowed ? MicrophoneChoice.allowed : MicrophoneChoice.later);
    }
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
      await ref
          .read(profileControllerProvider.notifier)
          .completeOnboarding(remindersEnabled: ref.read(remindersProvider).enabled);
    } on ApiException {
      // Inline errors leave the retry button visible.
      if (mounted) setState(() => _saveFailed = true);
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
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
                    WelcomeStep(onContinue: _next),
                    ConsentStep(
                      accepted: _consent,
                      onChanged: (value) => setState(() => _consent = value),
                      onContinue: _next,
                      onDecline: () => ref.read(authServiceProvider).signOut(),
                    ),
                    PermissionsStep(
                      microphone: _microphone,
                      onAllowMicrophone: _allowMicrophone,
                      onLaterMicrophone: () => setState(() => _microphone = MicrophoneChoice.later),
                      onContinue: _next,
                      remindersDenied: _remindersDenied,
                      onToggleReminders: _toggleReminders,
                    ),
                    HelpStep(finishing: _finishing, failed: _saveFailed, onFinish: _finish),
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

// Scroll content independently so actions stay reachable on small screens.
