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
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.blue,
              brightness: Brightness.light,
            ),
            visualDensity: VisualDensity.standard,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            appBarTheme: const AppBarTheme(
              backgroundColor: AppColors.bg,
              foregroundColor: AppColors.navy,
              elevation: 0,
              scrolledUnderElevation: 0,
              centerTitle: false,
            ),
            cardTheme: const CardThemeData(
              elevation: 0,
              margin: EdgeInsets.zero,
              color: Colors.white,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(24)),
                side: BorderSide(
                  color: AppColors.line,
                  width: 1,
                ),
              ),
            ),
            navigationBarTheme: const NavigationBarThemeData(
              height: 72,
              elevation: 0,
              backgroundColor: Colors.white,
              indicatorColor: Color(0xFFEAF0FF),
              labelBehavior:
                  NavigationDestinationLabelBehavior.alwaysShow,
            ),
            navigationDrawerTheme: const NavigationDrawerThemeData(
              backgroundColor: Colors.white,
              indicatorColor: Color(0xFFEAF0FF),
            ),
            dividerTheme: const DividerThemeData(
              color: AppColors.line,
              thickness: 1,
              space: 1,
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(48, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 17,
              ),
              labelStyle: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
              ),
              hintStyle: const TextStyle(color: AppColors.muted),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: AppColors.line,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: AppColors.line,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: AppColors.blue,
                  width: 1.6,
                ),
              ),
            ),
            snackBarTheme: SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          home: appController.loggedIn
              ? const RoleHomePage()
              : const LoginPage(),
        ),
      );
}
