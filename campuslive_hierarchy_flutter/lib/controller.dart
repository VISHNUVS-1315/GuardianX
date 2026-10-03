import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'models.dart';

class ApiError implements Exception {
  ApiError(this.message);
  final String message;
  @override
  String toString() => message;
}

class AppController extends ChangeNotifier {
  static const apiBase = 'https://campuslive-hierarchy-api.onrender.com';

  final http.Client _client = http.Client();
  WebSocketChannel? _socket;
  StreamSubscription<dynamic>? _socketSub;
  Timer? _heartbeat;

  String? token;
  SessionUser? user;
  bool loading = false;
  bool online = false;
  String? lastError;

  Map<String, dynamic> dashboard = {};
  List<PortalItem> portal = [];
  List<DirectoryUser> directory = [];
  List<InboxItem> inbox = [];
  List<DepartmentItem> departments = [];
  List<AuditItem> auditItems = [];
  List<ChainItem> chainItems = [];

  bool get loggedIn => token != null && user != null;

  Map<String, String> get headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer ' + token!,
      };

  Uri uri(String path) => Uri.parse(apiBase + path);

  Future<dynamic> _request(
    String method,
    String path, {
    Object? body,
    bool authenticated = true,
  }) async {
    http.Response response;
    final h = authenticated
        ? headers
        : const {'Content-Type': 'application/json'};
    final encoded = body == null ? null : jsonEncode(body);

    if (method == 'GET') {
      response = await _client.get(uri(path), headers: h);
    } else if (method == 'POST') {
      response = await _client.post(uri(path), headers: h, body: encoded);
    } else if (method == 'PATCH') {
      response = await _client.patch(uri(path), headers: h, body: encoded);
    } else if (method == 'PUT') {
      response = await _client.put(uri(path), headers: h, body: encoded);
    } else {
      throw ApiError('Unsupported request method');
    }

    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = 'Request failed (' + response.statusCode.toString() + ')';
      if (decoded is Map<String, dynamic> && decoded['detail'] != null) {
        message = decoded['detail'].toString();
      }
      throw ApiError(message);
    }

    online = true;
    return decoded;
  }

  Future<void> login({
    required String collegeCode,
    required String email,
    required String password,
  }) async {
    loading = true;
    lastError = null;
    notifyListeners();

    try {
      final data = await _request(
        'POST',
        '/auth/login',
        authenticated: false,
        body: {
          'college_code': collegeCode.trim(),
          'email': email.trim(),
          'password': password,
        },
      ) as Map<String, dynamic>;

      token = data['token']?.toString();
      user = SessionUser.fromJson(data['user'] as Map<String, dynamic>);
      await refreshAll();
      _connectRealtime();
    } catch (e) {
      online = false;
      lastError = e.toString();
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> setupCollege({
    required String collegeName,
    required String collegeCode,
    required String adminName,
    required String adminEmail,
    required String adminPassword,
  }) async {
    loading = true;
    lastError = null;
    notifyListeners();

    try {
      final data = await _request(
        'POST',
        '/setup/college',
        authenticated: false,
        body: {
          'college_name': collegeName.trim(),
          'college_code': collegeCode.trim(),
          'admin_name': adminName.trim(),
          'admin_email': adminEmail.trim(),
          'admin_password': adminPassword,
        },
      ) as Map<String, dynamic>;

      token = data['token']?.toString();
      user = SessionUser.fromJson(data['user'] as Map<String, dynamic>);
      await refreshAll();
      _connectRealtime();
    } catch (e) {
      online = false;
      lastError = e.toString();
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshAll() async {
    if (!loggedIn) return;

    try {
      final rows = await Future.wait<dynamic>([
        _request('GET', '/portal'),
        _request('GET', '/dashboard'),
        _request('GET', '/directory'),
        _request('GET', '/inbox'),
      ]);

      portal = (rows[0] as List<dynamic>)
          .map((e) => PortalItem.fromJson(e as Map<String, dynamic>))
          .where((e) => e.enabled)
          .toList()
        ..sort((a, b) => a.position.compareTo(b.position));

      dashboard = rows[1] as Map<String, dynamic>;

      directory = (rows[2] as List<dynamic>)
          .map((e) => DirectoryUser.fromJson(e as Map<String, dynamic>))
          .toList();

      inbox = (rows[3] as List<dynamic>)
          .map((e) => InboxItem.fromJson(e as Map<String, dynamic>))
          .toList();

      if (user?.role == 'admin') {
        await Future.wait([
          loadDepartments(),
          loadAudit(),
          loadChain(),
        ]);
      }

      online = true;
      lastError = null;
    } catch (e) {
      online = false;
      lastError = e.toString();
    }

    notifyListeners();
  }

  Future<void> loadDepartments() async {
    if (user?.role != 'admin') return;
    final rows = await _request('GET', '/admin/departments') as List<dynamic>;
    departments = rows
        .map((e) => DepartmentItem.fromJson(e as Map<String, dynamic>))
        .toList();
    notifyListeners();
  }

  Future<void> loadAudit() async {
    if (user?.role != 'admin') return;
    final rows = await _request('GET', '/admin/audit') as List<dynamic>;
    auditItems = rows
        .map((e) => AuditItem.fromJson(e as Map<String, dynamic>))
        .toList();
    notifyListeners();
  }

  Future<void> loadChain() async {
    if (user?.role != 'admin') return;
    final rows =
        await _request('GET', '/admin/assignments') as List<dynamic>;
    chainItems = rows
        .map((e) => ChainItem.fromJson(e as Map<String, dynamic>))
        .toList();
    notifyListeners();
  }

  Future<List<DirectoryUser>> loadAdminUsers() async {
    final rows = await _request('GET', '/admin/users') as List<dynamic>;
    return rows
        .map((e) => DirectoryUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createDepartment({
    required String name,
    required String code,
  }) async {
    await _request(
      'POST',
      '/admin/departments',
      body: {'name': name.trim(), 'code': code.trim()},
    );
    await refreshAll();
  }

  Future<void> createUser({
    required String name,
    required String email,
    required String password,
    required String role,
    int? departmentId,
    String year = '',
    String section = '',
  }) async {
    await _request(
      'POST',
      '/admin/users',
      body: {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        'role': role,
        'department_id': departmentId,
        'year': year.trim(),
        'section': section.trim(),
      },
    );
    await refreshAll();
  }

  Future<void> setUserActive(int userId, bool active) async {
    await _request(
      'PATCH',
      '/admin/users/' + userId.toString(),
      body: {'is_active': active},
    );
    await refreshAll();
  }

  Future<void> sendAssignment({
    required List<int> targetUserIds,
    required String title,
    required String body,
    required String kind,
  }) async {
    await _request(
      'POST',
      '/assignments',
      body: {
        'target_user_ids': targetUserIds,
        'title': title.trim(),
        'body': body.trim(),
        'kind': kind,
      },
    );
    await refreshAll();
  }

  Future<void> markAssignment(int id, String status) async {
    await _request(
      'PATCH',
      '/assignments/' + id.toString(),
      body: {'status': status},
    );
    await refreshAll();
  }

  Future<List<PortalItem>> loadRolePortal(String role) async {
    final rows =
        await _request('GET', '/admin/portal/' + role) as List<dynamic>;
    return rows
        .map((e) => PortalItem.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
  }

  Future<void> saveRolePortal(
    String role,
    List<PortalItem> items,
  ) async {
    for (var i = 0; i < items.length; i++) {
      items[i].position = i;
    }

    await _request(
      'PUT',
      '/admin/portal/' + role,
      body: {
        'items': items.map((e) => e.toJson()).toList(),
      },
    );

    if (user?.role == role) {
      await refreshAll();
    }
  }

  void _connectRealtime() {
    _wsSubscription?.cancel();
    _socket?.sink.close();
    _heartbeat?.cancel();

    if (token == null) return;

    try {
      final wsBase = apiBase
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://');
      final wsUri = Uri.parse(
        wsBase + '/ws?token=' + Uri.encodeQueryComponent(token!),
      );
      _socket = WebSocketChannel.connect(wsUri);
      _wsSubscription = _socket!.stream.listen(
        (_) => unawaited(refreshAll()),
        onError: (_) {},
        onDone: () {},
      );
      _heartbeat = Timer.periodic(
        const Duration(seconds: 25),
        (_) {
          try {
            _socket?.sink.add('ping');
          } catch (_) {}
        },
      );
    } catch (_) {}
  }

  void logout() {
    _heartbeat?.cancel();
    _wsSubscription?.cancel();
    _socket?.sink.close();

    token = null;
    user = null;
    loading = false;
    online = false;
    lastError = null;
    dashboard = {};
    portal = [];
    directory = [];
    inbox = [];
    departments = [];
    auditItems = [];
    chainItems = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _heartbeat?.cancel();
    _wsSubscription?.cancel();
    _socket?.sink.close();
    _client.close();
    super.dispose();
  }
}

final appController = AppController();
