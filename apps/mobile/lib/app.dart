import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'state/app_state.dart';
import 'widgets/app_widgets.dart';

class AttendanceApp extends StatefulWidget {
  const AttendanceApp({super.key});
  @override
  State<AttendanceApp> createState() => _AttendanceAppState();
}

class _AttendanceAppState extends State<AttendanceApp> {
  late final AppState state;
  @override
  void initState() {
    super.initState();
    state = AppState();
    state.addListener(_changed);
  }

  void _changed() => setState(() {});
  @override
  void dispose() {
    state.removeListener(_changed);
    state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Classroom attendance',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: AnimatedBuilder(
            animation: state,
            builder: (_, __) => state.user == null
                ? LoginScreen(state: state)
                : HomeScreen(state: state)),
      );
}
