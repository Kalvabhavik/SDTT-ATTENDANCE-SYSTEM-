
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:classroom_attendance_mobile/state/app_state.dart';
import 'package:classroom_attendance_mobile/models/models.dart';
import 'package:classroom_attendance_mobile/screens/home_screen.dart';
import 'package:classroom_attendance_mobile/widgets/app_widgets.dart';

void main() {
  testWidgets('HomeScreen respects SafeArea and renders below status bar padding', (tester) async {
    final state = AppState();
    state.auth = const AuthSession(
      accessToken: 'token',
      user: User(id: 't1', name: 'Demo Teacher', email: 'demo@teacher.edu', role: 'teacher'),
    );

    const screenHeight = 844.0;
    const topPadding = 48.0;
    const bottomPadding = 34.0;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(isTest: true),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, screenHeight),
            padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
          ),
          child: HomeScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify SafeArea exists
    expect(find.byType(SafeArea), findsWidgets);

    // Verify Welcome text is rendered below status bar (y >= topPadding)
    final welcomeFinder = find.textContaining('Welcome, Demo Teacher');
    expect(welcomeFinder, findsOneWidget);

    final welcomeTopLeft = tester.getTopLeft(welcomeFinder);
    expect(welcomeTopLeft.dy, greaterThanOrEqualTo(topPadding),
        reason: 'Welcome header must not overlap status bar padding of ');

    // Verify Date text is also rendered below status bar (y >= topPadding)
    final dateFinder = find.byType(ListView);
    final listTopLeft = tester.getTopLeft(dateFinder);
    expect(listTopLeft.dy, greaterThanOrEqualTo(topPadding));

    // Verify floating dock sits above bottom safe area
    final homeIconFinder = find.byIcon(Icons.home_rounded);
    expect(homeIconFinder, findsOneWidget);
    final homeBottom = tester.getBottomLeft(homeIconFinder);
    // Home icon bottom must be above (screenHeight - bottomPadding)
    expect(homeBottom.dy, lessThanOrEqualTo(screenHeight - bottomPadding + 5),
        reason: 'Floating dock must sit above system bottom gesture bar');

  });
}
