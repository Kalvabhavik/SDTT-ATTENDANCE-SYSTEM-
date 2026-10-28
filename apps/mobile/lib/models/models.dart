import 'dart:convert';

String _string(dynamic value, [String fallback = '']) =>
    value?.toString() ?? fallback;
String _id(dynamic value) => value == null ? '' : value.toString();
int _int(dynamic value) =>
    value is int ? value : int.tryParse(_string(value)) ?? 0;
double _double(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse(_string(value)) ?? 0;
Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

class User {
  const User(
      {required this.id,
      required this.name,
      required this.email,
      required this.role});
  final String id;
  final String name;
  final String email;
  final String role;
  bool get isTeacher => role.toLowerCase() == 'teacher';
  factory User.fromJson(Map<String, dynamic> json) => User(
        id: _id(json['id']),
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
  const Classroom(
      {required this.id,
      required this.name,
      this.code = '',
      this.teacherName = ''});
  final String id;
  final String name;
  final String code;
  final String teacherName;
  factory Classroom.fromJson(Map<String, dynamic> json) => Classroom(
        id: _id(json['id'] ?? json['class_id']),
        name:
            _string(json['name'] ?? json['title'], 'Class ${json['id'] ?? ''}'),
        code: _string(json['code']),
        teacherName: _string(json['teacher_name']),
      );
}

class AttendanceRecord {
  const AttendanceRecord(
      {required this.studentId,
      required this.studentName,
      required this.status,
      this.note = '',
      this.confidence,
      this.sessionId,
      this.className,
      this.updatedAt});
  final String studentId;
  final String studentName;
  final String status;
  final String note;
  final double? confidence;
  final String? sessionId;
  final String? className;
  final DateTime? updatedAt;
  bool get isPresent => status == 'present';
  bool get isAbsent => status == 'absent';
  bool get isPending => status == 'pending';
  AttendanceRecord copyWith(
          {String? status, String? note, double? confidence}) =>
      AttendanceRecord(
        studentId: studentId,
        studentName: studentName,
        status: status ?? this.status,
        note: note ?? this.note,
        confidence: confidence ?? this.confidence,
        sessionId: sessionId,
        className: className,
        updatedAt: updatedAt,
      );
  factory AttendanceRecord.fromJson(Map<String, dynamic> json) =>
      AttendanceRecord(
        studentId: _id(json['student_id'] ?? json['id']),
        studentName: _string(json['student_name'] ?? json['name'], 'Student'),
        status: _string(json['status'], 'pending'),
        note: _string(json['note']),
        confidence:
            json['confidence'] == null ? null : _double(json['confidence']),
        sessionId: json['session_id'] == null ? null : _id(json['session_id']),
        className:
            json['class_name'] == null ? null : _string(json['class_name']),
        updatedAt: DateTime.tryParse(_string(json['updated_at'])),
      );
}

class Suggestion {
  const Suggestion(
      {required this.studentId,
      required this.studentName,
      required this.confidence,
      this.status = 'present'});
  final String studentId;
  final String studentName;
  final double confidence;
  final String status;
  factory Suggestion.fromJson(Map<String, dynamic> json) => Suggestion(
        studentId: _id(json['student_id'] ?? json['id']),
        studentName: _string(json['student_name'] ?? json['name'], 'Student'),
        confidence: _double(json['confidence']),
        // The API's status is the label "suggestion", not an attendance status.
        // Applying a teacher-reviewed suggestion is an explicit present action.
        status: 'present',
      );
}

class AttendanceSession {
  const AttendanceSession(
      {required this.id,
      required this.classId,
      required this.className,
      required this.status,
      required this.records,
      this.createdAt,
      this.finalizedAt});
  final String id;
  final String classId;
  final String className;
  final String status;
  final List<AttendanceRecord> records;
  final DateTime? createdAt;
  final DateTime? finalizedAt;
  bool get isOpen => status.toLowerCase() == 'open';
  AttendanceSession copyWith(
          {String? status, List<AttendanceRecord>? records}) =>
      AttendanceSession(
        id: id,
        classId: classId,
        className: className,
        status: status ?? this.status,
        records: records ?? this.records,
        createdAt: createdAt,
        finalizedAt: finalizedAt,
      );
  factory AttendanceSession.fromJson(Map<String, dynamic> json) {
    final rawRecords =
        json['attendance'] ?? json['records'] ?? json['roster'] ?? <dynamic>[];
    final list = rawRecords is List ? rawRecords : <dynamic>[];
    return AttendanceSession(
      id: _id(json['id'] ?? json['session_id']),
      classId: _id(json['class_id'] ?? _map(json['class'])['id']),
      className: _string(json['class_name'] ?? _map(json['class'])['name'],
          'Attendance session'),
      status: _string(json['status'], 'open'),
      records: list.map((e) => AttendanceRecord.fromJson(_map(e))).toList(),
      createdAt: DateTime.tryParse(_string(json['created_at'])),
      finalizedAt: DateTime.tryParse(_string(json['finalized_at'])),
    );
  }
}

class AttendanceSummary {
  const AttendanceSummary(
      {required this.total,
      required this.present,
      required this.absent,
      required this.pending,
      required this.percentage});
  final int total;
  final int present;
  final int absent;
  final int pending;
  final double percentage;
  factory AttendanceSummary.fromJson(Map<String, dynamic> json) {
    final source =
        _map(json['summary']).isNotEmpty ? _map(json['summary']) : json;
    return AttendanceSummary(
      total: _int(source['total'] ??
          source['total_finalized'] ??
          source['total_sessions']),
      present: _int(source['present']),
      absent: _int(source['absent']),
      pending: _int(source['pending']),
      percentage:
          _double(source['percentage'] ?? source['attendance_percentage']),
    );
  }
}

class StudentAttendance {
  const StudentAttendance({required this.entries, required this.summary});
  final List<AttendanceRecord> entries;
  final AttendanceSummary summary;
  factory StudentAttendance.fromJson(Map<String, dynamic> json) {
    final raw = json['entries'] ?? json['attendance'] ?? <dynamic>[];
    return StudentAttendance(
      entries: (raw is List ? raw : <dynamic>[])
          .map((e) => AttendanceRecord.fromJson(_map(e)))
          .toList(),
      summary: AttendanceSummary.fromJson(json),
    );
  }
}

class AppNotification {
  const AppNotification(
      {required this.id,
      required this.title,
      required this.message,
      required this.read,
      this.createdAt});
  final String id;
  final String title;
  final String message;
  final bool read;
  final DateTime? createdAt;
  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: _id(json['id']),
        title: _string(json['title'], 'Attendance update'),
        message: _string(json['message'] ?? json['body']),
        read: json['read'] == true ||
            json['is_read'] == true ||
            json['read_at'] != null,
        createdAt: DateTime.tryParse(_string(json['created_at'])),
      );
}

class RealtimeEvent {
  const RealtimeEvent({required this.type, required this.data});
  final String type;
  final Map<String, dynamic> data;
  factory RealtimeEvent.fromJson(dynamic value) {
    final map = value is String ? jsonDecode(value) : value;
    final json = _map(map);
    return RealtimeEvent(type: _string(json['type']), data: _map(json['data']));
  }
}
