import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:classroom_attendance_mobile/services/api_client.dart';

void main() {
  test('uploads repeated panorama frames and returns the processing job',
      () async {
    final api = ApiClient(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, endsWith('/sessions/session-1/panorama'));
        return http.Response(
          jsonEncode({'id': 'panorama-1', 'status': 'processing'}),
          202,
          headers: {'content-type': 'application/json'},
        );
      }),
    )..accessToken = 'test-token';

    final result = await api.uploadClassroomPanorama(
      'session-1',
      captureId: 'capture-1',
      capturedAt: DateTime.utc(2026, 10, 30),
      frameBytes: [
        List<int>.filled(100, 1),
        List<int>.filled(100, 2),
        List<int>.filled(100, 3),
      ],
    );

    expect(result['id'], 'panorama-1');
    expect(result['status'], 'processing');
  });

  test('surfaces panorama upload failures as API exceptions', () async {
    final api = ApiClient(
      client: MockClient((_) async => http.Response(
            jsonEncode(
                {'detail': 'Panorama upload exceeds the 40 MB total limit'}),
            413,
            headers: {'content-type': 'application/json'},
          )),
    );

    await expectLater(
      api.uploadClassroomPanorama(
        'session-1',
        captureId: 'capture-1',
        capturedAt: DateTime.utc(2026, 10, 30),
        frameBytes: [
          List<int>.filled(100, 1),
          List<int>.filled(100, 2),
          List<int>.filled(100, 3)
        ],
      ),
      throwsA(isA<ApiException>()
          .having((error) => error.statusCode, 'statusCode', 413)),
    );
  });
}
