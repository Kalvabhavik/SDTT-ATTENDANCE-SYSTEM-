import 'dart:async';
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
  String? selectedRole; // 'student' or 'lecturer'
  Duration serverClockOffset = Duration.zero;
  EnrollmentStatus? enrollmentStatus;

  List<Classroom> classes = [];
  List<AttendanceSession> sessions = [];
  List<AppNotification> notifications = [];
  StudentAttendance? studentAttendance;
  AttendanceSession? activeSession;
  List<CheckinReviewItem> reviewItems = [];

  bool busy = false;
  String? error;
  String? liveMessage;

  User? get user => auth?.user;
  bool get isTeacher => user?.isTeacher == true;
  int get unreadCount => notifications.where((n) => !n.read).length;

  /// Returns current server-authoritative time estimated via clock offset
  DateTime get serverTimeNow => DateTime.now().add(serverClockOffset);

  void setRole(String role) {
    selectedRole = role;
    notifyListeners();
  }

  Future<void> syncServerTime() async {
    try {
      final st = await api.serverTime();
      serverClockOffset = st.difference(DateTime.now());
    } catch (_) {}
  }

  Future<bool> login(String email, String password) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await syncServerTime();
      auth = await api.login(
        email.trim(),
        password,
        selectedRole: selectedRole,
      );
      enrollmentStatus = await api.enrollmentStatus();
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

  Future<void> checkEnrollment() async {
    try {
      enrollmentStatus = await api.enrollmentStatus();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadHome() async {
    classes = await api.classes();
    sessions = await api.sessions();
    notifications = await api.notifications();
    if (!isTeacher) {
      studentAttendance = await api.studentAttendance();
    }
    notifyListeners();
  }

  Future<void> retryHome() async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await syncServerTime();
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
      liveMessage = 'Live: ${event.type}';
      if (event.type == 'connected') {
        await loadHome();
        return;
      }
      if (event.type == 'notification.created') {
        notifications = await api.notifications();
      }
      if (event.type == 'session.closed') {
        sessions = await api.sessions();
        if (activeSession != null) {
          activeSession = await api.session(activeSession!.id);
        }
      }
      if (event.type == 'attendance.changed' && activeSession != null) {
        activeSession = await api.session(activeSession!.id);
        if (isTeacher) {
          reviewItems = await api.reviewQueue(activeSession!.id);
        }
      }
      if (event.type == 'session.created' || event.type == 'session.finalized') {
        sessions = await api.sessions();
        if (!isTeacher) {
          studentAttendance = await api.studentAttendance();
        }
      }
      notifyListeners();
    }, onError: (msg) {
      liveMessage = msg;
      notifyListeners();
    });
  }

  Future<bool> startSession(String classId, {int durationMinutes = 10}) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await syncServerTime();
      activeSession = await api.createSession(classId, durationMinutes: durationMinutes);
      await loadHome();
      return true;
    } on ApiException catch (e) {
      error = e.message;
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> openSession(String sessionId) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await syncServerTime();
      activeSession = await api.session(sessionId);
      if (isTeacher) {
        reviewItems = await api.reviewQueue(sessionId);
      }
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> refreshReviewQueue(String sessionId) async {
    try {
      reviewItems = await api.reviewQueue(sessionId);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> reviewDecision(
    String sessionId,
    String attemptId,
    String decision, {
    String? note,
  }) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await api.reviewDecision(sessionId, attemptId, decision, note: note);
      activeSession = await api.session(sessionId);
      reviewItems = await api.reviewQueue(sessionId);
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> updateAttendance(
    String studentId,
    String status, {
    String? note,
  }) async {
    if (activeSession == null) return;
    try {
      await api.updateAttendance(activeSession!.id, studentId, status, note: note);
      activeSession = await api.session(activeSession!.id);
      notifyListeners();
    } on ApiException catch (e) {
      error = e.message;
      notifyListeners();
    }
  }

  Future<void> finalizeSession({bool markPendingAbsent = true}) async {
    if (activeSession == null) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      activeSession = await api.finalizeSession(
        activeSession!.id,
        markPendingAbsent: markPendingAbsent,
      );
      await loadHome();
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    realtime.disconnect();
    auth = null;
    selectedRole = null;
    activeSession = null;
    classes.clear();
    sessions.clear();
    notifications.clear();
    reviewItems.clear();
    studentAttendance = null;
    enrollmentStatus = null;
    notifyListeners();
  }
}
