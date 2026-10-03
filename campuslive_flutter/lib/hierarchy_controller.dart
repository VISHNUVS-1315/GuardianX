import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'hierarchy_models.dart';

class ApiError implements Exception {
  ApiError(this.message);
  final String message;
  @override
  String toString() => message;
}

class HierarchyController extends ChangeNotifier {
  static const apiBase = 'https://campuslive-hierarchy-api.onrender.com';

  final http.Client _client = http.Client();
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _wsSub;
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
    Map<String, String>? customHeaders,
  }) async {
    final h = customHeaders ?? headers;
    final encoded = body == null ? null : jsonEncode(body);
    late http.Response response;

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
    if (response.body.trim().isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Request failed (' + response.statusCode.toString() + ')';
      if (decoded is Map<String, dynamic> && decoded['detail'] != null) {
        message = decoded['detail'].toString();
      }
      throw ApiError(message);
    }

    online = true;
    return decoded;
  }

  Future<Map<String, dynamic>> _map(
    String method,
    String path, {
    Object? body,
    Map<String, String>? customHeaders,
  }) async {
    final data = await _request(
      method,
      path,
      body: body,
      customHeaders: customHeaders,
    );
    if (data is Map<String, dynamic>) return data;
    return <String, dynamic>{};
  }

  Future<List<dynamic>> _list(String path) async {
    final data = await _request('GET', path);
    return data is List<dynamic> ? data : <dynamic>[];
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
      final data = await _map(
        'POST',
        '/auth/login',
        customHeaders: const {'Content-Type': 'application/json'},
        body: {
          'college_code': collegeCode.trim(),
          'email': email.trim(),
          'password': password,
        },
      );
      token = data['token']?.toString();
      user = SessionUser.fromJson(
        (data['user'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      );
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
      final data = await _map(
        'POST',
        '/setup/college',
        customHeaders: const {'Content-Type': 'application/json'},
        body: {
          'college_name': collegeName.trim(),
          'college_code': collegeCode.trim(),
          'admin_name': adminName.trim(),
          'admin_email': adminEmail.trim(),
          'admin_password': adminPassword,
        },
      );
      token = data['token']?.toString();
      user = SessionUser.fromJson(
        (data['user'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      );
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
      final p = await _list('/portal');
      final d = await _map('GET', '/dashboard');
      final dir = await _list('/directory');
      final box = await _list('/inbox');

      portal = p
          .map((e) => PortalItem.fromJson(e as Map<String, dynamic>))
          .where((e) => e.enabled)
          .toList()
        ..sort((a, b) => a.position.compareTo(b.position));

      dashboard = d;
      directory = dir
          .map((e) => DirectoryUser.fromJson(e as Map<String, dynamic>))
          .toList();
      inbox = box
          .map((e) => InboxItem.fromJson(e as Map<String, dynamic>))
          .toList();

      if (user?.role == 'admin') {
        await loadDepartments();
        await loadAudit();
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
    final rows = await _list('/admin/departments');
    departments = rows
        .map((e) => DepartmentItem.fromJson(e as Map<String, dynamic>))
        .toList();
    notifyListeners();
  }

  Future<void> loadAudit() async {
    if (user?.role != 'admin') return;
    final rows = await _list('/admin/audit');
    auditItems =
        rows.map((e) => AuditItem.fromJson(e as Map<String, dynamic>)).toList();
    notifyListeners();
  }

  Future<List<DirectoryUser>> loadAllAdminUsers() async {
    final rows = await _list('/admin/users');
    return rows
        .map((e) => DirectoryUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createDepartment({
    required String name,
    required String code,
  }) async {
    await _map(
      'POST',
      '/admin/departments',
      body: {'name': name.trim(), 'code': code.trim()},
    );
    await loadDepartments();
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
    await _map(
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
    await _map(
      'PATCH',
      '/admin/users/' + userId.toString(),
      body: {'is_active': active},
    );
    await refreshAll();
  }

  Future<void> assignHod({
    required int departmentId,
    required int hodUserId,
  }) async {
    await _map(
      'PATCH',
      '/admin/departments/' + departmentId.toString(),
      body: {'hod_user_id': hodUserId},
    );
    await loadDepartments();
    await refreshAll();
  }

  Future<void> sendAssignment({
    required List<int> targetUserIds,
    required String title,
    required String body,
    required String kind,
  }) async {
    await _map(
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
    await _map(
      'PATCH',
      '/assignments/' + id.toString(),
      body: {'status': status},
    );
    await refreshAll();
  }

  Future<List<PortalItem>> loadPortalRole(String role) async {
    final rows = await _list('/admin/portal/' + role);
    return rows
        .map((e) => PortalItem.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
  }

  Future<void> savePortalRole(String role, List<PortalItem> items) async {
    for (var i = 0; i < items.length; i++) {
      items[i].position = i;
    }
    await _map(
      'PUT',
      '/admin/portal/' + role,
      body: {'items': items.map((e) => e.toJson()).toList()},
    );
    await refreshAll();
  }

  void _connectRealtime() {
    _wsSub?.cancel();
    _channel?.sink.close();
    _heartbeat?.cancel();
    if (token == null) return;

    try {
      final base = apiBase
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://');
      final target = Uri.parse(
        base + '/ws?token=' + Uri.encodeComponent(token!),
      );
      _channel = WebSocketChannel.connect(target);
      _wsSub = _channel!.stream.listen(
        (_) => unawaited(refreshAll()),
        onError: (_) {},
        onDone: () {},
      );
      _heartbeat = Timer.periodic(
        const Duration(seconds: 25),
        (_) {
          try {
            _channel?.sink.add('ping');
          } catch (_) {}
        },
      );
    } catch (_) {}
  }

  void logout() {
    _heartbeat?.cancel();
    _wsSub?.cancel();
    _channel?.sink.close();
    token = null;
    user = null;
    dashboard = {};
    portal = [];
    directory = [];
    inbox = [];
    departments = [];
    auditItems = [];
    online = false;
    lastError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _heartbeat?.cancel();
    _wsSub?.cancel();
    _channel?.sink.close();
    _client.close();
    super.dispose();
  }
}

final hierarchyController = HierarchyController();
