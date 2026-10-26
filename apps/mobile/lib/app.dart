import 'dart:async';
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/face_enrollment_screen.dart';
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
  String? selectedRole;
  bool showSplash = true;

  @override
  void initState() {
    super.initState();
    state = AppState()..addListener(_changed);
    state.restoreSession();
    Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => showSplash = false);
    });
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
        title: 'Classroom Attendance',
        debugShowCheckedModeBanner: false,
        theme: buildTheme().copyWith(
          pageTransitionsTheme: const PageTransitionsTheme(builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
            TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
            TargetPlatform.linux: ZoomPageTransitionsBuilder(),
            TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
            TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          }),
        ),
        home: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: showSplash
              ? const _SplashScreen(key: ValueKey('splash'))
              : state.user != null
                  ? state.enrollmentComplete
                      ? HomeScreen(key: const ValueKey('home'), state: state)
                      : FaceEnrollmentScreen(key: const ValueKey('enrollment'), state: state)
                  : selectedRole == null
                      ? RoleSelectionScreen(
                          key: const ValueKey('role'),
                          onSelect: (role) => setState(() => selectedRole = role),
                        )
                      : LoginScreen(
                          key: const ValueKey('login'),
                          state: state,
                          selectedRole: selectedRole!,
                          onBack: () => setState(() => selectedRole = null),
                        ),
        ),
      );
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.ink,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.fact_check_rounded, size: 52, color: Colors.white),
            const SizedBox(height: 16),
            Text('SDTT Attendance', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white)),
          ]),
        ),
      );
}

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key, required this.onSelect});
  final ValueChanged<String> onSelect;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Icon(Icons.fact_check_rounded, size: 48, color: AppColors.emerald),
                  const SizedBox(height: 16),
                  Text('Choose your role', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  const Text('Your account role will be checked when you sign in.', textAlign: TextAlign.center),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: () => onSelect('student'),
                    icon: const Icon(Icons.school_rounded),
                    label: const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('I am a Student')),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => onSelect('teacher'),
                    icon: const Icon(Icons.person_pin_rounded),
                    label: const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('I am a Lecturer')),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
}
