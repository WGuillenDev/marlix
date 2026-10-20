import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/auth_screen.dart';
import 'screens/onboarding/profile_gate.dart';
import 'services/auth_service.dart';
import 'services/reminder_scheduler.dart';
import 'services/reminders.dart';
import 'theme/app_theme.dart';

class MarlixApp extends ConsumerStatefulWidget {
  const MarlixApp({super.key});

  @override
  ConsumerState<MarlixApp> createState() => _MarlixAppState();
}

class _MarlixAppState extends ConsumerState<MarlixApp> with WidgetsBindingObserver {
  final _navigator = GlobalKey<NavigatorState>();
  StreamSubscription<void>? _reminderTaps;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Tapping a reminder lands on the chat, the root screen, not on whatever
    // was open.
    _reminderTaps = ref.read(reminderSchedulerProvider).taps.listen((_) {
      _navigator.currentState?.popUntil((route) => route.isFirst);
    });
    _rescheduleReminders();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reminderTaps?.cancel();
    super.dispose();
  }

  // Coming back to the app counts as opening it.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _rescheduleReminders();
  }

  /// The reminders only exist while there is a session.
  void _rescheduleReminders() {
    final reminders = ref.read(remindersProvider.notifier);
    unawaited(ref.read(signedInUserProvider) == null ? reminders.cancel() : reminders.reschedule());
  }

  @override
  Widget build(BuildContext context) {
    // When the session starts or ends, screens opened on top (settings, help)
    // are closed, so none of the previous session stays on screen.
    ref.listen(signedInUserProvider, (_, _) {
      _navigator.currentState?.popUntil((route) => route.isFirst);
      _rescheduleReminders();
    });
    final signedIn = ref.watch(signedInUserProvider) != null;

    return MaterialApp(
      navigatorKey: _navigator,
      title: 'marlix',
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      home: signedIn ? const ProfileGate() : const AuthScreen(),
    );
  }
}
