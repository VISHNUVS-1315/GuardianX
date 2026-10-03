import 'package:flutter/material.dart';

import 'hierarchy_auth.dart';
import 'hierarchy_common.dart';
import 'hierarchy_controller.dart';
import 'hierarchy_portals.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CampusLiveHierarchyApp());
}

class CampusLiveHierarchyApp extends StatelessWidget {
  const CampusLiveHierarchyApp({super.key});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: hierarchyController,
        builder: (context, _) => MaterialApp(
          title: 'CampusLive',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: AppColors.bg,
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.blue,
              primary: AppColors.blue,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.navy,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
            ),
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
          home: hierarchyController.loggedIn
              ? const RoleHomePage()
              : const LoginPage(),
        ),
      );
}
