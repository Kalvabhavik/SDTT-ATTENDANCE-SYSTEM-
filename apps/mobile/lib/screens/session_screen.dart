import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../state/app_state.dart';
import '../widgets/app_widgets.dart';

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key, required this.state});
  final AppState state;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  final ImagePicker picker = ImagePicker();
  String searchQuery = '';
  final searchController = TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.state.activeSession;
    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Session Details')),
        body: const Center(
          child: EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Session Unavailable',
            message: 'Return to dashboard and try reopening this session.',
          ),
        ),
      );
    }

    final total = session.records.length;
    final presentCount = session.records.where((r) => r.isPresent).length;
    final absentCount = session.records.where((r) => r.isAbsent).length;
    final pendingCount = session.records.where((r) => r.isPending).length;

    final filteredRecords = session.records.where((r) {
      if (searchQuery.trim().isEmpty) return true;
      return r.studentName.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              session.className,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            Text(
              'Session #${session.id} • ${session.status.toUpperCase()}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.slate,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh roster',
            onPressed: () async {
              await widget.state.openSession(session.id);
              if (mounted) setState(() {});
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await widget.state.openSession(session.id);
        },
        color: AppColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          children: [
            // Session Overview Card
            FadeSlideIn(
              offsetY: 16,
              child: AppCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.fact_check_rounded,
                                color: AppColors.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Live Roll Call',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                                Text(
                                  '$total Enrolled Students',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.muted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        StatusChip(status: session.status),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Multi-color breakdown bar
                    AttendanceBreakdownBar(
                      present: presentCount,
                      absent: absentCount,
                      pending: pendingCount,
                      height: 10,
                    ),

                    const SizedBox(height: 14),

                    // Metric pills row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _StatusCounter(
                          label: 'Present',
                          count: presentCount,
                          color: AppColors.emerald,
                        ),
                        _StatusCounter(
                          label: 'Absent',
                          count: absentCount,
                          color: AppColors.rose,
                        ),
                        _StatusCounter(
                          label: 'Pending',
                          count: pendingCount,
                          color: AppColors.amber,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Camera Capture Card (only when open)
            if (session.isOpen)
              FadeSlideIn(
                delay: const Duration(milliseconds: 60),
                child: AppCard(
                  padding: const EdgeInsets.all(20),
                  borderColor: AppColors.secondary.withValues(alpha: 0.3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: AppColors.accentGradient,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Camera Roll Call Assist',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const Text(
                                  'Instant simulated suggestions for review',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.slate,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Take one classroom photo. Suggestions are synthetic and must be confirmed by the teacher. No photos are retained.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.slate,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      AnimatedPressable(
                        onTap: widget.state.busy ? null : _capture,
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.secondary,
                                AppColors.primary,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.secondary.withValues(alpha: 0.3),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: widget.state.busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.camera_enhance_rounded,
                                          color: Colors.white, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Open Camera Capture',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14.5,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Suggestions List Card
            if (widget.state.suggestions.isNotEmpty) ...[
              const SizedBox(height: 16),
              FadeSlideIn(
                delay: const Duration(milliseconds: 100),
                child: AppCard(
                  padding: const EdgeInsets.all(18),
                  borderColor: AppColors.emeraldBorder,
                  backgroundColor: AppColors.emeraldBg.withValues(alpha: 0.5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome_rounded,
                              color: AppColors.emerald, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${widget.state.suggestions.length} Review Suggestions',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...widget.state.suggestions.map((sug) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.emeraldBorder),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          sug.studentName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          '${(sug.confidence * 100).toStringAsFixed(0)}% simulated confidence',
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            color: AppColors.slate,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  FilledButton.icon(
                                    onPressed: () async {
                                      await widget.state.setAttendance(
                                          sug.studentId, 'present');
                                      if (mounted) setState(() {});
                                    },
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.emerald,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      minimumSize: Size.zero,
                                    ),
                                    icon: const Icon(Icons.check_rounded, size: 16),
                                    label: const Text('Mark Present',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                            ),
                          )),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Roster Header & Search
            FadeSlideIn(
              delay: const Duration(milliseconds: 120),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Class Roster', style: Theme.of(context).textTheme.titleLarge),
                  Text(
                    '$pendingCount pending',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: pendingCount > 0 ? AppColors.amber : AppColors.emerald,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Search Bar
            FadeSlideIn(
              delay: const Duration(milliseconds: 140),
              child: TextField(
                controller: searchController,
                onChanged: (val) => setState(() => searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search student name...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            searchController.clear();
                            setState(() => searchQuery = '');
                          },
                        )
                      : null,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),

            const SizedBox(height: 12),

            if (filteredRecords.isEmpty)
              const FadeSlideIn(
                delay: Duration(milliseconds: 160),
                child: EmptyState(
                  icon: Icons.person_search_rounded,
                  title: 'No matching students',
                  message: 'Try checking your search query spelling.',
                ),
              ),

            // Student Roster List with Instant Tap Buttons
            ...filteredRecords.asMap().entries.map((entry) {
              final index = entry.key;
              final record = entry.value;

              return FadeSlideIn(
                delay: Duration(milliseconds: 160 + index * 30),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: record.isPresent
                                  ? AppColors.emeraldBg
                                  : record.isAbsent
                                      ? AppColors.roseBg
                                      : AppColors.cardSubtle,
                              child: Text(
                                record.studentName.isNotEmpty
                                    ? record.studentName.substring(0, 1).toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: record.isPresent
                                      ? AppColors.emerald
                                      : record.isAbsent
                                          ? AppColors.rose
                                          : AppColors.slate,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                record.studentName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: AppColors.ink,
                                ),
                              ),
                            ),
                            StatusChip(status: record.status, compact: true),
                          ],
                        ),
                        if (session.isOpen) ...[
                          const SizedBox(height: 10),
                          const Divider(height: 1, color: AppColors.border),
                          const SizedBox(height: 8),
                          // Instant Action Segmented Row
                          Row(
                            children: [
                              Expanded(
                                child: _RosterActionButton(
                                  label: 'Present',
                                  icon: Icons.check_rounded,
                                  isActive: record.isPresent,
                                  activeColor: AppColors.emerald,
                                  onTap: () async {
                                    await widget.state.setAttendance(
                                        record.studentId, 'present');
                                    if (mounted) setState(() {});
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _RosterActionButton(
                                  label: 'Absent',
                                  icon: Icons.close_rounded,
                                  isActive: record.isAbsent,
                                  activeColor: AppColors.rose,
                                  onTap: () async {
                                    await widget.state.setAttendance(
                                        record.studentId, 'absent');
                                    if (mounted) setState(() {});
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _RosterActionButton(
                                  label: 'Pending',
                                  icon: Icons.schedule_rounded,
                                  isActive: record.isPending,
                                  activeColor: AppColors.amber,
                                  onTap: () async {
                                    await widget.state.setAttendance(
                                        record.studentId, 'pending');
                                    if (mounted) setState(() {});
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
      bottomSheet: session.isOpen
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: const Border(top: BorderSide(color: AppColors.border)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: AnimatedPressable(
                  onTap: widget.state.busy ? null : _finalize,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: pendingCount == 0
                          ? AppColors.primaryGradient
                          : const LinearGradient(
                              colors: [Color(0xFFEA580C), Color(0xFFC2410C)],
                            ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: (pendingCount == 0
                                  ? AppColors.primary
                                  : const Color(0xFFEA580C))
                              .withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: widget.state.busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.lock_outline_rounded,
                                    color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  pendingCount == 0
                                      ? 'Finalize Attendance Session'
                                      : 'Finalize & Mark $pendingCount Absent',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Future<void> _capture() async {
    XFile? picked;
    try {
      picked = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (picked == null) return;
      await widget.state.uploadCapture(File(picked.path));
      if (mounted && widget.state.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.state.error!),
            backgroundColor: AppColors.rose,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Camera capture was cancelled or unavailable. Manual roll call remains ready.'),
          ),
        );
      }
    } finally {
      if (picked != null) {
        try {
          final file = File(picked.path);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
    }
  }

  Future<void> _finalize() async {
    final session = widget.state.activeSession;
    final pending =
        session?.records.where((r) => r.isPending).length ?? 0;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Finalize Attendance Session?'),
        content: Text(
          pending > 0
              ? 'This will close the session and permanently mark $pending pending student(s) as absent. Students will receive private in-app notifications.'
              : 'All students are accounted for. This will close the session and notify students.',
          style: const TextStyle(fontSize: 14, color: AppColors.slate, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Reviewing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor:
                  pending > 0 ? const Color(0xFFEA580C) : AppColors.primary,
            ),
            child: const Text('Confirm Finalize'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    final ok = await widget.state.finalizeActive();
    if (mounted && ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.emerald,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Attendance session finalized successfully.'),
            ],
          ),
        ),
      );
      setState(() {});
    }
  }
}

class _StatusCounter extends StatelessWidget {
  const _StatusCounter({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$count',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 15,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.slate,
          ),
        ),
      ],
    );
  }
}

class _RosterActionButton extends StatelessWidget {
  const _RosterActionButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedPressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withValues(alpha: 0.12)
              : AppColors.cardSubtle,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? activeColor : AppColors.border,
            width: isActive ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? activeColor : AppColors.slate,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
                color: isActive ? activeColor : AppColors.slate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
