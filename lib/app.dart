import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'screens/shell_screen.dart';

class GuardianXApp extends StatelessWidget {
  const GuardianXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GuardianX',
      debugShowCheckedModeBanner: false,
      theme: GuardianXTheme.dark,
      home: const ShellScreen(),
    );
  }
}
