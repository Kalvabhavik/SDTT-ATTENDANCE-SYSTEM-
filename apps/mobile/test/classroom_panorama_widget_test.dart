import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:classroom_attendance_mobile/models/models.dart';
import 'package:classroom_attendance_mobile/screens/session_screen.dart';
import 'package:classroom_attendance_mobile/state/app_state.dart';

AttendanceSession _session(String status) => AttendanceSession.fromJson({
      'id': 'session-12345678',
      'class_id': 'class-1',
      'class_name': 'Computer Vision',
      'class_code': 'CV-101',
      'status': status,
      'created_at': '2026-10-30T09:00:00Z',
      'ends_at': status == 'open' ? '2099-10-30T10:00:00Z' : null,
      'attendance': [],
    });

void main() {
  testWidgets('active faculty session exposes classroom panorama action',
      (tester) async {
    final state = AppState()
      ..auth = const AuthSession(
        accessToken: 'test-token',
        user: User(
            id: 'teacher-1',
            name: 'Lecturer',
            email: 'lecturer@test',
            role: 'teacher'),
      )
      ..activeSession = _session('open');

    await tester.pumpWidget(MaterialApp(home: SessionScreen(state: state)));

    expect(find.text('Capture Classroom Panorama'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('closed faculty session does not allow a new panorama capture',
      (tester) async {
    final state = AppState()
      ..auth = const AuthSession(
        accessToken: 'test-token',
        user: User(
            id: 'teacher-1',
            name: 'Lecturer',
            email: 'lecturer@test',
            role: 'teacher'),
      )
      ..activeSession = _session('closed');

    await tester.pumpWidget(MaterialApp(home: SessionScreen(state: state)));

    expect(find.text('Capture Classroom Panorama'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });
}
