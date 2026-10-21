import 'package:flutter/material.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../widgets/app_widgets.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: state.retryHome,
        child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              AppCard(
                  child: Row(children: [
                const Icon(Icons.notifications_active_outlined,
                    color: AppColors.teal, size: 28),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(
                        'Private in-app updates only. No email or SMS is sent.',
                        style: Theme.of(context).textTheme.bodyLarge)),
              ])),
              const SizedBox(height: 18),
              if (state.notifications.isEmpty)
                const EmptyState(
                    icon: Icons.mark_email_read_outlined,
                    title: 'You’re all caught up',
                    message:
                        'Attendance updates will appear here after a session is finalized.'),
              ...state.notifications.map((item) => _NotificationCard(
                  item: item, onRead: () => state.markNotificationRead(item))),
            ]),
      );
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, required this.onRead});
  final AppNotification item;
  final VoidCallback onRead;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          onTap: item.read ? null : onRead,
          borderRadius: BorderRadius.circular(22),
          child: AppCard(
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(
                item.read
                    ? Icons.notifications_none
                    : Icons.notifications_active,
                color: item.read ? AppColors.slate : AppColors.teal),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Expanded(
                        child: Text(item.title,
                            style: Theme.of(context).textTheme.titleMedium)),
                    if (!item.read)
                      Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: AppColors.coral, shape: BoxShape.circle))
                  ]),
                  const SizedBox(height: 4),
                  Text(item.message,
                      style: Theme.of(context).textTheme.bodyMedium),
                  if (!item.read) ...[
                    const SizedBox(height: 8),
                    const Text('Tap to mark as read',
                        style: TextStyle(
                            color: AppColors.teal,
                            fontWeight: FontWeight.w700,
                            fontSize: 12))
                  ],
                ])),
          ])),
        ),
      );
}
