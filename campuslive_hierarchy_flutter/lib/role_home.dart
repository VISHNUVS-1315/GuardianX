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
  final scaffoldKey = GlobalKey<ScaffoldState>();
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

  List<String> preferredModules(String role) {
    switch (role) {
      case 'admin':
        return ['overview', 'users', 'departments', 'live_activity'];
      case 'principal':
        return ['overview', 'directory', 'inbox', 'assign'];
      case 'hod':
        return [
          'overview',
          'department_activity',
          'manage_team',
          'assign',
        ];
      case 'staff':
        return ['overview', 'manage_team', 'inbox', 'assign'];
      case 'student':
        return ['overview', 'inbox', 'profile'];
      default:
        return ['overview'];
    }
  }

  List<PortalItem> quickItems(
    String role,
    List<PortalItem> items,
  ) {
    final preferred = preferredModules(role);
    final result = <PortalItem>[];

    for (final module in preferred) {
      for (final item in items) {
        if (item.module == module &&
            !result.any((x) => x.module == item.module)) {
          result.add(item);
          break;
        }
      }
    }

    for (final item in items) {
      if (result.length >= 4) break;
      if (!result.any((x) => x.module == item.module)) {
        result.add(item);
      }
    }

    return result.take(4).toList();
  }

  void selectModule(String module) {
    setState(() => selectedModule = module);
  }

  @override
  Widget build(BuildContext context) {
    final user = appController.user!;
    final items = enabledItems;

    if (!items.any((e) => e.module == selectedModule)) {
      selectedModule = items.first.module;
    }

    final quick = quickItems(user.role, items);
    final hasMore = items.any(
      (item) => !quick.any((q) => q.module == item.module),
    );
    final selectedQuickIndex = quick.indexWhere(
      (item) => item.module == selectedModule,
    );
    final drawerIndex = items.indexWhere(
      (item) => item.module == selectedModule,
    );
    final navIndex = selectedQuickIndex >= 0
        ? selectedQuickIndex
        : (hasMore ? quick.length : 0);

    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        toolbarHeight: 70,
        leading: IconButton(
          tooltip: 'Open portal menu',
          onPressed: () => scaffoldKey.currentState?.openDrawer(),
          icon: const Icon(Icons.menu_rounded),
        ),
        titleSpacing: 2,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user.collegeName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 16.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              roleLabel(user.role) +
                  (user.department == null || user.department!.isEmpty
                      ? ''
                      : ' • ' + user.department!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          Semantics(
            label: appController.online
                ? 'Backend connected live'
                : 'Backend offline',
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 15),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: appController.online
                    ? const Color(0xFFE8F8F0)
                    : const Color(0xFFFFF1E5),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  Icon(
                    appController.online
                        ? Icons.cloud_done_rounded
                        : Icons.cloud_off_rounded,
                    size: 15,
                    color: appController.online
                        ? AppColors.green
                        : AppColors.orange,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    appController.online ? 'LIVE' : 'OFFLINE',
                    style: TextStyle(
                      color: appController.online
                          ? AppColors.green
                          : AppColors.orange,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (items.any((item) => item.module == 'inbox'))
            IconButton(
              tooltip: 'Open inbox',
              onPressed: () => selectModule('inbox'),
              icon: Badge(
                isLabelVisible:
                    (appController.dashboard['unread'] ?? 0) != 0,
                label: Text(
                  (appController.dashboard['unread'] ?? 0).toString(),
                ),
                child: const Icon(Icons.notifications_none_rounded),
              ),
            ),
          IconButton(
            tooltip: 'Refresh live data',
            onPressed: appController.refreshAll,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.navy,
                      Color(0xFF173D86),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 29,
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.blue,
                      child: Icon(roleIcon(user.role), size: 29),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            roleLabel(user.role),
                            style: const TextStyle(
                              color: Color(0xFFAEC5FF),
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user.collegeCode,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: NavigationDrawer(
                  selectedIndex:
                      drawerIndex >= 0 ? drawerIndex : null,
                  onDestinationSelected: (index) {
                    if (index < 0 || index >= items.length) return;
                    selectModule(items[index].module);
                    Navigator.pop(context);
                  },
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
                      child: Text(
                        'PORTAL',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    for (final item in items)
                      NavigationDrawerDestination(
                        icon: Icon(moduleIcon(item.module)),
                        selectedIcon: Icon(
                          moduleIcon(item.module),
                          color: AppColors.blue,
                        ),
                        label: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              moduleHint(item.module),
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 9.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                minTileHeight: 58,
                leading: const Icon(Icons.logout_rounded),
                title: const Text(
                  'Logout',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
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
        top: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: KeyedSubtree(
            key: ValueKey(selectedModule),
            child: _modulePage(selectedModule),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navIndex,
        onDestinationSelected: (index) {
          if (index < quick.length) {
            selectModule(quick[index].module);
          } else if (hasMore) {
            scaffoldKey.currentState?.openDrawer();
          }
        },
        destinations: [
          for (final item in quick)
            NavigationDestination(
              icon: Icon(moduleIcon(item.module)),
              selectedIcon: Icon(
                moduleIcon(item.module),
                color: AppColors.blue,
              ),
              label: _shortLabel(item),
              tooltip: item.label,
            ),
          if (hasMore)
            const NavigationDestination(
              icon: Icon(Icons.more_horiz_rounded),
              selectedIcon: Icon(
                Icons.more_horiz_rounded,
                color: AppColors.blue,
              ),
              label: 'More',
              tooltip: 'More portal pages',
            ),
        ],
      ),
    );
  }

  String _shortLabel(PortalItem item) {
    switch (item.module) {
      case 'department_activity':
        return 'Live';
      case 'manage_team':
        return appController.user?.role == 'hod'
            ? 'Staff'
            : appController.user?.role == 'staff'
                ? 'Students'
                : 'Manage';
      case 'live_activity':
        return 'Monitor';
      case 'portal_control':
        return 'Control';
      case 'departments':
        return 'Depts';
      case 'directory':
        return nextRoleLabel(appController.user!.role);
      case 'assign':
        return 'Assign';
      default:
        return item.label.length > 11
            ? item.label.substring(0, 11)
            : item.label;
    }
  }

  Widget _modulePage(String module) {
    switch (module) {
      case 'overview':
        return const OverviewPage();
      case 'directory':
        return const DirectoryPage();
      case 'department_activity':
        return const DepartmentActivityPage();
      case 'manage_team':
        return const TeamManagementPage();
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
