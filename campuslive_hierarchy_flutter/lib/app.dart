import 'package:flutter/material.dart';

import 'auth_pages.dart';
import 'controller.dart';
import 'role_home.dart';
import 'ui_common.dart';

class CampusLiveApp extends StatelessWidget {
  const CampusLiveApp({super.key});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: appController,
        builder: (context, _) => MaterialApp(
          title: 'CampusLive',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: AppColors.bg,
            colorScheme:
                ColorScheme.fromSeed(seedColor: AppColors.blue),
            cardTheme: const CardThemeData(
              elevation: 0,
              margin: EdgeInsets.zero,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(22)),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          home: appController.loggedIn
              ? const RoleHomePage()
              : const LoginPage(),
        ),
      );
}
