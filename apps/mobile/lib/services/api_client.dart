import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/models.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.errorCode});
  final String message;
  final int? statusCode;
  final String? errorCode;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  String? accessToken;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      };

  Uri _endpoint(String suffix, [String? baseUrl]) {
    final targetUrl = baseUrl ?? AppConfig.apiBaseUrl;
    final baseUri = Uri.parse(targetUrl);
    final base = baseUri.path.endsWith('/')
        ? baseUri.path.substring(0, baseUri.path.length - 1)
        : baseUri.path;
    return baseUri.replace(path: '$base$suffix');
  }

  bool _isNetworkError(Object e) {
    if (e is SocketException || e is http.ClientException || e is TimeoutException) {
      return true;
    }
    final str = e.toString().toLowerCase();
    return str.contains('socketexception') ||
        str.contains('connection refused') ||
        str.contains('failed host lookup') ||
        str.contains('network is unreachable') ||
        str.contains('connection timed out') ||
        str.contains('clientexception');
  }

  Future<T> _executeWithFailover<T>(Future<T> Function(String baseUrl) action) async {
    try {
      return await action(AppConfig.apiBaseUrl);
    } catch (e) {
      if (e is ApiException) rethrow;
      if (_isNetworkError(e)) {
        final fallbackUrl = AppConfig.alternateUrl;
        try {
          final res = await action(fallbackUrl);
          // Auto switch active url on successful fallback
          AppConfig.apiBaseUrl = fallbackUrl;
          return res;
        } catch (inner) {
          if (inner is ApiException) rethrow;
          throw ApiException(
            'Cannot connect to attendance server. Tested ${AppConfig.apiBaseUrl} and $fallbackUrl. Check your network or USB connection.',
            statusCode: 0,
          );
        }
      }
      rethrow;
    }
  }

  Future<bool> checkHealth([String? baseUrl]) async {
    try {
      final uri = _endpoint('/time', baseUrl ?? AppConfig.apiBaseUrl);
      final resp = await _client.get(uri).timeout(const Duration(seconds: 3));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<String> probeFastestServer() async {
    if (await checkHealth(AppConfig.apiBaseUrl)) {
      return AppConfig.apiBaseUrl;
    }
    if (await checkHealth(AppConfig.alternateUrl)) {
      AppConfig.apiBaseUrl = AppConfig.alternateUrl;
      return AppConfig.apiBaseUrl;
    }
    return AppConfig.apiBaseUrl;
  }

  Future<dynamic> _request(String method, String path,
      {Object? body, Map<String, String>? query}) async {
    return _executeWithFailover((baseUrl) async {
      final uri = _endpoint(path, baseUrl).replace(queryParameters: query);
      final request = http.Request(method, uri)..headers.addAll(_headers);
      if (body != null) request.body = jsonEncode(body);
      final response =
          await _client.send(request).timeout(const Duration(seconds: 15));
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
        final errorCode = response.headers['x-error-code'];
        throw ApiException(
            message?.toString() ?? 'Request failed (${response.statusCode}).',
            statusCode: response.statusCode,
            errorCode: errorCode);
      }
      return decoded;
    });
  }

  Future<AuthSession> login(String email, String password, {String? selectedRole}) async {
    final cleanEmail = email.trim();
    // Connect directly to Supabase Auth instead of Render to eliminate cold start latency
    try {
      final supaUri = Uri.parse('${AppConfig.supabaseUrl}/auth/v1/token?grant_type=password');
      final resp = await _client.post(
        supaUri,
        headers: {
          'apikey': AppConfig.supabaseAnonKey,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': cleanEmail,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
        final token = decoded['access_token']?.toString() ?? '';
        final userObj = decoded['user'] is Map ? Map<String, dynamic>.from(decoded['user'] as Map) : <String, dynamic>{};
        final meta = userObj['user_metadata'] is Map ? Map<String, dynamic>.from(userObj['user_metadata'] as Map) : <String, dynamic>{};

        final role = (meta['role']?.toString() ?? userObj['role']?.toString() ?? selectedRole ?? 'student').toLowerCase();
        final user = User(
          id: userObj['id']?.toString() ?? '',
          name: meta['name']?.toString() ?? userObj['name']?.toString() ?? 'User',
          email: userObj['email']?.toString() ?? cleanEmail,
          role: role,
          rollNumber: meta['roll_number']?.toString() ?? userObj['roll_number']?.toString(),
          studentId: meta['student_id']?.toString() ?? userObj['student_id']?.toString(),
          registrationLocked: meta['registration_locked'] == true,
        );
        final session = AuthSession(accessToken: token, user: user);
        accessToken = session.accessToken;
        return session;
      } else if (resp.statusCode == 400 || resp.statusCode == 401) {
        dynamic errBody;
        try {
          errBody = jsonDecode(resp.body);
        } catch (_) {}
        final msg = errBody is Map ? (errBody['error_description'] ?? errBody['msg'] ?? errBody['message']) : null;
        throw ApiException(
          msg?.toString() ?? 'Invalid email or password. [INVALID_CREDENTIALS]',
          statusCode: resp.statusCode,
          errorCode: 'INVALID_CREDENTIALS',
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      // Network error or timeout: fall back to backend endpoint
    }

    final body = <String, dynamic>{
      'email': cleanEmail,
      'password': password,
      if (selectedRole != null) 'selected_role': selectedRole,
    };
    final data = await _request('POST', '/auth/login', body: body);
    final session = AuthSession.fromJson(Map<String, dynamic>.from(data as Map));
    accessToken = session.accessToken;
    return session;
  }

  Future<User> me() async => User.fromJson(
      Map<String, dynamic>.from(await _request('GET', '/me') as Map));

  Future<DateTime> serverTime() async {
    final res = await _request('GET', '/time');
    if (res is Map && res['server_time'] != null) {
      return DateTime.tryParse(res['server_time'].toString()) ?? DateTime.now();
    }
    return DateTime.now();
  }

  Future<EnrollmentStatus> enrollmentStatus() async {
    final res = await _request('GET', '/auth/enrollment-status');
    return EnrollmentStatus.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<Map<String, dynamic>> enrollReferenceSelfie(
      List<int> imageBytes, bool consent) async {
    return _executeWithFailover((baseUrl) async {
      final uri = _endpoint('/auth/enroll', baseUrl);
      final req = http.MultipartRequest('POST', uri);
      if (accessToken != null) {
        req.headers['Authorization'] = 'Bearer $accessToken';
      }
      req.fields['consent'] = consent ? 'true' : 'false';
      req.files.add(http.MultipartFile.fromBytes(
        'photo',
        imageBytes,
        filename: 'reference_selfie.jpg',
      ));

      final streamed = await _client.send(req).timeout(const Duration(seconds: 30));
      final text = await streamed.stream.bytesToString();
      dynamic decoded;
      try {
        decoded = jsonDecode(text);
      } catch (_) {
        decoded = text;
      }
      if (streamed.statusCode != 200) {
        final msg = decoded is Map ? (decoded['detail'] ?? decoded['message']) : null;
        final errorCode = streamed.headers['x-error-code'];
        throw ApiException(msg?.toString() ?? 'Enrollment failed (${streamed.statusCode}).',
            statusCode: streamed.statusCode, errorCode: errorCode);
      }
      return Map<String, dynamic>.from(decoded as Map);
    });
  }

  Future<List<Classroom>> classes() async {
    final raw = await _request('GET', '/classes');
    final list = raw is List ? raw : <dynamic>[];
    return list
        .map((e) => Classroom.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<AttendanceSession>> sessions() async {
    final raw = await _request('GET', '/sessions');
    final list = raw is List ? raw : <dynamic>[];
    return list
        .map((e) => AttendanceSession.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<AttendanceSession> session(String id) async =>
      AttendanceSession.fromJson(
          Map<String, dynamic>.from(await _request('GET', '/sessions/$id') as Map));

  Future<AttendanceSession> createSession(String classId, {int durationMinutes = 10}) async {
    final data = await _request(
      'POST',
      '/sessions',
      body: {'class_id': classId, 'duration_minutes': durationMinutes},
    );
    return AttendanceSession.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<Map<String, dynamic>> setSessionReference(String sessionId, String photoBase64) async {
    final data = await _request(
      'POST',
      '/sessions/$sessionId/reference',
      body: {'room_photo': photoBase64},
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> checkinSweep({
    required String sessionId,
    required String attemptId,
    required List<Map<String, dynamic>> metadata,
    required List<List<int>> frameBytesList,
  }) async {
    return _executeWithFailover((baseUrl) async {
      final uri = _endpoint('/sessions/$sessionId/checkin', baseUrl);
      final req = http.MultipartRequest('POST', uri);
      if (accessToken != null) {
        req.headers['Authorization'] = 'Bearer $accessToken';
      }
      req.fields['attempt_id'] = attemptId;
      req.fields['metadata'] = jsonEncode(metadata);

      for (int i = 0; i < frameBytesList.length; i++) {
        req.files.add(http.MultipartFile.fromBytes(
          'frames',
          frameBytesList[i],
          filename: 'frame_$i.jpg',
        ));
      }

      final streamed = await _client.send(req).timeout(const Duration(seconds: 35));
      final text = await streamed.stream.bytesToString();
      dynamic decoded;
      try {
        decoded = jsonDecode(text);
      } catch (_) {
        decoded = text;
      }
      if (streamed.statusCode != 200) {
        final msg = decoded is Map ? (decoded['detail'] ?? decoded['message']) : null;
        throw ApiException(msg?.toString() ?? 'Sweep checkin failed (${streamed.statusCode}).',
            statusCode: streamed.statusCode);
      }
      return Map<String, dynamic>.from(decoded as Map);
    });
  }

  Future<List<CheckinReviewItem>> reviewQueue(String sessionId) async {
    final raw = await _request('GET', '/sessions/$sessionId/review-queue');
    final list = raw is List ? raw : <dynamic>[];
    return list
        .map((e) => CheckinReviewItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Map<String, dynamic>> reviewDecision(
    String sessionId,
    String attemptId,
    String decision, {
    String? note,
  }) async {
    final res = await _request(
      'POST',
      '/sessions/$sessionId/review/$attemptId',
      body: {'decision': decision, if (note != null) 'note': note},
    );
    return Map<String, dynamic>.from(res as Map);
  }

  Future<void> updateAttendance(
    String sessionId,
    String studentId,
    String status, {
    String? note,
  }) async {
    await _request(
      'PATCH',
      '/sessions/$sessionId/attendance/$studentId',
      body: {'status': status, 'note': note},
    );
  }

  Future<AttendanceSession> finalizeSession(
    String sessionId, {
    bool markPendingAbsent = true,
  }) async {
    final data = await _request(
      'POST',
      '/sessions/$sessionId/finalize',
      body: {'mark_pending_absent': markPendingAbsent},
    );
    return AttendanceSession.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<StudentAttendance> studentAttendance() async =>
      StudentAttendance.fromJson(Map<String, dynamic>.from(
          await _request('GET', '/students/me/attendance') as Map));

  Future<List<AppNotification>> notifications() async {
    final raw = await _request('GET', '/notifications');
    final list = raw is List ? raw : <dynamic>[];
    return list
        .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> markNotificationRead(String id) async {
    await _request('POST', '/notifications/$id/read');
  }

  Future<String> wsTicket() async {
    final data = await _request('POST', '/realtime/ticket');
    return (data as Map)['ticket'].toString();
  }

  Future<SessionReport> report(String sessionId) async {
    final data = await _request('GET', '/sessions/$sessionId/report');
    return SessionReport.fromJson(Map<String, dynamic>.from(data as Map));
  }

  String sessionExcelExportUrl(String sessionId) {
    return '${AppConfig.apiBaseUrl}/sessions/$sessionId/export/excel';
  }

  Future<AttendanceVerifyResult> verifyAttendanceLive(
    String sessionId, {
    required List<int> faceBytes,
    List<int>? roomBytes,
    List<int>? faceLeftBytes,
    List<int>? faceRightBytes,
    List<int>? faceBlinkBytes,
  }) async {
    return _executeWithFailover((baseUrl) async {
      final uri = _endpoint('/sessions/$sessionId/verify-attendance', baseUrl);
      final req = http.MultipartRequest('POST', uri);
      if (accessToken != null) {
        req.headers['Authorization'] = 'Bearer $accessToken';
      }
      req.files.add(http.MultipartFile.fromBytes(
        'face_image',
        faceBytes,
        filename: 'live_face.jpg',
      ));
      if (roomBytes != null && roomBytes.isNotEmpty) {
        req.files.add(http.MultipartFile.fromBytes(
          'classroom_image',
          roomBytes,
          filename: 'classroom_room.jpg',
        ));
      }
      if (faceLeftBytes != null && faceLeftBytes.isNotEmpty) {
        req.files.add(http.MultipartFile.fromBytes(
          'face_left',
          faceLeftBytes,
          filename: 'face_left.jpg',
        ));
      }
      if (faceRightBytes != null && faceRightBytes.isNotEmpty) {
        req.files.add(http.MultipartFile.fromBytes(
          'face_right',
          faceRightBytes,
          filename: 'face_right.jpg',
        ));
      }
      if (faceBlinkBytes != null && faceBlinkBytes.isNotEmpty) {
        req.files.add(http.MultipartFile.fromBytes(
          'face_blink',
          faceBlinkBytes,
          filename: 'face_blink.jpg',
        ));
      }

      final streamed = await req.send().timeout(const Duration(seconds: 25));
      final resp = await http.Response.fromStream(streamed);
      final body = resp.body.isNotEmpty ? jsonDecode(resp.body) : {};
      if (resp.statusCode >= 400) {
        final detail = body is Map ? body['detail'] : resp.body;
        final errorCode = resp.headers['x-error-code'];
        throw ApiException(detail?.toString() ?? 'Verification failed', statusCode: resp.statusCode, errorCode: errorCode);
      }
      return AttendanceVerifyResult.fromJson(Map<String, dynamic>.from(body as Map));
    });
  }

  Future<bool> getRegistrationWindow() async {
    final data = await _request('GET', '/controller/registration-window');
    return data is Map && data['is_open'] == true;
  }

  Future<void> setRegistrationWindow(bool isOpen) async {
    await _request('POST', '/controller/registration-window', body: {'is_open': isOpen});
  }

  Future<Map<String, dynamic>> importRegistryCsv(List<int> csvBytes) async {
    return _executeWithFailover((baseUrl) async {
      final uri = _endpoint('/controller/registry/import', baseUrl);
      final req = http.MultipartRequest('POST', uri);
      if (accessToken != null) {
        req.headers['Authorization'] = 'Bearer $accessToken';
      }
      req.files.add(http.MultipartFile.fromBytes(
        'file',
        csvBytes,
        filename: 'registry.csv',
      ));
      final streamed = await req.send().timeout(const Duration(seconds: 25));
      final resp = await http.Response.fromStream(streamed);
      final body = resp.body.isNotEmpty ? jsonDecode(resp.body) : {};
      if (resp.statusCode >= 400) {
        final detail = body is Map ? body['detail'] : resp.body;
        throw ApiException(detail?.toString() ?? 'Import failed', statusCode: resp.statusCode);
      }
      return Map<String, dynamic>.from(body as Map);
    });
  }

  Future<List<Classroom>> controllerClasses() async {
    final raw = await _request('GET', '/controller/classes');
    final list = raw is List ? raw : <dynamic>[];
    return list
        .map((e) => Classroom.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Classroom> controllerCreateClass({
    required String name,
    required String code,
    String? section,
    String? roomNumber,
    int? capacity,
    String? hallType,
    String? roomPhoto,
    String? teacherId,
  }) async {
    final data = await _request(
      'POST',
      '/controller/classes',
      body: {
        'name': name,
        'code': code,
        'section': section,
        'room_number': roomNumber,
        'capacity': capacity,
        'hall_type': hallType,
        'room_photo': roomPhoto,
        'teacher_id': teacherId,
      },
    );
    return Classroom.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<Map<String, dynamic>> controllerCaptureRoom({
    required String classId,
    required List<int> photoBytes,
    int? capacity,
    String? hallType,
    String? roomNumber,
  }) async {
    return _executeWithFailover((baseUrl) async {
      final uri = _endpoint('/controller/classes/$classId/capture-room', baseUrl);
      final req = http.MultipartRequest('POST', uri);
      if (accessToken != null) {
        req.headers['Authorization'] = 'Bearer $accessToken';
      }
      if (capacity != null) req.fields['capacity'] = capacity.toString();
      if (hallType != null) req.fields['hall_type'] = hallType;
      if (roomNumber != null) req.fields['room_number'] = roomNumber;
      req.files.add(http.MultipartFile.fromBytes(
        'photo',
        photoBytes,
        filename: 'room_reference.jpg',
      ));

      final streamed = await _client.send(req).timeout(const Duration(seconds: 30));
      final text = await streamed.stream.bytesToString();
      dynamic decoded;
      try {
        decoded = jsonDecode(text);
      } catch (_) {
        decoded = text;
      }
      if (streamed.statusCode != 200) {
        final msg = decoded is Map ? (decoded['detail'] ?? decoded['message']) : null;
        throw ApiException(msg?.toString() ?? 'Capture failed (${streamed.statusCode}).',
            statusCode: streamed.statusCode);
      }
      return Map<String, dynamic>.from(decoded as Map);
    });
  }

  Future<List<ControllerStudent>> controllerStudents() async {
    final raw = await _request('GET', '/controller/students');
    final list = raw is List ? raw : <dynamic>[];
    return list
        .map((e) => ControllerStudent.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ControllerStudent> controllerCreateStudent({
    required String name,
    required String email,
    required String rollNumber,
    String? studentId,
    List<String> classIds = const [],
  }) async {
    final data = await _request(
      'POST',
      '/controller/students',
      body: {
        'name': name,
        'email': email,
        'roll_number': rollNumber,
        'student_id': studentId,
        'class_ids': classIds,
      },
    );
    return ControllerStudent.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> controllerUnlockStudent(String studentId) async {
    await _request('POST', '/controller/students/$studentId/unlock');
  }
}
