import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../services/realtime_service.dart';

class AppState extends ChangeNotifier {
  AppState() {
    realtime = RealtimeService(api);
  }
  final ApiClient api = ApiClient();
  late final RealtimeService realtime;
  AuthSession? auth;
  List<Classroom> classes = [];
  List<AttendanceSession> sessions = [];
  List<AppNotification> notifications = [];
  StudentAttendance? studentAttendance;
  AttendanceSession? activeSession;
  List<Suggestion> suggestions = [];
  bool busy = false;
  String? error;
  String? liveMessage;
  final Set<String> _seenRealtimeEventIds = <String>{};
  final Map<String, int> _latestRealtimeVersions = <String, int>{};

  User? get user => auth?.user;
  bool get isTeacher => user?.isTeacher == true;
  int get unreadCount => notifications.where((n) => !n.read).length;

  Future<bool> login(String email, String password) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      auth = await api.login(email.trim(), password);
      await loadHome();
      _startRealtime();
      return true;
    } on ApiException catch (e) {
      error = e.message;
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> loadHome() async {
    final results = await Future.wait<dynamic>([
      api.classes(),
      api.sessions(),
      api.notifications(),
      if (!isTeacher) api.studentAttendance(),
    ]);
    classes = results[0] as List<Classroom>;
    sessions = results[1] as List<AttendanceSession>;
    notifications = results[2] as List<AppNotification>;
    if (!isTeacher) studentAttendance = results[3] as StudentAttendance;
    notifyListeners();
  }

  Future<void> retryHome() async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await loadHome();
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void _startRealtime() {
    var initialConnection = true;
    realtime.connect(onEvent: (event) async {
      liveMessage = 'Live update: ${event.type}';
      if (event.type == 'connected') {
        _seenRealtimeEventIds.clear();
        _latestRealtimeVersions.clear();
        if (!initialConnection) await loadHome();
        initialConnection = false;
        liveMessage = 'Live updates connected';
        return;
      }
      if (!_acceptRealtimeEvent(event)) return;
      if (event.type == 'notification.created' ||
          event.type == 'session.finalized') {
        notifications = await api.notifications();
      }
      if (event.type == 'session.finalized' && !isTeacher) {
        studentAttendance = await api.studentAttendance();
      }
      if (event.type == 'attendance.changed' && activeSession != null) {
        final studentId = event.data['student_id']?.toString();
        final nextStatus = event.data['status']?.toString();
        final attendance = event.data['attendance'];
        if (studentId != null && nextStatus != null && attendance is Map) {
          final current = activeSession!;
          final nextRecord = AttendanceRecord.fromJson(
              Map<String, dynamic>.from(attendance));
          final records = current.records
              .map((record) => record.studentId == studentId ? nextRecord : record)
              .toList();
          activeSession = current.copyWith(records: records);
        } else {
          activeSession = await api.session(activeSession!.id);
        }
      }
      if (event.type == 'session.created' ||
          event.type == 'session.finalized') {
        sessions = await api.sessions();
      }
      notifyListeners();
    }, onError: (message) {
      liveMessage = message;
      notifyListeners();
    });
  }

  bool _acceptRealtimeEvent(RealtimeEvent event) {
    final eventId = event.eventId;
    if (eventId != null && eventId.isNotEmpty) {
      if (_seenRealtimeEventIds.contains(eventId)) return false;
      _seenRealtimeEventIds.add(eventId);
      if (_seenRealtimeEventIds.length > 2000) {
        _seenRealtimeEventIds.remove(_seenRealtimeEventIds.first);
      }
    }
    final sessionId = event.sessionId;
    final version = event.eventVersion;
    if (sessionId != null && version != null) {
      final latest = _latestRealtimeVersions[sessionId] ?? 0;
      if (version <= latest) return false;
      _latestRealtimeVersions[sessionId] = version;
    }
    return true;
  }

  Future<void> openSession(String sessionId) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      activeSession = await api.session(sessionId);
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> startSession(String classId) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      activeSession = await api.createSession(classId);
      sessions = await api.sessions();
      return true;
    } on ApiException catch (e) {
      error = e.message;
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> uploadCapture(File file) async {
    if (activeSession == null) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      suggestions = await api.capture(activeSession!.id, file);
      return true;
    } on ApiException catch (e) {
      error = e.message;
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> setAttendance(String studentId, String status) async {
    if (activeSession == null) return false;
    try {
      await api.updateAttendance(activeSession!.id, studentId, status);
      activeSession = await api.session(activeSession!.id);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> finalizeActive() async {
    if (activeSession == null) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await api.finalizeSession(activeSession!.id);
      activeSession = await api.session(activeSession!.id);
      sessions = await api.sessions();
      return true;
    } on ApiException catch (e) {
      error = e.message;
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> markNotificationRead(AppNotification item) async {
    if (item.read) return;
    try {
      await api.markNotificationRead(item.id);
      notifications = notifications
          .map((n) => n.id == item.id
              ? AppNotification(
                  id: n.id,
                  title: n.title,
                  message: n.message,
                  read: true,
                  createdAt: n.createdAt)
              : n)
          .toList();
      notifyListeners();
    } on ApiException catch (e) {
      error = e.message;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await realtime.dispose();
    api.accessToken = null;
    auth = null;
    classes = [];
    sessions = [];
    notifications = [];
    activeSession = null;
    suggestions = [];
    notifyListeners();
  }

  @override
  void dispose() {
    realtime.dispose();
    super.dispose();
  }
}
