import 'package:flutter/material.dart';

import 'controller.dart';
import 'ui_common.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final college = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  bool obscure = true;

  Future<void> submit() async {
    if (college.text.trim().isEmpty ||
        email.text.trim().isEmpty ||
        password.text.isEmpty) {
      showMessage(
        context,
        'Enter college code, email and password.',
        error: true,
      );
      return;
    }

    try {
      await appController.login(
        collegeCode: college.text,
        email: email.text,
        password: password.text,
      );
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.navy,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  children: [
                    Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.blue, AppColors.cyan],
                        ),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: const Icon(
                        Icons.account_tree_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'CampusLive',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Admin → Principal → HOD → Staff → Student',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60),
                    ),
                    const SizedBox(height: 26),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            formField(
                              college,
                              'College Code',
                              Icons.domain_rounded,
                            ),
                            const SizedBox(height: 12),
                            formField(
                              email,
                              'Official Email',
                              Icons.mail_outline_rounded,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: password,
                              obscureText: obscure,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon:
                                    const Icon(Icons.lock_outline_rounded),
                                suffixIcon: IconButton(
                                  onPressed: () =>
                                      setState(() => obscure = !obscure),
                                  icon: Icon(
                                    obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            FilledButton(
                              onPressed:
                                  appController.loading ? null : submit,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(52),
                                backgroundColor: AppColors.blue,
                              ),
                              child: appController.loading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Login to My Portal'),
                            ),
                            const SizedBox(height: 10),
                            TextButton.icon(
                              onPressed: appController.loading
                                  ? null
                                  : () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const SetupCollegePage(),
                                        ),
                                      ),
                              icon: const Icon(Icons.add_business_rounded),
                              label: const Text(
                                'First time? Create College Admin',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'No demo accounts are preloaded. College Admin creates the real hierarchy.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class SetupCollegePage extends StatefulWidget {
  const SetupCollegePage({super.key});

  @override
  State<SetupCollegePage> createState() => _SetupCollegePageState();
}

class _SetupCollegePageState extends State<SetupCollegePage> {
  final collegeName = TextEditingController();
  final collegeCode = TextEditingController();
  final adminName = TextEditingController();
  final adminEmail = TextEditingController();
  final password = TextEditingController();

  Future<void> create() async {
    if ([collegeName, collegeCode, adminName, adminEmail, password]
        .any((controller) => controller.text.trim().isEmpty)) {
      showMessage(context, 'Fill all fields.', error: true);
      return;
    }

    try {
      await appController.setupCollege(
        collegeName: collegeName.text,
        collegeCode: collegeCode.text,
        adminName: adminName.text,
        adminEmail: adminEmail.text,
        adminPassword: password.text,
      );
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text(
            'Create College',
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
              title: 'Creates the first College Admin',
              text:
                  'Then Admin creates real Principal, Departments, HOD, Staff and Student accounts. No fake users are generated.',
            ),
            const SizedBox(height: 16),
            formField(
              collegeName,
              'Official College Name',
              Icons.school_rounded,
            ),
            const SizedBox(height: 10),
            formField(
              collegeCode,
              'Unique College Code',
              Icons.domain_rounded,
            ),
            const SizedBox(height: 10),
            formField(
              adminName,
              'Admin Name',
              Icons.person_rounded,
            ),
            const SizedBox(height: 10),
            formField(
              adminEmail,
              'Admin Email',
              Icons.mail_outline_rounded,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Admin Password (8+ characters)',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: appController.loading ? null : create,
              icon: const Icon(Icons.rocket_launch_rounded),
              label: const Text('Create College & Admin'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                backgroundColor: AppColors.blue,
              ),
            ),
          ],
        ),
      );
}
