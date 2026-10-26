import 'package:flutter_test/flutter_test.dart';
import 'package:classroom_attendance_mobile/app.dart';

void main() {
  testWidgets('shows role selection before a blank role-bound login', (tester) async {
    await tester.pumpWidget(const AttendanceApp());
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('I am a Student'), findsOneWidget);
    expect(find.text('I am a Lecturer'), findsOneWidget);

    await tester.tap(find.text('I am a Student'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in as Student'), findsOneWidget);
    expect(find.text('Change role'), findsOneWidget);
    expect(find.text('student1@demo.edu'), findsNothing);
    expect(find.text('student123'), findsNothing);
  });
}
