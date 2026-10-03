import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFFF5F7FB);
  static const navy = Color(0xFF0B1734);
  static const blue = Color(0xFF315EFB);
  static const cyan = Color(0xFF16B5E8);
  static const green = Color(0xFF22B573);
  static const orange = Color(0xFFFFA31A);
  static const red = Color(0xFFE74C3C);
  static const purple = Color(0xFF725BFF);
  static const muted = Color(0xFF6D7890);
  static const line = Color(0xFFE6EAF2);
}

String roleLabel(String role) {
  switch (role) {
    case 'admin':
      return 'College Admin';
    case 'principal':
      return 'Principal';
    case 'hod':
      return 'HOD';
    case 'staff':
      return 'Staff';
    case 'student':
      return 'Student';
    default:
      return role;
  }
}

String nextRoleLabel(String role) {
  switch (role) {
    case 'admin':
      return 'College Users';
    case 'principal':
      return 'HODs';
    case 'hod':
      return 'Staff';
    case 'staff':
      return 'Students';
    default:
      return 'Updates';
  }
}

IconData roleIcon(String role) {
  switch (role) {
    case 'admin':
      return Icons.admin_panel_settings_rounded;
    case 'principal':
      return Icons.account_balance_rounded;
    case 'hod':
      return Icons.apartment_rounded;
    case 'staff':
      return Icons.badge_rounded;
    case 'student':
      return Icons.school_rounded;
    default:
      return Icons.person_rounded;
  }
}

IconData moduleIcon(String module) {
  switch (module) {
    case 'overview':
      return Icons.dashboard_rounded;
    case 'directory':
      return Icons.groups_rounded;
    case 'inbox':
      return Icons.inbox_rounded;
    case 'assign':
      return Icons.assignment_add_rounded;
    case 'users':
      return Icons.manage_accounts_rounded;
    case 'departments':
      return Icons.apartment_rounded;
    case 'portal_control':
      return Icons.dashboard_customize_rounded;
    case 'live_activity':
      return Icons.monitor_heart_rounded;
    case 'profile':
      return Icons.person_rounded;
    default:
      return Icons.grid_view_rounded;
  }
}

void showMessage(
  BuildContext context,
  String message, {
  bool error = false,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.red : AppColors.navy,
    ),
  );
}

Widget formField(
  TextEditingController controller,
  String label,
  IconData icon,
) =>
    TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
    );

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (action != null) action!,
        ],
      );
}

class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
    this.color = AppColors.blue,
  });

  final IconData icon;
  final String title;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: color.withOpacity(.08),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    text,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 10.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFFEEF2FF),
                foregroundColor: AppColors.blue,
                child: Icon(icon, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
}
