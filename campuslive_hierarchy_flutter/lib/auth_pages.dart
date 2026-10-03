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
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.navy,
                Color(0xFF173D86),
                Color(0xFF315EFB),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    children: [
                      Semantics(
                        label: 'CampusLive app logo',
                        child: Container(
                          width: 82,
                          height: 82,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33000000),
                                blurRadius: 24,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.account_tree_rounded,
                            color: AppColors.blue,
                            size: 40,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'CampusLive',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'One college. Five connected portals.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Text(
                          'Admin → Principal → HOD → Staff → Student',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Welcome back',
                                style: TextStyle(
                                  color: AppColors.navy,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Use your college code and official account.',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 11.5,
                                ),
                              ),
                              const SizedBox(height: 18),
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
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => submit(),
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon:
                                      const Icon(Icons.lock_outline_rounded),
                                  suffixIcon: IconButton(
                                    tooltip: obscure
                                        ? 'Show password'
                                        : 'Hide password',
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
                              FilledButton.icon(
                                onPressed:
                                    appController.loading ? null : submit,
                                icon: appController.loading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.login_rounded),
                                label: Text(
                                  appController.loading
                                      ? 'Signing in...'
                                      : 'Login to My Portal',
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Row(
                                children: [
                                  Expanded(child: Divider()),
                                  Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 10),
                                    child: Text(
                                      'NEW COLLEGE',
                                      style: TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: .8,
                                      ),
                                    ),
                                  ),
                                  Expanded(child: Divider()),
                                ],
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
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
                                label: const Text('Create College Workspace'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'No demo accounts are preloaded. Real college accounts only.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
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
