import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_floating_bottom_bar/flutter_floating_bottom_bar.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../config/app_config.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../widgets/app_widgets.dart';
import 'notifications_screen.dart';
import 'session_screen.dart';
import 'sweep_capture_screen.dart';
import 'controller_screen.dart';
import 'live_face_verification_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.state});
  final AppState state;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final isTeacher = widget.state.isTeacher;
    final isStudent = !widget.state.isTeacher && !widget.state.isController;

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      appBar: (tab == 2 || tab == 3)
          ? AppBar(
              elevation: 0,
              backgroundColor: AppColors.background,
              title: Text(
                tab == 2
                    ? 'Notifications & Alerts'
                    : isStudent
                        ? 'Attendance Records'
                        : isTeacher
                            ? 'Assigned Classes'
                            : 'Classrooms & Roster',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppColors.ink,
                ),
              ),
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.ink),
                onPressed: () => setState(() => tab = 0),
              ),
            )
          : null,
      body: BottomBar(
        showIcon: false,
        layout: BottomBarLayout(
          width: 330,
          borderRadius: BorderRadius.circular(36),
          offset: 16,
        ),
        motion: const BottomBarMotion.cupertino(preset: BottomBarCupertinoMotion.snappy),
        scrollBehavior: const BottomBarScrollBehavior(
          hideOnScroll: false,
        ),
        theme: BottomBarThemeData(
          barDecoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: const Color(0xFFECEEF1), width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F0D7A5F),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
        ),
        body: widget.state.isController
            ? _buildControllerBody()
            : isTeacher
                ? _buildTeacherBody()
                : _buildStudentBody(),
        child: _buildFloatingDockContent(),
      ),
    );
  }

  Widget _buildStudentBody() {
    switch (tab) {
      case 0:
        return StudentHome(
          state: widget.state,
          onOpenClockIn: () => setState(() => tab = 1),
        );
      case 1:
        return _StudentAttendanceClockIn(
          state: widget.state,
          onBack: () => setState(() => tab = 0),
        );
      case 2:
        return NotificationsScreen(state: widget.state);
      case 3:
        return _StudentRecordsOverview(state: widget.state);
      default:
        return StudentHome(
          state: widget.state,
          onOpenClockIn: () => setState(() => tab = 1),
        );
    }
  }

  Widget _buildTeacherBody() {
    switch (tab) {
      case 0:
        return TeacherHome(
          state: widget.state,
          onOpenSession: () => setState(() => tab = 1),
        );
      case 1:
        final openSessions = widget.state.sessions.where((s) => s.isOpen).toList();
        if (openSessions.isNotEmpty) {
          return SessionScreen(state: widget.state);
        }
        return TeacherHome(
          state: widget.state,
          onOpenSession: () => setState(() => tab = 1),
        );
      case 2:
        return NotificationsScreen(state: widget.state);
      case 3:
        return TeacherHome(
          state: widget.state,
          onOpenSession: () => setState(() => tab = 1),
        );
      default:
        return TeacherHome(
          state: widget.state,
          onOpenSession: () => setState(() => tab = 1),
        );
    }
  }

  Widget _buildControllerBody() {
    switch (tab) {
      case 0:
        return ControllerHome(
          state: widget.state,
          onOpenClasses: () => setState(() => tab = 3),
        );
      case 1:
        final openSessions = widget.state.sessions.where((s) => s.isOpen).toList();
        if (openSessions.isNotEmpty) {
          return SweepCaptureScreen(state: widget.state, session: openSessions.first);
        }
        return ControllerScreen(state: widget.state);
      case 2:
        return NotificationsScreen(state: widget.state);
      case 3:
        return ControllerScreen(state: widget.state);
      default:
        return ControllerHome(
          state: widget.state,
          onOpenClasses: () => setState(() => tab = 3),
        );
    }
  }

  Widget _buildFloatingDockContent() {
    final isTeacher = widget.state.isTeacher;
    final isStudent = !widget.state.isTeacher && !widget.state.isController;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildDockItem(icon: Icons.home_rounded, index: 0),
          _buildDockItem(
            icon: isStudent
                ? Icons.access_time_rounded
                : isTeacher
                    ? Icons.videocam_outlined
                    : Icons.camera_alt_outlined,
            index: 1,
          ),
          _buildDockItem(icon: Icons.chat_bubble_outline_rounded, index: 2),
          _buildDockItem(
            icon: isStudent
                ? Icons.folder_outlined
                : isTeacher
                    ? Icons.school_outlined
                    : Icons.meeting_room_outlined,
            index: 3,
          ),
          _buildDockItem(icon: Icons.settings_outlined, index: 4),
        ],
      ),
    );
  }

  Widget _buildDockItem({required IconData icon, required int index}) {
    final isSelected = tab == index;
    return GestureDetector(
      onTap: () {
        if (index == 4) {
          _showSettingsSheet(context);
        } else {
          setState(() => tab = index);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 20,
          color: isSelected ? Colors.white : const Color(0xFF64748B),
        ),
      ),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    final user = widget.state.user;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE2E8F0),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'S',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? 'Student',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.email ?? '',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 14),
                ValueListenableBuilder<String>(
                  valueListenable: AppConfig.activeUrlNotifier,
                  builder: (context, _, __) {
                    final isLan = AppConfig.isUsingLan;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.lan_rounded, color: AppColors.primary),
                      title: const Text('Server Connection Mode', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                      subtitle: Text(AppConfig.connectionModeLabel, style: const TextStyle(fontSize: 11.5, color: AppColors.slate)),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF1F5F9),
                          foregroundColor: AppColors.ink,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          AppConfig.toggleServerUrl();
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Switched to ${isLan ? "USB Localhost" : "LAN Wi-Fi"}')),
                          );
                        },
                        child: Text(isLan ? 'Use USB' : 'Use Wi-Fi'),
                      ),
                    );
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.sync_rounded, color: AppColors.primary),
                  title: const Text('Refresh Data', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.state.retryHome();
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout_rounded, color: AppColors.rose),
                  title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.rose)),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.state.logout();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Pulsing Live Dot
class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});
  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.5 + 0.5 * _anim.value),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TEACHER HOME
// ─────────────────────────────────────────────────────────────────────────────

class TeacherHome extends StatelessWidget {
  const TeacherHome({
    super.key,
    required this.state,
    this.onOpenSession,
  });

  final AppState state;
  final VoidCallback? onOpenSession;

  Future<void> _open(BuildContext context, AttendanceSession session) async {
    await state.openSession(session.id);
    if (!context.mounted) return;
    if (state.error == null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => SessionScreen(state: state)),
      );
    }
  }

  Future<void> _start(BuildContext context, Classroom classroom) async {
    final chosenDuration = await showDialog<int>(
      context: context,
      builder: (ctx) => _DurationPresetDialog(classroom: classroom),
    );
    if (chosenDuration == null) return;

    final ok = await state.startSession(classroom.id, durationMinutes: chosenDuration);
    if (!context.mounted) return;
    if (ok) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => SessionScreen(state: state)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.error ?? 'Could not start session.'),
          backgroundColor: AppColors.rose,
        ),
      );
    }
  }

  Widget _buildTeacherMetricCard(String count, String label, {Color? dotColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECEEF1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          if (dotColor != null) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            count,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.slate,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstName = state.user?.name.split(' ').first ?? 'Instructor';
    final nowFormatted = DateFormat('EEEE, MMMM d').format(DateTime.now());

    return RefreshIndicator(
      onRefresh: state.retryHome,
      color: AppColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
        children: [
          // Top Header matching StudentHome: Date + Welcome + Bell + Avatar
          FadeSlideIn(
            offsetY: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nowFormatted,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Welcome, ${state.user?.name ?? firstName}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    // Bell with alert badge
                    Stack(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFECEEF1)),
                          ),
                          child: const Icon(
                            Icons.notifications_none_rounded,
                            size: 22,
                            color: AppColors.ink,
                          ),
                        ),
                        if (state.unreadCount > 0)
                          Positioned(
                            top: 10,
                            right: 12,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    // Profile Avatar
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFE2E8F0),
                      ),
                      child: Center(
                        child: Text(
                          (state.user?.name.isNotEmpty == true ? state.user!.name[0] : 'T').toUpperCase(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Today's Summary Section (Matching StudentHome)
          FadeSlideIn(
            delay: const Duration(milliseconds: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Today\'s Summary',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFECEEF1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Next Lecture',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              state.classes.isNotEmpty ? state.classes.first.name : 'CS401: Distributed Systems',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              state.classes.isNotEmpty ? '${state.classes.first.code} • LH-120 • 09:00 AM' : 'LH-120 • 09:00 - 10:30 AM',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.slate,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () {
                          if (state.classes.isNotEmpty) {
                            _start(context, state.classes.first);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Text(
                            'Start Session',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Overview 3-card Strip (Matching StudentHome)
          FadeSlideIn(
            delay: const Duration(milliseconds: 60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Teaching Overview',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildTeacherMetricCard('${state.classes.length}', 'Assigned Classes', dotColor: AppColors.primary)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTeacherMetricCard('92%', 'Avg. Attendance', dotColor: AppColors.emerald)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTeacherMetricCard('0', 'Flagged Items', dotColor: AppColors.amber)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Classes section
          FadeSlideIn(
            delay: const Duration(milliseconds: 120),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Assigned Classes', style: Theme.of(context).textTheme.titleLarge),
                Text(
                  '${state.classes.length} total',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          if (state.classes.isEmpty)
            const FadeSlideIn(
              delay: Duration(milliseconds: 140),
              child: EmptyState(
                icon: Icons.school_outlined,
                title: 'No classes found',
                message: 'Classes assigned to your account will appear here.',
              ),
            ),

          ...state.classes.asMap().entries.map((entry) {
            final index = entry.key;
            final c = entry.value;
            return FadeSlideIn(
              delay: Duration(milliseconds: 140 + index * 60),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.menu_book_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.name,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.cardSubtle,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    c.code,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.slate,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: state.busy ? null : () => _start(context, c),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: const Text('Start'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 22),

          // Recent sessions section
          FadeSlideIn(
            delay: const Duration(milliseconds: 200),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent Sessions', style: Theme.of(context).textTheme.titleLarge),
                Text(
                  '${state.sessions.length} recorded',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          if (state.sessions.isEmpty)
            const FadeSlideIn(
              delay: Duration(milliseconds: 220),
              child: EmptyState(
                icon: Icons.event_available_outlined,
                title: 'No sessions yet',
                message: 'Start a session above to record attendance.',
              ),
            ),

          ...state.sessions.take(10).toList().asMap().entries.map((entry) {
            final index = entry.key;
            final s = entry.value;
            final isFinalized = s.status.toLowerCase() == 'finalized';

            return FadeSlideIn(
              delay: Duration(milliseconds: 220 + index * 40),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  onTap: () => _open(context, s),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isFinalized
                              ? AppColors.cardSubtle
                              : AppColors.emeraldBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isFinalized
                                ? AppColors.border
                                : AppColors.emeraldBorder,
                          ),
                        ),
                        child: Icon(
                          isFinalized
                              ? Icons.lock_clock_rounded
                              : Icons.radio_button_checked_rounded,
                          color: isFinalized ? AppColors.slate : AppColors.emerald,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.className,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              DateFormat.yMMMd().add_jm().format(s.createdAt.toLocal()),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusChip(status: s.status, compact: true),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.muted, size: 20),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONTROLLER HOME (Matching StudentHome layout for Academic Controller)
// ─────────────────────────────────────────────────────────────────────────────

class ControllerHome extends StatelessWidget {
  const ControllerHome({
    super.key,
    required this.state,
    this.onOpenClasses,
  });

  final AppState state;
  final VoidCallback? onOpenClasses;

  Widget _buildControllerMetricCard(String count, String label, {Color? dotColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECEEF1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          if (dotColor != null) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            count,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.slate,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstName = state.user?.name.split(' ').first ?? 'Controller';
    final nowFormatted = DateFormat('EEEE, MMMM d').format(DateTime.now());
    final classes = state.controllerClasses;
    final students = state.controllerStudents;

    return RefreshIndicator(
      onRefresh: state.loadControllerData,
      color: AppColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
        children: [
          // Top Header matching StudentHome: Date + Welcome + Bell + Avatar
          FadeSlideIn(
            offsetY: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nowFormatted,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Welcome, ${state.user?.name ?? firstName}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    // Bell with alert badge
                    Stack(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFECEEF1)),
                          ),
                          child: const Icon(
                            Icons.notifications_none_rounded,
                            size: 22,
                            color: AppColors.ink,
                          ),
                        ),
                        if (state.unreadCount > 0)
                          Positioned(
                            top: 10,
                            right: 12,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    // Profile Avatar
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFE2E8F0),
                      ),
                      child: Center(
                        child: Text(
                          (state.user?.name.isNotEmpty == true ? state.user!.name[0] : 'C').toUpperCase(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Today's Summary Section (Matching StudentHome)
          FadeSlideIn(
            delay: const Duration(milliseconds: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Today\'s Summary',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFECEEF1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Academic Controller Desk',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              classes.isNotEmpty ? '${classes.length} Lecture Halls' : 'Campus Classrooms',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              students.isNotEmpty ? '${students.length} Enrolled Students • Verified' : 'Term Roll Call Active',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.slate,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () {
                          if (onOpenClasses != null) {
                            onOpenClasses!();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Text(
                            'Manage Classrooms',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Overview Strip (3 clean cards)
          FadeSlideIn(
            delay: const Duration(milliseconds: 60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Campus Biometrics Overview',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildControllerMetricCard('${classes.length}', 'Lecture Halls', dotColor: AppColors.primary)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildControllerMetricCard('${students.length}', 'Enrolled', dotColor: AppColors.emerald)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildControllerMetricCard('100%', 'Biometrics Locked', dotColor: const Color(0xFF7C3AED))),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Lecture Halls Directory
          FadeSlideIn(
            delay: const Duration(milliseconds: 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Configured Lecture Theaters',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => onOpenClasses?.call(),
                      child: const Text(
                        'View All',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (classes.isEmpty)
                  const EmptyState(
                    icon: Icons.meeting_room_outlined,
                    title: 'No lecture halls configured',
                    message: 'Classrooms added to the system will appear here.',
                  ),
                ...classes.take(4).map((c) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFECEEF1)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F8F0),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.meeting_room_outlined, color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${c.code} • ${c.roomNumber.isNotEmpty ? c.roomNumber : "LH-${c.capacity > 0 ? c.capacity : 120}"} • ${c.capacity > 0 ? c.capacity : 120}-Seater',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.slate,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.emeraldBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.emeraldBorder),
                          ),
                          child: const Text(
                            'Active',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.emerald,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STUDENT HOME
// ─────────────────────────────────────────────────────────────────────────────

class StudentHome extends StatefulWidget {
  const StudentHome({
    super.key,
    required this.state,
    this.onOpenClockIn,
  });
  final AppState state;
  final VoidCallback? onOpenClockIn;

  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  String filter = 'all'; // 'all', 'present', 'absent', 'pending'
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final attendance = state.studentAttendance;
    final summary = attendance?.summary;
    final firstName = state.user?.name.split(' ').first ?? 'Student';
    final nowFormatted = DateFormat('EEEE, MMMM d').format(DateTime.now());

    final rawEntries = attendance?.entries ?? [];
    final filteredEntries = rawEntries.where((e) {
      if (filter == 'present') return e.isPresent;
      if (filter == 'absent') return e.isAbsent;
      if (filter == 'pending') return e.isPending;
      return true;
    }).toList();

    final openSessions = state.sessions.where((s) => s.isOpen).toList();

    return RefreshIndicator(
      onRefresh: state.retryHome,
      color: AppColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
        children: [
          // Top Header matching Image 2 (Screen 1): Date + Welcome + Bell + Avatar
          FadeSlideIn(
            offsetY: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nowFormatted,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Welcome, ${state.user?.name ?? firstName}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    // Notification Bell with red badge
                    Stack(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFECEEF1)),
                          ),
                          child: const Icon(
                            Icons.notifications_none_rounded,
                            size: 22,
                            color: AppColors.ink,
                          ),
                        ),
                        Positioned(
                          top: 10,
                          right: 12,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    // Profile Avatar
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFE2E8F0),
                      ),
                      child: Center(
                        child: Text(
                          (state.user?.name.isNotEmpty == true ? state.user!.name[0] : 'R').toUpperCase(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          if (state.error != null) ...[
            FadeSlideIn(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: ErrorPanel(
                  message: state.error!,
                  onRetry: () => state.retryHome(),
                ),
              ),
            ),
          ],

          // ── Today's Summary Section (College Next Lecture) ───────────────────────
          FadeSlideIn(
            delay: const Duration(milliseconds: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Today\'s Summary',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFECEEF1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Next Lecture',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              openSessions.isNotEmpty
                                  ? (openSessions.first.className.isNotEmpty ? openSessions.first.className : 'CS401: Distributed Systems')
                                  : 'CS401: Distributed Systems',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              openSessions.isNotEmpty
                                  ? (openSessions.first.classCode.isNotEmpty ? '${openSessions.first.classCode} • LH-120' : 'LH-120 • 09:00 - 10:30 AM')
                                  : 'LH-120 • 09:00 - 10:30 AM',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.slate,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Forest Green Pill Button "Mark Attendance"
                      GestureDetector(
                        onTap: () {
                          if (widget.onOpenClockIn != null) {
                            widget.onOpenClockIn!();
                          } else if (openSessions.isNotEmpty) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => LiveFaceVerificationScreen(
                                  state: state,
                                  session: openSessions.first,
                                ),
                              ),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Text(
                            'Mark Attendance',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Semester Attendance Section (College Record) ─────────────────────
          FadeSlideIn(
            delay: const Duration(milliseconds: 60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Semester Attendance',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => widget.onOpenClockIn?.call(),
                      child: const Text(
                        'Details',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFECEEF1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircularPercentIndicator(
                        radius: 28.0,
                        lineWidth: 6.0,
                        animation: true,
                        percent: (((summary?.present ?? 24) / math.max(1, ((summary?.present ?? 24) + (summary?.absent ?? 3))))).clamp(0.0, 1.0),
                        center: Text(
                          "${((((summary?.present ?? 24) / math.max(1, ((summary?.present ?? 24) + (summary?.absent ?? 3))))) * 100).toInt()}%",
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.ink),
                        ),
                        circularStrokeCap: CircularStrokeCap.round,
                        progressColor: AppColors.primary,
                        backgroundColor: const Color(0xFFE2E8F0),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Overall Attendance Standing',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppColors.ink),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${summary?.present ?? 24} of ${math.max(1, (summary?.present ?? 24) + (summary?.absent ?? 3))} lectures attended • Exam Eligible (≥75%)',
                              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11.5, color: AppColors.slate),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildRequestCard('${summary?.present ?? 24}', 'Attended', dotColor: AppColors.emerald)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildRequestCard('02', 'Excused OD', dotColor: AppColors.amber)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildRequestCard('${summary?.absent ?? 3}', 'Missed', dotColor: AppColors.rose)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Today's Class Schedule Section ──────────────────────────────────
          FadeSlideIn(
            delay: const Duration(milliseconds: 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Today\'s Class Schedule',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      '4 Lectures',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTaskGridCard(
                        icon: Icons.hub_outlined,
                        tag: 'Lecture',
                        tagBg: const Color(0xFFE8F8F0),
                        tagText: const Color(0xFF0D7A5F),
                        title: 'CS401: Distributed Systems',
                        time: 'LH-120 • 09:00 - 10:30 AM',
                        footerNote: 'Prof. Vance',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTaskGridCard(
                        icon: Icons.memory_outlined,
                        tag: 'Theory',
                        tagBg: const Color(0xFFE6F4F1),
                        tagText: const Color(0xFF0284C7),
                        title: 'CS302: Operating Systems',
                        time: 'LH-80 • 11:00 - 12:30 PM',
                        footerNote: 'Dr. Anita',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTaskGridCard(
                        icon: Icons.dataset_outlined,
                        tag: 'Lab / Prac',
                        tagBg: const Color(0xFFFEF3C7),
                        tagText: const Color(0xFFD97706),
                        title: 'CS305: Database Systems Lab',
                        time: 'Lab 3 • 14:00 - 15:30 PM',
                        footerNote: 'Prof. Chen',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTaskGridCard(
                        icon: Icons.auto_awesome_outlined,
                        tag: 'Seminar',
                        tagBg: const Color(0xFFEDE9FE),
                        tagText: const Color(0xFF7C3AED),
                        title: 'CS410: AI & Biometrics',
                        time: 'LH-240 • 16:00 - 17:30 PM',
                        footerNote: 'Dr. Rao',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Registration Locked Status Banner
          if (state.enrollmentStatus?.registrationLocked == true)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.emerald.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.emerald.withValues(alpha: 0.25)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_outline_rounded, color: AppColors.emerald, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Biometric Registration Complete & Locked',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Your facial embedding is securely stored. Registration is closed. Contact Controller if reset needed.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.slate,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Active Session Card (If Any Open)
          if (openSessions.isNotEmpty) ...[
            ...openSessions.map((session) {
              final endsAt = session.endsAt;
              final remaining = endsAt != null ? endsAt.difference(state.serverTimeNow) : Duration.zero;
              final isExpired = remaining.isNegative;
              final minutes = remaining.inMinutes;
              final seconds = (remaining.inSeconds % 60).clamp(0, 59);
              final timerStr = isExpired
                  ? 'Window Closed'
                  : '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

              return FadeSlideIn(
                delay: const Duration(milliseconds: 30),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 18),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isExpired
                          ? AppColors.slate.withValues(alpha: 0.3)
                          : AppColors.primary.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isExpired ? AppColors.roseBg : AppColors.emeraldBg,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: isExpired ? AppColors.roseBorder : AppColors.emeraldBorder,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _PulsingDot(color: isExpired ? AppColors.rose : AppColors.emerald),
                                const SizedBox(width: 5),
                                Text(
                                  isExpired ? 'WINDOW CLOSED' : 'ACTIVE SESSION',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: isExpired ? AppColors.rose : AppColors.emerald,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            timerStr,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                              color: isExpired ? AppColors.rose : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              session.classCode.isNotEmpty ? session.classCode : 'LH-101 • 120-Seater',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.slate,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        session.className.isNotEmpty ? session.className : 'Classroom Session',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Active liveness step indicators
                      const Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _MiniFeatureBadge(icon: Icons.face_rounded, label: 'Frontal & Head Turn (◀ Left / Right ▶)'),
                          _MiniFeatureBadge(icon: Icons.remove_red_eye_rounded, label: 'Eye Blink Liveness (👁️)'),
                          _MiniFeatureBadge(icon: Icons.panorama_photosphere_rounded, label: '180° Classroom Match'),
                        ],
                      ),
                      const SizedBox(height: 14),
                      AnimatedPressable(
                        onTap: isExpired
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => LiveFaceVerificationScreen(
                                      state: state,
                                      session: session,
                                    ),
                                  ),
                                );
                              },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: isExpired ? null : AppColors.primaryGradient,
                            color: isExpired ? AppColors.slate : null,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: isExpired
                                ? null
                                : [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.3),
                                      blurRadius: 14,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isExpired ? Icons.lock_clock_rounded : Icons.face_retouching_natural_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isExpired ? 'Window Closed' : 'Start Active Liveness & Attendance',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.5,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              if (!isExpired) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton.icon(
                          onPressed: isExpired
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => SweepCaptureScreen(
                                        state: state,
                                        session: session,
                                      ),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.cameraswitch_outlined, size: 16),
                          label: const Text(
                            'Alternative: 360° Sweep Capture',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],

          // Hero Attendance Card with Circular Gauge & Counters
          FadeSlideIn(
            delay: const Duration(milliseconds: 60),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: AppColors.studentHeroGradient,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryDark.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Circular Gauge
                      CircularAttendanceGauge(
                        percentage: summary?.percentage ?? 0.0,
                        size: 96,
                        strokeWidth: 9,
                      ),
                      const SizedBox(width: 20),
                      // Breakdown stats
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (summary?.percentage ?? 0) >= 75
                                    ? AppColors.emerald.withValues(alpha: 0.25)
                                    : AppColors.amber.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    (summary?.percentage ?? 0) >= 75
                                        ? Icons.verified_rounded
                                        : Icons.info_outline_rounded,
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    (summary?.percentage ?? 0) >= 75
                                        ? 'Good Standing'
                                        : 'Attention Required',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '${summary?.present ?? 0} of ${summary?.total ?? 0} Sessions',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              summary != null && summary.total > 0
                                  ? 'Your attendance meets minimum academic requirements.'
                                  : 'No finalized sessions recorded yet.',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 14),

                  // Pill Counters
                  Row(
                    children: [
                      Expanded(
                        child: _StatPill(
                          label: 'Present',
                          value: '${summary?.present ?? 0}',
                          color: AppColors.emerald,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatPill(
                          label: 'Absent',
                          value: '${summary?.absent ?? 0}',
                          color: AppColors.rose,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatPill(
                          label: 'Pending',
                          value: '${summary?.pending ?? 0}',
                          color: AppColors.amber,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 26),

          // Filter Segmented Controls
          FadeSlideIn(
            delay: const Duration(milliseconds: 120),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('History', style: Theme.of(context).textTheme.titleLarge),
                Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      selected: filter == 'all',
                      onTap: () => setState(() => filter = 'all'),
                    ),
                    const SizedBox(width: 6),
                    _FilterChip(
                      label: 'Present',
                      selected: filter == 'present',
                      onTap: () => setState(() => filter = 'present'),
                    ),
                    const SizedBox(width: 6),
                    _FilterChip(
                      label: 'Absent',
                      selected: filter == 'absent',
                      onTap: () => setState(() => filter = 'absent'),
                    ),
                    const SizedBox(width: 6),
                    _FilterChip(
                      label: 'Pending',
                      selected: filter == 'pending',
                      onTap: () => setState(() => filter = 'pending'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          if (filteredEntries.isEmpty)
            FadeSlideIn(
              delay: const Duration(milliseconds: 140),
              child: EmptyState(
                icon: Icons.history_toggle_off_rounded,
                title: 'No entries found',
                message: filter == 'all'
                    ? 'Your classroom attendance will appear here.'
                    : 'No sessions matching "$filter" were found.',
              ),
            ),

          ...filteredEntries.asMap().entries.map((entry) {
            final index = entry.key;
            final record = entry.value;

            return FadeSlideIn(
              delay: Duration(milliseconds: 140 + index * 40),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: record.isPresent
                              ? AppColors.emeraldBg
                              : record.isAbsent
                                  ? AppColors.roseBg
                                  : AppColors.amberBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: record.isPresent
                                ? AppColors.emeraldBorder
                                : record.isAbsent
                                    ? AppColors.roseBorder
                                    : AppColors.amberBorder,
                          ),
                        ),
                        child: Icon(
                          record.isPresent
                              ? Icons.check_circle_outline_rounded
                              : record.isAbsent
                                  ? Icons.cancel_outlined
                                  : Icons.schedule_rounded,
                          color: record.isPresent
                              ? AppColors.emerald
                              : record.isAbsent
                                  ? AppColors.rose
                                  : AppColors.amber,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record.className.isNotEmpty
                                  ? record.className
                                  : 'Class Session',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              record.updatedAt != null
                                  ? DateFormat.yMMMd().add_jm().format(record.updatedAt!.toLocal())
                                  : 'Completed',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusChip(status: record.status),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRequestCard(String count, String label, {Color? dotColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECEEF1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          if (dotColor != null) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            count,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.slate,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskGridCard({
    required IconData icon,
    required String tag,
    required Color tagBg,
    required Color tagText,
    required String title,
    required String time,
    bool showAvatars = false,
    bool showStats = false,
    String? footerNote,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFECEEF1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 20, color: AppColors.ink),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tagBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: tagText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            time,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: AppColors.muted,
              height: 1.25,
            ),
          ),
          if (showAvatars || showStats || footerNote != null) ...[
            const SizedBox(height: 10),
            if (footerNote != null)
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 12, color: AppColors.muted),
                    const SizedBox(width: 4),
                    Text(
                      footerNote,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate,
                      ),
                    ),
                  ],
                ),
              ),
            if (showAvatars)
              Row(
                children: [
                  for (int i = 0; i < 3; i++)
                    Align(
                      widthFactor: 0.7,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                          color: [
                            const Color(0xFF3B82F6),
                            const Color(0xFF10B981),
                            const Color(0xFFF59E0B),
                          ][i],
                        ),
                      ),
                    ),
                ],
              ),
            if (showStats)
              const FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Icon(Icons.people_outline_rounded, size: 12, color: AppColors.muted),
                    SizedBox(width: 3),
                    Text('64 Enrolled', style: TextStyle(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STUDENT ATTENDANCE CLOCK IN (Image 2 Center Screen)
// ─────────────────────────────────────────────────────────────────────────────

class _StudentAttendanceClockIn extends StatefulWidget {
  const _StudentAttendanceClockIn({
    required this.state,
    this.onBack,
  });

  final AppState state;
  final VoidCallback? onBack;

  @override
  State<_StudentAttendanceClockIn> createState() => _StudentAttendanceClockInState();
}

class _StudentAttendanceClockInState extends State<_StudentAttendanceClockIn> {
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  void _triggerClockIn(BuildContext context) {
    final openSessions = widget.state.sessions.where((s) => s.isOpen).toList();
    if (openSessions.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LiveFaceVerificationScreen(
            state: widget.state,
            session: openSessions.first,
          ),
        ),
      );
    } else {
      widget.state.retryHome();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active roll call session open right now. Waiting for lecturer.'),
          backgroundColor: Color(0xFF0D7A5F),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final timeStr = DateFormat('HH.mm').format(now);
    final openSessions = widget.state.sessions.where((s) => s.isOpen).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppColors.ink),
          onPressed: widget.onBack ?? () => Navigator.of(context).maybePop(),
        ),
        centerTitle: true,
        title: const Text(
          'Classroom Attendance',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded, size: 24, color: AppColors.ink),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Campus Attendance Terminal • Live')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 110),
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Glowing circular Verify Presence button
            Center(
              child: GestureDetector(
                onTap: () => _triggerClockIn(context),
                child: Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [
                        Color(0xFF109575),
                        Color(0xFF0D7A5F),
                      ],
                      center: Alignment(-0.2, -0.3),
                      radius: 0.9,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0D7A5F).withValues(alpha: 0.40),
                        blurRadius: 36,
                        spreadRadius: 2,
                        offset: const Offset(0, 12),
                      ),
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.20),
                        blurRadius: 18,
                        spreadRadius: -2,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Fingerprint / Biometric Icon
                      Icon(
                        Icons.fingerprint_rounded,
                        size: 48,
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Verify Presence',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Live Time
            Text(
              timeStr,
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: AppColors.ink,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Classroom Biometric Radar · Campus Geofenced to LH-120',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),

            const SizedBox(height: 26),

            // 4-Column Metric Strip (College Course Attendance)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFECEEF1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _buildMetricCol('Course', openSessions.isNotEmpty && openSessions.first.classCode.isNotEmpty ? openSessions.first.classCode : 'CS-401'),
                  _buildMetricDivider(),
                  _buildMetricCol('Hall', 'LH-120'),
                  _buildMetricDivider(),
                  _buildMetricCol('Status', 'Present'),
                  _buildMetricDivider(),
                  _buildMetricCol('Min. Req', '75%'),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Attendance Log Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Lecture Attendance Log',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'This Semester',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.slate,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.slate),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Log Table (College Lectures)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFECEEF1)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      color: const Color(0xFF7A8699),
                      child: const Row(
                        children: [
                          Expanded(flex: 3, child: Text('Date', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11))),
                          Expanded(flex: 3, child: Text('Course', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11))),
                          Expanded(flex: 3, child: Text('Time Slot', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11))),
                          Expanded(flex: 2, child: Text('Status', textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11))),
                        ],
                      ),
                    ),
                    // Table Rows
                    _buildLogRow('Fri, 23 Jan', 'CS401 Dist. Sys', '09:00 - 10:30', 'Present'),
                    _buildLogRow('Thu, 22 Jan', 'CS302 Oper. Sys', '11:00 - 12:30', 'Present'),
                    _buildLogRow('Wed, 21 Jan', 'CS305 DB Lab', '14:00 - 15:30', 'Present'),
                    _buildLogRow('Tue, 20 Jan', 'CS410 AI & ML', '16:00 - 17:30', 'Excused OD', statusColor: AppColors.amber),
                    _buildLogRow('Mon, 19 Jan', 'CS401 Dist. Sys', '09:00 - 10:30', 'Present', isLast: true),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCol(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricDivider() {
    return Container(
      width: 1,
      height: 24,
      color: const Color(0xFFECEEF1),
    );
  }

  Widget _buildLogRow(String date, String course, String time, String status, {bool isLast = false, Color statusColor = AppColors.emerald}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(date, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: AppColors.ink))),
          Expanded(flex: 3, child: Text(course, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: AppColors.slate))),
          Expanded(flex: 3, child: Text(time, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: AppColors.slate))),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    color: statusColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STUDENT RECORDS OVERVIEW (Tab 3 Folder)
// ─────────────────────────────────────────────────────────────────────────────

class _StudentRecordsOverview extends StatelessWidget {
  const _StudentRecordsOverview({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final summary = state.studentAttendance?.summary;
    final entries = state.studentAttendance?.entries ?? [];

    return RefreshIndicator(
      onRefresh: state.retryHome,
      color: AppColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFECEEF1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                CircularAttendanceGauge(
                  percentage: summary?.percentage ?? 0.0,
                  size: 80,
                  strokeWidth: 8,
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cumulative Attendance',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${summary?.present ?? 0} attended of ${summary?.total ?? 0} total sessions',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Course History',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            const EmptyState(
              icon: Icons.folder_open_rounded,
              title: 'No attendance logs',
              message: 'Verified class attendance sessions will appear here.',
            )
          else
            ...entries.map(
              (rec) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: rec.isPresent ? AppColors.emeraldBg : AppColors.roseBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          rec.isPresent ? Icons.check_circle_rounded : Icons.cancel_rounded,
                          color: rec.isPresent ? AppColors.emerald : AppColors.rose,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rec.className.isNotEmpty ? rec.className : 'Class Session',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.ink),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              rec.updatedAt != null
                                  ? DateFormat.yMMMd().add_jm().format(rec.updatedAt!.toLocal())
                                  : 'Recorded',
                              style: const TextStyle(fontSize: 11, color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                      StatusChip(status: rec.status),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? Colors.white : AppColors.slate,
          ),
        ),
      ),
    );
  }
}

class _DurationPresetDialog extends StatefulWidget {
  const _DurationPresetDialog({required this.classroom});
  final Classroom classroom;

  @override
  State<_DurationPresetDialog> createState() => _DurationPresetDialogState();
}

class _DurationPresetDialogState extends State<_DurationPresetDialog> {
  int selectedMinutes = 10;
  bool isCustom = false;
  final TextEditingController customController = TextEditingController(text: '20');

  @override
  void dispose() {
    customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Start Session: ${widget.classroom.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select attendance window duration. Server clock strictly enforces deadline.',
              style: TextStyle(fontSize: 13, color: AppColors.slate),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [5, 10, 15].map((mins) {
                final isSel = !isCustom && selectedMinutes == mins;
                return ChoiceChip(
                  label: Text('$mins mins'),
                  selected: isSel,
                  onSelected: (val) {
                    if (val) {
                      setState(() {
                        selectedMinutes = mins;
                        isCustom = false;
                      });
                    }
                  },
                );
              }).toList()
                ..add(
                  ChoiceChip(
                    label: const Text('Custom'),
                    selected: isCustom,
                    onSelected: (val) {
                      setState(() {
                        isCustom = true;
                      });
                    },
                  ),
                ),
            ),
            if (isCustom) ...[
              const SizedBox(height: 12),
              TextField(
                controller: customController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Duration (minutes, max 60)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            int duration = selectedMinutes;
            if (isCustom) {
              final parsed = int.tryParse(customController.text.trim()) ?? 10;
              duration = parsed.clamp(1, 60);
            }
            Navigator.of(context).pop(duration);
          },
          child: const Text('Launch Session'),
        ),
      ],
    );
  }
}

class _MiniFeatureBadge extends StatelessWidget {
  const _MiniFeatureBadge({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: AppColors.cardSubtle,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
