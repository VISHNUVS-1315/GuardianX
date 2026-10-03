import 'dart:async';

import 'package:flutter/material.dart';

import 'admin_pages.dart';
import 'controller.dart';
import 'models.dart';
import 'role_pages.dart';
import 'ui_common.dart';

class RoleHomePage extends StatefulWidget {
  const RoleHomePage({super.key});

  @override
  State<RoleHomePage> createState() => _RoleHomePageState();
}

class _RoleHomePageState extends State<RoleHomePage> {
  String selectedModule = 'overview';

  @override
  void initState() {
    super.initState();
    unawaited(appController.refreshAll());
  }

  List<PortalItem> get enabledItems {
    final items = appController.portal.where((e) => e.enabled).toList();
    if (items.isEmpty) {
      return [
        PortalItem(
          module: 'overview',
          label: 'Overview',
          enabled: true,
          position: 0,
        ),
      ];
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final user = appController.user!;
    final items = enabledItems;

    if (!items.any((e) => e.module == selectedModule)) {
      selectedModule = items.first.module;
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user.collegeName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              roleLabel(user.role),
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 10,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Center(
              child: Chip(
                side: BorderSide.none,
                backgroundColor: appController.online
                    ? const Color(0xFFE8F8F0)
                    : const Color(0xFFFFF1E5),
                label: Text(
                  appController.online ? 'LIVE' : 'OFFLINE',
                  style: TextStyle(
                    color: appController.online
                        ? AppColors.green
                        : AppColors.orange,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: appController.refreshAll,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(
                  color: AppColors.navy,
                ),
                accountName: Text(
                  user.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                accountEmail: Text(
                  roleLabel(user.role) + ' • ' + user.collegeCode,
                ),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.blue,
                  child: Icon(roleIcon(user.role), size: 28),
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final item in items)
                      ListTile(
                        selected: selectedModule == item.module,
                        selectedTileColor:
                            const Color(0xFFEEF2FF),
                        leading: Icon(moduleIcon(item.module)),
                        title: Text(item.label),
                        onTap: () {
                          setState(
                            () => selectedModule = item.module,
                          );
                          Navigator.pop(context);
                        },
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Logout'),
                onTap: () {
                  Navigator.pop(context);
                  appController.logout();
                },
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: _modulePage(selectedModule),
      ),
    );
  }

  Widget _modulePage(String module) {
    switch (module) {
      case 'overview':
        return const OverviewPage();
      case 'directory':
        return const DirectoryPage();
      case 'inbox':
        return const InboxPage();
      case 'assign':
        return const AssignPage();
      case 'users':
        return const AdminUsersPage();
      case 'departments':
        return const AdminDepartmentsPage();
      case 'portal_control':
        return const PortalControlPage();
      case 'live_activity':
        return const LiveActivityPage();
      case 'profile':
        return const ProfilePage();
      default:
        return EmptyModulePage(module: module);
    }
  }
}
