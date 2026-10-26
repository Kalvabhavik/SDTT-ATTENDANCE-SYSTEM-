import 'dart:convert';

String _string(dynamic value, [String fallback = '']) =>
    value?.toString() ?? fallback;
int _int(dynamic value) =>
    value is int ? value : int.tryParse(_string(value)) ?? 0;
double _double(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse(_string(value)) ?? 0.0;
Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  final String id;
  final String name;
  final String email;
  final String role; // 'teacher' or 'student' in DB

  bool get isTeacher => role.toLowerCase() == 'teacher';
  String get displayRole => isTeacher ? 'Lecturer' : 'Student';

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: _string(json['id']),
        name: _string(json['name'], 'User'),
        email: _string(json['email']),
        role: _string(json['role'], 'student'),
      );
}

class AuthSession {
  const AuthSession({required this.accessToken, required this.user});
  final String accessToken;
  final User user;

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        accessToken: _string(json['access_token']),
        user: User.fromJson(_map(json['user'])),
      );
}

class Classroom {
  const Classroom({
    required this.id,
    required this.name,
    this.code = '',
    this.teacherName = '',
  });

  final String id;
  final String name;
  final String code;
  final String teacherName;

  factory Classroom.fromJson(Map<String, dynamic> json) => Classroom(
        id: _string(json['id'] ?? json['class_id']),
        name: _string(json['name'] ?? json['title'], 'Class'),
        code: _string(json['code']),
        teacherName: _string(json['teacher_name']),
      );
}

class AttendanceRecord {
  const AttendanceRecord({
    required this.studentId,
    required this.studentName,
    required this.status,
    this.note = '',
    this.sessionId,
    this.className,
    this.updatedAt,
  });

  final String studentId;
  final String studentName;
  final String status; // 'present', 'absent', 'pending'
  final String note;
  final String? sessionId;
  final String? className;
  final DateTime? updatedAt;

  bool get isPresent => status == 'present';
  bool get isAbsent => status == 'absent';
  bool get isPending => status == 'pending';

  AttendanceRecord copyWith({String? status, String? note}) =>
      AttendanceRecord(
        studentId: studentId,
        studentName: studentName,
        status: status ?? this.status,
        note: note ?? this.note,
        sessionId: sessionId,
        className: className,
        updatedAt: updatedAt,
      );

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) =>
      AttendanceRecord(
        studentId: _string(json['student_id'] ?? json['id']),
        studentName: _string(json['student_name'] ?? json['name'], 'Student'),
        status: _string(json['status'], 'pending'),
        note: _string(json['note']),
        sessionId: json['session_id'] != null ? _string(json['session_id']) : null,
        className: json['class_name'] != null ? _string(json['class_name']) : null,
        updatedAt: json['updated_at'] == null
            ? null
            : DateTime.tryParse(_string(json['updated_at'])),
      );
}

class AttendanceSession {
  const AttendanceSession({
    required this.id,
    required this.classId,
    required this.className,
    required this.classCode,
    required this.status,
    required this.createdAt,
    this.startsAt,
    this.endsAt,
    this.durationMinutes = 10,
    this.serverTime,
    this.finalizedAt,
    this.records = const [],
    this.verifiedCount = 0,
    this.flaggedCount = 0,
  });

  final String id;
  final String classId;
  final String className;
  final String classCode;
  final String status; // 'open', 'closed', 'finalized'
  final DateTime createdAt;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int durationMinutes;
  final DateTime? serverTime;
  final DateTime? finalizedAt;
  final List<AttendanceRecord> records;
  final int verifiedCount;
  final int flaggedCount;

  bool get isOpen => status == 'open';
  bool get isClosed => status == 'closed';
  bool get isFinalized => status == 'finalized';

  int get presentCount => records.where((r) => r.isPresent).length;
  int get absentCount => records.where((r) => r.isAbsent).length;
  int get pendingCount => records.where((r) => r.isPending).length;

  factory AttendanceSession.fromJson(Map<String, dynamic> json) {
    final attRaw = json['attendance'];
    final records = (attRaw is List ? attRaw : <dynamic>[])
        .map((e) => AttendanceRecord.fromJson(_map(e)))
        .toList();

    final summary = _map(json['summary']);
    return AttendanceSession(
      id: _string(json['id']),
      classId: _string(json['class_id']),
      className: _string(json['class_name'], 'Class'),
      classCode: _string(json['class_code']),
      status: _string(json['status'], 'open'),
      createdAt: DateTime.tryParse(_string(json['created_at'])) ?? DateTime.now(),
      startsAt: json['starts_at'] == null ? null : DateTime.tryParse(_string(json['starts_at'])),
      endsAt: json['ends_at'] == null ? null : DateTime.tryParse(_string(json['ends_at'])),
      durationMinutes: _int(json['duration_minutes'] ?? 10),
      serverTime: json['server_time'] == null ? null : DateTime.tryParse(_string(json['server_time'])),
      finalizedAt: json['finalized_at'] == null
          ? null
          : DateTime.tryParse(_string(json['finalized_at'])),
      records: records,
      verifiedCount: _int(summary['verified_count'] ?? summary['present'] ?? 0),
      flaggedCount: _int(summary['flagged_count'] ?? 0),
    );
  }
}

class CheckinReviewItem {
  const CheckinReviewItem({
    required this.attemptId,
    required this.sessionId,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.state,
    required this.reasonCode,
    required this.filmstripUrls,
    required this.metrics,
    required this.createdAt,
  });

  final String attemptId;
  final String sessionId;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final String state;
  final String reasonCode;
  final List<String> filmstripUrls;
  final Map<String, dynamic> metrics;
  final DateTime createdAt;

  factory CheckinReviewItem.fromJson(Map<String, dynamic> json) {
    final urlsRaw = json['filmstrip_urls'];
    final urls = (urlsRaw is List ? urlsRaw : <dynamic>[])
        .map((e) => e.toString())
        .toList();
    return CheckinReviewItem(
      attemptId: _string(json['attempt_id']),
      sessionId: _string(json['session_id']),
      studentId: _string(json['student_id']),
      studentName: _string(json['student_name'], 'Student'),
      studentEmail: _string(json['student_email']),
      state: _string(json['state'], 'flagged'),
      reasonCode: _string(json['error_code'] ?? json['reason_code'], 'FLAGGED'),
      filmstripUrls: urls,
      metrics: _map(json['metrics']),
      createdAt: DateTime.tryParse(_string(json['created_at'])) ?? DateTime.now(),
    );
  }
}

class EnrollmentStatus {
  const EnrollmentStatus({
    required this.enrolled,
    this.consentTimestamp,
    this.modelVersion,
  });

  final bool enrolled;
  final String? consentTimestamp;
  final String? modelVersion;

  factory EnrollmentStatus.fromJson(Map<String, dynamic> json) => EnrollmentStatus(
        enrolled: json['enrolled'] == true,
        consentTimestamp: json['consent_timestamp']?.toString(),
        modelVersion: json['model_version']?.toString(),
      );
}

class StudentAttendanceEntry {
  const StudentAttendanceEntry({
    required this.sessionId,
    required this.className,
    required this.classCode,
    required this.status,
    this.note = '',
    required this.createdAt,
    this.startsAt,
    this.endsAt,
  });

  final String sessionId;
  final String className;
  final String classCode;
  final String status;
  final String note;
  final DateTime createdAt;
  final DateTime? startsAt;
  final DateTime? endsAt;

  factory StudentAttendanceEntry.fromJson(Map<String, dynamic> json) =>
      StudentAttendanceEntry(
        sessionId: _string(json['session_id']),
        className: _string(json['class_name'], 'Class'),
        classCode: _string(json['class_code']),
        status: _string(json['status'], 'pending'),
        note: _string(json['note']),
        createdAt: DateTime.tryParse(_string(json['created_at'] ?? json['session_created_at'])) ??
            DateTime.now(),
        startsAt: json['starts_at'] == null ? null : DateTime.tryParse(_string(json['starts_at'])),
        endsAt: json['ends_at'] == null ? null : DateTime.tryParse(_string(json['ends_at'])),
      );
}

class StudentAttendance {
  const StudentAttendance({
    required this.present,
    required this.total,
    required this.percentage,
    required this.entries,
  });

  final int present;
  final int total;
  final double percentage;
  final List<StudentAttendanceEntry> entries;

  factory StudentAttendance.fromJson(Map<String, dynamic> json) {
    final summary = _map(json['summary']);
    final entriesRaw = json['entries'];
    final list = (entriesRaw is List ? entriesRaw : <dynamic>[])
        .map((e) => StudentAttendanceEntry.fromJson(_map(e)))
        .toList();
    return StudentAttendance(
      present: _int(summary['present']),
      total: _int(summary['total']),
      percentage: _double(summary['percentage']),
      entries: list,
    );
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.sessionId,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String title;
  final String body;
  final String type;
  final String? sessionId;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get read => readAt != null;

  AppNotification copyWith({DateTime? readAt}) => AppNotification(
        id: id,
        title: title,
        body: body,
        type: type,
        sessionId: sessionId,
        createdAt: createdAt,
        readAt: readAt ?? this.readAt,
      );

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: _string(json['id']),
        title: _string(json['title']),
        body: _string(json['body']),
        type: _string(json['type']),
        sessionId: json['session_id'] != null ? _string(json['session_id']) : null,
        createdAt: DateTime.tryParse(_string(json['created_at'])) ?? DateTime.now(),
        readAt: json['read_at'] == null ? null : DateTime.tryParse(_string(json['read_at'])),
      );
}

class SessionReport {
  const SessionReport({
    required this.session,
    required this.rows,
    required this.csv,
    required this.pdfHtml,
  });

  final Map<String, dynamic> session;
  final List<Map<String, dynamic>> rows;
  final String csv;
  final String pdfHtml;

  factory SessionReport.fromJson(Map<String, dynamic> json) => SessionReport(
        session: _map(json['session']),
        rows: (json['rows'] is List ? json['rows'] as List : <dynamic>[])
            .map((e) => _map(e))
            .toList(),
        csv: _string(json['csv']),
        pdfHtml: _string(json['pdf_html']),
      );
}
