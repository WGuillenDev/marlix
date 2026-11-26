import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import 'features/account/presentation/auth_screen.dart';
import 'features/account/presentation/profile_gate.dart';
import 'features/account/presentation/session_state.dart';
import 'features/settings/composition/reminder_scheduler_provider.dart';
import 'features/settings/presentation/reminders.dart';
import 'shared/presentation/app_theme.dart';

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
    // Open the chat root when a reminder is tapped.
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _rescheduleReminders();
  }

  void _rescheduleReminders() {
    final reminders = ref.read(remindersProvider.notifier);
    unawaited(ref.read(signedInUserProvider) == null ? reminders.cancel() : reminders.reschedule());
  }

  @override
  Widget build(BuildContext context) {
    // Discard screens opened by a previous session.
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
