import 'package:flutter/material.dart';

import 'controller.dart';
import 'ui_common.dart';

class RoleHomePage extends StatelessWidget {
  const RoleHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = appController.user!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          user.collegeName,
          style: const TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            onPressed: appController.refreshAll,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            roleLabel(user.role) + ' Portal',
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(user.name),
          const SizedBox(height: 18),
          for (final item in appController.portal)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: Icon(moduleIcon(item.module)),
                title: Text(item.label),
                subtitle: Text(item.module),
              ),
            ),
        ],
      ),
    );
  }
}
