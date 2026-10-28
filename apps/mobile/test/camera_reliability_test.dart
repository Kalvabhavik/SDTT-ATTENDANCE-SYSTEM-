import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:classroom_attendance_mobile/models/models.dart';
import 'package:classroom_attendance_mobile/screens/live_face_verification_screen.dart';
import 'package:classroom_attendance_mobile/state/app_state.dart';
import 'package:classroom_attendance_mobile/widgets/app_widgets.dart';

AppState _createAppState() {
  final state = AppState();
  state.auth = const AuthSession(
    accessToken: 'test_token',
    user: User(
      id: 'student-1',
      name: 'Himanshu Sharma',
      email: 'student1@demo.edu',
      role: 'student',
    ),
  );
  return state;
}

AttendanceSession _createSession() {
  return AttendanceSession(
    id: 'session-cs401',
    classId: 'class-cs401',
    className: 'CS401: Distributed Operating Systems',
    classCode: 'CS-401',
    status: 'open',
    createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
    durationMinutes: 20,
    serverTime: DateTime.now(),
    verifiedCount: 38,
    flaggedCount: 2,
    records: const [],
  );
}

Future<void> _renderAndCapture({
  required WidgetTester tester,
  required Widget widget,
  required String screenshotPath,
}) async {
  final boundaryKey = GlobalKey();

  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(isTest: true),
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: RepaintBoundary(
            key: boundaryKey,
            child: SizedBox(
              width: 390,
              height: 844,
              child: widget,
            ),
          ),
        ),
      ),
    ),
  );

  await tester.pump(const Duration(milliseconds: 300));

  await tester.runAsync(() async {
    final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary != null) {
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final file = File(screenshotPath);
        file.parent.createSync(recursive: true);
        file.writeAsBytesSync(byteData.buffer.asUint8List());
      }
    }
  });
}

void main() {
  final screenshotsDir = Platform.environment['ATTENDRIX_PROOF_DIR'] ?? '${Directory.systemTemp.path}/attendrix-proof/03_camera_reliability';

  group('Camera & Capture Reliability Tests', () {
    testWidgets('TC-MOB-009: Camera Permission Denied State', (tester) async {
      final state = _createAppState();
      final session = _createSession();

      await _renderAndCapture(
        tester: tester,
        widget: LiveFaceVerificationScreen(
          state: state,
          session: session,
          initialCameraPermissionDenied: true,
        ),
        screenshotPath: '$screenshotsDir/01_camera_permission_denied.png',
      );

      expect(find.text('Camera Permission Denied'), findsOneWidget);
      expect(find.byIcon(Icons.no_photography_rounded), findsOneWidget);
      expect(find.text('Grant Camera Access / Retry'), findsOneWidget);
      expect(find.text('Return to Home'), findsOneWidget);
    });

    testWidgets('TC-MOB-010: Camera Hardware Unavailable State', (tester) async {
      final state = _createAppState();
      final session = _createSession();

      await _renderAndCapture(
        tester: tester,
        widget: LiveFaceVerificationScreen(
          state: state,
          session: session,
          initialCameraUnavailable: true,
        ),
        screenshotPath: '$screenshotsDir/02_camera_hardware_unavailable.png',
      );

      expect(find.text('Camera Hardware Unavailable'), findsOneWidget);
      expect(find.byIcon(Icons.videocam_off_rounded), findsOneWidget);
      expect(find.text('Retry Camera Initialization'), findsOneWidget);
    });

    testWidgets('TC-MOB-011: Camera Stream Interrupted State', (tester) async {
      final state = _createAppState();
      final session = _createSession();

      await _renderAndCapture(
        tester: tester,
        widget: LiveFaceVerificationScreen(
          state: state,
          session: session,
          initialCameraStreamInterrupted: true,
        ),
        screenshotPath: '$screenshotsDir/03_camera_stream_interrupted.png',
      );

      expect(find.text('Camera Stream Interrupted'), findsOneWidget);
      expect(find.byIcon(Icons.pause_circle_outline_rounded), findsOneWidget);
      expect(find.text('Resume Camera Stream'), findsOneWidget);
    });

    testWidgets('TC-MOB-012: No Face Detected Alert and Guidance', (tester) async {
      final state = _createAppState();
      final session = _createSession();

      await _renderAndCapture(
        tester: tester,
        widget: LiveFaceVerificationScreen(
          state: state,
          session: session,
          initialStep: VerificationStep.result,
          initialErrorCode: 'NO_FACE_DETECTED',
          initialErrorMessage: 'No face detected in camera frame. Please align your face inside the reticle.',
        ),
        screenshotPath: '$screenshotsDir/04_no_face_detected_alert.png',
      );

      expect(find.text('Image Quality Check Failed'), findsOneWidget);
      expect(find.textContaining('NO_FACE_DETECTED'), findsOneWidget);
      expect(find.textContaining('Center your face inside the viewfinder reticle'), findsOneWidget);
      expect(find.text('Retry Verification Attempt'), findsOneWidget);
    });

    testWidgets('TC-MOB-013: Multiple Faces Rejected State', (tester) async {
      final state = _createAppState();
      final session = _createSession();

      await _renderAndCapture(
        tester: tester,
        widget: LiveFaceVerificationScreen(
          state: state,
          session: session,
          initialStep: VerificationStep.result,
          initialErrorCode: 'MULTIPLE_FACES',
          initialErrorMessage: 'Multiple faces detected in frame (2). Verification requires an individual solo selfie.',
        ),
        screenshotPath: '$screenshotsDir/05_multiple_faces_rejected.png',
      );

      expect(find.text('Image Quality Check Failed'), findsOneWidget);
      expect(find.textContaining('MULTIPLE_FACES'), findsOneWidget);
      expect(find.textContaining('Only one individual student face is permitted'), findsOneWidget);
    });

    testWidgets('TC-MOB-014: Face Too Small Guidance', (tester) async {
      final state = _createAppState();
      final session = _createSession();

      await _renderAndCapture(
        tester: tester,
        widget: LiveFaceVerificationScreen(
          state: state,
          session: session,
          initialStep: VerificationStep.result,
          initialErrorCode: 'FACE_TOO_SMALL',
          initialErrorMessage: 'Face occupies only 1.8% of frame; minimum 3.5% required.',
        ),
        screenshotPath: '$screenshotsDir/06_face_too_small_guidance.png',
      );

      expect(find.text('Image Quality Check Failed'), findsOneWidget);
      expect(find.textContaining('FACE_TOO_SMALL'), findsOneWidget);
      expect(find.textContaining('Move phone closer until your face fills 40% to 60%'), findsOneWidget);
    });

    testWidgets('TC-MOB-015: Poor Lighting and Blur Guidance', (tester) async {
      final state = _createAppState();
      final session = _createSession();

      await _renderAndCapture(
        tester: tester,
        widget: LiveFaceVerificationScreen(
          state: state,
          session: session,
          initialStep: VerificationStep.result,
          initialErrorCode: 'IMAGE_BLURRY',
          initialErrorMessage: 'Photo is too blurry (sharpness score 14.2 < 35.0). Hold phone steady in good lighting.',
        ),
        screenshotPath: '$screenshotsDir/07_poor_lighting_and_blur_guidance.png',
      );

      expect(find.text('Image Quality Check Failed'), findsOneWidget);
      expect(find.textContaining('IMAGE_BLURRY'), findsOneWidget);
      expect(find.textContaining('Hold your phone steady with both hands'), findsOneWidget);
    });

    testWidgets('TC-MOB-016: Network Timeout and Retry Submission', (tester) async {
      final state = _createAppState();
      final session = _createSession();

      await _renderAndCapture(
        tester: tester,
        widget: LiveFaceVerificationScreen(
          state: state,
          session: session,
          initialStep: VerificationStep.result,
          initialErrorCode: 'TIMEOUT',
          initialErrorMessage: 'Biometric transmission timed out. Latency threshold exceeded. Please retry.',
        ),
        screenshotPath: '$screenshotsDir/08_network_timeout_and_retry.png',
      );

      expect(find.text('Network Timeout / Disconnected'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      expect(find.text('Retry Verification Attempt'), findsOneWidget);
    });

    testWidgets('Duplicate submission prevented by 1-attempt policy', (tester) async {
      final state = _createAppState();
      final session = _createSession();

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(isTest: true),
          home: Scaffold(
            body: LiveFaceVerificationScreen(
              state: state,
              session: session,
              initialStep: VerificationStep.result,
              initialErrorMessage: 'Attendance checkin already recorded for this session. Strictly 1 attempt allowed.',
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Attendance Already Recorded'), findsOneWidget);
      expect(find.byIcon(Icons.fact_check_rounded), findsOneWidget);
      expect(find.textContaining('Strictly 1 attempt allowed'), findsOneWidget);
    });

    testWidgets('Quality failure never returns attendance present = true', (tester) async {
      final state = _createAppState();
      final session = _createSession();
      bool? poppedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                poppedResult = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => LiveFaceVerificationScreen(
                      state: state,
                      session: session,
                      initialStep: VerificationStep.result,
                      initialErrorCode: 'IMAGE_BLURRY',
                      initialErrorMessage: 'Photo too blurry',
                    ),
                  ),
                );
              },
              child: const Text('Launch Verification'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Launch Verification'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Close'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Quality failure strictly returns false (never converted to true)
      expect(poppedResult, false);
    });
  });
}
