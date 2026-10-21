import 'package:flutter_test/flutter_test.dart';
import 'package:classroom_attendance_mobile/app.dart';
import 'package:classroom_attendance_mobile/models/models.dart';

void main() {
  testWidgets('login screen shows demo access and privacy disclosure',
      (tester) async {
    await tester.pumpWidget(const AttendanceApp());
    expect(find.text('Classroom\nattendance'), findsOneWidget);
    expect(find.text('Teacher demo'), findsOneWidget);
    expect(find.textContaining('no face recognition'), findsOneWidget);
  });

  test('simulated suggestion maps to a valid reviewed attendance status', () {
    final suggestion = Suggestion.fromJson({
      'student_id': 12,
      'name': 'Synthetic Student',
      'confidence': 0.86,
      'status': 'suggestion',
    });
    expect(suggestion.status, 'present');
  });
}
