import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:classroom_attendance_mobile/widgets/app_widgets.dart';

void main() {
  group('UI State Widgets Tests', () {
    testWidgets('LoadingStateView renders title, message, and step indicators',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingStateView(
              title: 'Neural Verification in Progress',
              message: 'Extracting 512-dim ArcFace embeddings...',
              steps: [
                'Verifying frontal liveness',
                'Checking room environment',
              ],
            ),
          ),
        ),
      );

      expect(find.text('Neural Verification in Progress'), findsOneWidget);
      expect(find.text('Extracting 512-dim ArcFace embeddings...'), findsOneWidget);
      expect(find.text('Verifying frontal liveness'), findsOneWidget);
      expect(find.text('Checking room environment'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('SuccessStateView renders verified status, metrics, and calls action',
        (tester) async {
      bool actionTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SuccessStateView(
              title: 'Attendance Verified Present',
              message: 'Your biometric verification has passed.',
              metrics: const {
                'Biometric Match': '94%',
                'Active Liveness': 'Passed',
              },
              actionLabel: 'Return Home',
              onAction: () => actionTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Attendance Verified Present'), findsOneWidget);
      expect(find.text('94%'), findsOneWidget);
      expect(find.text('Passed'), findsOneWidget);
      expect(find.byIcon(Icons.verified_user_rounded), findsOneWidget);

      await tester.tap(find.text('Return Home'));
      expect(actionTapped, true);
    });

    testWidgets('RejectionStateView displays failure reason and invokes retry',
        (tester) async {
      bool retried = false;
      bool manualInvoked = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RejectionStateView(
              title: 'Empty Room Detected — Proxy Blocked',
              message: 'Audience and lecturer absent from classroom scene.',
              reason: 'Empty lecture hall anti-proxy rule triggered.',
              retryLabel: 'Try Verification Again',
              onRetry: () => retried = true,
              onManualOption: () => manualInvoked = true,
            ),
          ),
        ),
      );

      expect(find.text('Empty Room Detected — Proxy Blocked'), findsOneWidget);
      expect(find.text('Empty lecture hall anti-proxy rule triggered.'), findsOneWidget);
      expect(find.byIcon(Icons.gpp_bad_rounded), findsOneWidget);

      await tester.tap(find.text('Try Verification Again'));
      expect(retried, true);

      await tester.tap(find.text('Use Manual Roll Call'));
      expect(manualInvoked, true);
    });

    testWidgets('RetryStateCard renders custom icon, text, and handles retry',
        (tester) async {
      bool retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RetryStateCard(
              title: 'Camera Permission Denied',
              message: 'Please enable camera permission in device settings.',
              icon: Icons.videocam_off_rounded,
              buttonLabel: 'Request Permission',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('Camera Permission Denied'), findsOneWidget);
      expect(find.text('Please enable camera permission in device settings.'), findsOneWidget);
      expect(find.byIcon(Icons.videocam_off_rounded), findsOneWidget);

      await tester.tap(find.text('Request Permission'));
      expect(retried, true);
    });

    testWidgets('EmptyState renders title, subtitle, and executes action',
        (tester) async {
      bool actionClicked = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.inbox_rounded,
              title: 'No Active Sessions',
              message: 'You have no scheduled lectures right now.',
              actionLabel: 'Refresh Roster',
              onAction: () => actionClicked = true,
            ),
          ),
        ),
      );

      expect(find.text('No Active Sessions'), findsOneWidget);
      expect(find.text('You have no scheduled lectures right now.'), findsOneWidget);
      expect(find.byIcon(Icons.inbox_rounded), findsOneWidget);

      await tester.tap(find.text('Refresh Roster'));
      expect(actionClicked, true);
    });

    testWidgets('StatusChip renders all semantic status states properly',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StatusChip(status: 'present'),
                StatusChip(status: 'verified'),
                StatusChip(status: 'absent'),
                StatusChip(status: 'rejected'),
                StatusChip(status: 'pending'),
                StatusChip(status: 'flagged'),
                StatusChip(status: 'finalized'),
                StatusChip(status: 'open'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Present'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('Absent'), findsOneWidget);
      expect(find.text('Rejected'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Flagged'), findsOneWidget);
      expect(find.text('Finalized'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('AppDebouncedButton prevents rapid duplicate click executions',
        (tester) async {
      int tapCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppDebouncedButton(
              onPressed: () => tapCount++,
              debounceDuration: const Duration(milliseconds: 500),
              child: const Text('Capture Frame'),
            ),
          ),
        ),
      );

      // Perform three rapid taps within debounce window
      await tester.tap(find.text('Capture Frame'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Capture Frame'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Capture Frame'));
      await tester.pump(const Duration(milliseconds: 50));

      // Only the first tap should have been registered!
      expect(tapCount, 1);

      // Advance clock past debounce duration
      await tester.pump(const Duration(milliseconds: 600));

      // Now another tap should be permitted
      await tester.tap(find.text('Capture Frame'));
      expect(tapCount, 2);
    });
  });
}
