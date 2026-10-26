import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_config.dart';
import '../models/models.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  String? accessToken;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      };

  Uri _endpoint(String suffix) {
    final base = AppConfig.apiUri.path.endsWith('/')
        ? AppConfig.apiUri.path.substring(0, AppConfig.apiUri.path.length - 1)
        : AppConfig.apiUri.path;
    return AppConfig.apiUri.replace(path: '$base$suffix');
  }

  Future<dynamic> _request(String method, String path,
      {Object? body, Map<String, String>? query}) async {
    final uri = _endpoint(path).replace(queryParameters: query);
    try {
      final request = http.Request(method, uri)..headers.addAll(_headers);
      if (body != null) request.body = jsonEncode(body);
      final response =
          await _client.send(request).timeout(const Duration(seconds: 18));
      final text = await response.stream.bytesToString();
      dynamic decoded;
      if (text.trim().isNotEmpty) {
        try {
          decoded = jsonDecode(text);
        } catch (_) {
          decoded = text;
        }
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message =
            decoded is Map ? (decoded['detail'] ?? decoded['message']) : null;
        throw ApiException(
            message?.toString() ?? 'Request failed (${response.statusCode}).',
            statusCode: response.statusCode);
      }
      return decoded;
    } on SocketException {
      throw ApiException(
          'Cannot reach the attendance service. Check your connection or API base URL.');
    } on http.ClientException {
      throw ApiException('The attendance service is unavailable. Try again.');
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(
          'The request timed out. Check your connection and retry.');
    }
  }

  Future<AuthSession> login(String email, String password, String selectedRole) async {
    final data = await _request('POST', '/auth/login',
        body: {'email': email, 'password': password, 'selected_role': selectedRole});
    final session =
        AuthSession.fromJson(Map<String, dynamic>.from(data as Map));
    accessToken = session.accessToken;
    await _secureStorage.write(key: 'attendance_access_token', value: accessToken);
    return session;
  }

  Future<User?> restoreUser() async {
    accessToken = await _secureStorage.read(key: 'attendance_access_token');
    if (accessToken == null) return null;
    try {
      return User.fromJson(Map<String, dynamic>.from(await _request('GET', '/me') as Map));
    } on ApiException {
      await signOut();
      return null;
    }
  }

  Future<void> signOut() async {
    accessToken = null;
    await _secureStorage.delete(key: 'attendance_access_token');
  }

  Future<User> me() async => User.fromJson(
      Map<String, dynamic>.from(await _request('GET', '/me') as Map));

  Future<List<Classroom>> classes() async {
    final raw = await _request('GET', '/classes');
    final list =
        raw is List ? raw : (raw is Map ? raw['classes'] : <dynamic>[]);
    return (list is List ? list : <dynamic>[])
        .map((e) => Classroom.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<AttendanceSession>> sessions() async {
    final raw = await _request('GET', '/sessions');
    final list =
        raw is List ? raw : (raw is Map ? raw['sessions'] : <dynamic>[]);
    return (list is List ? list : <dynamic>[])
        .map((e) =>
            AttendanceSession.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<AttendanceSession> session(String sessionId) async =>
      AttendanceSession.fromJson(Map<String, dynamic>.from(
          await _request('GET', '/sessions/$sessionId') as Map));

  Future<AttendanceSession> createSession(String classId, int durationMinutes) async =>
      AttendanceSession.fromJson(Map<String, dynamic>.from(
          await _request('POST', '/sessions', body: {'class_id': classId, 'duration_minutes': durationMinutes})
              as Map));

  Future<Map<String, dynamic>> enrollmentStatus() async =>
      Map<String, dynamic>.from(await _request('GET', '/enrollment/status') as Map);

  Future<Map<String, dynamic>> config() async =>
      Map<String, dynamic>.from(await _request('GET', '/config') as Map);

  Future<Map<String, dynamic>> enrollFace(Uint8List selfieBytes) async {
    final request = http.MultipartRequest('POST', _endpoint('/enrollment/face'));
    request.headers['Accept'] = 'application/json';
    if (accessToken != null) request.headers['Authorization'] = 'Bearer $accessToken';
    request.fields['consent'] = 'true';
    request.files.add(http.MultipartFile.fromBytes('photo', selfieBytes,
        filename: 'enrollment-selfie.jpg', contentType: MediaType('image', 'jpeg')));
    final response = await _client.send(request).timeout(const Duration(seconds: 30));
    final text = await response.stream.bytesToString();
    final decoded = text.isEmpty ? <String, dynamic>{} : jsonDecode(text);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map ? decoded['detail'] : null;
      throw ApiException(detail?.toString() ?? 'Face enrollment failed (${response.statusCode}).', statusCode: response.statusCode);
    }
    return Map<String, dynamic>.from(decoded as Map);
  }

  Future<Map<String, dynamic>> submitSweep({
    required String sessionId,
    required String attemptId,
    required double durationSeconds,
    required List<Uint8List> frames,
    required List<Map<String, double>> metadata,
  }) async {
    final request = http.MultipartRequest('POST', _endpoint('/sessions/$sessionId/submissions'));
    request.headers['Accept'] = 'application/json';
    if (accessToken != null) request.headers['Authorization'] = 'Bearer $accessToken';
    request.fields['attempt_id'] = attemptId;
    request.fields['duration_seconds'] = durationSeconds.toStringAsFixed(3);
    request.fields['frame_metadata'] = jsonEncode(metadata);
    for (var index = 0; index < frames.length; index++) {
      request.files.add(http.MultipartFile.fromBytes('frames', frames[index],
          filename: 'frame-$index.jpg', contentType: MediaType('image', 'jpeg')));
    }
    final response = await _client.send(request).timeout(const Duration(minutes: 2));
    final text = await response.stream.bytesToString();
    final decoded = text.isEmpty ? <String, dynamic>{} : jsonDecode(text);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map ? decoded['detail'] : null;
      throw ApiException(detail?.toString() ?? 'Attendance upload failed (${response.statusCode}).', statusCode: response.statusCode);
    }
    return Map<String, dynamic>.from(decoded as Map);
  }

  Future<void> updateAttendance(String sessionId, String studentId, String status,
      {String? note}) async {
    await _request('PATCH', '/sessions/$sessionId/attendance/$studentId',
        body: {
          'status': status,
          if (note != null && note.isNotEmpty) 'note': note
        });
  }

  Future<void> finalizeSession(String sessionId) async =>
      _request('POST', '/sessions/$sessionId/finalize',
          body: {'mark_pending_absent': true});

  Future<StudentAttendance> studentAttendance() async =>
      StudentAttendance.fromJson(Map<String, dynamic>.from(
          await _request('GET', '/students/me/attendance') as Map));

  Future<List<AppNotification>> notifications() async {
    final raw = await _request('GET', '/notifications');
    final list = raw is List
        ? raw
        : raw is Map
            ? raw['notifications']
            : <dynamic>[];
    return (list is List ? list : <dynamic>[])
        .map((e) =>
            AppNotification.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> markNotificationRead(String id) async =>
      _request('POST', '/notifications/$id/read');

  Future<String> wsTicket() async {
    final data = await _request('POST', '/auth/ws-ticket');
    return (data as Map)['ticket'].toString();
  }
}
