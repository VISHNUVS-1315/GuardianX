import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CampusLiveApp());
}

class AppColors {
  static const bg = Color(0xFFF6F8FC);
  static const navy = Color(0xFF0B1734);
  static const blue = Color(0xFF315EFB);
  static const cyan = Color(0xFF18B7E9);
  static const green = Color(0xFF1DBA6F);
  static const orange = Color(0xFFFFA31A);
  static const red = Color(0xFFE74C3C);
  static const purple = Color(0xFF7C5CFC);
  static const muted = Color(0xFF6E7890);
  static const line = Color(0xFFE8ECF4);
}

class RoomState {
  RoomState(this.name, this.block, this.available, this.note);
  final String name;
  final String block;
  bool available;
  String note;
}

class Complaint {
  Complaint(this.id, this.place, this.issue, this.status);
  final String id;
  final String place;
  final String issue;
  String status;
}

class TimetableItem {
  TimetableItem(this.time, this.subject, this.room, this.faculty);
  final String time;
  final String subject;
  final String room;
  final String faculty;
}

class LabItem {
  LabItem(this.name, this.available, this.total, this.note);
  final String name;
  final int available;
  final int total;
  final String note;
}

class EventItem {
  EventItem(this.id, this.title, this.date, this.seatsLeft, this.registered);
  final int id;
  final String title;
  final String date;
  int seatsLeft;
  bool registered;
}

class CampusStore extends ChangeNotifier {
  CampusStore() {
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (token != null) {
        unawaited(syncAll());
      } else if (role != null) {
        busEta -= 1;
        if (busEta < 3) {
          busEta = 8;
          busOnTime = !busOnTime;
        }
        notifyListeners();
      }
    });
  }

  static const apiBase = 'https://campuslive-fullstack-api.onrender.com';
  final http.Client _client = http.Client();
  late final Timer _timer;

  String? token;
  String? role;
  String userName = 'Vishnu S';
  bool online = false;

  String studentId = '25ME103';
  String department = 'Mechanical Engineering';
  String year = '2';
  String section = 'A';
  String semester = '3';
  String busCode = 'BUS07';
  String busDisplay = 'Bus 07';
  String boardingStop = 'Udumalpet Bus Stand';
  String studentType = 'Day Scholar';
  bool isHosteller = false;
  int attendancePercent = 86;
  double cgpa = 7.64;
  int assignmentsDue = 3;
  bool placementEligible = true;

  int busEta = 8;
  bool busOnTime = true;

  final List<RoomState> rooms = [
    RoomState('M201', 'Mechanical Block', true, 'Free until 12:20 PM'),
    RoomState('M202', 'Mechanical Block', false, 'Thermodynamics until 12:20 PM'),
    RoomState('M203', 'Mechanical Block', true, 'Free until 1:10 PM'),
    RoomState('C301', 'Main Block', false, 'Programming class until 11:50 AM'),
    RoomState('A102', 'AI Block', true, 'Free until 2:00 PM'),
  ];

  final List<String> announcements = [
    'Engineering Mechanics room changed: M204 → C302',
    'Bus 03 delayed by approximately 12 minutes',
    'EV Design Workshop registration is open',
  ];

  final List<Complaint> complaints = [
    Complaint('CMP-1027', 'C204', 'Fan not working', 'Assigned'),
  ];

  final List<TimetableItem> timetable = [
    TimetableItem('09:00', 'Engineering Mechanics', 'M201', 'Dr. Ravi'),
    TimetableItem('09:50', 'Material Science', 'M202', 'Dr. Priya'),
    TimetableItem('10:40', 'Break', '-', '-'),
    TimetableItem('11:30', 'Engineering Thermodynamics', 'M204', 'Dr. Kumar'),
    TimetableItem('12:20', 'CAD Lab', 'CAD LAB 2', 'Mr. Arun'),
    TimetableItem('13:10', 'Lunch', '-', '-'),
    TimetableItem('14:00', 'Manufacturing Process', 'M203', 'Dr. Devi'),
  ];

  final List<LabItem> labs = [
    LabItem('CAD Lab', 21, 60, ''),
    LabItem('CAM Lab', 14, 40, ''),
    LabItem('AI Lab', 42, 60, ''),
    LabItem('Thermal Lab', 0, 30, 'Scheduled at 2 PM'),
  ];

  final List<EventItem> events = [
    EventItem(1, 'EV Design Workshop', 'Oct 04', 42, false),
    EventItem(2, 'TechFest 2026', 'Oct 12', 113, false),
    EventItem(3, 'CAD Sprint Challenge', 'Oct 18', 28, false),
  ];

  String placementCompany = 'Zoho';
  String placementRole = 'Software Developer';
  String placementRound = 'Technical';
  int placementQueue = 7;
  int placementEta = 24;

  bool libraryOpen = true;
  String libraryCloses = '20:00';
  int librarySeats = 182;
  int libraryTitles = 2340;

  bool canteenOpen = true;
  List<String> canteenWindows = [
    'Breakfast 08:00–10:00',
    'Lunch 12:00–14:30',
    'Snacks counter open',
  ];

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Uri _uri(String path) => Uri.parse('$apiBase$path');

  Future<bool> login(
    String email,
    String password, {
    required String expectedRole,
  }) async {
    try {
      final response = await _client
          .post(
            _uri('/auth/login'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email.trim(), 'password': password}),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        return false;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final user = data['user'] as Map<String, dynamic>;
      final serverRole = (user['role'] ?? '').toString();

      if (serverRole != expectedRole) {
        return false;
      }

      token = data['token'].toString();
      role = serverRole;
      userName = (user['name'] ?? 'CampusLive User').toString();
      online = true;
      notifyListeners();
      await syncAll();
      return true;
    } catch (_) {
      final fallbackEmail = expectedRole == 'admin'
          ? 'admin@campuslive.demo'
          : 'student@campuslive.demo';
      if (email.trim() == fallbackEmail && password == 'Campus@123') {
        token = null;
        role = expectedRole;
        online = false;
        notifyListeners();
        return true;
      }
      return false;
    }
  }

  Future<void> syncAll() async {
    if (token == null) return;
    var anySuccess = false;

    if (role == 'student') {
      try {
        final response = await _client
            .get(_uri('/student/context'), headers: _headers)
            .timeout(const Duration(seconds: 12));
        if (response.statusCode == 200) {
          final item = jsonDecode(response.body) as Map<String, dynamic>;
          studentId = (item['student_id'] ?? studentId).toString();
          userName = (item['name'] ?? userName).toString();
          department = (item['department'] ?? department).toString();
          year = (item['year'] ?? year).toString();
          section = (item['section'] ?? section).toString();
          semester = (item['semester'] ?? semester).toString();
          busCode = (item['bus_code'] ?? busCode).toString();
          busDisplay = (item['bus_display'] ?? busDisplay).toString();
          boardingStop = (item['boarding_stop'] ?? boardingStop).toString();
          studentType = (item['student_type'] ?? studentType).toString();
          isHosteller = item['is_hosteller'] == true;
          attendancePercent =
              (item['attendance_percent'] as num?)?.toInt() ?? attendancePercent;
          cgpa = (item['cgpa'] as num?)?.toDouble() ?? cgpa;
          assignmentsDue =
              (item['assignments_due'] as num?)?.toInt() ?? assignmentsDue;
          placementEligible = item['placement_eligible'] == true;
          anySuccess = true;
        }
      } catch (_) {}
    }

    try {
      final response = await _client
          .get(_uri('/rooms'), headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        rooms
          ..clear()
          ..addAll(
            list.map((raw) {
              final item = raw as Map<String, dynamic>;
              return RoomState(
                item['code'].toString(),
                item['block'].toString(),
                item['available'] == true,
                item['note'].toString(),
              );
            }),
          );
        anySuccess = true;
      }
    } catch (_) {}

    try {
      final response = await _client
          .get(_uri('/announcements'), headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        announcements
          ..clear()
          ..addAll(
            list.map((raw) {
              final item = raw as Map<String, dynamic>;
              final title = (item['title'] ?? '').toString();
              final message = (item['message'] ?? '').toString();
              return title.isEmpty ? message : '$title: $message';
            }),
          );
        anySuccess = true;
      }
    } catch (_) {}

    try {
      final response = await _client
          .get(_uri('/complaints'), headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        complaints
          ..clear()
          ..addAll(
            list.map((raw) {
              final item = raw as Map<String, dynamic>;
              return Complaint(
                item['ticket'].toString(),
                item['location'].toString(),
                item['description'].toString(),
                item['status'].toString(),
              );
            }),
          );
        anySuccess = true;
      }
    } catch (_) {}

    try {
      final response = await _client
          .get(_uri(role == 'student' ? '/transport/my' : '/transport/BUS07'), headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final item = jsonDecode(response.body) as Map<String, dynamic>;
        if (item['assigned'] != false) {
          busCode = (item['code'] ?? busCode).toString();
          busDisplay = (item['display'] ?? busDisplay).toString();
          boardingStop = (item['boarding_stop'] ?? boardingStop).toString();
          busEta = (item['eta_minutes'] as num?)?.toInt() ?? busEta;
          final status = (item['status'] ?? 'On time').toString().toLowerCase();
          busOnTime = !status.contains('delay');
        } else if (role == 'student') {
          busCode = '';
          busDisplay = 'No bus assigned';
          boardingStop = '-';
        }
        anySuccess = true;
      }
    } catch (_) {}

    try {
      final response = await _client
          .get(_uri('/timetable'), headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        timetable
          ..clear()
          ..addAll(
            list.map((raw) {
              final item = raw as Map<String, dynamic>;
              return TimetableItem(
                item['time'].toString(),
                item['subject'].toString(),
                item['room'].toString(),
                item['faculty'].toString(),
              );
            }),
          );
        anySuccess = true;
      }
    } catch (_) {}

    try {
      final response = await _client
          .get(_uri('/labs'), headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        labs
          ..clear()
          ..addAll(
            list.map((raw) {
              final item = raw as Map<String, dynamic>;
              return LabItem(
                item['name'].toString(),
                (item['available'] as num?)?.toInt() ?? 0,
                (item['total'] as num?)?.toInt() ?? 0,
                (item['note'] ?? '').toString(),
              );
            }),
          );
        anySuccess = true;
      }
    } catch (_) {}

    try {
      final response = await _client
          .get(_uri('/events'), headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        events
          ..clear()
          ..addAll(
            list.map((raw) {
              final item = raw as Map<String, dynamic>;
              return EventItem(
                (item['id'] as num?)?.toInt() ?? 0,
                item['title'].toString(),
                item['date'].toString(),
                (item['seats_left'] as num?)?.toInt() ?? 0,
                item['registered'] == true,
              );
            }),
          );
        anySuccess = true;
      }
    } catch (_) {}

    try {
      final response = await _client
          .get(_uri('/placement'), headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final item = jsonDecode(response.body) as Map<String, dynamic>;
        placementCompany = (item['company'] ?? placementCompany).toString();
        placementRole = (item['role'] ?? placementRole).toString();
        placementRound = (item['round'] ?? placementRound).toString();
        placementQueue = (item['queue'] as num?)?.toInt() ?? placementQueue;
        placementEta = (item['eta_minutes'] as num?)?.toInt() ?? placementEta;
        anySuccess = true;
      }
    } catch (_) {}

    try {
      final response = await _client
          .get(_uri('/library'), headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final item = jsonDecode(response.body) as Map<String, dynamic>;
        libraryOpen = item['open'] == true;
        libraryCloses = (item['closes'] ?? libraryCloses).toString();
        librarySeats = (item['seats_available'] as num?)?.toInt() ?? librarySeats;
        libraryTitles = (item['mechanical_titles'] as num?)?.toInt() ?? libraryTitles;
        anySuccess = true;
      }
    } catch (_) {}

    try {
      final response = await _client
          .get(_uri('/canteen'), headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final item = jsonDecode(response.body) as Map<String, dynamic>;
        canteenOpen = item['open'] == true;
        final windows = item['windows'] as List<dynamic>?;
        if (windows != null) {
          canteenWindows = windows.map((e) => e.toString()).toList();
        }
        anySuccess = true;
      }
    } catch (_) {}

    online = anySuccess;
    notifyListeners();
  }

  void registerEvent(EventItem event) {
    if (event.registered) return;
    event.registered = true;
    if (event.seatsLeft > 0) event.seatsLeft -= 1;
    notifyListeners();
    unawaited(_registerEventRemote(event));
  }

  Future<void> _registerEventRemote(EventItem event) async {
    if (token == null) return;
    try {
      final response = await _client
          .post(
            _uri('/events/${event.id}/register'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 12));
      online = response.statusCode >= 200 && response.statusCode < 300;
      if (online) await syncAll();
    } catch (_) {
      online = false;
      notifyListeners();
    }
  }

  Future<bool> sendEmergency(String kind) async {
    if (token == null) return true;
    try {
      final response = await _client
          .post(
            _uri('/emergency'),
            headers: _headers,
            body: jsonEncode({'kind': kind}),
          )
          .timeout(const Duration(seconds: 12));
      online = response.statusCode >= 200 && response.statusCode < 300;
      notifyListeners();
      return online;
    } catch (_) {
      online = false;
      notifyListeners();
      return false;
    }
  }

  void toggleRoom(RoomState room) {
    room.available = !room.available;
    room.note = room.available ? 'Available now' : 'Marked occupied by admin';
    notifyListeners();
    unawaited(_patchRoom(room));
  }

  Future<void> _patchRoom(RoomState room) async {
    if (token == null) return;
    try {
      final response = await _client
          .patch(
            _uri('/rooms/${Uri.encodeComponent(room.name)}'),
            headers: _headers,
            body: jsonEncode({
              'available': room.available,
              'note': room.note,
            }),
          )
          .timeout(const Duration(seconds: 12));
      online = response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      online = false;
    }
    notifyListeners();
  }

  void broadcast(String message) {
    announcements.insert(0, message);
    notifyListeners();
    unawaited(_sendBroadcast(message));
  }

  Future<void> _sendBroadcast(String message) async {
    if (token == null) return;
    try {
      final response = await _client
          .post(
            _uri('/announcements'),
            headers: _headers,
            body: jsonEncode({
              'title': 'Admin broadcast',
              'message': message,
              'audience': 'All campus',
            }),
          )
          .timeout(const Duration(seconds: 12));
      online = response.statusCode >= 200 && response.statusCode < 300;
      if (online) await syncAll();
    } catch (_) {
      online = false;
      notifyListeners();
    }
  }

  void addComplaint(String place, String issue) {
    complaints.insert(
      0,
      Complaint(
        'SYNCING',
        place,
        issue,
        'Reported',
      ),
    );
    notifyListeners();
    unawaited(_sendComplaint(place, issue));
  }

  Future<void> _sendComplaint(String place, String issue) async {
    if (token == null) return;
    try {
      final response = await _client
          .post(
            _uri('/complaints'),
            headers: _headers,
            body: jsonEncode({
              'category': 'General',
              'location': place,
              'description': issue,
            }),
          )
          .timeout(const Duration(seconds: 12));
      online = response.statusCode >= 200 && response.statusCode < 300;
      if (online) await syncAll();
    } catch (_) {
      online = false;
      notifyListeners();
    }
  }

  void advanceComplaint(Complaint complaint) {
    const states = ['Reported', 'Assigned', 'In Progress', 'Resolved'];
    final current = states.indexOf(complaint.status);
    if (current >= 0 && current < states.length - 1) {
      complaint.status = states[current + 1];
      notifyListeners();
      unawaited(_patchComplaint(complaint));
    }
  }

  Future<void> _patchComplaint(Complaint complaint) async {
    if (token == null || complaint.id == 'SYNCING') return;
    try {
      final response = await _client
          .patch(
            _uri('/complaints/${Uri.encodeComponent(complaint.id)}'),
            headers: _headers,
            body: jsonEncode({'status': complaint.status}),
          )
          .timeout(const Duration(seconds: 12));
      online = response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      online = false;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _timer.cancel();
    _client.close();
    super.dispose();
  }
}

final campusStore = CampusStore();

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
          margin: EdgeInsets.zero,
          color: Colors.white,
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
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool admin = false;
  bool loading = false;
  String? error;
  final idController = TextEditingController(text: 'student@campuslive.demo');
  final passwordController = TextEditingController(text: 'Campus@123');

  Future<void> login() async {
    setState(() {
      loading = true;
      error = null;
    });

    final ok = await campusStore.login(
      idController.text,
      passwordController.text,
      expectedRole: admin ? 'admin' : 'student',
    );

    if (!mounted) return;

    if (ok) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => admin ? const AdminShell() : const StudentShell(),
        ),
      );
    } else {
      setState(() {
        error = 'Login failed. Check credentials or network.';
      });
    }

    if (mounted) setState(() => loading = false);
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
                        colors: [AppColors.blue, AppColors.cyan],
                      ),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
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
                  const SizedBox(height: 6),
                  const Text(
                    'Your whole college. One live app.',
                    style: TextStyle(color: Colors.white60),
                  ),
                  const SizedBox(height: 28),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                value: false,
                                icon: Icon(Icons.person_outline),
                                label: Text('Student'),
                              ),
                              ButtonSegment(
                                value: true,
                                icon: Icon(Icons.admin_panel_settings_outlined),
                                label: Text('Admin'),
                              ),
                            ],
                            selected: {admin},
                            onSelectionChanged: (value) {
                              setState(() {
                                admin = value.first;
                                idController.text = admin
                                    ? 'admin@campuslive.demo'
                                    : 'student@campuslive.demo';
                              });
                            },
                          ),
                          const SizedBox(height: 18),
                          TextField(
                            controller: idController,
                            decoration: const InputDecoration(
                              labelText: 'College ID / Email',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                          ),
                          if (error != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              error!,
                              style: const TextStyle(
                                color: AppColors.red,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          FilledButton(
                            onPressed: loading ? null : login,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.blue,
                              minimumSize: const Size.fromHeight(52),
                            ),
                            child: loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(admin ? 'Open Admin' : 'Enter CampusLive'),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            admin
                                ? 'admin@campuslive.demo / Campus@123'
                                : 'student@campuslive.demo / Campus@123',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
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

class StudentShell extends StatefulWidget {
  const StudentShell({super.key});

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  int index = 0;
  final pages = const [
    HomePage(),
    AcademicPage(),
    CampusPage(),
    ServicesPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: pages[index]),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CampusAiPage()),
        ),
        child: const Icon(Icons.auto_awesome_rounded),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: NavigationBar(
        height: 72,
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE8EDFF),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school_rounded),
            label: 'Academic',
          ),
          NavigationDestination(
            icon: SizedBox(width: 30),
            label: '',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Services',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader(this.title, this.subtitle, {super.key});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: () => showSearch(
            context: context,
            delegate: CollegeSearchDelegate(),
          ),
          icon: const Icon(Icons.search_rounded),
        ),
        const SizedBox(width: 5),
        IconButton.filledTonal(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsPage()),
          ),
          icon: const Badge(
            smallSize: 8,
            child: Icon(Icons.notifications_none_rounded),
          ),
        ),
      ],
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: AppColors.navy,
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: campusStore,
      builder: (context, _) {
        final next = campusStore.timetable.firstWhere(
          (item) => item.subject != 'Break' && item.subject != 'Lunch',
          orElse: () => TimetableItem(
            '11:30',
            'Engineering Thermodynamics',
            'M204',
            'Dr. Kumar',
          ),
        );

        return RefreshIndicator(
          onRefresh: campusStore.syncAll,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 110),
            children: [
              PageHeader(
                'Good morning, ' + campusStore.userName + ' 👋',
                campusStore.department +
                    ' • Year ' +
                    campusStore.year +
                    ' • Section ' +
                    campusStore.section,
              ),
              const SizedBox(height: 18),
              const CampusLiveHero(),
              const SizedBox(height: 14),
              const SectionTitle('My day'),
              const SizedBox(height: 10),
              Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => openModule(context, 'Timetable'),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFECF1FF),
                      foregroundColor: AppColors.blue,
                      child: Icon(Icons.menu_book_rounded),
                    ),
                    title: Text(
                      next.subject,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    subtitle: Text(
                      'Next class • ' +
                          next.time +
                          ' • ' +
                          next.room +
                          ' • ' +
                          next.faculty,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: MiniCard(
                      icon: Icons.directions_bus_filled_rounded,
                      title: 'My Bus',
                      value: campusStore.busCode.isEmpty
                          ? 'Not assigned'
                          : campusStore.busEta.toString() + ' min',
                      foot: campusStore.busCode.isEmpty
                          ? campusStore.studentType
                          : campusStore.busDisplay +
                              ' • ' +
                              campusStore.boardingStop,
                      color: AppColors.blue,
                      onTap: () => openModule(context, 'Transport'),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: MiniCard(
                      icon: Icons.how_to_reg_rounded,
                      title: 'Attendance',
                      value: campusStore.attendancePercent.toString() + '%',
                      foot: campusStore.attendancePercent >= 75
                          ? 'On track'
                          : 'Needs attention',
                      color: AppColors.green,
                      onTap: () => openModule(context, 'Attendance'),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: MiniCard(
                      icon: Icons.assignment_rounded,
                      title: 'Assignments',
                      value: campusStore.assignmentsDue.toString() + ' due',
                      foot: 'My pending work',
                      color: AppColors.orange,
                      onTap: () => openModule(context, 'Assignments'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const SectionTitle('My quick access'),
              const SizedBox(height: 10),
              const CollegeGrid(),
              const SizedBox(height: 18),
              const SectionTitle('For me'),
              const SizedBox(height: 10),
              Card(
                child: Column(
                  children: [
                    for (var i = 0;
                        i < campusStore.announcements.length && i < 4;
                        i++) ...[
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFEEF2FF),
                          foregroundColor: AppColors.blue,
                          child: Icon(Icons.campaign_outlined),
                        ),
                        title: Text(
                          campusStore.announcements[i],
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (i < campusStore.announcements.length - 1 && i < 3)
                        const Divider(
                          height: 1,
                          indent: 70,
                          color: AppColors.line,
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const SectionTitle('My placement'),
              const SizedBox(height: 10),
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(15),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFF0EDFF),
                    foregroundColor: AppColors.purple,
                    child: Icon(Icons.work_rounded),
                  ),
                  title: Text(
                    campusStore.placementEligible
                        ? campusStore.placementCompany +
                            ' • ' +
                            campusStore.placementRole
                        : 'Placement eligibility',
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  subtitle: Text(
                    campusStore.placementEligible
                        ? campusStore.placementRound +
                            ' round • Queue #' +
                            campusStore.placementQueue.toString()
                        : 'Current CGPA ' +
                            campusStore.cgpa.toStringAsFixed(2),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => openModule(context, 'Placement'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class CampusLiveHero extends StatelessWidget {
  const CampusLiveHero({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.navy, Color(0xFF1C3A7C)],
          ),
          borderRadius: BorderRadius.circular(26),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bolt_rounded, color: AppColors.cyan),
                SizedBox(width: 7),
                Text(
                  'CAMPUS LIVE',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                Spacer(),
                Chip(
                  label: Text('LIVE'),
                  side: BorderSide.none,
                  backgroundColor: Color(0x3322C55E),
                  labelStyle: TextStyle(
                    color: Color(0xFF70F0A7),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Text(
              'Everything happening in college,\norganized in one place.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                height: 1.2,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                HeroMetric('9', 'Classes live'),
                HeroMetric('14', 'Buses active'),
                HeroMetric('6', 'Events'),
              ],
            ),
          ],
        ),
      );
}

class HeroMetric extends StatelessWidget {
  const HeroMetric(this.value, this.label, {super.key});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 10,
              ),
            ),
          ],
        ),
      );
}

class MiniCard extends StatelessWidget {
  const MiniCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.foot,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final String foot;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 21),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 10,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  foot,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class CollegeGrid extends StatelessWidget {
  const CollegeGrid({super.key});

  @override
  Widget build(BuildContext context) {
    const items = [
      ('Timetable', Icons.calendar_month_rounded, AppColors.purple, 'Timetable'),
      ('Attendance', Icons.how_to_reg_rounded, AppColors.green, 'Attendance'),
      ('Assignments', Icons.assignment_rounded, AppColors.orange, 'Assignments'),
      ('My Bus', Icons.directions_bus_rounded, AppColors.blue, 'Transport'),
      ('My Labs', Icons.computer_rounded, AppColors.cyan, 'Labs'),
      ('Library', Icons.local_library_rounded, AppColors.purple, 'Library'),
      ('Placement', Icons.work_rounded, AppColors.blue, 'Placement'),
      ('Events', Icons.event_rounded, AppColors.green, 'Events'),
      ('Complaints', Icons.build_circle_rounded, AppColors.red, 'Complaints'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 9,
        mainAxisSpacing: 9,
        childAspectRatio: .95,
      ),
      itemBuilder: (_, i) {
        final item = items[i];
        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => openModule(context, item.$4),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 7,
                vertical: 11,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: item.$3.withOpacity(.10),
                    foregroundColor: item.$3,
                    child: Icon(item.$2, size: 19),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.$1,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class AcademicPage extends StatelessWidget {
  const AcademicPage({super.key});

  @override
  Widget build(BuildContext context) {
    const items = [
      ('Timetable', Icons.calendar_month_rounded),
      ('Attendance', Icons.how_to_reg_rounded),
      ('Assignments', Icons.assignment_rounded),
      ('Tests & Exams', Icons.quiz_rounded),
      ('Marks', Icons.bar_chart_rounded),
      ('Materials', Icons.folder_copy_rounded),
      ('My Faculty', Icons.people_alt_rounded),
      ('My Labs', Icons.science_rounded),
    ];

    return AnimatedBuilder(
      animation: campusStore,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 110),
        children: [
          const PageHeader(
            'My Academic',
            'Only your course, section and semester',
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 27,
                  backgroundColor: Color(0xFF28457E),
                  child: Icon(
                    Icons.precision_manufacturing_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        campusStore.department,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Year ' +
                            campusStore.year +
                            ' • Section ' +
                            campusStore.section +
                            ' • Semester ' +
                            campusStore.semester,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const SectionTitle('My academic tools'),
          const SizedBox(height: 10),
          GridView.builder(
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
              final route = item.$1 == 'My Faculty'
                  ? 'Faculty'
                  : item.$1 == 'My Labs'
                      ? 'Labs'
                      : item.$1;
              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => openModule(context, route),
                  child: Padding(
                    padding: const EdgeInsets.all(13),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFFECF1FF),
                          foregroundColor: AppColors.blue,
                          child: Icon(item.$2, size: 19),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.$1,
                            style: const TextStyle(
                              color: AppColors.navy,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFEEF2FF),
                foregroundColor: AppColors.blue,
                child: Icon(Icons.insights_rounded),
              ),
              title: Text(
                'Attendance ' +
                    campusStore.attendancePercent.toString() +
                    '% • CGPA ' +
                    campusStore.cgpa.toStringAsFixed(2),
                style: const TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w900,
                ),
              ),
              subtitle: Text(
                campusStore.assignmentsDue.toString() +
                    ' assignments pending',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DepartmentList extends StatelessWidget {
  const DepartmentList({super.key});

  @override
  Widget build(BuildContext context) {
    const departments = [
      'Mechanical Engineering',
      'Computer Science & Engineering',
      'Artificial Intelligence & ML',
      'Electronics & Communication',
      'Electrical & Electronics',
      'Civil Engineering',
      'Information Technology',
      'Science & Humanities',
    ];

    return Card(
      child: Column(
        children: [
          for (var i = 0; i < departments.length; i++) ...[
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFF0F3F9),
                foregroundColor: AppColors.navy,
                child: Icon(Icons.apartment_rounded, size: 18),
              ),
              title: Text(
                departments[i],
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => openModule(context, departments[i]),
            ),
            if (i != departments.length - 1)
              const Divider(height: 1, indent: 68, color: AppColors.line),
          ],
        ],
      ),
    );
  }
}

class CampusPage extends StatelessWidget {
  const CampusPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: campusStore,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 110),
          children: [
            const PageHeader(
              'Campus',
              'Rooms, labs, buildings and transport',
            ),
            const SizedBox(height: 18),
            Container(
              height: 170,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF0FF),
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Stack(
                children: [
                  Positioned(
                    left: 10,
                    top: 8,
                    child: MapBlock('MAIN', AppColors.blue),
                  ),
                  Positioned(
                    right: 16,
                    top: 20,
                    child: MapBlock('CSE', AppColors.purple),
                  ),
                  Positioned(
                    left: 105,
                    bottom: 18,
                    child: MapBlock('MECH', AppColors.orange),
                  ),
                  Positioned(
                    right: 28,
                    bottom: 12,
                    child: MapBlock('LIB', AppColors.green),
                  ),
                  Positioned(
                    left: 12,
                    bottom: 5,
                    child: Text(
                      'Interactive campus map',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const SectionTitle('Live rooms'),
            const SizedBox(height: 10),
            for (final room in campusStore.rooms.take(4))
              Card(
                margin: const EdgeInsets.only(bottom: 9),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: room.available
                        ? const Color(0xFFEAF9F1)
                        : const Color(0xFFFFEEEE),
                    foregroundColor:
                        room.available ? AppColors.green : AppColors.red,
                    child: Text(
                      room.name,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  title: Text(
                    room.available ? 'Available' : 'Occupied',
                    style: TextStyle(
                      color:
                          room.available ? AppColors.green : AppColors.red,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  subtitle: Text(room.block + ' • ' + room.note),
                  onTap: () => openModule(context, 'Rooms'),
                ),
              ),
            const SizedBox(height: 10),
            const SectionTitle('Transport'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: Color(0xFF24375F),
                    foregroundColor: Colors.white,
                    child: Icon(Icons.directions_bus_filled),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BUS 07 • Udumalpet Route',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Live demo route status',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    campusStore.busEta.toString() + ' min',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class MapBlock extends StatelessWidget {
  const MapBlock(this.label, this.color, {super.key});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 66,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}

class ServicesPage extends StatelessWidget {
  const ServicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    const items = [
      ('Placement', Icons.work_rounded, AppColors.purple),
      ('Events', Icons.event_rounded, AppColors.green),
      ('Complaints', Icons.build_circle_rounded, AppColors.orange),
      ('Lost & Found', Icons.search_rounded, AppColors.cyan),
      ('Certificates', Icons.article_rounded, AppColors.blue),
      ('Fees', Icons.payments_outlined, AppColors.green),
      ('Transport', Icons.directions_bus_rounded, AppColors.orange),
      ('Library', Icons.local_library_rounded, AppColors.purple),
      ('Canteen', Icons.restaurant_rounded, AppColors.red),
      ('Sports', Icons.sports_rounded, AppColors.cyan),
      ('Hostel', Icons.home_work_rounded, AppColors.blue),
      ('Help Desk', Icons.help_center_rounded, AppColors.red),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 110),
      children: [
        const PageHeader(
          'Services',
          'Everything you need outside class',
        ),
        const SizedBox(height: 18),
        GridView.builder(
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
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => openModule(context, item.$1),
                child: Padding(
                  padding: const EdgeInsets.all(13),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: item.$3.withOpacity(.10),
                        foregroundColor: item.$3,
                        child: Icon(item.$2, size: 19),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.$1,
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 18),
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFFFEDEC),
              foregroundColor: AppColors.red,
              child: Icon(Icons.emergency_rounded),
            ),
            title: const Text(
              'Campus Emergency',
              style: TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w900,
              ),
            ),
            subtitle: const Text('Medical • Security • Fire • Accident'),
            trailing: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.red,
              ),
              onPressed: () => openModule(context, 'Emergency'),
              child: const Text('SOS'),
            ),
          ),
        ),
      ],
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 110),
        children: [
          const PageHeader(
            'Profile',
            'College identity and preferences',
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.blue, AppColors.cyan],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Text(
                      'VS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vishnu S',
                          style: TextStyle(
                            color: AppColors.navy,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'B.E. Mechanical Engineering',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '25ME103 • Year 2 • Section A',
                          style: TextStyle(
                            color: AppColors.blue,
                            fontSize: 10,
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
          const SizedBox(height: 14),
          const ProfileTile(
            Icons.badge_outlined,
            'Student ID',
            '25ME103',
          ),
          const ProfileTile(
            Icons.school_outlined,
            'Academic profile',
            'Mechanical • Year 2 • Section A',
          ),
          const ProfileTile(
            Icons.directions_bus_outlined,
            'My transport',
            'Bus 07 • Udumalpet route',
          ),
          const ProfileTile(
            Icons.language_rounded,
            'Language',
            'English',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => logout(context),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Logout'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ],
      );
}

class ProfileTile extends StatelessWidget {
  const ProfileTile(
    this.icon,
    this.title,
    this.subtitle, {
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 9),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFFEEF2FF),
            foregroundColor: AppColors.blue,
            child: Icon(icon, size: 19),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      );
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: moduleAppBar('Notifications'),
        body: AnimatedBuilder(
          animation: campusStore,
          builder: (context, _) => ListView.builder(
            padding: const EdgeInsets.all(18),
            itemCount: campusStore.announcements.length,
            itemBuilder: (_, i) => Card(
              margin: const EdgeInsets.only(bottom: 9),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEEF2FF),
                  foregroundColor: AppColors.blue,
                  child: Icon(Icons.notifications_active_outlined),
                ),
                title: Text(campusStore.announcements[i]),
              ),
            ),
          ),
        ),
      );
}

class ModulePage extends StatelessWidget {
  const ModulePage(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) {
    if (title == 'Timetable') return const TimetablePage();
    if (title == 'Rooms') return const RoomsPage();
    if (title == 'Transport') return const TransportPage();
    if (title == 'Placement') return const PlacementPage();
    if (title == 'Events') return const EventsPage();
    if (title == 'Complaints') return const ComplaintsPage();
    if (title == 'Emergency') return const EmergencyPage();
    return GenericModulePage(title);
  }
}

class TimetablePage extends StatelessWidget {
  const TimetablePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: moduleAppBar('Timetable'),
        body: AnimatedBuilder(
          animation: campusStore,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(18),
            children: [
              ModuleHero(
                Icons.calendar_month_rounded,
                campusStore.online ? 'Live timetable' : 'Offline timetable',
                'Semester 3 • Today',
                AppColors.blue,
              ),
              const SizedBox(height: 14),
              for (final row in campusStore.timetable)
                Card(
                  margin: const EdgeInsets.only(bottom: 9),
                  child: ListTile(
                    leading: Text(
                      row.time,
                      style: const TextStyle(
                        color: AppColors.blue,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    title: Text(
                      row.subject,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(row.room + ' • ' + row.faculty),
                  ),
                ),
            ],
          ),
        ),
      );
}

class RoomsPage extends StatelessWidget {
  const RoomsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: moduleAppBar('Live Rooms'),
        body: AnimatedBuilder(
          animation: campusStore,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const ModuleHero(
                Icons.meeting_room_rounded,
                'Find a free room',
                'Live demo availability',
                AppColors.green,
              ),
              const SizedBox(height: 14),
              for (final room in campusStore.rooms)
                Card(
                  margin: const EdgeInsets.only(bottom: 9),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: room.available
                          ? const Color(0xFFEAF9F1)
                          : const Color(0xFFFFEEEE),
                      foregroundColor:
                          room.available ? AppColors.green : AppColors.red,
                      child: Text(
                        room.name,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    title: Text(
                      room.available ? 'Available' : 'Occupied',
                      style: TextStyle(
                        color: room.available
                            ? AppColors.green
                            : AppColors.red,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    subtitle: Text(room.block + ' • ' + room.note),
                  ),
                ),
            ],
          ),
        ),
      );
}

class TransportPage extends StatelessWidget {
  const TransportPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: moduleAppBar('Transport'),
        body: AnimatedBuilder(
          animation: campusStore,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(18),
            children: [
              ModuleHero(
                Icons.directions_bus_filled_rounded,
                'BUS 07',
                'ETA ' + campusStore.busEta.toString() + ' minutes',
                AppColors.orange,
              ),
              const SizedBox(height: 14),
              for (final stop in const [
                'Udumalpet • Started',
                'Chinnampalayam • Passed',
                'Pollachi Road • Current area',
                'Kinathukadavu • Next',
                'Campus • Destination',
              ])
                Card(
                  margin: const EdgeInsets.only(bottom: 9),
                  child: ListTile(
                    leading: const Icon(
                      Icons.radio_button_checked_rounded,
                      color: AppColors.blue,
                    ),
                    title: Text(stop),
                  ),
                ),
            ],
          ),
        ),
      );
}

class PlacementPage extends StatelessWidget {
  const PlacementPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: moduleAppBar('Placement'),
        body: AnimatedBuilder(
          animation: campusStore,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(18),
            children: [
              ModuleHero(
                Icons.work_rounded,
                campusStore.placementCompany,
                campusStore.placementRole + ' • ' + campusStore.placementRound + ' Round',
                AppColors.purple,
              ),
              const SizedBox(height: 14),
              const StageTile('Aptitude', 'Qualified', true),
              const StageTile('Coding', 'Qualified', true),
              StageTile(
                'Technical',
                'Queue #${campusStore.placementQueue} • approx ${campusStore.placementEta} min',
                false,
              ),
              const StageTile('HR', 'Not started', false),
            ],
          ),
        ),
      );
}

class StageTile extends StatelessWidget {
  const StageTile(this.title, this.detail, this.done, {super.key});
  final String title;
  final String detail;
  final bool done;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 9),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor:
                done ? const Color(0xFFEAF9F1) : const Color(0xFFEEF2FF),
            foregroundColor:
                done ? AppColors.green : AppColors.blue,
            child: Icon(done ? Icons.check_rounded : Icons.schedule_rounded),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w900,
            ),
          ),
          subtitle: Text(detail),
        ),
      );
}

class EventsPage extends StatelessWidget {
  const EventsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: moduleAppBar('Events'),
        body: AnimatedBuilder(
          animation: campusStore,
          builder: (context, _) => ListView.builder(
            padding: const EdgeInsets.all(18),
            itemCount: campusStore.events.length,
            itemBuilder: (_, i) {
              final event = campusStore.events[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFEAF9F1),
                    foregroundColor: AppColors.green,
                    child: Icon(Icons.event_rounded),
                  ),
                  title: Text(
                    event.title,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  subtitle: Text(
                    event.date + ' • ' + event.seatsLeft.toString() + ' seats left',
                  ),
                  trailing: FilledButton.tonal(
                    onPressed: event.registered
                        ? null
                        : () => campusStore.registerEvent(event),
                    child: Text(event.registered ? 'Joined' : 'Register'),
                  ),
                ),
              );
            },
          ),
        ),
      );
}

class ComplaintsPage extends StatefulWidget {
  const ComplaintsPage({super.key});

  @override
  State<ComplaintsPage> createState() => _ComplaintsPageState();
}

class _ComplaintsPageState extends State<ComplaintsPage> {
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: moduleAppBar('Complaints'),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => showComplaintDialog(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('New complaint'),
        ),
        body: AnimatedBuilder(
          animation: campusStore,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(18),
            children: [
              for (final item in campusStore.complaints)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFFF4E7),
                      foregroundColor: AppColors.orange,
                      child: Icon(Icons.build_circle_outlined),
                    ),
                    title: Text(
                      item.id + ' • ' + item.place,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    subtitle: Text(item.issue),
                    trailing: Chip(
                      label: Text(
                        item.status,
                        style: const TextStyle(fontSize: 9),
                      ),
                      side: BorderSide.none,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}

class EmergencyPage extends StatelessWidget {
  const EmergencyPage({super.key});

  Future<void> request(BuildContext context, String label) async {
    final sent = await campusStore.sendEmergency(label);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(sent ? 'Emergency acknowledged' : 'Offline fallback'),
        content: Text(
          sent
              ? label + ' request was recorded by CampusLive backend.'
              : 'Backend is temporarily unavailable. Use the college emergency contact directly for a real emergency.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: moduleAppBar('Emergency'),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            ModuleHero(
              Icons.emergency_rounded,
              'Campus Emergency',
              campusStore.online
                  ? 'Connected to CampusLive backend'
                  : 'Offline fallback — use official emergency channels for real incidents',
              AppColors.red,
            ),
            const SizedBox(height: 14),
            for (final label in const [
              'Medical Emergency',
              'Security Issue',
              'Fire',
              'Accident',
            ])
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  trailing: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.red,
                    ),
                    onPressed: () => request(context, label),
                    child: const Text('Request'),
                  ),
                ),
              ),
          ],
        ),
      );
}

class GenericModulePage extends StatelessWidget {
  const GenericModulePage(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) {
    final rows = genericRows(title);
    return Scaffold(
      appBar: moduleAppBar(title),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          ModuleHero(
            Icons.grid_view_rounded,
            title,
            'CampusLive ' + title + ' module',
            AppColors.blue,
          ),
          const SizedBox(height: 14),
          for (final row in rows)
            Card(
              margin: const EdgeInsets.only(bottom: 9),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEEF2FF),
                  foregroundColor: AppColors.blue,
                  child: Icon(Icons.arrow_outward_rounded),
                ),
                title: Text(
                  row,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

List<String> genericRows(String title) {
  if (title == 'Attendance') {
    return [
      'Engineering Mechanics — 86%',
      'Thermodynamics — 91%',
      'Material Science — 82%',
      'CAD Lab — 94%',
    ];
  }
  if (title == 'Marks') {
    return [
      'Internal Test 1 — 78%',
      'Internal Test 2 — 82%',
      'CAD Practical — 88%',
      'Semester CGPA — 7.64',
    ];
  }
  if (title == 'Labs') {
    return campusStore.labs.map((lab) {
      final suffix = lab.note.isEmpty ? '' : ' • ' + lab.note;
      return lab.name +
          ' — ' +
          lab.available.toString() +
          '/' +
          lab.total.toString() +
          ' available' +
          suffix;
    }).toList();
  }
  if (title == 'Library') {
    return [
      campusStore.libraryOpen ? 'Library — Open' : 'Library — Closed',
      'Closes at ' + campusStore.libraryCloses,
      campusStore.librarySeats.toString() + ' seats currently available',
      'Mechanical books — ' + campusStore.libraryTitles.toString() + ' titles',
    ];
  }
  if (title == 'Canteen') {
    return [
      campusStore.canteenOpen ? 'Main canteen — Open' : 'Main canteen — Closed',
      ...campusStore.canteenWindows,
    ];
  }
  return [
    title + ' overview',
    title + ' latest updates',
    title + ' requests and status',
    title + ' help and contacts',
  ];
}

class ModuleHero extends StatelessWidget {
  const ModuleHero(
    this.icon,
    this.title,
    this.subtitle,
    this.color, {
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color.withOpacity(.10),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
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
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class CampusAiPage extends StatefulWidget {
  const CampusAiPage({super.key});

  @override
  State<CampusAiPage> createState() => _CampusAiPageState();
}

class _CampusAiPageState extends State<CampusAiPage> {
  final controller = TextEditingController();
  final List<(String, bool)> messages = [
    (
      'Hi Vishnu 👋 Ask me about timetable, rooms, buses, labs, library, events or placement.',
      false,
    ),
  ];

  void send() {
    final value = controller.text.trim();
    if (value.isEmpty) return;
    setState(() {
      messages.add((value, true));
      messages.add((aiReply(value), false));
      controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: moduleAppBar('Campus AI'),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(18),
                itemCount: messages.length,
                itemBuilder: (_, i) {
                  final message = messages[i];
                  return Align(
                    alignment: message.$2
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 315),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: message.$2 ? AppColors.blue : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        message.$1,
                        style: TextStyle(
                          color: message.$2 ? Colors.white : AppColors.navy,
                          height: 1.4,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
                child: TextField(
                  controller: controller,
                  onSubmitted: (_) => send(),
                  decoration: InputDecoration(
                    hintText: 'Ask anything about college...',
                    prefixIcon: const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.blue,
                    ),
                    suffixIcon: IconButton(
                      onPressed: send,
                      icon: const Icon(Icons.arrow_upward_rounded),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

String aiReply(String input) {
  final q = input.toLowerCase();
  if (q.contains('class')) {
    return 'Your next class is Engineering Thermodynamics at 11:30 AM in M204.';
  }
  if (q.contains('bus')) {
    return 'Bus 07 is approximately ' +
        campusStore.busEta.toString() +
        ' minutes away in this live demo.';
  }
  if (q.contains('room')) {
    final names = campusStore.rooms
        .where((room) => room.available)
        .map((room) => room.name)
        .join(', ');
    return 'Available rooms now: ' + names + '.';
  }
  if (q.contains('lab')) {
    return 'CAD Lab has 21 systems free. AI Lab has 42 systems free.';
  }
  if (q.contains('library')) {
    return 'Main Library is open until 8 PM with about 182 seats available.';
  }
  if (q.contains('placement') || q.contains('zoho')) {
    return 'Zoho drive: Technical Round, queue #7.';
  }
  if (q.contains('event')) {
    return 'Upcoming: EV Design Workshop, TechFest 2026 and CAD Sprint Challenge.';
  }
  return 'I can help with timetable, rooms, transport, labs, library, placement, events and college services.';
}

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int index = 0;
  final pages = const [
    AdminOverviewPage(),
    AdminOperationsPage(),
    AdminBroadcastPage(),
    AdminProfilePage(),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(child: pages[index]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (value) => setState(() => index = value),
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFE8EDFF),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'Overview',
            ),
            NavigationDestination(
              icon: Icon(Icons.tune_outlined),
              selectedIcon: Icon(Icons.tune_rounded),
              label: 'Operations',
            ),
            NavigationDestination(
              icon: Icon(Icons.campaign_outlined),
              selectedIcon: Icon(Icons.campaign_rounded),
              label: 'Broadcast',
            ),
            NavigationDestination(
              icon: Icon(Icons.admin_panel_settings_outlined),
              selectedIcon: Icon(Icons.admin_panel_settings_rounded),
              label: 'Admin',
            ),
          ],
        ),
      );
}

class AdminOverviewPage extends StatelessWidget {
  const AdminOverviewPage({super.key});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: campusStore,
        builder: (context, _) {
          final freeRooms =
              campusStore.rooms.where((room) => room.available).length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 90),
            children: [
              const PageHeader(
                'CampusLive Admin',
                'Whole-college operations control center',
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.navy,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    const AdminMetric('2,081', 'Students online'),
                    const AdminMetric('14', 'Buses active'),
                    AdminMetric(
                      campusStore.complaints.length.toString(),
                      'Issues',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const SectionTitle('Campus health'),
              const SizedBox(height: 10),
              AdminStatus(
                Icons.meeting_room_outlined,
                'Rooms',
                freeRooms.toString() +
                    ' / ' +
                    campusStore.rooms.length.toString() +
                    ' demo rooms free',
                AppColors.green,
              ),
              const AdminStatus(
                Icons.computer_outlined,
                'Labs',
                '126 systems available',
                AppColors.blue,
              ),
              AdminStatus(
                Icons.directions_bus_outlined,
                'Transport',
                campusStore.busOnTime
                    ? 'Demo bus on time'
                    : 'Minor demo delay',
                campusStore.busOnTime
                    ? AppColors.green
                    : AppColors.orange,
              ),
              const AdminStatus(
                Icons.emergency_outlined,
                'Emergency',
                'No active emergency',
                AppColors.green,
              ),
              const SizedBox(height: 18),
              const SectionTitle('Announcements'),
              const SizedBox(height: 10),
              Card(
                child: Column(
                  children: [
                    for (final item in campusStore.announcements.take(4))
                      ListTile(
                        leading: const Icon(
                          Icons.campaign_outlined,
                          color: AppColors.blue,
                        ),
                        title: Text(item),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      );
}

class AdminMetric extends StatelessWidget {
  const AdminMetric(this.value, this.label, {super.key});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 9.5,
              ),
            ),
          ],
        ),
      );
}

class AdminStatus extends StatelessWidget {
  const AdminStatus(
    this.icon,
    this.title,
    this.value,
    this.color, {
    super.key,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 9),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withOpacity(.10),
            foregroundColor: color,
            child: Icon(icon),
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

class AdminOperationsPage extends StatelessWidget {
  const AdminOperationsPage({super.key});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: campusStore,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 90),
          children: [
            const PageHeader(
              'Operations',
              'Manage live college modules',
            ),
            const SizedBox(height: 18),
            const SectionTitle('Room control'),
            const SizedBox(height: 10),
            for (final room in campusStore.rooms)
              Card(
                margin: const EdgeInsets.only(bottom: 9),
                child: SwitchListTile(
                  secondary: CircleAvatar(
                    backgroundColor: room.available
                        ? const Color(0xFFEAF9F1)
                        : const Color(0xFFFFEEEE),
                    foregroundColor:
                        room.available ? AppColors.green : AppColors.red,
                    child: Text(
                      room.name,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  title: Text(
                    room.name + ' • ' + room.block,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  subtitle: Text(room.note),
                  value: room.available,
                  onChanged: (_) => campusStore.toggleRoom(room),
                ),
              ),
            const SizedBox(height: 16),
            const SectionTitle('Complaint workflow'),
            const SizedBox(height: 10),
            for (final item in campusStore.complaints)
              Card(
                margin: const EdgeInsets.only(bottom: 9),
                child: ListTile(
                  title: Text(
                    item.id + ' • ' + item.place,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  subtitle: Text(item.issue + ' • ' + item.status),
                  trailing: IconButton(
                    onPressed: () => campusStore.advanceComplaint(item),
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                ),
              ),
          ],
        ),
      );
}

class AdminBroadcastPage extends StatefulWidget {
  const AdminBroadcastPage({super.key});

  @override
  State<AdminBroadcastPage> createState() => _AdminBroadcastPageState();
}

class _AdminBroadcastPageState extends State<AdminBroadcastPage> {
  final controller = TextEditingController();

  void send() {
    final message = controller.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an announcement.')),
      );
      return;
    }
    campusStore.broadcast(message);
    controller.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Announcement added to live feed.')),
    );
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 90),
        children: [
          const PageHeader(
            'Broadcast',
            'Send targeted college updates',
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  TextField(
                    controller: controller,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Announcement',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: send,
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Send broadcast'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
}

class AdminProfilePage extends StatelessWidget {
  const AdminProfilePage({super.key});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 90),
        children: [
          const PageHeader(
            'Admin',
            'System access and college setup',
          ),
          const SizedBox(height: 18),
          for (final item in const [
            ('College master data', Icons.account_tree_outlined),
            ('Departments', Icons.apartment_outlined),
            ('Students & Faculty', Icons.groups_outlined),
            ('Data imports', Icons.upload_file_outlined),
            ('Roles & permissions', Icons.security_outlined),
            ('Audit log', Icons.history_rounded),
            ('Reports & analytics', Icons.analytics_outlined),
          ])
            Card(
              margin: const EdgeInsets.only(bottom: 9),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFEEF2FF),
                  foregroundColor: AppColors.blue,
                  child: Icon(item.$2),
                ),
                title: Text(
                  item.$1,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => logout(context),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Logout Admin'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ],
      );
}

class CollegeSearchDelegate extends SearchDelegate<String> {
  final items = const [
    'Mechanical Engineering',
    'Computer Science & Engineering',
    'AI & ML Department',
    'M201 Classroom',
    'M204 Classroom',
    'CAD Lab',
    'AI Lab',
    'Main Library',
    'Bus 07',
    'Udumalpet Route',
    'Placement',
    'EV Design Workshop',
    'Auditorium',
    'Canteen',
    'Sports Complex',
    'Lost & Found',
    'Help Desk',
  ];

  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(
          onPressed: () => query = '',
          icon: const Icon(Icons.clear_rounded),
        ),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        onPressed: () => close(context, ''),
        icon: const Icon(Icons.arrow_back_rounded),
      );

  @override
  Widget buildResults(BuildContext context) => results(context);

  @override
  Widget buildSuggestions(BuildContext context) => results(context);

  Widget results(BuildContext context) {
    final filtered = items
        .where((item) => item.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return ListView(
      children: [
        for (final item in filtered)
          ListTile(
            leading: const Icon(Icons.search_rounded),
            title: Text(item),
            onTap: () {
              close(context, item);
              openModule(context, item);
            },
          ),
      ],
    );
  }
}

PreferredSizeWidget moduleAppBar(String title) => AppBar(
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.navy,
          fontWeight: FontWeight.w900,
        ),
      ),
    );

void openModule(BuildContext context, String title) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => ModulePage(title)),
  );
}

void logout(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginPage()),
    (_) => false,
  );
}

Future<void> showComplaintDialog(BuildContext context) async {
  final place = TextEditingController(text: 'M204');
  final issue = TextEditingController();

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('New complaint'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: place,
            decoration: const InputDecoration(labelText: 'Location'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: issue,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Problem'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (issue.text.trim().isEmpty) return;
            campusStore.addComplaint(
              place.text.trim(),
              issue.text.trim(),
            );
            Navigator.pop(dialogContext);
          },
          child: const Text('Submit'),
        ),
      ],
    ),
  );
}
