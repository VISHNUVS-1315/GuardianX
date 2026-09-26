import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'screens/live_share_screen.dart';
import 'screens/shell_screen.dart';

class GuardianXApp extends StatelessWidget {
  const GuardianXApp({super.key});

  @override
  Widget build(BuildContext context) {
    final shareId = _shareIdFromUri();
    return MaterialApp(
      title: 'GuardianX',
      debugShowCheckedModeBanner: false,
      theme: GuardianXTheme.dark,
      home: shareId == null
          ? const ShellScreen()
          : LiveShareScreen(shareId: shareId),
    );
  }

  String? _shareIdFromUri() {
    final fragment = Uri.base.fragment;
    final normalized = fragment.startsWith('/') ? fragment : '/$fragment';
    const prefix = '/share/';
    if (!normalized.startsWith(prefix)) return null;
    final value = normalized.substring(prefix.length).split('/').first.trim();
    return value.isEmpty ? null : value;
  }
}
