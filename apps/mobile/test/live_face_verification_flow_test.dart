import 'package:flutter_test/flutter_test.dart';
import 'package:classroom_attendance_mobile/screens/live_face_verification_screen.dart';

void main() {
  test('live liveness completion opens classroom panorama before verification', () {
    expect(nextStepAfterLiveness(), VerificationStep.classroomRoom);
  });
}
