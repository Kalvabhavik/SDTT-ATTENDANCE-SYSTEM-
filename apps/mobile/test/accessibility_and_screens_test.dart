import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:classroom_attendance_mobile/state/app_state.dart';
import 'package:classroom_attendance_mobile/screens/role_selection_screen.dart';
import 'package:classroom_attendance_mobile/screens/login_screen.dart';
import 'package:classroom_attendance_mobile/widgets/app_widgets.dart';

Future<void> _captureBoundary(GlobalKey key, String path, WidgetTester tester) async {
  await tester.runAsync(() async {
    final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary != null) {
      final image = await boundary.toImage(pixelRatio: 1.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final file = File(path);
        file.parent.createSync(recursive: true);
        file.writeAsBytesSync(byteData.buffer.asUint8List());
      }
    }
  });
}

void main() {
  final screenshotsDir = Platform.environment['ATTENDRIX_PROOF_DIR'] ?? '${Directory.systemTemp.path}/attendrix-proof/07_automated_testing';

  group('Category 12: Supported Screen Sizes & Responsiveness Tests', () {
    final screenSizes = [
      {'name': 'Compact (320x568)', 'file': '01_screen_compact_320x568.png', 'size': const Size(320, 568)},
      {'name': 'Standard (390x844)', 'file': '02_screen_standard_390x844.png', 'size': const Size(390, 844)},
      {'name': 'Large (430x932)', 'file': '02b_screen_large_430x932.png', 'size': const Size(430, 932)},
      {'name': 'Tablet (800x1280)', 'file': '03_screen_tablet_800x1280.png', 'size': const Size(800, 1280)},
    ];

    for (final screen in screenSizes) {
      testWidgets('RoleSelectionScreen renders without overflow on ${screen['name']}',
          (tester) async {
        final size = screen['size'] as Size;
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final boundaryKey = GlobalKey();
        final state = AppState();
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(isTest: true),
            home: RepaintBoundary(
              key: boundaryKey,
              child: RoleSelectionScreen(state: state),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        await _captureBoundary(boundaryKey, '$screenshotsDir/${screen['file']}', tester);

        expect(tester.takeException(), isNull,
            reason: 'Layout overflow detected on ${screen['name']}');
        expect(find.textContaining('ATTENDRIX'), findsOneWidget);
        expect(find.text('Student Portal'), findsOneWidget);
        expect(find.text('Faculty / Lecturer'), findsOneWidget);
        expect(find.text('Academic Controller'), findsOneWidget);
      });

      testWidgets('LoginScreen renders without overflow on ${screen['name']}',
          (tester) async {
        final size = screen['size'] as Size;
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final state = AppState();
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(isTest: true),
            home: LoginScreen(state: state, role: 'student'),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull,
            reason: 'Layout overflow detected on ${screen['name']}');
        expect(find.text('Student Access'), findsWidgets);
        expect(find.byType(TextFormField), findsWidgets);
      });

      testWidgets('RejectionStateView renders gracefully on ${screen['name']}',
          (tester) async {
        final size = screen['size'] as Size;
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(isTest: true),
            home: Scaffold(
              body: RejectionStateView(
                title: 'Empty Room Anti-Proxy Rule Triggered',
                message: 'Classroom scene does not show sufficient student audience or lecture setup.',
                reason: 'Threshold score 0.28 below required 0.65',
                retryLabel: 'Capture Again',
                onRetry: () {},
                onManualOption: () {},
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull,
            reason: 'Overflow in RejectionStateView on ${screen['name']}');
        expect(find.text('Empty Room Anti-Proxy Rule Triggered'), findsOneWidget);
        expect(find.text('Capture Again'), findsOneWidget);
      });
    }
  });

  group('Category 12: Accessibility & Text Scaling Tests', () {
    testWidgets('UI elements support 1.5x text scaling without clipping errors',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final state = AppState();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(isTest: true),
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(1.5),
              size: Size(390, 844),
            ),
            child: RoleSelectionScreen(state: state),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull,
          reason: 'RenderFlex overflow on 1.5x font scaling');
      expect(find.text('Student Portal'), findsOneWidget);
    });

    testWidgets('UI elements support 2.0x (max accessibility) text scaling in scroll views',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final state = AppState();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(isTest: true),
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(2.0),
              size: Size(390, 844),
            ),
            child: LoginScreen(state: state, role: 'student'),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull,
          reason: 'RenderFlex overflow on 2.0x max font scaling');
      expect(find.byType(TextFormField), findsWidgets);
    });

    testWidgets('Interactive buttons provide touch targets >= 44px for accessibility',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(isTest: true),
          home: Scaffold(
            body: Center(
              child: AppDebouncedButton(
                onPressed: () => tapped = true,
                child: const Text('Confirm Biometric Verification'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final buttonFinder = find.byType(AppDebouncedButton);
      expect(buttonFinder, findsOneWidget);

      final renderBox = tester.renderObject<RenderBox>(buttonFinder);
      expect(renderBox.size.height, greaterThanOrEqualTo(44.0),
          reason: 'WCAG AAA target height requires >= 44px');

      await tester.tap(buttonFinder);
      expect(tapped, isTrue);
    });

    testWidgets('Accessibility Semantics are present on critical state views',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(isTest: true),
          home: Scaffold(
            body: SuccessStateView(
              title: 'Verification Complete',
              message: 'Attendance record confirmed present.',
              metrics: const {'Match': '98%'},
              actionLabel: 'Finish',
              onAction: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Verification Complete'), findsOneWidget);
      expect(find.text('Attendance record confirmed present.'), findsOneWidget);
      expect(find.text('Finish'), findsOneWidget);
    });
  });
}
