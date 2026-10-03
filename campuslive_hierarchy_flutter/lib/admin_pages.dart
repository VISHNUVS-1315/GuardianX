import 'package:flutter/material.dart';

import 'controller.dart';
import 'models.dart';
import 'role_pages.dart';
import 'ui_common.dart';

class AdminDepartmentsPage extends StatelessWidget {
  const AdminDepartmentsPage({super.key});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: appController,
        builder: (context, _) => RefreshIndicator(
          onRefresh: appController.loadDepartments,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              SectionHeader(
                title: 'Departments',
                subtitle:
                    'Create real departments and attach HOD, staff and students',
                action: FilledButton.icon(
                  onPressed: () => showCreateDepartment(context),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add'),
                ),
              ),
              const SizedBox(height: 14),
              if (appController.departments.isEmpty)
                const EmptyState(
                  icon: Icons.apartment_outlined,
                  title: 'No departments yet',
                  text:
                      'Add your college departments first. HOD, Staff and Student accounts can then be assigned to them.',
                )
              else
                for (final dept in appController.departments)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(14),
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFEEF2FF),
                        foregroundColor: AppColors.blue,
                        child: Text(
                          dept.code,
                          textAlign: TextAlign.center,
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
        ),
      );
}

Future<void> showCreateDepartment(BuildContext context) async {
  final name = TextEditingController();
  final code = TextEditingController();

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Add Department'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          formField(name, 'Department Name', Icons.apartment_rounded),
          const SizedBox(height: 10),
          formField(code, 'Department Code', Icons.tag_rounded),
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
              await appController.createDepartment(
                name: name.text,
                code: code.text,
              );
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
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
  String filter = 'all';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      users = await appController.loadAdminUsers();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final visible = users
        .where((u) => filter == 'all' || u.role == filter)
        .toList();

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          SectionHeader(
            title: 'College Users',
            subtitle:
                'Create actual Principal, HOD, Staff and Student accounts',
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
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final role in [
                  'all',
                  'principal',
                  'hod',
                  'staff',
                  'student'
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: ChoiceChip(
                      selected: filter == role,
                      label: Text(
                        role == 'all' ? 'All' : roleLabel(role),
                      ),
                      onSelected: (_) => setState(() => filter = role),
                    ),
                  ),
              ],
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
          else if (visible.isEmpty)
            const EmptyState(
              icon: Icons.group_add_outlined,
              title: 'No users in this role',
              text:
                  'Create users only from verified college records. No sample users are preloaded.',
            )
          else
            for (final person in visible)
              UserCard(person: person),
        ],
      ),
    );
  }
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
        'Enter name, email and password with at least 8 characters.',
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
      await appController.createUser(
        name: name.text,
        email: email.text,
        password: password.text,
        role: role,
        departmentId: needsDepartment ? departmentId : null,
        year: role == 'student' ? year.text : '',
        section: role == 'student' ? section.text : '',
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
              icon: Icons.verified_user_outlined,
              title: 'Verified college record only',
              text:
                  'The selected role decides what this account can monitor and who it can assign information to.',
            ),
            const SizedBox(height: 14),
            formField(name, 'Full Name', Icons.person_rounded),
            const SizedBox(height: 10),
            formField(email, 'Official Email', Icons.mail_outline_rounded),
            const SizedBox(height: 10),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Temporary Password (8+ characters)',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: role,
              decoration: const InputDecoration(
                labelText: 'Role',
                prefixIcon: Icon(Icons.security_rounded),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'principal',
                  child: Text('Principal'),
                ),
                DropdownMenuItem(
                  value: 'hod',
                  child: Text('HOD'),
                ),
                DropdownMenuItem(
                  value: 'staff',
                  child: Text('Staff'),
                ),
                DropdownMenuItem(
                  value: 'student',
                  child: Text('Student'),
                ),
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
                value: departmentId,
                decoration: const InputDecoration(
                  labelText: 'Department',
                  prefixIcon: Icon(Icons.apartment_rounded),
                ),
                items: appController.departments
                    .map(
                      (dept) => DropdownMenuItem(
                        value: dept.id,
                        child: Text(
                          dept.code + ' • ' + dept.name,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => departmentId = value),
              ),
            ],
            if (role == 'student') ...[
              const SizedBox(height: 10),
              formField(year, 'Year', Icons.calendar_view_month_rounded),
              const SizedBox(height: 10),
              formField(section, 'Section', Icons.view_column_rounded),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: saving ? null : save,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text(saving ? 'Creating...' : 'Create Account'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
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
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      items = await appController.loadRolePortal(role);
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> save() async {
    try {
      await appController.saveRolePortal(role, items);
      if (mounted) {
        showMessage(context, roleLabel(role) + ' portal saved.');
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  void move(int index, int delta) {
    final next = index + delta;
    if (next < 0 || next >= items.length) return;

    setState(() {
      final item = items.removeAt(index);
      items.insert(next, item);
    });
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const SectionHeader(
            title: 'Portal Control',
            subtitle:
                'Admin controls page visibility, labels and order for every role',
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: role,
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
              DropdownMenuItem(
                value: 'student',
                child: Text('Student'),
              ),
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
          else
            for (var i = 0; i < items.length; i++)
              Card(
                margin: const EdgeInsets.only(bottom: 9),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
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
                            onPressed:
                                i == 0 ? null : () => move(i, -1),
                            icon:
                                const Icon(Icons.keyboard_arrow_up_rounded),
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
          if (!loading) ...[
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
        animation: appController,
        builder: (context, _) => RefreshIndicator(
          onRefresh: appController.refreshAll,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const SectionHeader(
                title: 'Admin Monitoring',
                subtitle:
                    'Audit trail and full information/task chain across the college',
              ),
              const SizedBox(height: 14),
              const InfoBanner(
                icon: Icons.visibility_rounded,
                title: 'Monitor everything',
                text:
                    'Admin can see hierarchy activity and who sent what to whom. Role permissions still control who can create downstream assignments.',
              ),
              const SizedBox(height: 18),
              const Text(
                'Information / Task Chain',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              if (appController.chainItems.isEmpty)
                const EmptyState(
                  icon: Icons.account_tree_outlined,
                  title: 'No assignment chain yet',
                  text:
                      'Principal/HOD/Staff assignments will appear here in real time.',
                )
              else
                for (final item in appController.chainItems.take(100))
                  Card(
                    margin: const EdgeInsets.only(bottom: 9),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFEEF2FF),
                        foregroundColor: AppColors.blue,
                        child: Icon(
                          item.kind == 'task'
                              ? Icons.assignment_rounded
                              : Icons.campaign_rounded,
                        ),
                      ),
                      title: Text(
                        item.title,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      subtitle: Text(
                        item.senderName +
                            ' (' +
                            roleLabel(item.senderRole) +
                            ') → ' +
                            item.recipientName +
                            ' (' +
                            roleLabel(item.recipientRole) +
                            ')\n' +
                            item.status.toUpperCase(),
                      ),
                      isThreeLine: true,
                    ),
                  ),
              const SizedBox(height: 18),
              const Text(
                'Audit Log',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              if (appController.auditItems.isEmpty)
                const EmptyState(
                  icon: Icons.history_rounded,
                  title: 'No audit activity',
                  text:
                      'Account, department, assignment and portal-control actions are logged here.',
                )
              else
                for (final item in appController.auditItems.take(100))
                  Card(
                    margin: const EdgeInsets.only(bottom: 9),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFF2F4F8),
                        foregroundColor: AppColors.muted,
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
                            (item.detail.isEmpty
                                ? ''
                                : ' • ' + item.detail),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      );
}
