import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CampusLiveApp());
}

class AppColors {
  static const bg = Color(0xFFF6F8FC);
  static const navy = Color(0xFF0C1830);
  static const blue = Color(0xFF315EFB);
  static const green = Color(0xFF1DBA6F);
  static const orange = Color(0xFFFFA31A);
  static const red = Color(0xFFE74C3C);
  static const purple = Color(0xFF7C5CFC);
  static const muted = Color(0xFF6E7890);
}

class PortalItem {
  PortalItem(this.module, this.label, this.enabled, this.position);

  final String module;
  String label;
  bool enabled;
  int position;

  factory PortalItem.fromJson(Map<String, dynamic> j) {
    return PortalItem(
      (j['module'] ?? '').toString(),
      (j['label'] ?? '').toString(),
      j['enabled'] == true,
      (j['position'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'module': module,
      'label': label,
      'enabled': enabled,
      'position': position,
    };
  }
}

class Person {
  Person({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.departmentId,
    this.department,
    this.year = '',
    this.section = '',
    this.active = true,
  });

  final int id;
  final String name;
  final String email;
  final String role;
  final int? departmentId;
  final String? department;
  final String year;
  final String section;
  final bool active;

  factory Person.fromJson(Map<String, dynamic> j) {
    return Person(
      id: (j['id'] as num).toInt(),
      name: (j['name'] ?? '').toString(),
      email: (j['email'] ?? '').toString(),
      role: (j['role'] ?? '').toString(),
      departmentId: (j['department_id'] as num?)?.toInt(),
      department: j['department']?.toString(),
      year: (j['year'] ?? '').toString(),
      section: (j['section'] ?? '').toString(),
      active: j['active'] != false,
    );
  }
}

class Department {
  Department({
    required this.id,
    required this.name,
    required this.code,
    this.hodName,
    this.staffCount = 0,
    this.studentCount = 0,
  });

  final int id;
  final String name;
  final String code;
  final String? hodName;
  final int staffCount;
  final int studentCount;

  factory Department.fromJson(Map<String, dynamic> j) {
    return Department(
      id: (j['id'] as num).toInt(),
      name: (j['name'] ?? '').toString(),
      code: (j['code'] ?? '').toString(),
      hodName: j['hod_name']?.toString(),
      staffCount: (j['staff_count'] as num?)?.toInt() ?? 0,
      studentCount: (j['student_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class MessageItem {
  MessageItem({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.status,
    required this.otherName,
    required this.otherRole,
  });

  final int id;
  final String title;
  final String body;
  final String kind;
  String status;
  final String otherName;
  final String otherRole;

  factory MessageItem.inbox(Map<String, dynamic> j) {
    return MessageItem(
      id: (j['id'] as num).toInt(),
      title: (j['title'] ?? '').toString(),
      body: (j['body'] ?? '').toString(),
      kind: (j['kind'] ?? '').toString(),
      status: (j['status'] ?? '').toString(),
      otherName: (j['sender_name'] ?? '').toString(),
      otherRole: (j['sender_role'] ?? '').toString(),
    );
  }

  factory MessageItem.sent(Map<String, dynamic> j) {
    return MessageItem(
      id: (j['id'] as num).toInt(),
      title: (j['title'] ?? '').toString(),
      body: (j['body'] ?? '').toString(),
      kind: (j['kind'] ?? '').toString(),
      status: (j['status'] ?? '').toString(),
      otherName: (j['recipient_name'] ?? '').toString(),
      otherRole: (j['recipient_role'] ?? '').toString(),
    );
  }
}

class AppState extends ChangeNotifier {
  static const api = 'https://campuslive-hierarchy-api.onrender.com';

  final http.Client client = http.Client();
  WebSocketChannel? socket;
  StreamSubscription<dynamic>? socketSubscription;

  String? token;
  Person? me;
  String collegeName = '';
  String collegeCode = '';
  bool online = false;
  bool busy = false;

  List<PortalItem> portal = [];
  Map<String, dynamic> dashboard = {};
  List<Person> directory = [];
  List<MessageItem> inbox = [];
  List<MessageItem> sent = [];
  List<Person> adminUsers = [];
  List<Department> departments = [];
  List<Map<String, dynamic>> audit = [];

  Map<String, String> get headers {
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer ' + token!,
    };
  }

  Uri apiUri(String path) => Uri.parse(api + path);

  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    http.Response response;
    final encoded = body == null ? null : jsonEncode(body);

    if (method == 'POST') {
      response = await client.post(apiUri(path), headers: headers, body: encoded);
    } else if (method == 'PATCH') {
      response = await client.patch(apiUri(path), headers: headers, body: encoded);
    } else if (method == 'PUT') {
      response = await client.put(apiUri(path), headers: headers, body: encoded);
    } else {
      response = await client.get(apiUri(path), headers: headers);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      var detail = 'Request failed (' + response.statusCode.toString() + ')';
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        detail = (data['detail'] ?? detail).toString();
      } catch (_) {}
      throw Exception(detail);
    }

    if (response.body.trim().isEmpty) return <String, dynamic>{};
    return jsonDecode(response.body);
  }

  Future<void> createCollege({
    required String collegeNameValue,
    required String collegeCodeValue,
    required String adminName,
    required String email,
    required String password,
  }) async {
    busy = true;
    notifyListeners();
    try {
      final data = await request(
        'POST',
        '/setup/college',
        body: {
          'college_name': collegeNameValue,
          'college_code': collegeCodeValue,
          'admin_name': adminName,
          'admin_email': email,
          'admin_password': password,
        },
      ) as Map<String, dynamic>;
      token = data['token'].toString();
      loadUser(data['user'] as Map<String, dynamic>);
      await refreshAll();
      connectRealtime();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> login(String code, String email, String password) async {
    busy = true;
    notifyListeners();
    try {
      final data = await request(
        'POST',
        '/auth/login',
        body: {
          'college_code': code,
          'email': email,
          'password': password,
        },
      ) as Map<String, dynamic>;
      token = data['token'].toString();
      loadUser(data['user'] as Map<String, dynamic>);
      await refreshAll();
      connectRealtime();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void loadUser(Map<String, dynamic> data) {
    me = Person.fromJson(data);
    collegeName = (data['college_name'] ?? '').toString();
    collegeCode = (data['college_code'] ?? '').toString();
  }

  Future<void> refreshAll() async {
    if (me == null || token == null) return;
    try {
      final portalRaw = await request('GET', '/portal') as List<dynamic>;
      final dashRaw = await request('GET', '/dashboard') as Map<String, dynamic>;
      final dirRaw = await request('GET', '/directory') as List<dynamic>;
      final inboxRaw = await request('GET', '/inbox') as List<dynamic>;

      portal = portalRaw
          .map((e) => PortalItem.fromJson(e as Map<String, dynamic>))
          .where((e) => e.enabled)
          .toList()
        ..sort((a, b) => a.position.compareTo(b.position));

      dashboard = dashRaw;
      directory = dirRaw
          .map((e) => Person.fromJson(e as Map<String, dynamic>))
          .toList();
      inbox = inboxRaw
          .map((e) => MessageItem.inbox(e as Map<String, dynamic>))
          .toList();

      if (me!.role != 'student') {
        final sentRaw = await request('GET', '/sent') as List<dynamic>;
        sent = sentRaw
            .map((e) => MessageItem.sent(e as Map<String, dynamic>))
            .toList();
      } else {
        sent = [];
      }

      if (me!.role == 'admin') {
        await refreshAdminData();
      }

      online = true;
    } catch (_) {
      online = false;
    }
    notifyListeners();
  }

  Future<void> refreshAdminData() async {
    if (me?.role != 'admin') return;
    try {
      final usersRaw = await request('GET', '/admin/users') as List<dynamic>;
      final deptRaw =
          await request('GET', '/admin/departments') as List<dynamic>;
      final auditRaw = await request('GET', '/admin/audit') as List<dynamic>;
      adminUsers = usersRaw
          .map((e) => Person.fromJson(e as Map<String, dynamic>))
          .toList();
      departments = deptRaw
          .map((e) => Department.fromJson(e as Map<String, dynamic>))
          .toList();
      audit = auditRaw.map((e) => e as Map<String, dynamic>).toList();
    } catch (_) {}
  }

  void connectRealtime() {
    socketSubscription?.cancel();
    socket?.sink.close();
    if (token == null) return;
    try {
      final wsBase = api.replaceFirst('https://', 'wss://');
      socket = WebSocketChannel.connect(
        Uri.parse(wsBase + '/ws?token=' + Uri.encodeQueryComponent(token!)),
      );
      socketSubscription = socket!.stream.listen(
        (_) => unawaited(refreshAll()),
        onError: (_) {},
      );
    } catch (_) {}
  }

  Future<void> addDepartment(String name, String code) async {
    await request(
      'POST',
      '/admin/departments',
      body: {'name': name, 'code': code},
    );
    await refreshAll();
  }

  Future<void> addUser({
    required String name,
    required String email,
    required String password,
    required String role,
    int? departmentId,
    String year = '',
    String section = '',
  }) async {
    await request(
      'POST',
      '/admin/users',
      body: {
        'name': name,
        'email': email,
        'password': password,
        'role': role,
        'department_id': departmentId,
        'year': year,
        'section': section,
      },
    );
    await refreshAll();
  }

  Future<void> setUserActive(Person person, bool active) async {
    await request(
      'PATCH',
      '/admin/users/' + person.id.toString(),
      body: {'is_active': active},
    );
    await refreshAll();
  }

  Future<void> sendAssignment({
    required List<int> recipients,
    required String title,
    required String body,
    required String kind,
  }) async {
    await request(
      'POST',
      '/assignments',
      body: {
        'target_user_ids': recipients,
        'title': title,
        'body': body,
        'kind': kind,
      },
    );
    await refreshAll();
  }

  Future<void> updateMessage(MessageItem item, String status) async {
    await request(
      'PATCH',
      '/assignments/' + item.id.toString(),
      body: {'status': status},
    );
    await refreshAll();
  }

  Future<List<PortalItem>> getRolePortal(String role) async {
    final raw = await request('GET', '/admin/portal/' + role) as List<dynamic>;
    final items =
        raw.map((e) => PortalItem.fromJson(e as Map<String, dynamic>)).toList();
    items.sort((a, b) => a.position.compareTo(b.position));
    return items;
  }

  Future<void> saveRolePortal(String role, List<PortalItem> items) async {
    for (var i = 0; i < items.length; i++) {
      items[i].position = i;
    }
    await request(
      'PUT',
      '/admin/portal/' + role,
      body: {'items': items.map((e) => e.toJson()).toList()},
    );
    await refreshAll();
  }

  void logout() {
    socketSubscription?.cancel();
    socket?.sink.close();
    token = null;
    me = null;
    collegeName = '';
    collegeCode = '';
    online = false;
    portal = [];
    dashboard = {};
    directory = [];
    inbox = [];
    sent = [];
    adminUsers = [];
    departments = [];
    audit = [];
    notifyListeners();
  }
}

final appState = AppState();

class CampusLiveApp extends StatelessWidget {
  const CampusLiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CampusLive',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.blue),
        cardTheme: const CardThemeData(
          elevation: 0,
          color: Colors.white,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(22)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        if (appState.me == null) return const LoginPage();
        return const PortalHome();
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final code = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  String? error;

  Future<void> submit() async {
    setState(() => error = null);
    try {
      await appState.login(code.text, email.text, password.text);
    } catch (e) {
      if (mounted) setState(() => error = cleanError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.blue, AppColors.purple],
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
                      fontSize: 31,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Admin → Principal → HOD → Staff → Student',
                    style: TextStyle(color: Colors.white60),
                  ),
                  const SizedBox(height: 26),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          TextField(
                            controller: code,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'College Code',
                              prefixIcon: Icon(Icons.apartment_rounded),
                            ),
                          ),
                          const SizedBox(height: 11),
                          TextField(
                            controller: email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.mail_outline_rounded),
                            ),
                          ),
                          const SizedBox(height: 11),
                          TextField(
                            controller: password,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              prefixIcon: Icon(Icons.lock_outline_rounded),
                            ),
                          ),
                          if (error != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              error!,
                              style: const TextStyle(
                                color: AppColors.red,
                                fontSize: 11,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: appState.busy ? null : submit,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                            ),
                            child: appState.busy
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
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CollegeSetupPage(),
                              ),
                            ),
                            icon: const Icon(Icons.add_business_rounded),
                            label: const Text('Create College Admin'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'No dummy accounts are preloaded. Create the real college workspace first.',
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
}

class CollegeSetupPage extends StatefulWidget {
  const CollegeSetupPage({super.key});

  @override
  State<CollegeSetupPage> createState() => _CollegeSetupPageState();
}

class _CollegeSetupPageState extends State<CollegeSetupPage> {
  final college = TextEditingController();
  final code = TextEditingController();
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  String? error;

  Future<void> submit() async {
    setState(() => error = null);
    try {
      await appState.createCollege(
        collegeNameValue: college.text,
        collegeCodeValue: code.text,
        adminName: name.text,
        email: email.text,
        password: password.text,
      );
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      if (mounted) setState(() => error = cleanError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: pageBar('Create College'),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const HeroBox(
            icon: Icons.apartment_rounded,
            title: 'Real College Setup',
            subtitle:
                'Create only the college workspace. Actual departments and accounts are added after setup.',
            color: AppColors.blue,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: college,
            decoration: const InputDecoration(labelText: 'College Name'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: code,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Unique College Code',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Admin Name'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: email,
            decoration: const InputDecoration(labelText: 'Admin Email'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Admin Password (8+ characters)',
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(error!, style: const TextStyle(color: AppColors.red)),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: appState.busy ? null : submit,
            icon: const Icon(Icons.rocket_launch_rounded),
            label: const Text('Create College Workspace'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ],
      ),
    );
  }
}

class PortalHome extends StatelessWidget {
  const PortalHome({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final me = appState.me!;
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appState.collegeName,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  roleTitle(me.role) + ' Portal • ' + appState.collegeCode,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
            actions: [
              Icon(
                appState.online ? Icons.cloud_done_rounded : Icons.cloud_off,
                color: appState.online ? AppColors.green : AppColors.orange,
              ),
              IconButton(
                onPressed: appState.refreshAll,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: appState.refreshAll,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
              children: [
                RoleHero(person: me),
                const SizedBox(height: 18),
                const Text(
                  'My Portal',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                if (appState.portal.isEmpty)
                  const EmptyBox(
                    icon: Icons.dashboard_customize_outlined,
                    title: 'No modules enabled',
                    text: 'College Admin has disabled all modules for this role.',
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: appState.portal.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.35,
                    ),
                    itemBuilder: (_, i) {
                      final item = appState.portal[i];
                      return ModuleCard(
                        item: item,
                        onTap: () => openModule(context, item.module),
                      );
                    },
                  ),
                const SizedBox(height: 18),
                if (appState.inbox.isNotEmpty) ...[
                  const Text(
                    'Latest Update',
                    style: TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 10),
                  MessageCard(item: appState.inbox.first, inboxMode: true),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class RoleHero extends StatelessWidget {
  const RoleHero({super.key, required this.person});
  final Person person;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navy, Color(0xFF1D3E86)],
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white12,
            foregroundColor: Colors.white,
            child: Icon(roleIcon(person.role)),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  roleTitle(person.role) +
                      (person.department == null
                          ? ''
                          : ' • ' + person.department!),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  hierarchyText(person.role),
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 10.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ModuleCard extends StatelessWidget {
  const ModuleCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  final PortalItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = moduleColor(item.module);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(.10),
                foregroundColor: color,
                child: Icon(moduleIcon(item.module), size: 20),
              ),
              const Spacer(),
              Text(
                item.label,
                maxLines: 2,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                moduleHint(item.module),
                maxLines: 2,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 9.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: pageBar('Overview'),
      body: AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          final p = appState.me!;
          final d = appState.dashboard;
          final tiles = <String>[];

          if (p.role == 'admin') {
            final counts =
                (d['counts'] as Map<String, dynamic>?) ?? <String, dynamic>{};
            tiles.add('Departments: ' + (d['departments'] ?? 0).toString());
            tiles.add('Principal: ' + (counts['principal'] ?? 0).toString());
            tiles.add('HODs: ' + (counts['hod'] ?? 0).toString());
            tiles.add('Staff: ' + (counts['staff'] ?? 0).toString());
            tiles.add('Students: ' + (counts['student'] ?? 0).toString());
            tiles.add(
              'Pending assignments: ' +
                  (d['pending_assignments'] ?? 0).toString(),
            );
          } else if (p.role == 'principal') {
            tiles.add('HODs: ' + (d['hod_count'] ?? 0).toString());
          } else if (p.role == 'hod') {
            tiles.add('Staff: ' + (d['staff_count'] ?? 0).toString());
          } else if (p.role == 'staff') {
            tiles.add('Students: ' + (d['student_count'] ?? 0).toString());
          }
          tiles.add('Unread: ' + (d['unread'] ?? 0).toString());

          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              HeroBox(
                icon: roleIcon(p.role),
                title: roleTitle(p.role) + ' Monitoring',
                subtitle: hierarchyText(p.role),
                color: AppColors.blue,
              ),
              const SizedBox(height: 16),
              for (final item in tiles)
                Card(
                  margin: const EdgeInsets.only(bottom: 9),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFEEF2FF),
                      foregroundColor: AppColors.blue,
                      child: Icon(Icons.analytics_outlined),
                    ),
                    title: Text(
                      item,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class DirectoryPage extends StatelessWidget {
  const DirectoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final role = appState.me!.role;
    String title = 'Directory';
    if (role == 'principal') title = 'HODs';
    if (role == 'hod') title = 'Department Staff';
    if (role == 'staff') title = 'Students';
    if (role == 'admin') title = 'College Users';

    return Scaffold(
      appBar: pageBar(title),
      body: AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          if (appState.directory.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(18),
              children: [
                EmptyBox(
                  icon: Icons.groups_outlined,
                  title: 'No users available',
                  text: emptyDirectoryText(role),
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(18),
            itemCount: appState.directory.length,
            separatorBuilder: (_, __) => const SizedBox(height: 9),
            itemBuilder: (_, i) {
              return PersonCard(person: appState.directory[i]);
            },
          );
        },
      ),
    );
  }
}

class InboxPage extends StatelessWidget {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: pageBar('Inbox'),
      body: AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          if (appState.inbox.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(18),
              children: const [
                EmptyBox(
                  icon: Icons.inbox_outlined,
                  title: 'Inbox is empty',
                  text:
                      'Information and tasks assigned to you will appear here live.',
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(18),
            itemCount: appState.inbox.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              return MessageCard(
                item: appState.inbox[i],
                inboxMode: true,
              );
            },
          );
        },
      ),
    );
  }
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
  bool sending = false;

  Future<void> send() async {
    if (selected.isEmpty ||
        title.text.trim().isEmpty ||
        body.text.trim().isEmpty) {
      snack(context, 'Select recipients and enter title + message.');
      return;
    }
    setState(() => sending = true);
    try {
      await appState.sendAssignment(
        recipients: selected.toList(),
        title: title.text.trim(),
        body: body.text.trim(),
        kind: kind,
      );
      title.clear();
      body.clear();
      selected.clear();
      if (mounted) snack(context, 'Sent successfully.');
    } catch (e) {
      if (mounted) snack(context, cleanError(e));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: pageBar(assignmentTitle(appState.me!.role)),
      body: AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              HeroBox(
                icon: Icons.send_rounded,
                title: assignmentTitle(appState.me!.role),
                subtitle: hierarchyText(appState.me!.role),
                color: AppColors.orange,
              ),
              const SizedBox(height: 16),
              if (appState.directory.isEmpty)
                const EmptyBox(
                  icon: Icons.person_off_outlined,
                  title: 'No recipients available',
                  text: 'Admin must create the next-level accounts first.',
                )
              else ...[
                Row(
                  children: [
                    TextButton(
                      onPressed: () => setState(() {
                        selected
                          ..clear()
                          ..addAll(appState.directory.map((e) => e.id));
                      }),
                      child: const Text('Select all'),
                    ),
                    TextButton(
                      onPressed: () => setState(selected.clear),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
                Card(
                  child: Column(
                    children: [
                      for (final person in appState.directory)
                        CheckboxListTile(
                          value: selected.contains(person.id),
                          onChanged: (value) => setState(() {
                            if (value == true) {
                              selected.add(person.id);
                            } else {
                              selected.remove(person.id);
                            }
                          }),
                          title: Text(
                            person.name,
                            style: const TextStyle(
                              color: AppColors.navy,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: Text(
                            roleTitle(person.role) +
                                (person.department == null
                                    ? ''
                                    : ' • ' + person.department!),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: kind,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(
                    value: 'information',
                    child: Text('Information'),
                  ),
                  DropdownMenuItem(value: 'task', child: Text('Task')),
                  DropdownMenuItem(
                    value: 'academic',
                    child: Text('Academic'),
                  ),
                  DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                ],
                onChanged: (value) {
                  setState(() => kind = value ?? 'information');
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: body,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Information / Instruction',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: sending ? null : send,
                icon: const Icon(Icons.send_rounded),
                label: Text(
                  sending
                      ? 'Sending...'
                      : 'Send to ' + selected.length.toString() + ' user(s)',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
              if (appState.sent.isNotEmpty) ...[
                const SizedBox(height: 22),
                const Text(
                  'Recently Sent',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                for (final item in appState.sent.take(10))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: MessageCard(item: item, inboxMode: false),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class AdminUsersPage extends StatelessWidget {
  const AdminUsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: pageBar('Users'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddUserDialog(context),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add User'),
      ),
      body: AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const HeroBox(
                icon: Icons.manage_accounts_rounded,
                title: 'Real College Accounts',
                subtitle:
                    'Admin creates actual Principal, HOD, Staff and Student accounts.',
                color: AppColors.green,
              ),
              const SizedBox(height: 16),
              if (appState.adminUsers.isEmpty)
                const EmptyBox(
                  icon: Icons.person_add_alt_rounded,
                  title: 'No accounts yet',
                  text: 'Tap Add User to create the first actual account.',
                )
              else
                for (final person in appState.adminUsers)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: PersonCard(
                      person: person,
                      trailing: person.id == appState.me?.id
                          ? null
                          : Switch(
                              value: person.active,
                              onChanged: (value) async {
                                try {
                                  await appState.setUserActive(person, value);
                                } catch (e) {
                                  if (context.mounted) {
                                    snack(context, cleanError(e));
                                  }
                                }
                              },
                            ),
                    ),
                  ),
              const SizedBox(height: 70),
            ],
          );
        },
      ),
    );
  }
}

class AdminDepartmentsPage extends StatelessWidget {
  const AdminDepartmentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: pageBar('Departments'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddDepartmentDialog(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Department'),
      ),
      body: AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const HeroBox(
                icon: Icons.apartment_rounded,
                title: 'Department Structure',
                subtitle:
                    'Create departments, then assign actual HOD, staff and students.',
                color: AppColors.purple,
              ),
              const SizedBox(height: 16),
              if (appState.departments.isEmpty)
                const EmptyBox(
                  icon: Icons.apartment_outlined,
                  title: 'No departments yet',
                  text: 'Tap Department to create one.',
                )
              else
                for (final d in appState.departments)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(14),
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFF0EDFF),
                        foregroundColor: AppColors.purple,
                        child: Text(
                          d.code.length > 4 ? d.code.substring(0, 4) : d.code,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      title: Text(
                        d.name,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      subtitle: Text(
                        'HOD: ' +
                            (d.hodName ?? 'Not assigned') +
                            '\n' +
                            d.staffCount.toString() +
                            ' staff • ' +
                            d.studentCount.toString() +
                            ' students',
                      ),
                      isThreeLine: true,
                    ),
                  ),
              const SizedBox(height: 70),
            ],
          );
        },
      ),
    );
  }
}

class PortalControlPage extends StatefulWidget {
  const PortalControlPage({super.key});

  @override
  State<PortalControlPage> createState() => _PortalControlPageState();
}

class _PortalControlPageState extends State<PortalControlPage> {
  String role = 'principal';
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
      items = await appState.getRolePortal(role);
    } catch (e) {
      if (mounted) snack(context, cleanError(e));
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> save() async {
    try {
      await appState.saveRolePortal(role, items);
      if (mounted) snack(context, 'Portal layout saved.');
    } catch (e) {
      if (mounted) snack(context, cleanError(e));
    }
  }

  void move(int index, int delta) {
    final newIndex = index + delta;
    if (newIndex < 0 || newIndex >= items.length) return;
    setState(() {
      final item = items.removeAt(index);
      items.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: pageBar('Portal Control'),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const HeroBox(
            icon: Icons.dashboard_customize_rounded,
            title: 'Admin Controls Every Portal',
            subtitle:
                'Enable or disable modules, rename labels and change page order for each role.',
            color: AppColors.orange,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: role,
            decoration: const InputDecoration(labelText: 'Portal Role'),
            items: roleList
                .map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text(roleTitle(item)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              role = value;
              load();
            },
          ),
          const SizedBox(height: 14),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else
            for (var i = 0; i < items.length; i++)
              Card(
                margin: const EdgeInsets.only(bottom: 9),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Switch(
                        value: items[i].enabled,
                        onChanged: (value) {
                          setState(() => items[i].enabled = value);
                        },
                      ),
                      Expanded(
                        child: TextFormField(
                          initialValue: items[i].label,
                          onChanged: (value) => items[i].label = value,
                          decoration: InputDecoration(
                            labelText: items[i].module,
                            isDense: true,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => move(i, -1),
                        icon: const Icon(Icons.keyboard_arrow_up_rounded),
                      ),
                      IconButton(
                        onPressed: () => move(i, 1),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: loading ? null : save,
            icon: const Icon(Icons.save_rounded),
            label: const Text('Save Portal Layout'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ],
      ),
    );
  }
}

class AuditPage extends StatelessWidget {
  const AuditPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: pageBar('Live Activity'),
      body: AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          if (appState.audit.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(18),
              children: const [
                EmptyBox(
                  icon: Icons.history_rounded,
                  title: 'No activity yet',
                  text:
                      'Account, department, assignment and portal changes will appear here.',
                ),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(18),
            itemCount: appState.audit.length,
            itemBuilder: (_, i) {
              final row = appState.audit[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 9),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFEEF2FF),
                    foregroundColor: AppColors.blue,
                    child: Icon(Icons.history_rounded, size: 18),
                  ),
                  title: Text(
                    (row['action'] ?? '').toString(),
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  subtitle: Text(
                    (row['actor'] ?? '').toString() +
                        '\n' +
                        (row['detail'] ?? '').toString(),
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = appState.me!;
    return Scaffold(
      appBar: pageBar('Profile'),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          HeroBox(
            icon: roleIcon(p.role),
            title: p.name,
            subtitle: roleTitle(p.role) + ' • ' + appState.collegeName,
            color: AppColors.blue,
          ),
          const SizedBox(height: 14),
          infoTile(Icons.mail_outline_rounded, 'Email', p.email),
          infoTile(
            Icons.apartment_outlined,
            'Department',
            p.department ?? 'College level',
          ),
          if (p.year.isNotEmpty)
            infoTile(Icons.school_outlined, 'Year', p.year),
          if (p.section.isNotEmpty)
            infoTile(Icons.class_outlined, 'Section', p.section),
          infoTile(Icons.badge_outlined, 'Role', roleTitle(p.role)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: appState.logout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Logout'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ],
      ),
    );
  }
}

class PersonCard extends StatelessWidget {
  const PersonCard({
    super.key,
    required this.person,
    this.trailing,
  });

  final Person person;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: CircleAvatar(
          backgroundColor: roleColor(person.role).withOpacity(.10),
          foregroundColor: roleColor(person.role),
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
          roleTitle(person.role) +
              (person.department == null
                  ? ''
                  : ' • ' + person.department!) +
              (person.year.isEmpty ? '' : ' • Year ' + person.year) +
              (person.section.isEmpty ? '' : ' • Sec ' + person.section) +
              '\n' +
              person.email,
        ),
        isThreeLine: true,
        trailing: trailing,
      ),
    );
  }
}

class MessageCard extends StatelessWidget {
  const MessageCard({
    super.key,
    required this.item,
    required this.inboxMode,
  });

  final MessageItem item;
  final bool inboxMode;

  @override
  Widget build(BuildContext context) {
    final color = kindColor(item.kind);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  side: BorderSide.none,
                  backgroundColor: color.withOpacity(.10),
                  label: Text(
                    item.kind.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Spacer(),
                Chip(
                  side: BorderSide.none,
                  label: Text(
                    item.status.toUpperCase(),
                    style: const TextStyle(fontSize: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              item.title,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.body,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              (inboxMode ? 'From: ' : 'To: ') +
                  item.otherName +
                  ' • ' +
                  roleTitle(item.otherRole),
              style: const TextStyle(
                color: AppColors.blue,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (inboxMode) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (item.status == 'new')
                    TextButton(
                      onPressed: () =>
                          appState.updateMessage(item, 'read'),
                      child: const Text('Mark Read'),
                    ),
                  if (item.status != 'done')
                    TextButton(
                      onPressed: () =>
                          appState.updateMessage(item, 'done'),
                      child: const Text('Done'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class HeroBox extends StatelessWidget {
  const HeroBox({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 27,
            backgroundColor: color,
            foregroundColor: Colors.white,
            child: Icon(icon),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 10.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyBox extends StatelessWidget {
  const EmptyBox({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(icon, color: AppColors.muted, size: 34),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w900,
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
}

Future<void> showAddDepartmentDialog(BuildContext context) async {
  final name = TextEditingController();
  final code = TextEditingController();

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Add Department'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Department Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: code,
              decoration: const InputDecoration(labelText: 'Department Code'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await appState.addDepartment(name.text, code.text);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (e) {
                if (dialogContext.mounted) {
                  snack(dialogContext, cleanError(e));
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      );
    },
  );
}

Future<void> showAddUserDialog(BuildContext context) async {
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final year = TextEditingController();
  final section = TextEditingController();
  String role = 'principal';
  int? departmentId;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setLocal) {
          final needsDepartment =
              role == 'hod' || role == 'staff' || role == 'student';
          return AlertDialog(
            title: const Text('Add User'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Full Name'),
                    ),
                    const SizedBox(height: 9),
                    TextField(
                      controller: email,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 9),
                    TextField(
                      controller: password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Initial Password (8+)',
                      ),
                    ),
                    const SizedBox(height: 9),
                    DropdownButtonFormField<String>(
                      value: role,
                      decoration: const InputDecoration(labelText: 'Role'),
                      items: const [
                        DropdownMenuItem(
                          value: 'principal',
                          child: Text('Principal'),
                        ),
                        DropdownMenuItem(value: 'hod', child: Text('HOD')),
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
                        setLocal(() {
                          role = value ?? 'principal';
                          if (role == 'principal') departmentId = null;
                        });
                      },
                    ),
                    if (needsDepartment) ...[
                      const SizedBox(height: 9),
                      DropdownButtonFormField<int>(
                        value: departmentId,
                        decoration: const InputDecoration(
                          labelText: 'Department',
                        ),
                        items: appState.departments
                            .map(
                              (d) => DropdownMenuItem(
                                value: d.id,
                                child: Text(d.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setLocal(() => departmentId = value);
                        },
                      ),
                    ],
                    if (role == 'student') ...[
                      const SizedBox(height: 9),
                      TextField(
                        controller: year,
                        decoration: const InputDecoration(labelText: 'Year'),
                      ),
                      const SizedBox(height: 9),
                      TextField(
                        controller: section,
                        decoration: const InputDecoration(labelText: 'Section'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  try {
                    await appState.addUser(
                      name: name.text,
                      email: email.text,
                      password: password.text,
                      role: role,
                      departmentId: departmentId,
                      year: year.text,
                      section: section.text,
                    );
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  } catch (e) {
                    if (dialogContext.mounted) {
                      snack(dialogContext, cleanError(e));
                    }
                  }
                },
                child: const Text('Create Account'),
              ),
            ],
          );
        },
      );
    },
  );
}

void openModule(BuildContext context, String module) {
  Widget page;

  if (module == 'overview') {
    page = const OverviewPage();
  } else if (module == 'users') {
    page = const AdminUsersPage();
  } else if (module == 'departments') {
    page = const AdminDepartmentsPage();
  } else if (module == 'portal_control') {
    page = const PortalControlPage();
  } else if (module == 'live_activity') {
    page = const AuditPage();
  } else if (module == 'directory') {
    page = const DirectoryPage();
  } else if (module == 'inbox') {
    page = const InboxPage();
  } else if (module == 'assign') {
    page = const AssignPage();
  } else if (module == 'profile') {
    page = const ProfilePage();
  } else {
    page = Scaffold(
      appBar: pageBar('Module'),
      body: const Center(child: Text('Module is not configured.')),
    );
  }

  Navigator.push(context, MaterialPageRoute(builder: (_) => page));
}

PreferredSizeWidget pageBar(String title) {
  return AppBar(
    title: Text(
      title,
      style: const TextStyle(
        color: AppColors.navy,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

Widget infoTile(IconData icon, String title, String value) {
  return Card(
    margin: const EdgeInsets.only(bottom: 9),
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFEEF2FF),
        foregroundColor: AppColors.blue,
        child: Icon(icon, size: 18),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.navy,
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Text(value),
    ),
  );
}

const roleList = ['admin', 'principal', 'hod', 'staff', 'student'];

String roleTitle(String role) {
  if (role == 'admin') return 'College Admin';
  if (role == 'principal') return 'Principal';
  if (role == 'hod') return 'HOD';
  if (role == 'staff') return 'Staff';
  if (role == 'student') return 'Student';
  return role;
}

IconData roleIcon(String role) {
  if (role == 'admin') return Icons.admin_panel_settings_rounded;
  if (role == 'principal') return Icons.account_balance_rounded;
  if (role == 'hod') return Icons.supervisor_account_rounded;
  if (role == 'staff') return Icons.badge_rounded;
  return Icons.school_rounded;
}

Color roleColor(String role) {
  if (role == 'admin') return AppColors.red;
  if (role == 'principal') return AppColors.purple;
  if (role == 'hod') return AppColors.blue;
  if (role == 'staff') return AppColors.green;
  return AppColors.orange;
}

IconData moduleIcon(String module) {
  if (module == 'overview') return Icons.dashboard_rounded;
  if (module == 'users') return Icons.manage_accounts_rounded;
  if (module == 'departments') return Icons.apartment_rounded;
  if (module == 'portal_control') return Icons.dashboard_customize_rounded;
  if (module == 'live_activity') return Icons.history_rounded;
  if (module == 'directory') return Icons.groups_rounded;
  if (module == 'inbox') return Icons.inbox_rounded;
  if (module == 'assign') return Icons.send_rounded;
  if (module == 'profile') return Icons.person_rounded;
  return Icons.grid_view_rounded;
}

Color moduleColor(String module) {
  if (module == 'users') return AppColors.green;
  if (module == 'departments') return AppColors.purple;
  if (module == 'portal_control') return AppColors.orange;
  if (module == 'live_activity') return AppColors.purple;
  if (module == 'assign') return AppColors.orange;
  if (module == 'directory') return AppColors.green;
  return AppColors.blue;
}

String moduleHint(String module) {
  if (module == 'overview') return 'Role-level monitoring';
  if (module == 'users') return 'Create and manage accounts';
  if (module == 'departments') return 'College structure';
  if (module == 'portal_control') return 'Control role pages';
  if (module == 'live_activity') return 'Audit activity';
  if (module == 'directory') return 'People you can monitor';
  if (module == 'inbox') return 'Assigned information';
  if (module == 'assign') return 'Send to next level';
  if (module == 'profile') return 'Account details';
  return '';
}

String hierarchyText(String role) {
  if (role == 'admin') {
    return 'Admin monitors the entire college and controls every role portal.';
  }
  if (role == 'principal') {
    return 'Principal monitors HODs and sends information only to HODs.';
  }
  if (role == 'hod') {
    return 'HOD monitors staff in the assigned department and assigns work to staff.';
  }
  if (role == 'staff') {
    return 'Staff monitors students in the assigned department and assigns information to students.';
  }
  return 'Student sees only information and tasks assigned to their own account.';
}

String emptyDirectoryText(String role) {
  if (role == 'principal') {
    return 'College Admin must create and assign HOD accounts.';
  }
  if (role == 'hod') {
    return 'College Admin must add staff to your department.';
  }
  if (role == 'staff') {
    return 'College Admin must add students to your department.';
  }
  return 'College Admin has not added other accounts yet.';
}

String assignmentTitle(String role) {
  if (role == 'admin') return 'Assign / Broadcast';
  if (role == 'principal') return 'Send to HODs';
  if (role == 'hod') return 'Assign to Staff';
  if (role == 'staff') return 'Assign to Students';
  return 'Send';
}

Color kindColor(String kind) {
  if (kind == 'urgent') return AppColors.red;
  if (kind == 'task') return AppColors.orange;
  if (kind == 'academic') return AppColors.purple;
  return AppColors.blue;
}

String cleanError(Object error) {
  final text = error.toString();
  if (text.startsWith('Exception: ')) return text.substring(11);
  return text;
}

void snack(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text)),
  );
}
