import 'package:flutter/material.dart';

import 'screens/chat/chat_screen.dart';
import 'theme/app_theme.dart';

class MarlixApp extends StatelessWidget {
  const MarlixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'marlix',
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      home: const ChatScreen(),
    );
  }
}
