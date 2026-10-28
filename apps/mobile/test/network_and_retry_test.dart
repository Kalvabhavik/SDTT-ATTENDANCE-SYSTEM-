import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:classroom_attendance_mobile/config/app_config.dart';
import 'package:classroom_attendance_mobile/services/api_client.dart';
import 'package:classroom_attendance_mobile/widgets/app_widgets.dart';

/// Lightweight custom BaseClient for deterministic network testing
class MockHttpAdapter extends http.BaseClient {
  MockHttpAdapter(this.handler);
  final Future<http.StreamedResponse> Function(http.BaseRequest request) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => handler(request);
}

void main() {
  group('Category 09: Network Failure, Failover & Retry Tests (Mobile)', () {
    setUp(() {
      AppConfig.apiBaseUrl = AppConfig.usbBaseUrl;
    });

    test('Network SocketException triggers fallback URL and raises clean ApiException', () async {
      final requestedUrls = <String>[];

      final mockClient = MockHttpAdapter((request) async {
        requestedUrls.add(request.url.toString());
        throw const SocketException('Connection refused: 192.168.1.100:8000');
      });

      final api = ApiClient(client: mockClient);

      expect(
        () async => await api.checkHealth(),
        returnsNormally,
      );

      final isHealthy = await api.checkHealth();
      expect(isHealthy, isFalse);

      expect(
        () async => await api.serverTime(),
        throwsA(isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('Cannot connect to attendance server'),
        )),
      );

      // Verify both primary and fallback URLs were probed
      expect(requestedUrls.length, greaterThanOrEqualTo(2));
    });

    test('HTTP 503 Server Unavailable maps to ApiException with 503 statusCode', () async {
      final mockClient = MockHttpAdapter((request) async {
        final body = jsonEncode({'detail': 'Biometric verification queue is overloaded. Retry shortly.'});
        return http.StreamedResponse(
          Stream.value(utf8.encode(body)),
          503,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = ApiClient(client: mockClient);

      expect(
        () async => await api.serverTime(),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 503)),
      );
    });

    test('HTTP 400 Bad Request maps error code and message properly', () async {
      final mockClient = MockHttpAdapter((request) async {
        final body = jsonEncode({'detail': 'Invalid liveness token or single-use nonce consumed.'});
        return http.StreamedResponse(
          Stream.value(utf8.encode(body)),
          400,
          headers: {
            'content-type': 'application/json',
            'x-error-code': 'NONCE_ALREADY_USED',
          },
        );
      });

      final api = ApiClient(client: mockClient);

      try {
        await api.serverTime();
        fail('Should have thrown ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, 400);
        expect(e.errorCode, 'NONCE_ALREADY_USED');
        expect(e.message, contains('Invalid liveness token'));
      }
    });

    test('Successful failover automatically updates active AppConfig.apiBaseUrl', () async {
      final originalPrimary = AppConfig.apiBaseUrl;
      final alternate = AppConfig.alternateUrl;

      final mockClient = MockHttpAdapter((request) async {
        if (request.url.toString().startsWith(originalPrimary)) {
          throw const SocketException('Primary host down');
        }
        // Alternate succeeds
        final body = jsonEncode({'server_time': '2026-10-27T12:00:00Z'});
        return http.StreamedResponse(
          Stream.value(utf8.encode(body)),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = ApiClient(client: mockClient);
      final time = await api.serverTime();

      expect(time.year, 2026);
      expect(AppConfig.apiBaseUrl, alternate);
    });
  });

  group('Category 09: Network Failure UI States & Button Debounce Tests', () {
    testWidgets('RetryStateCard renders connection timeout state and invokes onRetry',
        (tester) async {
      bool retryClicked = false;
      final boundaryKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(isTest: true),
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: boundaryKey,
                child: SizedBox(
                  width: 390,
                  height: 400,
                  child: RetryStateCard(
                    title: 'Connection Timed Out',
                    message: 'Could not reach attendance server. Check Wi-Fi or USB connection.',
                    icon: Icons.wifi_off_rounded,
                    buttonLabel: 'Retry Connection',
                    onRetry: () => retryClicked = true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      await tester.runAsync(() async {
        final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary != null) {
          final image = await boundary.toImage(pixelRatio: 1.5);
          final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
          if (byteData != null) {
            final proofDir = Platform.environment['ATTENDRIX_PROOF_DIR'] ?? '${Directory.systemTemp.path}/attendrix-proof/07_automated_testing';
            final file = File('$proofDir/04_network_timeout_retry_card.png');
            file.parent.createSync(recursive: true);
            file.writeAsBytesSync(byteData.buffer.asUint8List());
          }
        }
      });

      expect(find.text('Connection Timed Out'), findsOneWidget);
      expect(find.text('Could not reach attendance server. Check Wi-Fi or USB connection.'),
          findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
      expect(find.text('Retry Connection'), findsOneWidget);

      await tester.tap(find.text('Retry Connection'));
      await tester.pump();
      expect(retryClicked, isTrue);
    });

    testWidgets('AppDebouncedButton prevents rapid duplicate network retry clicks',
        (tester) async {
      int submissionCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(isTest: true),
          home: Scaffold(
            body: Center(
              child: AppDebouncedButton(
                debounceDuration: const Duration(milliseconds: 500),
                onPressed: () => submissionCount++,
                child: const Text('Submit Attendance'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final buttonFinder = find.text('Submit Attendance');

      // Rapidly tap 5 times within 100ms
      await tester.tap(buttonFinder);
      await tester.pump(const Duration(milliseconds: 20));
      await tester.tap(buttonFinder);
      await tester.pump(const Duration(milliseconds: 20));
      await tester.tap(buttonFinder);
      await tester.pump(const Duration(milliseconds: 20));
      await tester.tap(buttonFinder);
      await tester.pump(const Duration(milliseconds: 20));
      await tester.tap(buttonFinder);
      await tester.pump();

      // Only exactly 1 submission should have executed
      expect(submissionCount, 1,
          reason: 'Rapid taps within debounce window must be ignored to prevent race storms');

      // Advance time past debounce interval
      await tester.pump(const Duration(milliseconds: 600));

      // Next tap should now execute
      await tester.tap(buttonFinder);
      await tester.pump();
      expect(submissionCount, 2);
    });
  });
}
