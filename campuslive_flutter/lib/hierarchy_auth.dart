import 'package:flutter/material.dart';

import 'hierarchy_common.dart';
import 'hierarchy_controller.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final collegeController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool obscure = true;

  Future<void> submit() async {
    if (collegeController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        passwordController.text.isEmpty) {
      showMessage(
        context,
        'Enter college code, email and password.',
        error: true,
      );
      return;
    }

    try {
      await hierarchyController.login(
        collegeCode: collegeController.text,
        email: emailController.text,
        password: passwordController.text,
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
                            TextField(
                              controller: collegeController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                labelText: 'College Code',
                                prefixIcon: Icon(Icons.domain_rounded),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.mail_outline_rounded),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: passwordController,
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
                                  hierarchyController.loading ? null : submit,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(52),
                                backgroundColor: AppColors.blue,
                              ),
                              child: hierarchyController.loading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Login to Portal'),
                            ),
                            const SizedBox(height: 10),
                            TextButton.icon(
                              onPressed: hierarchyController.loading
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
                      'No demo account is preloaded. College Admin creates the real hierarchy.',
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
        .any((c) => c.text.trim().isEmpty)) {
      showMessage(context, 'Fill all fields.', error: true);
      return;
    }
    if (password.text.length < 8) {
      showMessage(context, 'Password needs at least 8 characters.', error: true);
      return;
    }

    try {
      await hierarchyController.setupCollege(
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
                  'After setup, Admin creates real Principal, Departments, HODs, Staff and Students. No fake users are generated.',
            ),
            const SizedBox(height: 16),
            appTextField(
              collegeName,
              'Official College Name',
              Icons.school_rounded,
            ),
            const SizedBox(height: 10),
            appTextField(
              collegeCode,
              'Unique College Code',
              Icons.domain_rounded,
            ),
            const SizedBox(height: 10),
            appTextField(adminName, 'Admin Name', Icons.person_rounded),
            const SizedBox(height: 10),
            appTextField(
              adminEmail,
              'Admin Email',
              Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 10),
            appTextField(
              password,
              'Admin Password (8+ characters)',
              Icons.lock_outline_rounded,
              obscure: true,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: hierarchyController.loading ? null : create,
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
