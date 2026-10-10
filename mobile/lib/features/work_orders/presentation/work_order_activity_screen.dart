import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/state_views.dart';
import '../../operations/presentation/widgets/tx_widgets.dart';
import 'work_orders_controller.dart';
import '../../../core/l10n.dart';

/// Server-side audit trail of a work order, oldest first.
class WorkOrderActivityScreen extends ConsumerWidget {
  const WorkOrderActivityScreen({super.key, required this.id, this.code});

  final String id;
  final String? code;

  IconData _icon(String type) => switch (type) {
    'CREATED' => Icons.add_circle_outline,
    'ASSIGNED' => Icons.person_add_alt,
    'STARTED' => Icons.play_circle_outline,
    'CHECKLIST_UPDATED' => Icons.check_box_outlined,
    'EVIDENCE_ADDED' || 'EVIDENCE_REMOVED' => Icons.photo_camera_outlined,
    'SUBMITTED' => Icons.send_outlined,
    'CHANGES_REQUESTED' => Icons.feedback_outlined,
    'APPROVED' => Icons.verified_outlined,
    'CANCELLED' => Icons.block,
    'MATERIAL_ISSUED' => Icons.inventory_2_outlined,
    _ => Icons.circle_outlined,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(woEventsProvider(id));
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          code == null
              ? context.l10n.activity
              : context.l10n.codeActivity(code!),
        ),
      ),
      body: events.when(
        data: (list) => list.isEmpty
            ? MessageView(icon: Icons.history, title: context.l10n.noActivity)
            : RefreshIndicator(
                onRefresh: () => ref.refresh(woEventsProvider(id).future),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final e = list[i];
                    final last = i == list.length - 1;
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Column(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor:
                                    theme.colorScheme.surfaceContainerHighest,
                                child: Icon(
                                  _icon(e.type),
                                  size: 18,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              if (!last)
                                Expanded(
                                  child: VerticalDivider(
                                    width: 2,
                                    color: theme.colorScheme.outlineVariant,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.toStatus == null
                                        ? e.tr(context.l10n)
                                        : '${e.tr(context.l10n)} → ${e.toStatus!.tr(context.l10n)}',
                                    style: theme.textTheme.titleSmall,
                                  ),
                                  if (e.note != null) Text(e.note!),
                                  Text(
                                    '${e.actor?.name ?? context.l10n.system} · ${formatDateTime(e.createdAt)}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(woEventsProvider(id)),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
