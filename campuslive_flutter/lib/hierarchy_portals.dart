import 'dart:async';

import 'package:flutter/material.dart';

import 'hierarchy_common.dart';
import 'hierarchy_controller.dart';
import 'hierarchy_models.dart';

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
    unawaited(hierarchyController.refreshAll());
  }

  List<PortalItem> get enabledItems {
    final items = hierarchyController.portal.where((e) => e.enabled).toList();
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
    final user = hierarchyController.user!;
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
              roleLabel(user.role) + ' Portal',
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
                backgroundColor: hierarchyController.online
                    ? const Color(0xFFE8F8F0)
                    : const Color(0xFFFFF1E5),
                label: Text(
                  hierarchyController.online ? 'LIVE' : 'OFFLINE',
                  style: TextStyle(
                    color: hierarchyController.online
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
            onPressed: hierarchyController.refreshAll,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(color: AppColors.navy),
                accountName: Text(
                  user.name,
                  style: const TextStyle(fontWeight: FontWeight.w900),
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
                        selectedTileColor: const Color(0xFFEEF2FF),
                        leading: Icon(moduleIcon(item.module)),
                        title: Text(item.label),
                        onTap: () {
                          setState(() => selectedModule = item.module);
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
                  hierarchyController.logout();
                },
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(child: modulePage(selectedModule)),
    );
  }

  Widget modulePage(String module) {
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

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: hierarchyController,
        builder: (context, _) {
          final user = hierarchyController.user!;
          final data = hierarchyController.dashboard;
          return RefreshIndicator(
            onRefresh: hierarchyController.refreshAll,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.navy, Color(0xFF1B3979)],
                    ),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 29,
                        backgroundColor: Colors.white12,
                        foregroundColor: Colors.white,
                        child: Icon(roleIcon(user.role), size: 29),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              roleLabel(user.role),
                              style: const TextStyle(
                                color: Color(0xFF8EB0FF),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (user.department != null &&
                                user.department!.isNotEmpty)
                              Text(
                                user.department!,
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 10.5,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (user.role == 'admin')
                  _AdminOverview(data: data)
                else if (user.role == 'principal')
                  _PrincipalOverview(data: data)
                else if (user.role == 'hod')
                  _HodOverview(data: data, department: user.department)
                else if (user.role == 'staff')
                  _StaffOverview(data: data)
                else
                  _StudentOverview(data: data),
                if (hierarchyController.lastError != null) ...[
                  const SizedBox(height: 16),
                  InfoBanner(
                    icon: Icons.cloud_off_rounded,
                    title: 'Connection status',
                    text: hierarchyController.lastError!,
                    color: AppColors.orange,
                  ),
                ],
              ],
            ),
          );
        },
      );
}

class _AdminOverview extends StatelessWidget {
  const _AdminOverview({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final counts = (data['counts'] as Map?) ?? {};
    return Column(
      children: [
        _MetricGrid(
          items: [
            _Metric('Principal', (counts['principal'] ?? 0).toString(),
                Icons.account_balance_rounded, AppColors.purple),
            _Metric('HODs', (counts['hod'] ?? 0).toString(),
                Icons.apartment_rounded, AppColors.blue),
            _Metric('Staff', (counts['staff'] ?? 0).toString(),
                Icons.badge_rounded, AppColors.green),
            _Metric('Students', (counts['student'] ?? 0).toString(),
                Icons.school_rounded, AppColors.cyan),
            _Metric('Departments', (data['departments'] ?? 0).toString(),
                Icons.account_tree_rounded, AppColors.orange),
            _Metric('Pending', (data['pending_assignments'] ?? 0).toString(),
                Icons.pending_actions_rounded, AppColors.red),
          ],
        ),
        const SizedBox(height: 18),
        const InfoBanner(
          icon: Icons.tune_rounded,
          title: 'Admin controls all portals',
          text:
              'Admin creates real users and departments, monitors college activity, and controls which pages each role can see.',
        ),
      ],
    );
  }
}

class _PrincipalOverview extends StatelessWidget {
  const _PrincipalOverview({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          _MetricGrid(
            items: [
              _Metric('HODs', (data['hod_count'] ?? 0).toString(),
                  Icons.apartment_rounded, AppColors.blue),
              _Metric('Unread', (data['unread'] ?? 0).toString(),
                  Icons.mark_email_unread_rounded, AppColors.orange),
            ],
          ),
          const SizedBox(height: 18),
          const InfoBanner(
            icon: Icons.account_tree_rounded,
            title: 'Principal → HOD',
            text:
                'Principal monitors HODs and can send information or tasks only to HOD accounts.',
          ),
        ],
      );
}

class _HodOverview extends StatelessWidget {
  const _HodOverview({required this.data, this.department});
  final Map<String, dynamic> data;
  final String? department;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          _MetricGrid(
            items: [
              _Metric('Staff', (data['staff_count'] ?? 0).toString(),
                  Icons.badge_rounded, AppColors.green),
              _Metric('Unread', (data['unread'] ?? 0).toString(),
                  Icons.mark_email_unread_rounded, AppColors.orange),
            ],
          ),
          const SizedBox(height: 18),
          InfoBanner(
            icon: Icons.apartment_rounded,
            title: department ?? 'Department',
            text:
                'HOD monitors only staff inside the assigned department and can assign work only to those staff.',
          ),
        ],
      );
}

class _StaffOverview extends StatelessWidget {
  const _StaffOverview({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          _MetricGrid(
            items: [
              _Metric('Students', (data['student_count'] ?? 0).toString(),
                  Icons.school_rounded, AppColors.cyan),
              _Metric('Unread', (data['unread'] ?? 0).toString(),
                  Icons.mark_email_unread_rounded, AppColors.orange),
            ],
          ),
          const SizedBox(height: 18),
          const InfoBanner(
            icon: Icons.assignment_turned_in_rounded,
            title: 'Staff → Student',
            text:
                'Staff can send notices, academic information and tasks only to students in their own department.',
          ),
        ],
      );
}

class _StudentOverview extends StatelessWidget {
  const _StudentOverview({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          _MetricGrid(
            items: [
              _Metric('New Updates', (data['unread'] ?? 0).toString(),
                  Icons.notifications_active_rounded, AppColors.blue),
            ],
          ),
          const SizedBox(height: 18),
          const InfoBanner(
            icon: Icons.lock_person_rounded,
            title: 'Personal student portal',
            text:
                'Student sees only information and tasks assigned to that account. Other students data is not shown.',
          ),
        ],
      );
}

class _Metric {
  const _Metric(this.label, this.value, this.icon, this.color);
  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.items});
  final List<_Metric> items;

  @override
  Widget build(BuildContext context) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.55,
        ),
        itemBuilder: (_, i) {
          final item = items[i];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: item.color.withOpacity(.10),
                    foregroundColor: item.color,
                    child: Icon(item.icon, size: 19),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.value,
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          item.label,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
}

class DirectoryPage extends StatelessWidget {
  const DirectoryPage({super.key});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: hierarchyController,
        builder: (context, _) {
          final role = hierarchyController.user!.role;
          return RefreshIndicator(
            onRefresh: hierarchyController.refreshAll,
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                SectionHeader(
                  title: nextRoleLabel(role),
                  subtitle: role == 'admin'
                      ? 'All active users in this college'
                      : 'Only users this role is allowed to monitor',
                ),
                const SizedBox(height: 14),
                if (hierarchyController.directory.isEmpty)
                  const EmptyState(
                    icon: Icons.groups_outlined,
                    title: 'No users yet',
                    text:
                        'College Admin must create the real hierarchy accounts first.',
                  )
                else
                  for (final person in hierarchyController.directory)
                    UserCard(person: person),
              ],
            ),
          );
        },
      );
}

class InboxPage extends StatelessWidget {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: hierarchyController,
        builder: (context, _) => RefreshIndicator(
          onRefresh: hierarchyController.refreshAll,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const SectionHeader(
                title: 'Inbox',
                subtitle: 'Live information and assignments sent to you',
              ),
              const SizedBox(height: 14),
              if (hierarchyController.inbox.isEmpty)
                const EmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'Inbox is empty',
                  text:
                      'When your parent role sends information or a task, it appears here in real time.',
                )
              else
                for (final item in hierarchyController.inbox)
                  _InboxCard(item: item),
            ],
          ),
        ),
      );
}

class _InboxCard extends StatelessWidget {
  const _InboxCard({required this.item});
  final InboxItem item;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _showInboxItem(context, item),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: item.status == 'new'
                      ? const Color(0xFFEEF2FF)
                      : const Color(0xFFF2F4F8),
                  foregroundColor: item.status == 'new'
                      ? AppColors.blue
                      : AppColors.muted,
                  child: Icon(
                    item.kind == 'task'
                        ? Icons.assignment_rounded
                        : Icons.campaign_rounded,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        'From ' +
                            item.senderName +
                            ' • ' +
                            roleLabel(item.senderRole) +
                            ' • ' +
                            item.status.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.blue,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

Future<void> _showInboxItem(BuildContext context, InboxItem item) async {
  if (item.status == 'new') {
    try {
      await hierarchyController.markAssignment(item.id, 'read');
    } catch (_) {}
  }
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.title,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'From ' +
                  item.senderName +
                  ' • ' +
                  roleLabel(item.senderRole),
              style: const TextStyle(
                color: AppColors.blue,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              item.body,
              style: const TextStyle(
                color: AppColors.navy,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: item.status == 'done'
                  ? null
                  : () async {
                      try {
                        await hierarchyController.markAssignment(
                          item.id,
                          'done',
                        );
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                      } catch (e) {
                        if (sheetContext.mounted) {
                          showMessage(
                            sheetContext,
                            e.toString(),
                            error: true,
                          );
                        }
                      }
                    },
              icon: const Icon(Icons.check_circle_rounded),
              label: Text(
                item.status == 'done' ? 'Completed' : 'Mark Done',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class AssignPage extends StatefulWidget {
  const AssignPage({super.key});

  @override
  State<AssignPage> createState() => _AssignPageState();
}

class _AssignPageState extends State<AssignPage> {
  final titleController = TextEditingController();
  final bodyController = TextEditingController();
  final Set<int> selected = {};
  String kind = 'information';

  Future<void> send() async {
    if (selected.isEmpty) {
      showMessage(context, 'Select at least one recipient.', error: true);
      return;
    }
    if (titleController.text.trim().isEmpty ||
        bodyController.text.trim().isEmpty) {
      showMessage(context, 'Enter title and message.', error: true);
      return;
    }

    try {
      await hierarchyController.sendAssignment(
        targetUserIds: selected.toList(),
        title: titleController.text,
        body: bodyController.text,
        kind: kind,
      );
      selected.clear();
      titleController.clear();
      bodyController.clear();
      if (mounted) {
        setState(() {});
        showMessage(context, 'Sent in real time.');
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = hierarchyController.user!.role;
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        SectionHeader(
          title: 'Assign to ' + nextRoleLabel(role),
          subtitle: role == 'admin'
              ? 'Admin can send to any active user in this college.'
              : 'Recipients are restricted by hierarchy and department.',
        ),
        const SizedBox(height: 14),
        if (hierarchyController.directory.isEmpty)
          const EmptyState(
            icon: Icons.person_add_alt_rounded,
            title: 'No eligible recipients',
            text:
                'Accounts must first be created by the College Admin.',
          )
        else ...[
          Card(
            child: Column(
              children: [
                CheckboxListTile(
                  value:
                      selected.length == hierarchyController.directory.length,
                  onChanged: (value) {
                    setState(() {
                      selected.clear();
                      if (value == true) {
                        selected.addAll(
                          hierarchyController.directory.map((e) => e.id),
                        );
                      }
                    });
                  },
                  title: const Text(
                    'Select all eligible',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const Divider(height: 1),
                for (final person in hierarchyController.directory)
                  CheckboxListTile(
                    value: selected.contains(person.id),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          selected.add(person.id);
                        } else {
                          selected.remove(person.id);
                        }
                      });
                    },
                    secondary: Icon(roleIcon(person.role)),
                    title: Text(person.name),
                    subtitle: Text(
                      roleLabel(person.role) +
                          (person.department == null
                              ? ''
                              : ' • ' + person.department!),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: kind,
            decoration: const InputDecoration(
              labelText: 'Type',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: const [
              DropdownMenuItem(
                value: 'information',
                child: Text('Information / Notice'),
              ),
              DropdownMenuItem(
                value: 'task',
                child: Text('Task / Assignment'),
              ),
            ],
            onChanged: (value) => setState(() => kind = value ?? kind),
          ),
          const SizedBox(height: 10),
          appTextField(
            titleController,
            'Title',
            Icons.title_rounded,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: bodyController,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Information / Instructions',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: send,
            icon: const Icon(Icons.send_rounded),
            label: Text(
              'Send to ' + selected.length.toString() + ' recipient(s)',
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: AppColors.blue,
            ),
          ),
        ],
      ],
    );
  }
}

class AdminDepartmentsPage extends StatelessWidget {
  const AdminDepartmentsPage({super.key});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: hierarchyController,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(18),
          children: [
            SectionHeader(
              title: 'Departments',
              subtitle: hierarchyController.departments.length.toString() +
                  ' departments configured',
              action: FilledButton.icon(
                onPressed: () => _showCreateDepartment(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add'),
              ),
            ),
            const SizedBox(height: 14),
            if (hierarchyController.departments.isEmpty)
              const EmptyState(
                icon: Icons.apartment_outlined,
                title: 'No departments',
                text:
                    'Add your real college departments first. Then create HOD, staff and student accounts for those departments.',
              )
            else
              for (final dept in hierarchyController.departments)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(14),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFEEF2FF),
                      foregroundColor: AppColors.blue,
                      child: Text(
                        dept.code,
                        style: const TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    title: Text(
                      dept.name,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    subtitle: Text(
                      'HOD: ' +
                          (dept.hodName ?? 'Not assigned') +
                          '\n' +
                          dept.staffCount.toString() +
                          ' staff • ' +
                          dept.studentCount.toString() +
                          ' students',
                    ),
                    isThreeLine: true,
                  ),
                ),
          ],
        ),
      );
}

Future<void> _showCreateDepartment(BuildContext context) async {
  final name = TextEditingController();
  final code = TextEditingController();

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Add Department'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          appTextField(name, 'Department Name', Icons.apartment_rounded),
          const SizedBox(height: 10),
          appTextField(code, 'Code (e.g. MECH)', Icons.tag_rounded),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            if (name.text.trim().isEmpty || code.text.trim().isEmpty) {
              showMessage(
                dialogContext,
                'Enter department name and code.',
                error: true,
              );
              return;
            }
            try {
              await hierarchyController.createDepartment(
                name: name.text,
                code: code.text,
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            } catch (e) {
              if (dialogContext.mounted) {
                showMessage(dialogContext, e.toString(), error: true);
              }
            }
          },
          child: const Text('Create'),
        ),
      ],
    ),
  );
}

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  List<DirectoryUser> users = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      users = await hierarchyController.loadAllAdminUsers();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            SectionHeader(
              title: 'Users',
              subtitle:
                  'Principal, HOD, Staff and Student accounts for this college',
              action: FilledButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreateUserPage(),
                    ),
                  );
                  await load();
                },
                icon: const Icon(Icons.person_add_rounded),
                label: const Text('Create'),
              ),
            ),
            const SizedBox(height: 14),
            if (loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (users.isEmpty)
              const EmptyState(
                icon: Icons.group_add_outlined,
                title: 'No hierarchy users',
                text:
                    'Create Principal first, then HODs, Staff and Students using real college records.',
              )
            else
              for (final person in users)
                UserCard(person: person),
          ],
        ),
      );
}

class CreateUserPage extends StatefulWidget {
  const CreateUserPage({super.key});

  @override
  State<CreateUserPage> createState() => _CreateUserPageState();
}

class _CreateUserPageState extends State<CreateUserPage> {
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final year = TextEditingController();
  final section = TextEditingController();

  String role = 'principal';
  int? departmentId;
  bool saving = false;

  bool get needsDepartment =>
      role == 'hod' || role == 'staff' || role == 'student';

  Future<void> save() async {
    if (name.text.trim().isEmpty ||
        email.text.trim().isEmpty ||
        password.text.length < 8) {
      showMessage(
        context,
        'Enter name, email and password (8+ characters).',
        error: true,
      );
      return;
    }
    if (needsDepartment && departmentId == null) {
      showMessage(context, 'Select a department.', error: true);
      return;
    }

    setState(() => saving = true);
    try {
      await hierarchyController.createUser(
        name: name.text,
        email: email.text,
        password: password.text,
        role: role,
        departmentId: needsDepartment ? departmentId : null,
        year: year.text,
        section: section.text,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text(
            'Create Real User',
            style: TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const InfoBanner(
              icon: Icons.info_outline_rounded,
              title: 'No dummy profile',
              text:
                  'Create this account only from verified college records. Role permissions are enforced by the backend.',
            ),
            const SizedBox(height: 14),
            appTextField(name, 'Full Name', Icons.person_rounded),
            const SizedBox(height: 10),
            appTextField(
              email,
              'Official Email',
              Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 10),
            appTextField(
              password,
              'Temporary Password (8+)',
              Icons.lock_outline_rounded,
              obscure: true,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: role,
              decoration: const InputDecoration(
                labelText: 'Role',
                prefixIcon: Icon(Icons.security_rounded),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'principal',
                  child: Text('Principal'),
                ),
                DropdownMenuItem(value: 'hod', child: Text('HOD')),
                DropdownMenuItem(value: 'staff', child: Text('Staff')),
                DropdownMenuItem(value: 'student', child: Text('Student')),
              ],
              onChanged: (value) {
                setState(() {
                  role = value ?? role;
                  if (!needsDepartment) departmentId = null;
                });
              },
            ),
            if (needsDepartment) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: departmentId,
                decoration: const InputDecoration(
                  labelText: 'Department',
                  prefixIcon: Icon(Icons.apartment_rounded),
                ),
                items: hierarchyController.departments
                    .map(
                      (dept) => DropdownMenuItem(
                        value: dept.id,
                        child: Text(dept.code + ' • ' + dept.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => departmentId = value),
              ),
            ],
            if (role == 'student') ...[
              const SizedBox(height: 10),
              appTextField(
                year,
                'Year',
                Icons.calendar_view_month_rounded,
              ),
              const SizedBox(height: 10),
              appTextField(section, 'Section', Icons.view_column_rounded),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: saving ? null : save,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Create Account'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: AppColors.blue,
              ),
            ),
          ],
        ),
      );
}

class PortalControlPage extends StatefulWidget {
  const PortalControlPage({super.key});

  @override
  State<PortalControlPage> createState() => _PortalControlPageState();
}

class _PortalControlPageState extends State<PortalControlPage> {
  String role = 'student';
  List<PortalItem> items = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      items = await hierarchyController.loadPortalRole(role);
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> save() async {
    try {
      await hierarchyController.savePortalRole(role, items);
      if (mounted) {
        showMessage(context, roleLabel(role) + ' portal saved.');
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  void move(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= items.length) return;
    setState(() {
      final item = items.removeAt(index);
      items.insert(target, item);
    });
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const SectionHeader(
            title: 'Portal Control',
            subtitle:
                'Admin controls page visibility, label and order for every role',
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: role,
            decoration: const InputDecoration(
              labelText: 'Configure Role',
              prefixIcon: Icon(Icons.manage_accounts_rounded),
            ),
            items: const [
              DropdownMenuItem(value: 'admin', child: Text('Admin')),
              DropdownMenuItem(
                value: 'principal',
                child: Text('Principal'),
              ),
              DropdownMenuItem(value: 'hod', child: Text('HOD')),
              DropdownMenuItem(value: 'staff', child: Text('Staff')),
              DropdownMenuItem(value: 'student', child: Text('Student')),
            ],
            onChanged: (value) async {
              if (value == null) return;
              setState(() => role = value);
              await load();
            },
          ),
          const SizedBox(height: 14),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: CircularProgressIndicator(),
              ),
            )
          else ...[
            for (var i = 0; i < items.length; i++)
              Card(
                margin: const EdgeInsets.only(bottom: 9),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                  child: Row(
                    children: [
                      Switch(
                        value: items[i].enabled,
                        onChanged: (value) =>
                            setState(() => items[i].enabled = value),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: TextFormField(
                          initialValue: items[i].label,
                          onChanged: (value) => items[i].label = value,
                          decoration: InputDecoration(
                            labelText: items[i].module,
                            filled: false,
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          IconButton(
                            onPressed: i == 0 ? null : () => move(i, -1),
                            icon: const Icon(
                              Icons.keyboard_arrow_up_rounded,
                            ),
                          ),
                          IconButton(
                            onPressed: i == items.length - 1
                                ? null
                                : () => move(i, 1),
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: save,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Save Portal Layout'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ],
      );
}

class LiveActivityPage extends StatelessWidget {
  const LiveActivityPage({super.key});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: hierarchyController,
        builder: (context, _) => RefreshIndicator(
          onRefresh: hierarchyController.loadAudit,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const SectionHeader(
                title: 'Live Activity',
                subtitle:
                    'Admin audit trail for hierarchy and portal changes',
              ),
              const SizedBox(height: 14),
              if (hierarchyController.auditItems.isEmpty)
                const EmptyState(
                  icon: Icons.history_rounded,
                  title: 'No activity yet',
                  text:
                      'Real actions such as account creation, department creation and assignments will appear here.',
                )
              else
                for (final item in hierarchyController.auditItems)
                  Card(
                    margin: const EdgeInsets.only(bottom: 9),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFEEF2FF),
                        foregroundColor: AppColors.blue,
                        child: Icon(Icons.history_rounded),
                      ),
                      title: Text(
                        item.action,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      subtitle: Text(
                        item.actor +
                            ' • ' +
                            item.detail +
                            '\n' +
                            item.createdAt,
                      ),
                      isThreeLine: true,
                    ),
                  ),
            ],
          ),
        ),
      );
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = hierarchyController.user!;
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const SectionHeader(
          title: 'My Profile',
          subtitle: 'Account context provided by your college',
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: const Color(0xFFEEF2FF),
                  foregroundColor: AppColors.blue,
                  child: Icon(roleIcon(user.role), size: 32),
                ),
                const SizedBox(height: 12),
                Text(
                  user.name,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  user.email,
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                const Divider(color: AppColors.line),
                _profileRow('Role', roleLabel(user.role)),
                _profileRow('College', user.collegeName),
                _profileRow('College Code', user.collegeCode),
                if (user.department != null)
                  _profileRow('Department', user.department!),
                if (user.year.isNotEmpty)
                  _profileRow('Year', user.year),
                if (user.section.isNotEmpty)
                  _profileRow('Section', user.section),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Widget _profileRow(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );

class EmptyModulePage extends StatelessWidget {
  const EmptyModulePage({super.key, required this.module});
  final String module;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(18),
        children: [
          EmptyState(
            icon: Icons.extension_rounded,
            title: module,
            text:
                'This module is enabled by Admin but does not have a custom screen yet.',
          ),
        ],
      );
}
