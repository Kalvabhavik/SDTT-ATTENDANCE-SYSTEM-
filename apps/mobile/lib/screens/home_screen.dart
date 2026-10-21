import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../widgets/app_widgets.dart';
import 'notifications_screen.dart';
import 'session_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.state});
  final AppState state;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(
              tab == 1
                  ? 'Notifications'
                  : widget.state.isTeacher
                      ? 'Teacher desk'
                      : 'My attendance',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          actions: [
            if (widget.state.liveMessage != null)
              const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.wifi_rounded, color: AppColors.teal)),
            IconButton(
                tooltip: 'Refresh',
                onPressed: widget.state.busy ? null : widget.state.retryHome,
                icon: const Icon(Icons.refresh_rounded)),
            PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'logout') widget.state.logout();
                },
                itemBuilder: (_) => const [
                      PopupMenuItem(value: 'logout', child: Text('Sign out'))
                    ]),
          ],
        ),
        body: tab == 1
            ? NotificationsScreen(state: widget.state)
            : widget.state.isTeacher
                ? TeacherHome(state: widget.state)
                : StudentHome(state: widget.state),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (index) => setState(() => tab = index),
          destinations: [
            NavigationDestination(
                icon: Icon(widget.state.isTeacher
                    ? Icons.dashboard_outlined
                    : Icons.insights_outlined),
                selectedIcon: Icon(
                    widget.state.isTeacher ? Icons.dashboard : Icons.insights),
                label: widget.state.isTeacher ? 'Desk' : 'Overview'),
            NavigationDestination(
                icon: Badge(
                    isLabelVisible: widget.state.unreadCount > 0,
                    label: Text('${widget.state.unreadCount}'),
                    child: const Icon(Icons.notifications_none_rounded)),
                selectedIcon: const Icon(Icons.notifications_rounded),
                label: 'Alerts'),
          ],
        ),
      );
}

class TeacherHome extends StatelessWidget {
  const TeacherHome({super.key, required this.state});
  final AppState state;

  Future<void> _open(BuildContext context, AttendanceSession session) async {
    await state.openSession(session.id);
    if (!context.mounted) return;
    if (state.error == null) {
      Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => SessionScreen(state: state)));
    }
  }

  Future<void> _start(BuildContext context, Classroom classroom) async {
    final ok = await state.startSession(classroom.id);
    if (!context.mounted) return;
    if (ok) {
      Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => SessionScreen(state: state)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.error ?? 'Could not start session.')));
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: state.retryHome,
        child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              Text(
                  'Good to see you, ${state.user?.name.split(' ').first ?? 'teacher'}.',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text(
                  'Start a session, then review every decision before finalizing.',
                  style: Theme.of(context).textTheme.bodyLarge),
              if (state.liveMessage != null) ...[
                const SizedBox(height: 14),
                _LiveBanner(message: state.liveMessage!)
              ],
              const SizedBox(height: 24),
              Text('Your classes',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              if (state.classes.isEmpty)
                const EmptyState(
                    icon: Icons.school_outlined,
                    title: 'No classes yet',
                    message:
                        'Classes assigned to this teacher will appear here.'),
              ...state.classes.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                        child: Row(children: [
                      Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                              color: AppColors.mint,
                              borderRadius: BorderRadius.circular(14)),
                          child: const Icon(Icons.menu_book_rounded,
                              color: AppColors.teal)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(c.name,
                                style: Theme.of(context).textTheme.titleMedium),
                            if (c.code.isNotEmpty)
                              Text(c.code,
                                  style: Theme.of(context).textTheme.bodyMedium)
                          ])),
                      FilledButton(
                          onPressed:
                              state.busy ? null : () => _start(context, c),
                          child: const Text('Start')),
                    ])),
                  )),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Recent sessions',
                    style: Theme.of(context).textTheme.titleLarge),
                Text('${state.sessions.length}',
                    style: Theme.of(context).textTheme.titleMedium)
              ]),
              const SizedBox(height: 10),
              if (state.sessions.isEmpty)
                const EmptyState(
                    icon: Icons.event_available_outlined,
                    title: 'No sessions yet',
                    message: 'Start your first class session above.'),
              ...state.sessions.take(8).map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () => _open(context, s),
                        child: AppCard(
                            child: Row(children: [
                          const Icon(Icons.event_note_rounded,
                              color: AppColors.teal),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(s.className,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                Text('Session #${s.id}',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium)
                              ])),
                          StatusChip(status: s.status),
                        ]))),
                  )),
            ]),
      );
}

class StudentHome extends StatelessWidget {
  const StudentHome({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final attendance = state.studentAttendance;
    final summary = attendance?.summary;
    return RefreshIndicator(
      onRefresh: state.retryHome,
      child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            Text('Hi, ${state.user?.name.split(' ').first ?? 'student'}.',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text('Here’s your attendance at a glance.',
                style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 24),
            if (summary == null)
              const EmptyState(
                  icon: Icons.insights_outlined,
                  title: 'Attendance is loading',
                  message: 'Pull to refresh when you are back online.')
            else
              AppCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Overall attendance',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 14),
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('${summary.percentage.toStringAsFixed(0)}%',
                          style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w800,
                              color: AppColors.teal)),
                      const SizedBox(width: 12),
                      Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: Text(
                              '${summary.present} of ${summary.total} sessions present',
                              style: Theme.of(context).textTheme.bodyMedium)),
                    ]),
                    const SizedBox(height: 14),
                    ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                            value: summary.percentage / 100,
                            minHeight: 10,
                            backgroundColor: AppColors.mint,
                            color: AppColors.teal)),
                    const SizedBox(height: 16),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _Metric(
                              label: 'Present',
                              value: '${summary.present}',
                              color: AppColors.teal),
                          _Metric(
                              label: 'Absent',
                              value: '${summary.absent}',
                              color: AppColors.coral),
                          _Metric(
                              label: 'Pending',
                              value: '${summary.pending}',
                              color: AppColors.amber),
                        ]),
                  ])),
            const SizedBox(height: 22),
            Text('Recent entries',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            if (attendance?.entries.isEmpty ?? true)
              const EmptyState(
                  icon: Icons.history_rounded,
                  title: 'No attendance entries',
                  message: 'Your sessions will show up here.'),
            ...?attendance?.entries.take(12).map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                      child: Row(children: [
                    const Icon(Icons.calendar_today_outlined,
                        color: AppColors.teal),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(
                              entry.className?.isNotEmpty == true
                                  ? entry.className!
                                  : 'Class session',
                              style: Theme.of(context).textTheme.titleMedium),
                          if (entry.updatedAt != null)
                            Text(
                                DateFormat.yMMMd()
                                    .format(entry.updatedAt!.toLocal()),
                                style: Theme.of(context).textTheme.bodyMedium),
                        ])),
                    StatusChip(status: entry.status),
                  ])),
                )),
          ]),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: Theme.of(context).textTheme.bodyMedium)
      ]);
}

class _LiveBanner extends StatelessWidget {
  const _LiveBanner({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppColors.mint, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        const Icon(Icons.wifi_rounded, color: AppColors.teal),
        const SizedBox(width: 8),
        Expanded(
            child: Text(message,
                style: const TextStyle(
                    color: AppColors.ink, fontWeight: FontWeight.w600)))
      ]));
}
