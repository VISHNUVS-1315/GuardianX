import 'package:flutter/material.dart';

import 'controller.dart';
import 'models.dart';
import 'ui_common.dart';

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: appController,
        builder: (context, _) {
          final user = appController.user!;
          final d = appController.dashboard;
          final cards = <Widget>[];

          if (user.role == 'admin') {
            final counts = (d['counts'] as Map?) ?? {};
            cards.addAll([
              metricCard('Principal', (counts['principal'] ?? 0).toString()),
              metricCard('HODs', (counts['hod'] ?? 0).toString()),
              metricCard('Staff', (counts['staff'] ?? 0).toString()),
              metricCard('Students', (counts['student'] ?? 0).toString()),
              metricCard('Departments', (d['departments'] ?? 0).toString()),
              metricCard('Pending', (d['pending_assignments'] ?? 0).toString()),
            ]);
          } else if (user.role == 'principal') {
            cards.addAll([
              metricCard('HODs', (d['hod_count'] ?? 0).toString()),
              metricCard('Unread', (d['unread'] ?? 0).toString()),
            ]);
          } else if (user.role == 'hod') {
            cards.addAll([
              metricCard('Staff', (d['staff_count'] ?? 0).toString()),
              metricCard('Unread', (d['unread'] ?? 0).toString()),
            ]);
          } else if (user.role == 'staff') {
            cards.addAll([
              metricCard('Students', (d['student_count'] ?? 0).toString()),
              metricCard('Unread', (d['unread'] ?? 0).toString()),
            ]);
          } else {
            cards.add(metricCard('My Updates', (d['unread'] ?? 0).toString()));
          }

          return RefreshIndicator(
            onRefresh: appController.refreshAll,
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                SectionHeader(
                  title: roleLabel(user.role) + ' Overview',
                  subtitle: hierarchyText(user.role),
                ),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.6,
                  children: cards,
                ),
                const SizedBox(height: 16),
                if (!appController.online)
                  InfoBanner(
                    icon: Icons.cloud_off_rounded,
                    title: 'Backend offline',
                    text: appController.lastError ??
                        'Could not reach the real-time backend.',
                    color: AppColors.orange,
                  ),
              ],
            ),
          );
        },
      );

  Widget metricCard(String title, String value) => Card(
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
      );
}

String hierarchyText(String role) {
  switch (role) {
    case 'admin':
      return 'Monitor the entire college and control pages for every role.';
    case 'principal':
      return 'Monitor HODs and send information only to HOD accounts.';
    case 'hod':
      return 'Monitor staff in your department and assign work to them.';
    case 'staff':
      return 'Monitor students in your department and assign work to them.';
    case 'student':
      return 'See only information and tasks assigned to your account.';
    default:
      return '';
  }
}

class DirectoryPage extends StatelessWidget {
  const DirectoryPage({super.key});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: appController,
        builder: (context, _) => RefreshIndicator(
          onRefresh: appController.refreshAll,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              SectionHeader(
                title: nextRoleLabel(appController.user!.role),
                subtitle: 'Only users allowed by your role hierarchy',
              ),
              const SizedBox(height: 14),
              if (appController.directory.isEmpty)
                const EmptyState(
                  icon: Icons.groups_outlined,
                  title: 'No users yet',
                  text:
                      'College Admin must create the real hierarchy accounts first.',
                )
              else
                for (final person in appController.directory)
                  UserCard(person: person),
            ],
          ),
        ),
      );
}

class UserCard extends StatelessWidget {
  const UserCard({
    super.key,
    required this.person,
    this.trailing,
  });

  final DirectoryUser person;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          contentPadding: const EdgeInsets.all(13),
          leading: CircleAvatar(
            backgroundColor: const Color(0xFFEEF2FF),
            foregroundColor: AppColors.blue,
            child: Icon(roleIcon(person.role), size: 19),
          ),
          title: Text(
            person.name,
            style: const TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w900,
            ),
          ),
          subtitle: Text(
            [
              roleLabel(person.role),
              if (person.department != null &&
                  person.department!.isNotEmpty)
                person.department!,
              if (person.year.isNotEmpty) 'Year ' + person.year,
              if (person.section.isNotEmpty) 'Sec ' + person.section,
              person.email,
            ].join(' • '),
          ),
          isThreeLine: true,
          trailing: trailing,
        ),
      );
}

class InboxPage extends StatelessWidget {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: appController,
        builder: (context, _) => RefreshIndicator(
          onRefresh: appController.refreshAll,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const SectionHeader(
                title: 'Inbox',
                subtitle: 'Live information and tasks sent to you',
              ),
              const SizedBox(height: 14),
              if (appController.inbox.isEmpty)
                const EmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'Inbox is empty',
                  text:
                      'Updates from the role above you will appear here in real time.',
                )
              else
                for (final item in appController.inbox)
                  InboxCard(item: item),
            ],
          ),
        ),
      );
}

class InboxCard extends StatelessWidget {
  const InboxCard({super.key, required this.item});
  final InboxItem item;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () async {
            if (item.status == 'new') {
              try {
                await appController.markAssignment(item.id, 'read');
              } catch (_) {}
            }
            if (!context.mounted) return;
            await showModalBottomSheet<void>(
              context: context,
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
                      Text(item.body),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: item.status == 'done'
                            ? null
                            : () async {
                                try {
                                  await appController.markAssignment(
                                    item.id,
                                    'done',
                                  );
                                  if (sheetContext.mounted) {
                                    Navigator.pop(sheetContext);
                                  }
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
                          item.status == 'done'
                              ? 'Completed'
                              : 'Mark Done',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
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

class AssignPage extends StatefulWidget {
  const AssignPage({super.key});

  @override
  State<AssignPage> createState() => _AssignPageState();
}

class _AssignPageState extends State<AssignPage> {
  final title = TextEditingController();
  final body = TextEditingController();
  final Set<int> selected = {};
  String kind = 'information';

  Future<void> send() async {
    if (selected.isEmpty) {
      showMessage(context, 'Select at least one recipient.', error: true);
      return;
    }
    if (title.text.trim().isEmpty || body.text.trim().isEmpty) {
      showMessage(context, 'Enter title and information.', error: true);
      return;
    }

    try {
      await appController.sendAssignment(
        targetUserIds: selected.toList(),
        title: title.text,
        body: body.text,
        kind: kind,
      );
      selected.clear();
      title.clear();
      body.clear();
      if (mounted) {
        setState(() {});
        showMessage(context, 'Sent in real time.');
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(18),
        children: [
          SectionHeader(
            title: 'Assign to ' +
                nextRoleLabel(appController.user!.role),
            subtitle:
                'Recipients are automatically restricted by the hierarchy',
          ),
          const SizedBox(height: 14),
          if (appController.directory.isEmpty)
            const EmptyState(
              icon: Icons.person_add_alt_rounded,
              title: 'No eligible recipients',
              text:
                  'College Admin must create the correct downstream accounts first.',
            )
          else ...[
            Card(
              child: Column(
                children: [
                  CheckboxListTile(
                    value:
                        selected.length == appController.directory.length,
                    onChanged: (value) {
                      setState(() {
                        selected.clear();
                        if (value == true) {
                          selected.addAll(
                            appController.directory.map((e) => e.id),
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
                  for (final person in appController.directory)
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
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: kind,
              decoration: const InputDecoration(labelText: 'Type'),
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
              onChanged: (value) =>
                  setState(() => kind = value ?? kind),
            ),
            const SizedBox(height: 10),
            formField(title, 'Title', Icons.title_rounded),
            const SizedBox(height: 10),
            TextField(
              controller: body,
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
            ),
          ],
        ],
      );
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = appController.user!;
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const SectionHeader(
          title: 'My Profile',
          subtitle: 'Role and college context',
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
                const Divider(height: 28),
                profileRow('Role', roleLabel(user.role)),
                profileRow('College', user.collegeName),
                profileRow('College Code', user.collegeCode),
                if (user.department != null)
                  profileRow('Department', user.department!),
                if (user.year.isNotEmpty)
                  profileRow('Year', user.year),
                if (user.section.isNotEmpty)
                  profileRow('Section', user.section),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget profileRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: AppColors.muted),
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
}

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
                'This page is enabled by Admin but has no custom screen yet.',
          ),
        ],
      );
}
