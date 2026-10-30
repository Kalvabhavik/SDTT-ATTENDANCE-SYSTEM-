import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_floating_bottom_bar/flutter_floating_bottom_bar.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../config/app_config.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../widgets/app_widgets.dart';
import 'notifications_screen.dart';
import 'session_screen.dart';
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
      appBar: (!isStudent && (tab == 2 || tab == 3))
          ? AppBar(
              elevation: 0,
              backgroundColor: AppColors.background,
              title: Text(
                tab == 2
                    ? 'Notifications & Alerts'
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
      body: SafeArea(
        child: BottomBar(
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
      ),
    );
  }

  Widget _buildStudentBody() {
    switch (tab) {
      case 0:
        return StudentHome(
          state: widget.state,
          onOpenClockIn: () => setState(() => tab = 3),
          onOpenProfile: () => setState(() => tab = 1),
          onOpenCalendar: () => setState(() => tab = 2),
        );
      case 1:
        return _StudentProfileView(
          state: widget.state,
          onBack: () => setState(() => tab = 0),
        );
      case 2:
        return _StudentCalendarView(
          state: widget.state,
          onBack: () => setState(() => tab = 0),
        );
      case 3:
        return _StudentAttendanceClockIn(
          state: widget.state,
          onBack: () => setState(() => tab = 0),
        );
      default:
        return StudentHome(
          state: widget.state,
          onOpenClockIn: () => setState(() => tab = 3),
          onOpenProfile: () => setState(() => tab = 1),
          onOpenCalendar: () => setState(() => tab = 2),
        );
    }
  }

  Future<void> _startSessionForClass(Classroom classroom) async {
    final chosenDuration = await showDialog<int>(
      context: context,
      builder: (ctx) => _DurationPresetDialog(classroom: classroom),
    );
    if (chosenDuration == null) return;

    final ok = await widget.state.startSession(classroom.id, durationMinutes: chosenDuration);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => SessionScreen(state: widget.state)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.state.error ?? 'Could not start session.'),
          backgroundColor: AppColors.rose,
        ),
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
        return _TeacherClassesOverview(
          state: widget.state,
          onStartSession: _startSessionForClass,
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
        return _ControllerLiveMonitor(
          state: widget.state,
          onOpenController: () => setState(() => tab = 3),
        );
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
    final isController = widget.state.isController;
    final isStudent = !isTeacher && !isController;

    if (isStudent) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildDockItem(icon: Icons.home_rounded, index: 0, label: 'Home'),
            _buildDockItem(icon: Icons.person_rounded, index: 1, label: 'Profile'),
            _buildDockItem(icon: Icons.calendar_month_rounded, index: 2, label: 'Schedule'),
            _buildDockItem(icon: Icons.access_time_rounded, index: 3, label: 'Clock In'),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildDockItem(icon: Icons.home_rounded, index: 0, label: 'Home'),
          _buildDockItem(
            icon: isTeacher
                ? Icons.videocam_outlined
                : Icons.camera_alt_outlined,
            index: 1,
            label: isTeacher ? 'Sessions' : 'Monitor',
          ),
          _buildDockItem(icon: Icons.chat_bubble_outline_rounded, index: 2, label: 'Alerts'),
          _buildDockItem(
            icon: isTeacher
                ? Icons.school_outlined
                : Icons.meeting_room_outlined,
            index: 3,
            label: isTeacher ? 'Classes' : 'Halls',
          ),
          _buildDockItem(icon: Icons.settings_outlined, index: 4, label: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildDockItem({required IconData icon, required int index, String label = ''}) {
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
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: isSelected && label.isNotEmpty
            ? const EdgeInsets.symmetric(horizontal: 14, vertical: 7)
            : const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE0F2FE) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF64748B),
            ),
            if (isSelected && label.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0284C7),
                ),
              ),
            ],
          ],
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

// ─────────────────────────────────────────────────────────────────────────────
// STUDENT HOME (Image 1 Screen 1: Modern Sky Blue Attendance Interface)
// ─────────────────────────────────────────────────────────────────────────────

class StudentHome extends StatefulWidget {
  const StudentHome({
    super.key,
    required this.state,
    this.onOpenClockIn,
    this.onOpenCalendar,
    this.onOpenProfile,
  });
  final AppState state;
  final VoidCallback? onOpenClockIn;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenProfile;

  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
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

  void _showLeaveDialog() {
    String reason = 'Medical Leave';
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.event_busy_rounded, color: Color(0xFFFF6584)),
              SizedBox(width: 8),
              Text('Request Leave / Absence', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select reason for absence today:', style: TextStyle(fontSize: 12, color: AppColors.slate)),
              const SizedBox(height: 12),
              for (final r in ['Medical Leave', 'Official College Duty', 'Family Emergency', 'Academic Competition'])
                RadioListTile<String>(
                  title: Text(r, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  value: r,
                  groupValue: reason,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: const Color(0xFF0284C7),
                  onChanged: (val) {
                    if (val != null) setDlgState(() => reason = val);
                  },
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.slate)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Absence notice "$reason" recorded for college attendance.'),
                    backgroundColor: const Color(0xFF0284C7),
                  ),
                );
              },
              child: const Text('Submit Request'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCoursesModal() {
    final todayClasses = widget.state.todayTimetable;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Enrolled Courses & Sections', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink)),
              const SizedBox(height: 4),
              const Text('Authorized lecture halls and faculty assignments', style: TextStyle(fontSize: 12, color: AppColors.slate)),
              const SizedBox(height: 16),
              if (todayClasses.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('No classes scheduled today.', style: TextStyle(color: AppColors.muted))),
                )
              else
                ...todayClasses.map((cls) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFECEEF1)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.school_rounded, color: Color(0xFF0284C7), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${cls['subject_code']}: ${cls['subject_name']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.ink)),
                            const SizedBox(height: 2),
                            Text('${cls['start_time']} - ${cls['end_time']} • ${cls['room'] ?? "LH-120"} • ${cls['faculty_name'] ?? "Faculty"}', style: const TextStyle(fontSize: 11, color: AppColors.slate)),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final attendance = state.studentAttendance;
    final summary = attendance?.summary;
    final firstName = state.user?.name.split(' ').first ?? 'Firman';
    final now = DateTime.now();
    final dateFormatted = DateFormat('yyyy, MMM d').format(now);

    final openSessions = state.sessions.where((s) => s.isOpen).toList();
    final todayClasses = state.todayTimetable;

    final firstClassTime = todayClasses.isNotEmpty ? (todayClasses.first['start_time']?.toString().replaceAll(':', '.') ?? '07.44') : '07.44';
    final nextClassTime = state.nextClass != null ? (state.nextClass!['start_time']?.toString().replaceAll(':', '.') ?? '09.00') : '09.00';
    final lastClassTime = todayClasses.isNotEmpty ? (todayClasses.last['end_time']?.toString().replaceAll(':', '.') ?? '16.44') : '16.44';
    final locationText = state.nextClass != null
        ? '${state.nextClass!['room'] ?? "LH-101"}, Computer Science Wing, SDTT'
        : 'Jl. MH Thamrin, Kebon Sirih, Kec. Menteng, Jakarta Pusat';

    return RefreshIndicator(
      onRefresh: state.retryHome,
      color: const Color(0xFF0284C7),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: EdgeInsets.zero,
        children: [
          // ── Top Gradient Hero Header (Sky Blue Gradient from Reference Image) ──
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Menu Button (Left) + Notification & Avatar (Right)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Hamburger Menu
                    GestureDetector(
                      onTap: () {
                        // Open Settings / Connection Sheet
                        showModalBottomSheet<void>(
                          context: context,
                          backgroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                          ),
                          builder: (ctx) => SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(state.user?.name ?? 'Student', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 4),
                                  Text(state.user?.email ?? '', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                                  const SizedBox(height: 16),
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.lan_rounded, color: Color(0xFF0284C7)),
                                    title: const Text('Toggle Server Mode'),
                                    subtitle: Text(AppConfig.connectionModeLabel),
                                    onTap: () {
                                      AppConfig.toggleServerUrl();
                                      Navigator.pop(ctx);
                                      setState(() {});
                                    },
                                  ),
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.logout_rounded, color: AppColors.rose),
                                    title: const Text('Sign Out', style: TextStyle(color: AppColors.rose)),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      state.logout();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.menu_rounded, color: Colors.white, size: 22),
                      ),
                    ),
                    // Right Avatar & Bell
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => NotificationsScreen(state: state)),
                            );
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                        GestureDetector(
                          onTap: widget.onOpenProfile,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const ClipOval(
                              child: _Character3DAvatar(size: 40),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // "Hello, Firman!"
                Text(
                  'Hello, $firstName!',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),

          // ── Overlapping Content Body ──
          Transform.translate(
            offset: const Offset(0, -32),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 1. "My Attendance" White Card (Screen 1 Main Card) ──
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.10),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card Header: "My Attendance" + Date
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'My Attendance',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                            Text(
                              dateFormatted,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Row of 3 Clock Chips (07.44 / 09.00 / 16.44 from reference)
                        Row(
                          children: [
                            _buildTimePill(Icons.access_time_rounded, firstClassTime, const Color(0xFF94A3B8)),
                            const SizedBox(width: 8),
                            _buildTimePill(Icons.access_time_filled_rounded, nextClassTime, const Color(0xFF10B981)),
                            const SizedBox(width: 8),
                            _buildTimePill(Icons.logout_rounded, lastClassTime, const Color(0xFFF97316)),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Subtitle Location
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                locationText,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ── 2. Four Colorful Action Buttons (Leave, Calendar, Salary/Courses, Task) ──
                  Row(
                    children: [
                      // Coral Pink: Leave
                      Expanded(
                        child: _buildActionTile(
                          icon: Icons.event_busy_rounded,
                          label: 'Leave',
                          color: const Color(0xFFFF6584),
                          onTap: _showLeaveDialog,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Sky Blue: Calendar
                      Expanded(
                        child: _buildActionTile(
                          icon: Icons.calendar_month_rounded,
                          label: 'Calendar',
                          color: const Color(0xFF38BDF8),
                          onTap: widget.onOpenCalendar,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Mint Green: Courses
                      Expanded(
                        child: _buildActionTile(
                          icon: Icons.school_rounded,
                          label: 'Courses',
                          color: const Color(0xFF34D399),
                          onTap: _showCoursesModal,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Soft Violet: Sessions
                      Expanded(
                        child: _buildActionTile(
                          icon: Icons.face_retouching_natural_rounded,
                          label: 'Sessions',
                          color: const Color(0xFFA78BFA),
                          onTap: () {
                            if (openSessions.isNotEmpty) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => LiveFaceVerificationScreen(
                                    state: state,
                                    session: openSessions.first,
                                  ),
                                ),
                              );
                            } else {
                              widget.onOpenClockIn?.call();
                            }
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // ── 3. "Today's Task" / Schedule Section Header with Chevron ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Today's Schedule',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                          letterSpacing: -0.3,
                        ),
                      ),
                      GestureDetector(
                        onTap: widget.onOpenCalendar,
                        child: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Schedule Item 1: Elevated Interactive Card (Card 1 in Reference) ──
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Left Checkmark Box (Blue pill container like screenshot)
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF38BDF8),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.check_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 14),
                        // Dot & Text
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF0284C7),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                todayClasses.isNotEmpty
                                    ? '${todayClasses[0]['subject_code']}: ${todayClasses[0]['subject_name']}'
                                    : 'CS401: Distributed Systems',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppColors.ink),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                todayClasses.isNotEmpty
                                    ? '${todayClasses[0]['start_time']} - ${todayClasses[0]['end_time']} • ${todayClasses[0]['room'] ?? "LH-120"}'
                                    : '10:00 - 11:00 AM • LH-120',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.calendar_month_outlined, size: 20, color: Color(0xFF0284C7)),
                          tooltip: 'Add to Google Calendar',
                          onPressed: () {
                            final cls = todayClasses.isNotEmpty ? todayClasses[0] : {
                              'subject_code': 'CS401',
                              'subject_name': 'Distributed Systems',
                              'start_time': '10:00',
                              'end_time': '11:00',
                              'room': 'LH-120',
                              'faculty_name': 'Prof. Turing',
                            };
                            final url = state.api.generateGoogleCalendarUrl(
                              title: '${cls['subject_code']}: ${cls['subject_name']}',
                              startTime: cls['start_time']?.toString() ?? '10:00',
                              endTime: cls['end_time']?.toString() ?? '11:00',
                              location: cls['room']?.toString() ?? 'LH-120',
                              details: 'College lecture verified on Attendrix.',
                            );
                            Clipboard.setData(ClipboardData(text: url));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Google Calendar link copied to clipboard!')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // ── Schedule Item 2: Reporting / Practical (Card 2 in Reference) ──
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 6, right: 12),
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                todayClasses.length > 1
                                    ? '${todayClasses[1]['subject_code']}: ${todayClasses[1]['subject_name']}'
                                    : 'CS262: Data Structures Lab',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppColors.ink),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                todayClasses.length > 1
                                    ? '${todayClasses[1]['start_time']} - ${todayClasses[1]['end_time']} • ${todayClasses[1]['room'] ?? "Lab 3"}'
                                    : '01:00 PM • Lab 3',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Scheduled',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Schedule Item 3: Online Meeting / Lecture with Arrow Button (Card 3 in Reference) ──
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 6, right: 12),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF6584),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                todayClasses.length > 2
                                    ? '${todayClasses[2]['subject_code']}: ${todayClasses[2]['subject_name']}'
                                    : 'CS264: Computer Architecture',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppColors.ink),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                todayClasses.length > 2
                                    ? '${todayClasses[2]['start_time']} - ${todayClasses[2]['end_time']} • ${todayClasses[2]['room'] ?? "LH-204"}'
                                    : '02:00 - 3:30 PM • LH-204',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        // Circular Blue Arrow Action Button (From Screenshot)
                        GestureDetector(
                          onTap: () {
                            if (openSessions.isNotEmpty) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => LiveFaceVerificationScreen(
                                    state: state,
                                    session: openSessions.first,
                                  ),
                                ),
                              );
                            } else {
                              widget.onOpenCalendar?.call();
                            }
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: Color(0xFF38BDF8),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Active Live Session Card (If Teacher Opened Session) ──
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

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.4), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                              blurRadius: 14,
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
                                    color: isExpired ? AppColors.roseBg : const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    children: [
                                      _PulsingDot(color: isExpired ? AppColors.rose : const Color(0xFF10B981)),
                                      const SizedBox(width: 5),
                                      Text(
                                        isExpired ? 'WINDOW CLOSED' : 'ACTIVE LIVE SESSION',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: isExpired ? AppColors.rose : const Color(0xFF059669),
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
                                    color: isExpired ? AppColors.rose : const Color(0xFF0284C7),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              session.className.isNotEmpty ? session.className : 'Classroom Attendance Session',
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${session.classCode} • Verify your presence via contactless face recognition',
                              style: const TextStyle(fontSize: 11.5, color: AppColors.slate),
                            ),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: isExpired ? null : () {
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
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: isExpired ? null : const LinearGradient(colors: [Color(0xFF38BDF8), Color(0xFF0284C7)]),
                                  color: isExpired ? AppColors.slate : null,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.face_retouching_natural_rounded, color: Colors.white, size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        'Start Face Verification',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],

                  // ── 4. Semester Attendance Summary (Circular Indicator & Presence) ──
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 90),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFECEEF1)),
                    ),
                    child: Row(
                      children: [
                        CircularPercentIndicator(
                          radius: 30.0,
                          lineWidth: 6.0,
                          animation: true,
                          percent: (((summary?.present ?? 24) / math.max(1, ((summary?.present ?? 24) + (summary?.absent ?? 3))))).clamp(0.0, 1.0),
                          center: Text(
                            "${((((summary?.present ?? 24) / math.max(1, ((summary?.present ?? 24) + (summary?.absent ?? 3))))) * 100).toInt()}%",
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.ink),
                          ),
                          circularStrokeCap: CircularStrokeCap.round,
                          progressColor: const Color(0xFF0284C7),
                          backgroundColor: const Color(0xFFE2E8F0),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Semester Attendance', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink)),
                              const SizedBox(height: 3),
                              Text(
                                '${summary?.present ?? 24} Present • ${summary?.absent ?? 3} Absent',
                                style: const TextStyle(fontSize: 11.5, color: AppColors.slate, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('Good Standing', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePill(IconData icon, String time, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor),
          const SizedBox(width: 5),
          Text(
            time,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            height: 62,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STUDENT PROFILE VIEW (Image 1 Screen 2: 3D Character Avatar & Verified Student Card)
// ─────────────────────────────────────────────────────────────────────────────


// ─────────────────────────────────────────────────────────────────────────────
// 3D ILLUSTRATED CHARACTER AVATAR (Image 1 Screen 2 Avatar Model)
// ─────────────────────────────────────────────────────────────────────────────

class _Character3DAvatar extends StatelessWidget {
  const _Character3DAvatar({super.key, this.size = 140});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _Character3DPainter(),
      ),
    );
  }
}

class _Character3DPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    // 1. Ears (Left & Right round 3D lobes)
    final earShader = RadialGradient(
      center: const Alignment(-0.2, -0.2),
      colors: const [Color(0xFFFDC5B0), Color(0xFFF8A589), Color(0xFFE28B70)],
    ).createShader(Rect.fromCircle(center: Offset(w * 0.17, h * 0.52), radius: w * 0.12));
    final earPaint = Paint()..shader = earShader;
    canvas.drawCircle(Offset(w * 0.17, h * 0.52), w * 0.11, earPaint);

    final rightEarShader = RadialGradient(
      center: const Alignment(0.2, -0.2),
      colors: const [Color(0xFFFDC5B0), Color(0xFFF8A589), Color(0xFFE28B70)],
    ).createShader(Rect.fromCircle(center: Offset(w * 0.83, h * 0.52), radius: w * 0.12));
    final rightEarPaint = Paint()..shader = rightEarShader;
    canvas.drawCircle(Offset(w * 0.83, h * 0.52), w * 0.11, rightEarPaint);

    // Inner ear shadows
    final innerEarPaint = Paint()..color = const Color(0xFFD6775C).withValues(alpha: 0.45);
    canvas.drawCircle(Offset(w * 0.18, h * 0.52), w * 0.055, innerEarPaint);
    canvas.drawCircle(Offset(w * 0.82, h * 0.52), w * 0.055, innerEarPaint);

    // 2. Face Base (Smooth 3D Spherical Head)
    final faceRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(center.dx, center.dy + h * 0.04), width: w * 0.65, height: h * 0.62),
      Radius.circular(w * 0.28),
    );
    final facePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.25, -0.35),
        radius: 0.9,
        colors: const [Color(0xFFFED7C7), Color(0xFFF8A589), Color(0xFFDE8266)],
      ).createShader(faceRect.outerRect);
    canvas.drawRRect(faceRect, facePaint);

    // 3. Hair (Voluminous glossy 3D styled hair)
    final hairPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Color(0xFF334155), Color(0xFF1E293B), Color(0xFF0F172A)],
      ).createShader(Rect.fromLTWH(w * 0.14, h * 0.04, w * 0.72, h * 0.44));

    final hairPath = Path()
      ..moveTo(w * 0.15, h * 0.42)
      ..cubicTo(w * 0.12, h * 0.15, w * 0.32, h * 0.03, w * 0.50, h * 0.03)
      ..cubicTo(w * 0.68, h * 0.03, w * 0.88, h * 0.15, w * 0.85, h * 0.42)
      ..cubicTo(w * 0.80, h * 0.32, w * 0.70, h * 0.26, w * 0.58, h * 0.28)
      ..cubicTo(w * 0.44, h * 0.30, w * 0.30, h * 0.24, w * 0.15, h * 0.42)
      ..close();
    canvas.drawPath(hairPath, hairPaint);

    // Specular Hair Sheen / Highlight (gloss reflection)
    final hairHighlight = Paint()
      ..shader = LinearGradient(
        colors: [Colors.white.withValues(alpha: 0.50), Colors.white.withValues(alpha: 0.0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(w * 0.32, h * 0.07, w * 0.36, h * 0.14));

    final highlightPath = Path()
      ..moveTo(w * 0.35, h * 0.14)
      ..cubicTo(w * 0.40, h * 0.08, w * 0.55, h * 0.08, w * 0.65, h * 0.15)
      ..cubicTo(w * 0.55, h * 0.11, w * 0.42, h * 0.11, w * 0.35, h * 0.14)
      ..close();
    canvas.drawPath(highlightPath, hairHighlight);

    // 4. Eyebrows
    final browPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.038
      ..strokeCap = StrokeCap.round;

    final leftBrow = Path()
      ..moveTo(w * 0.34, h * 0.42)
      ..quadraticBezierTo(w * 0.41, h * 0.39, w * 0.47, h * 0.42);
    final rightBrow = Path()
      ..moveTo(w * 0.53, h * 0.42)
      ..quadraticBezierTo(w * 0.59, h * 0.39, w * 0.66, h * 0.42);
    canvas.drawPath(leftBrow, browPaint);
    canvas.drawPath(rightBrow, browPaint);

    // 5. Cartoon Eyes with Catchlight
    final eyePaint = Paint()..color = const Color(0xFF1E293B);
    final leftEyeRect = Rect.fromCenter(center: Offset(w * 0.41, h * 0.48), width: w * 0.065, height: h * 0.085);
    final rightEyeRect = Rect.fromCenter(center: Offset(w * 0.59, h * 0.48), width: w * 0.065, height: h * 0.085);
    canvas.drawOval(leftEyeRect, eyePaint);
    canvas.drawOval(rightEyeRect, eyePaint);

    // Pure White Catchlight Sparkle
    final catchlightPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(w * 0.425, h * 0.465), w * 0.018, catchlightPaint);
    canvas.drawCircle(Offset(w * 0.605, h * 0.465), w * 0.018, catchlightPaint);

    // 6. Rounded 3D Button Nose
    final nosePaint = Paint()
      ..shader = RadialGradient(
        colors: const [Color(0xFFFCAE95), Color(0xFFE2886E)],
      ).createShader(Rect.fromCircle(center: Offset(w * 0.50, h * 0.54), radius: w * 0.045));
    canvas.drawCircle(Offset(w * 0.50, h * 0.54), w * 0.042, nosePaint);

    // 7. Beard & Mustache (hugging the jawline like reference image)
    final beardPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Color(0xFF27303F), Color(0xFF1E293B), Color(0xFF0F172A)],
      ).createShader(Rect.fromLTWH(w * 0.22, h * 0.56, w * 0.56, h * 0.22));

    final beardPath = Path()
      ..moveTo(w * 0.25, h * 0.56)
      ..cubicTo(w * 0.24, h * 0.74, w * 0.36, h * 0.77, w * 0.50, h * 0.77)
      ..cubicTo(w * 0.64, h * 0.77, w * 0.76, h * 0.74, w * 0.75, h * 0.56)
      ..cubicTo(w * 0.70, h * 0.62, w * 0.62, h * 0.64, w * 0.50, h * 0.64)
      ..cubicTo(w * 0.38, h * 0.64, w * 0.30, h * 0.62, w * 0.25, h * 0.56)
      ..close();
    canvas.drawPath(beardPath, beardPaint);

    // 8. Smiling Mouth with Teeth
    final mouthBg = Paint()..color = const Color(0xFF881337);
    final mouthPath = Path()
      ..moveTo(w * 0.43, h * 0.63)
      ..quadraticBezierTo(w * 0.50, h * 0.70, w * 0.57, h * 0.63)
      ..close();
    canvas.drawPath(mouthPath, mouthBg);

    // Clean white teeth bar
    final teethPaint = Paint()..color = Colors.white;
    final teethRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.445, h * 0.63, w * 0.11, h * 0.024),
      const Radius.circular(2),
    );
    canvas.drawRRect(teethRect, teethPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StudentProfileView extends StatelessWidget {
  const _StudentProfileView({
    required this.state,
    this.onBack,
  });

  final AppState state;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final user = state.user;
    final name = user?.name ?? 'Ge Firman';
    final email = user?.email ?? 'gefirmans@gmail.com';
    final rollNumber = user?.rollNumber ?? '21BCS042';
    final studentId = user?.studentId ?? 'STU-9402';
    final isLocked = user?.registrationLocked ?? true;
    final summary = state.studentAttendance?.summary;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F6FE),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const BouncingScrollPhysics(),
          children: [
            // Sky-Blue Gradient Header Banner with Back Button
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                        onPressed: onBack,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Student Profile',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Stylized 3D Avatar Hero (Matches Screen 2 Reference) ──
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Soft Outer Glow Ring 1
                        Container(
                          width: 190,
                          height: 190,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        // Soft Outer Glow Ring 2
                        Container(
                          width: 165,
                          height: 165,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                        // 3D Avatar Character Model
                        const _Character3DAvatar(size: 150),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Large White Profile Card (Matches Screen 2 Reference) ──
            Transform.translate(
              offset: const Offset(0, -20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Mini Avatar (matching Screen 2 profile card)
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const ClipOval(
                          child: _Character3DAvatar(size: 48),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Name
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),

                      // Role / Major
                      const Text(
                        'Computer Science & Engineering',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Date / Email
                      Text(
                        'Roll: $rollNumber  |  $email',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Bio text
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFECEEF1)),
                        ),
                        child: const Text(
                          'Student at SDTT Campus. Multi-angle facial embeddings registered & verified for high-trust automated attendance.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF475569),
                            height: 1.35,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 4 Info Badges from Database Schema
                      Row(
                        children: [
                          Expanded(
                            child: _buildProfileMetricTile(
                              icon: Icons.lock_outline_rounded,
                              label: 'Registration',
                              value: isLocked ? 'Locked' : 'Open',
                              color: isLocked ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildProfileMetricTile(
                              icon: Icons.badge_outlined,
                              label: 'Student ID',
                              value: studentId,
                              color: const Color(0xFF0284C7),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildProfileMetricTile(
                              icon: Icons.verified_user_outlined,
                              label: 'Biometric Model',
                              value: 'ArcFace ResNet',
                              color: const Color(0xFF8B5CF6),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildProfileMetricTile(
                              icon: Icons.analytics_outlined,
                              label: 'Attendance Rate',
                              value: '${summary?.percentage.toStringAsFixed(1) ?? '89.5'}%',
                              color: const Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Settings & Sign Out Actions
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.lan_rounded, color: Color(0xFF0284C7)),
                        title: const Text('Server Connection Mode', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        subtitle: Text(AppConfig.connectionModeLabel, style: const TextStyle(fontSize: 11, color: AppColors.slate)),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF1F5F9),
                            foregroundColor: AppColors.ink,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            AppConfig.toggleServerUrl();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Switched to ${AppConfig.isUsingLan ? "LAN Wi-Fi" : "USB Localhost"}')),
                            );
                          },
                          child: Text(AppConfig.isUsingLan ? 'Use USB' : 'Use Wi-Fi', style: const TextStyle(fontSize: 11.5)),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.logout_rounded, color: AppColors.rose),
                        title: const Text('Sign Out', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.rose)),
                        onTap: () => state.logout(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileMetricTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFECEEF1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STUDENT CALENDAR & TIMETABLE (Image 1 Screen 3: Monthly Matrix & Day Schedule)
// ─────────────────────────────────────────────────────────────────────────────

class _StudentCalendarView extends StatefulWidget {
  const _StudentCalendarView({
    required this.state,
    this.onBack,
  });

  final AppState state;
  final VoidCallback? onBack;

  @override
  State<_StudentCalendarView> createState() => _StudentCalendarViewState();
}

class _StudentCalendarViewState extends State<_StudentCalendarView> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final now = DateTime.now();
    final yearStr = DateFormat('yyyy').format(_selectedDate);
    final monthStr = DateFormat('MMMM').format(_selectedDate).toUpperCase();
    final todayStr = DateFormat('yyyy, d MMM').format(_selectedDate);
    final tomorrow = _selectedDate.add(const Duration(days: 1));
    final nextStr = DateFormat('yyyy, d MMM').format(tomorrow);

    final todayClasses = state.todayTimetable;
    final nextClass = state.nextClass;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F6FE),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const BouncingScrollPhysics(),
          children: [
            // ── Top Gradient Calendar Header (Screen 3 Reference) ──
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back Arrow & Year
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                        onPressed: widget.onBack,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$yearStr ▼',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Month Dropdown Title (e.g. "OCTOBER ▼" matching "MARCH ▼")
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      '$monthStr ▼',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Weekdays Row: Sun Mon Tue Wed Thu Fri Sat
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: const [
                        Text('Sun', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                        Text('Mon', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                        Text('Tue', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                        Text('Wed', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                        Text('Thu', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                        Text('Fri', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                        Text('Sat', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Monthly Calendar Days Matrix with Indicator Dots
                  _buildCalendarMatrix(now),
                ],
              ),
            ),

            // ── Schedule Cards Below ──
            Transform.translate(
              offset: const Offset(0, -14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  children: [
                    // ── Card A: Today's Schedule (Screen 3 Card 1) ──
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.08),
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
                              Text(
                                'Today  $todayStr',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink),
                              ),
                              const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF38BDF8)),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Lectures with colored dots (Blue, Green, Red)
                          _buildScheduleDotRow(
                            color: const Color(0xFF0284C7),
                            title: todayClasses.isNotEmpty ? '${todayClasses[0]['subject_code']}: ${todayClasses[0]['subject_name']}' : 'CS401: Distributed Systems',
                            time: todayClasses.isNotEmpty ? '${todayClasses[0]['start_time']} - ${todayClasses[0]['end_time']}' : '09:00 - 10:30 AM',
                            room: todayClasses.isNotEmpty ? '${todayClasses[0]['room'] ?? "LH-120"}' : 'LH-120',
                          ),
                          const SizedBox(height: 10),
                          _buildScheduleDotRow(
                            color: const Color(0xFF10B981),
                            title: todayClasses.length > 1 ? '${todayClasses[1]['subject_code']}: ${todayClasses[1]['subject_name']}' : 'CS262: Data Structures Lab',
                            time: todayClasses.length > 1 ? '${todayClasses[1]['start_time']} - ${todayClasses[1]['end_time']}' : '11:00 AM - 12:30 PM',
                            room: todayClasses.length > 1 ? '${todayClasses[1]['room'] ?? "Lab 3"}' : 'Lab 3',
                          ),
                          const SizedBox(height: 10),
                          _buildScheduleDotRow(
                            color: const Color(0xFFFF6584),
                            title: todayClasses.length > 2 ? '${todayClasses[2]['subject_code']}: ${todayClasses[2]['subject_name']}' : 'CS264: Computer Architecture',
                            time: todayClasses.length > 2 ? '${todayClasses[2]['start_time']} - ${todayClasses[2]['end_time']}' : '02:00 - 03:30 PM',
                            room: todayClasses.length > 2 ? '${todayClasses[2]['room'] ?? "LH-204"}' : 'LH-204',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Card B: Next Schedule (Screen 3 Card 2) ──
                    Container(
                      padding: const EdgeInsets.all(18),
                      margin: const EdgeInsets.only(bottom: 90),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.08),
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
                              Text(
                                'Next schedule  $nextStr',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink),
                              ),
                              const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF38BDF8)),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _buildScheduleDotRow(
                            color: const Color(0xFF0284C7),
                            title: nextClass != null
                                ? '${nextClass['subject_code']}: ${nextClass['subject_name']}'
                                : 'CS302: Operating Systems & Kernel',
                            time: nextClass != null
                                ? '${nextClass['start_time']} - ${nextClass['end_time']}'
                                : '10:00 - 11:30 AM',
                            room: nextClass != null ? '${nextClass['room'] ?? "LH-80"}' : 'LH-80',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleDotRow({
    required Color color,
    required String title,
    required String time,
    required String room,
  }) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '$time • $room',
                style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarMatrix(DateTime now) {
    final days = [
      [1, 2, 3, 4, 5, 6, 7],
      [8, 9, 10, 11, 12, 13, 14],
      [15, 16, 17, 18, 19, 20, 21],
      [22, 23, 24, 25, 26, 27, 28],
      [29, 30, 31, 0, 0, 0, 0],
    ];

    return Column(
      children: [
        for (final week in days)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (final day in week)
                  if (day == 0)
                    const SizedBox(width: 34, height: 38)
                  else
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedDate = DateTime(now.year, now.month, day);
                        });
                      },
                      child: Container(
                        width: 34,
                        height: 38,
                        decoration: BoxDecoration(
                          color: _selectedDate.day == day ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$day',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: _selectedDate.day == day ? FontWeight.w900 : FontWeight.w600,
                                color: _selectedDate.day == day ? const Color(0xFF0284C7) : Colors.white,
                              ),
                            ),
                            if (day % 3 == 0 || day == now.day) ...[
                              const SizedBox(height: 2),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: _selectedDate.day == day ? const Color(0xFF0284C7) : Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
              ],
            ),
          ),
      ],
    );
  }
}


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

class _TeacherClassesOverview extends StatelessWidget {
  const _TeacherClassesOverview({
    required this.state,
    this.onStartSession,
  });

  final AppState state;
  final ValueChanged<Classroom>? onStartSession;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: state.retryHome,
      color: AppColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Class Management',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Assigned classrooms and course rosters',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${state.classes.length} Classes',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (state.classes.isEmpty)
            const EmptyState(
              icon: Icons.school_outlined,
              title: 'No Classes Assigned',
              message: 'Assigned courses and classes will appear here.',
            )
          else
            ...state.classes.map((c) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: AppCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.accentIndigoBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Icon(Icons.school_rounded, color: AppColors.primary, size: 22),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${c.code} • ${c.roomNumber} • ${c.capacity} Seats',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.slate,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.people_outline_rounded, size: 16, color: AppColors.muted),
                              const SizedBox(width: 6),
                              Text(
                                '${c.capacity} Max Hall Size',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.slate,
                                ),
                              ),
                            ],
                          ),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            onPressed: () => onStartSession?.call(c),
                            icon: const Icon(Icons.play_arrow_rounded, size: 16),
                            label: const Text(
                              'Start Session',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _ControllerLiveMonitor extends StatelessWidget {
  const _ControllerLiveMonitor({
    required this.state,
    this.onOpenController,
  });

  final AppState state;
  final VoidCallback? onOpenController;

  @override
  Widget build(BuildContext context) {
    final openSessions = state.sessions.where((s) => s.isOpen).toList();
    final closedSessions = state.sessions.where((s) => !s.isOpen).toList();

    return RefreshIndicator(
      onRefresh: state.retryHome,
      color: AppColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Live Session Monitor',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Campus-wide real-time attendance roll calls',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: openSessions.isNotEmpty
                      ? AppColors.emerald.withValues(alpha: 0.15)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${openSessions.length} Active',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: openSessions.isNotEmpty ? AppColors.emerald : AppColors.slate,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (openSessions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: AppCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.radio_button_checked_rounded, size: 40, color: AppColors.muted),
                    const SizedBox(height: 12),
                    const Text(
                      'No Active Roll Calls',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'All lectures and sessions are currently closed. New live roll calls will appear here automatically.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.slate),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: onOpenController,
                      icon: const Icon(Icons.tune_rounded, size: 16),
                      label: const Text('Open System Controller'),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            const Text(
              'Active In-Progress Sessions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
            const SizedBox(height: 12),
            ...openSessions.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.emerald,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.className.isNotEmpty ? s.className : 'Session ${s.id.substring(0, 8)}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${s.verifiedCount} Verified Present • Hall: ${s.classCode}',
                            style: const TextStyle(fontSize: 12, color: AppColors.slate),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )),
          ],
          if (closedSessions.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Recent Concluded Sessions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
            const SizedBox(height: 12),
            ...closedSessions.take(5).map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, color: AppColors.muted, size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        s.className.isNotEmpty ? s.className : 'Session ${s.id.substring(0, 8)}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                      ),
                    ),
                    Text(
                      '${s.verifiedCount} Present',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: AppColors.slate),
                    ),
                  ],
                ),
              ),
            )),
          ],
        ],
      ),
    );
  }
}

