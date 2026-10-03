class SessionUser {
  SessionUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.collegeName,
    required this.collegeCode,
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
  final String collegeName;
  final String collegeCode;

  factory SessionUser.fromJson(Map<String, dynamic> json) => SessionUser(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: (json['name'] ?? '').toString(),
        email: (json['email'] ?? '').toString(),
        role: (json['role'] ?? '').toString(),
        departmentId: (json['department_id'] as num?)?.toInt(),
        department: json['department']?.toString(),
        year: (json['year'] ?? '').toString(),
        section: (json['section'] ?? '').toString(),
        active: json['active'] != false,
        collegeName: (json['college_name'] ?? '').toString(),
        collegeCode: (json['college_code'] ?? '').toString(),
      );
}

class PortalItem {
  PortalItem({
    required this.module,
    required this.label,
    required this.enabled,
    required this.position,
  });

  String module;
  String label;
  bool enabled;
  int position;

  factory PortalItem.fromJson(Map<String, dynamic> json) => PortalItem(
        module: (json['module'] ?? '').toString(),
        label: (json['label'] ?? '').toString(),
        enabled: json['enabled'] == true,
        position: (json['position'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'module': module,
        'label': label,
        'enabled': enabled,
        'position': position,
      };
}

class DirectoryUser {
  DirectoryUser({
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

  factory DirectoryUser.fromJson(Map<String, dynamic> json) => DirectoryUser(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: (json['name'] ?? '').toString(),
        email: (json['email'] ?? '').toString(),
        role: (json['role'] ?? '').toString(),
        departmentId: (json['department_id'] as num?)?.toInt(),
        department: json['department']?.toString(),
        year: (json['year'] ?? '').toString(),
        section: (json['section'] ?? '').toString(),
        active: json['active'] != false,
      );
}

class InboxItem {
  InboxItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.status,
    required this.senderName,
    required this.senderRole,
    this.createdAt = '',
  });

  final int id;
  final String kind;
  final String title;
  final String body;
  String status;
  final String senderName;
  final String senderRole;
  final String createdAt;

  factory InboxItem.fromJson(Map<String, dynamic> json) => InboxItem(
        id: (json['id'] as num?)?.toInt() ?? 0,
        kind: (json['kind'] ?? 'information').toString(),
        title: (json['title'] ?? '').toString(),
        body: (json['body'] ?? '').toString(),
        status: (json['status'] ?? 'new').toString(),
        senderName: (json['sender_name'] ?? '').toString(),
        senderRole: (json['sender_role'] ?? '').toString(),
        createdAt: (json['created_at'] ?? '').toString(),
      );
}

class DepartmentItem {
  DepartmentItem({
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

  factory DepartmentItem.fromJson(Map<String, dynamic> json) => DepartmentItem(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: (json['name'] ?? '').toString(),
        code: (json['code'] ?? '').toString(),
        hodName: json['hod_name']?.toString(),
        staffCount: (json['staff_count'] as num?)?.toInt() ?? 0,
        studentCount: (json['student_count'] as num?)?.toInt() ?? 0,
      );
}

class AuditItem {
  AuditItem({
    required this.action,
    required this.detail,
    required this.actor,
    required this.createdAt,
  });

  final String action;
  final String detail;
  final String actor;
  final String createdAt;

  factory AuditItem.fromJson(Map<String, dynamic> json) => AuditItem(
        action: (json['action'] ?? '').toString(),
        detail: (json['detail'] ?? '').toString(),
        actor: (json['actor'] ?? '').toString(),
        createdAt: (json['created_at'] ?? '').toString(),
      );
}

class ChainItem {
  ChainItem({
    required this.title,
    required this.body,
    required this.kind,
    required this.status,
    required this.senderName,
    required this.senderRole,
    required this.recipientName,
    required this.recipientRole,
    required this.createdAt,
  });

  final String title;
  final String body;
  final String kind;
  final String status;
  final String senderName;
  final String senderRole;
  final String recipientName;
  final String recipientRole;
  final String createdAt;

  factory ChainItem.fromJson(Map<String, dynamic> json) => ChainItem(
        title: (json['title'] ?? '').toString(),
        body: (json['body'] ?? '').toString(),
        kind: (json['kind'] ?? '').toString(),
        status: (json['status'] ?? '').toString(),
        senderName: (json['sender_name'] ?? '').toString(),
        senderRole: (json['sender_role'] ?? '').toString(),
        recipientName: (json['recipient_name'] ?? '').toString(),
        recipientRole: (json['recipient_role'] ?? '').toString(),
        createdAt: (json['created_at'] ?? '').toString(),
      );
}
