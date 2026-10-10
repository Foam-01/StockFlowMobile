import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors.dart';
import '../../../core/l10n.dart';
import '../../../core/widgets/state_views.dart';
import '../../operations/presentation/widgets/tx_widgets.dart';
import '../domain/app_notification.dart';
import 'notifications_controller.dart';

/// Bell with an unread badge; opens the inbox.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider).value ?? 0;
    return IconButton(
      key: const Key('notifications_bell'),
      tooltip: unread > 0
          ? context.l10n.notificationsUnread(unread)
          : context.l10n.notifications,
      onPressed: () => context.push('/work-orders/notifications'),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 99 ? '99+' : '$unread'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}

String notificationText(BuildContext context, AppNotification n) {
  final t = context.l10n;
  final actor = n.actorName ?? t.system;
  final code = n.workOrderCode;
  return switch (n.type) {
    'ASSIGNED' => t.ntfAssigned(actor, code),
    'SUBMITTED' => t.ntfSubmitted(actor, code),
    'CHANGES_REQUESTED' => t.ntfChangesRequested(actor, code),
    'APPROVED' => t.ntfApproved(actor, code),
    'CANCELLED' => t.ntfCancelled(actor, code),
    _ => code,
  };
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    AppNotification n,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    if (!n.read) {
      try {
        await ref.read(inboxProvider.notifier).markRead(n.id);
      } catch (e) {
        // Still open the job; just say the read mark didn't stick.
        messenger.showSnackBar(
          SnackBar(content: Text(ApiException.from(e).message)),
        );
      }
    }
    router.push('/work-orders/${n.workOrderId}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(inboxProvider);
    final notifier = ref.read(inboxProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.notifications),
        actions: [
          if (inbox.value?.hasUnread ?? false)
            TextButton(
              key: const Key('mark_all_read'),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await notifier.markAllRead();
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(ApiException.from(e).message)),
                  );
                }
              },
              child: Text(context.l10n.markAllRead),
            ),
        ],
      ),
      body: switch (inbox) {
        AsyncError(:final error) when inbox.value == null => ErrorView(
          error: error,
          onRetry: notifier.refresh,
        ),
        AsyncValue(:final value?) => RefreshIndicator(
          onRefresh: notifier.refresh,
          child: value.items.isEmpty
              ? ListView(
                  children: [
                    const SizedBox(height: 80),
                    MessageView(
                      icon: Icons.notifications_none,
                      title: context.l10n.noNotifications,
                      message: context.l10n.noNotificationsHint,
                    ),
                  ],
                )
              : NotificationListener<ScrollNotification>(
                  onNotification: (s) {
                    if (s.metrics.extentAfter < 300) {
                      notifier.loadMore().ignore();
                    }
                    return false;
                  },
                  child: ListView.separated(
                    itemCount: value.items.length + (value.loadingMore ? 1 : 0),
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      if (i == value.items.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final n = value.items[i];
                      return ListTile(
                        key: Key('notification_${n.id}'),
                        leading: Icon(
                          _icon(n.type),
                          color: n.read
                              ? scheme.onSurfaceVariant
                              : scheme.primary,
                        ),
                        title: Text(
                          notificationText(context, n),
                          style: TextStyle(
                            fontWeight: n.read
                                ? FontWeight.normal
                                : FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          [
                            n.workOrderTitle,
                            if (n.note != null && n.note!.isNotEmpty) n.note!,
                            formatDateTime(n.createdAt),
                          ].join('\n'),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: n.read
                            ? null
                            : Icon(
                                Icons.circle,
                                size: 10,
                                color: scheme.primary,
                              ),
                        onTap: () => _open(context, ref, n),
                      );
                    },
                  ),
                ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  static IconData _icon(String type) => switch (type) {
    'ASSIGNED' => Icons.assignment_ind_outlined,
    'SUBMITTED' => Icons.rate_review_outlined,
    'CHANGES_REQUESTED' => Icons.feedback_outlined,
    'APPROVED' => Icons.verified_outlined,
    'CANCELLED' => Icons.block,
    _ => Icons.notifications_outlined,
  };
}
