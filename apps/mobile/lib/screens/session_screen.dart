import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';
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

  @override
  Widget build(BuildContext context) {
    final session = widget.state.activeSession;
    if (session == null) {
      return const Scaffold(body: Center(child: Text('Session unavailable')));
    }
    final pending = session.records.where((record) => record.isPending).length;
    return Scaffold(
      appBar: AppBar(title: Text(session.className), actions: [
        IconButton(
            tooltip: 'Refresh roster',
            onPressed: () async {
              await widget.state.openSession(session.id);
              if (mounted) setState(() {});
            },
            icon: const Icon(Icons.refresh)),
      ]),
      body: RefreshIndicator(
        onRefresh: () async {
          await widget.state.openSession(session.id);
        },
        child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              _SessionHeader(session: session, pending: pending),
              const SizedBox(height: 14),
              AppCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Camera capture',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 6),
                    const Text(
                        'Take one photo for this session. The API returns simulated suggestions for review; this app does not perform face recognition or retain the photo.'),
                    const SizedBox(height: 14),
                    SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                            onPressed: session.isOpen && !widget.state.busy
                                ? _capture
                                : null,
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: Text(widget.state.busy
                                ? 'Uploading…'
                                : 'Open camera'))),
                    const SizedBox(height: 8),
                    const Text(
                        'If camera capture is unavailable, use the manual roll call below.',
                        style: TextStyle(fontSize: 12, color: AppColors.slate)),
                  ])),
              if (widget.state.suggestions.isNotEmpty) ...[
                const SizedBox(height: 14),
                _SuggestionsCard(state: widget.state)
              ],
              const SizedBox(height: 22),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Manual roll call',
                    style: Theme.of(context).textTheme.titleLarge),
                Text('$pending pending',
                    style: Theme.of(context).textTheme.bodyMedium)
              ]),
              const SizedBox(height: 8),
              const Text(
                  'Every change is audited. Pending is safe until you are ready to finalize.',
                  style: TextStyle(color: AppColors.slate)),
              const SizedBox(height: 10),
              if (session.records.isEmpty)
                const EmptyState(
                    icon: Icons.groups_outlined,
                    title: 'Roster unavailable',
                    message: 'Retry the session to load the class roster.'),
              ...session.records.map((record) => _RosterRow(
                  record: record,
                  onStatus: (status) async {
                    await widget.state.setAttendance(record.studentId, status);
                    if (mounted) setState(() {});
                  })),
              const SizedBox(height: 20),
              if (widget.state.error != null)
                Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(widget.state.error!,
                        style: const TextStyle(
                            color: AppColors.coral,
                            fontWeight: FontWeight.w600))),
              FilledButton.icon(
                  onPressed:
                      session.isOpen && !widget.state.busy ? _finalize : null,
                  icon: const Icon(Icons.lock_outline),
                  label: Text(pending == 0
                      ? 'Finalize attendance'
                      : 'Finalize and mark $pending absent')),
              const SizedBox(height: 8),
              const Text(
                  'Finalization is explicit and cannot be undone from this demo screen.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.slate)),
            ]),
      ),
    );
  }

  Future<void> _capture() async {
    XFile? picked;
    try {
      picked = await picker.pickImage(
          source: ImageSource.camera, imageQuality: 80, maxWidth: 1600);
      if (picked == null) return;
      await widget.state.uploadCapture(File(picked.path));
      if (mounted && widget.state.error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(widget.state.error!)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Camera capture was cancelled or unavailable. Manual roll call remains available.')));
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
    final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Finalize attendance?'),
              content: const Text(
                  'This explicitly closes the session. Any students still pending will be marked absent and students will receive private in-app notifications.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Keep reviewing')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Finalize'))
              ],
            ));
    if (confirm != true) return;
    final ok = await widget.state.finalizeActive();
    if (mounted && ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Attendance finalized.')));
      setState(() {});
    }
  }
}

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({required this.session, required this.pending});
  final AttendanceSession session;
  final int pending;
  @override
  Widget build(BuildContext context) => AppCard(
          child: Row(children: [
        Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: AppColors.mint, borderRadius: BorderRadius.circular(15)),
            child:
                const Icon(Icons.fact_check_outlined, color: AppColors.teal)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Session #${session.id}',
              style: Theme.of(context).textTheme.titleLarge),
          Text('${session.records.length} students • $pending pending',
              style: Theme.of(context).textTheme.bodyMedium)
        ])),
        StatusChip(status: session.status),
      ]));
}

class _SuggestionsCard extends StatelessWidget {
  const _SuggestionsCard({required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => AppCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.auto_awesome_outlined, color: AppColors.teal),
          const SizedBox(width: 8),
          Expanded(
              child: Text('Simulated suggestions — review before applying',
                  style: Theme.of(context).textTheme.titleMedium))
        ]),
        const SizedBox(height: 6),
        const Text(
            'These are synthetic API suggestions, not face recognition. Nothing is applied automatically.'),
        const SizedBox(height: 10),
        ...state.suggestions.map((suggestion) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Expanded(
                  child: Text(suggestion.studentName,
                      style: Theme.of(context).textTheme.titleMedium)),
              Text(
                  '${(suggestion.confidence * 100).toStringAsFixed(0)}% confidence',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(width: 8),
              OutlinedButton(
                  onPressed: () => state.setAttendance(
                      suggestion.studentId, suggestion.status),
                  child: const Text('Apply')),
            ]))),
      ]));
}

class _RosterRow extends StatelessWidget {
  const _RosterRow({required this.record, required this.onStatus});
  final AttendanceRecord record;
  final Future<void> Function(String) onStatus;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(children: [
          CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.mint,
              child: Text(
                  record.studentName.isEmpty
                      ? '?'
                      : record.studentName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                      color: AppColors.teal, fontWeight: FontWeight.w800))),
          const SizedBox(width: 10),
          Expanded(
              child: Text(record.studentName,
                  style: Theme.of(context).textTheme.titleMedium)),
          PopupMenuButton<String>(
              tooltip: 'Set attendance for ${record.studentName}',
              onSelected: onStatus,
              itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: 'present', child: Text('Mark present')),
                    PopupMenuItem(value: 'absent', child: Text('Mark absent')),
                    PopupMenuItem(value: 'pending', child: Text('Keep pending'))
                  ],
              child: StatusChip(status: record.status)),
        ]),
      ));
}
