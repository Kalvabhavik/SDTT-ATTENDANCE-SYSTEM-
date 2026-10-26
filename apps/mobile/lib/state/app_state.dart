
import 'package:flutter/foundation.dart';
import 'dart:typed_data';

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
  bool busy = false;
  bool enrollmentComplete = false;
  int maxSessionMinutes = 60;
  String? error;
  String? liveMessage;

  User? get user => auth?.user;
  bool get isTeacher => user?.isTeacher == true;
  int get unreadCount => notifications.where((n) => !n.read).length;

  Future<bool> login(String email, String password, String selectedRole) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      auth = await api.login(email.trim(), password, selectedRole);
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

  Future<void> restoreSession() async {
    try {
      final restored = await api.restoreUser();
      if (restored != null) {
        auth = AuthSession(accessToken: api.accessToken ?? '', user: restored);
        await loadHome();
        _startRealtime();
      }
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Secure token storage is unavailable on this device.';
    } finally {
      notifyListeners();
    }
  }

  Future<void> loadHome() async {
    final config = await api.config();
    maxSessionMinutes = int.tryParse(config['max_session_minutes'].toString()) ?? 60;
    final enrollment = await api.enrollmentStatus();
    enrollmentComplete = enrollment['enrolled'] == true;
    classes = await api.classes();
    sessions = await api.sessions();
    notifications = await api.notifications();
    if (!isTeacher) studentAttendance = await api.studentAttendance();
    notifyListeners();
  }

  Future<bool> enrollFace(Uint8List selfieBytes) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await api.enrollFace(selfieBytes);
      enrollmentComplete = true;
      return true;
    } on ApiException catch (e) {
      error = e.message;
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
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
    realtime.connect(onEvent: (event) async {
      liveMessage = 'Live update: ${event.type}';
      if (event.type == 'connected') {
        await loadHome();
        liveMessage = 'Live updates connected';
        return;
      }
      if (event.type == 'notification.created' ||
          event.type == 'session.finalized') {
        notifications = await api.notifications();
      }
      if (event.type == 'session.finalized' && !isTeacher) {
        studentAttendance = await api.studentAttendance();
      }
      if (event.type == 'attendance.changed' && activeSession != null) {
        activeSession = await api.session(activeSession!.id);
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

  Future<bool> startSession(String classId, {int durationMinutes = 10}) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      activeSession = await api.createSession(classId, durationMinutes);
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
    await api.signOut();
    auth = null;
    classes = [];
    sessions = [];
    notifications = [];
    activeSession = null;
    notifyListeners();
  }

  @override
  void dispose() {
    realtime.dispose();
    super.dispose();
  }
}
