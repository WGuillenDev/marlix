import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/auth_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

class MarlixApp extends ConsumerStatefulWidget {
  const MarlixApp({super.key});

  @override
  ConsumerState<MarlixApp> createState() => _MarlixAppState();
}

class _MarlixAppState extends ConsumerState<MarlixApp> {
  final _navigator = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    // When the session starts or ends, screens opened on top (settings, help)
    // are closed, so none of the previous session stays on screen.
    ref.listen(signedInUserProvider, (_, _) {
      _navigator.currentState?.popUntil((route) => route.isFirst);
    });
    final signedIn = ref.watch(signedInUserProvider) != null;

    return MaterialApp(
      navigatorKey: _navigator,
      title: 'marlix',
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      home: signedIn ? const ChatScreen() : const AuthScreen(),
    );
  }
}
