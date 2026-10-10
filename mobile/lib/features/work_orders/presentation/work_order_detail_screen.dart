import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errors.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../operations/presentation/evidence_photos.dart'
    show imagePickerProvider;
import '../../operations/presentation/widgets/tx_widgets.dart';
import '../domain/work_order.dart';
import 'issue_materials.dart';
import 'widgets/wo_badges.dart';
import 'work_orders_controller.dart';

class WorkOrderDetailScreen extends ConsumerStatefulWidget {
  const WorkOrderDetailScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<WorkOrderDetailScreen> createState() =>
      _WorkOrderDetailScreenState();
}

class _WorkOrderDetailScreenState extends ConsumerState<WorkOrderDetailScreen> {
  /// What is in flight, so buttons can show progress and not double-submit.
  String? _busy;
  double? _uploadProgress;

  WoDetailController get _ctl => ref.read(woDetailProvider(widget.id).notifier);

  Future<void> _run(
    String key,
    Future<void> Function() op, {
    String? success,
  }) async {
    if (_busy != null) return;
    setState(() => _busy = key);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await op();
      if (success != null) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(ApiException.from(e).message),
            duration: const Duration(seconds: 6),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<bool> _confirm(String title, String message, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Back'),
            ),
            FilledButton(
              key: const Key('confirm_action'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<String?> _askText({
    required String title,
    required String label,
    required String action,
    bool required = true,
    String? initial,
  }) => showDialog<String>(
    context: context,
    builder: (_) => _TextDialog(
      title: title,
      label: label,
      action: action,
      required: required,
      initial: initial,
    ),
  );

  Future<void> _submit(WorkOrder wo) async {
    final ok = await _confirm(
      'Submit for review?',
      'A supervisor will check the checklist and photos. You can’t change '
          'them after submitting unless changes are requested.',
      'Submit',
    );
    if (ok) await _run('submit', _ctl.submit, success: 'Submitted for review');
  }

  Future<void> _approve() async {
    final note = await _askText(
      title: 'Approve work',
      label: 'Comment (optional)',
      action: 'Approve',
      required: false,
    );
    if (note == null) return;
    await _run('approve', () => _ctl.approve(note: note), success: 'Approved');
  }

  Future<void> _requestChanges() async {
    final reason = await _askText(
      title: 'Request changes',
      label: 'What needs to change?',
      action: 'Send back',
    );
    if (reason == null) return;
    await _run(
      'requestChanges',
      () => _ctl.requestChanges(reason),
      success: 'Sent back to the technician',
    );
  }

  Future<void> _cancel() async {
    final reason = await _askText(
      title: 'Cancel work order',
      label: 'Reason',
      action: 'Cancel work order',
    );
    if (reason == null) return;
    await _run('cancel', () => _ctl.cancel(reason), success: 'Cancelled');
  }

  Future<void> _assign(WorkOrder wo) async {
    final result = await showDialog<({String? assigneeId, String? reviewerId})>(
      context: context,
      builder: (_) => _AssignDialog(wo: wo),
    );
    if (result == null) return;
    await _run(
      'assign',
      () => _ctl.assign(
        assigneeId: result.assigneeId,
        reviewerId: result.reviewerId,
      ),
      success: 'Assignment updated',
    );
  }

  Future<void> _editNote(ChecklistItem item) async {
    final note = await _askText(
      title: item.title,
      label: 'Note',
      action: 'Save',
      required: false,
      initial: item.note,
    );
    if (note == null) return;
    await _run(
      'item_${item.id}',
      () => _ctl.setChecklistItem(item.id, item.done, note: note),
    );
  }

  Future<void> _addPhoto() async {
    final category = await showModalBottomSheet<EvidenceCategory>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final c in EvidenceCategory.values)
              ListTile(
                key: Key('photo_category_${c.name}'),
                leading: const Icon(Icons.label_outline),
                title: Text('${c.label} work'),
                onTap: () => Navigator.pop(context, c),
              ),
          ],
        ),
      ),
    );
    if (category == null || !mounted) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    final image = await ref.read(imagePickerProvider)(source);
    if (image == null || !mounted) return;
    setState(() => _uploadProgress = 0);
    await _run(
      'upload',
      () => _ctl.uploadEvidence(
        category,
        image.bytes,
        image.name,
        onProgress: (p) {
          if (mounted) setState(() => _uploadProgress = p);
        },
      ),
      success: 'Photo added',
    );
    if (mounted) setState(() => _uploadProgress = null);
  }

  void _viewPhoto(WorkOrder wo, WoEvidence photo) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _PhotoView(
          photo: photo,
          canDelete: wo.can(WoAction.manageEvidence),
          onDelete: () async {
            final ok = await _confirm(
              'Delete photo?',
              'It will be removed from the work order.',
              'Delete',
            );
            if (!ok) return false;
            await _run(
              'delete_${photo.id}',
              () => _ctl.removeEvidence(photo.id),
              success: 'Photo deleted',
            );
            return true;
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(woDetailProvider(widget.id));
    final user = ref.watch(authControllerProvider).value;
    final wo = async.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(wo?.code ?? 'Work order'),
        actions: [
          if (wo != null)
            IconButton(
              key: const Key('wo_activity'),
              tooltip: 'Activity',
              icon: const Icon(Icons.history),
              onPressed: () => context.push(
                '/work-orders/${wo.id}/activity',
                extra: wo.code,
              ),
            ),
          if (wo != null &&
              (wo.can(WoAction.assign) || wo.can(WoAction.cancel)))
            PopupMenuButton<String>(
              key: const Key('wo_menu'),
              onSelected: (v) => v == 'assign' ? _assign(wo) : _cancel(),
              itemBuilder: (_) => [
                if (wo.can(WoAction.assign))
                  const PopupMenuItem(value: 'assign', child: Text('Assign…')),
                if (wo.can(WoAction.cancel))
                  const PopupMenuItem(
                    value: 'cancel',
                    child: Text('Cancel work order…'),
                  ),
              ],
            ),
        ],
      ),
      body: switch (async) {
        AsyncValue(:final value?) => RefreshIndicator(
          onRefresh: _ctl.refresh,
          child: _body(
            value,
            user?.canWriteInventory ?? false,
            user?.canSeeInventory ?? false,
          ),
        ),
        AsyncValue(:final error?) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(woDetailProvider(widget.id)),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
      bottomNavigationBar: wo == null ? null : _actionBar(wo),
    );
  }

  Widget? _actionBar(WorkOrder wo) {
    final buttons = <Widget>[];
    Widget busyLabel(String key, String label) => _busy == key
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          )
        : Text(label);

    if (wo.can(WoAction.start)) {
      final resume = wo.status == WoStatus.needsRevision;
      buttons.add(
        FilledButton.icon(
          key: const Key('wo_start'),
          onPressed: _busy != null
              ? null
              : () => _run(
                  'start',
                  _ctl.start,
                  success: resume ? 'Back in progress' : 'Work started',
                ),
          icon: const Icon(Icons.play_arrow_rounded),
          label: busyLabel('start', resume ? 'Resume work' : 'Start work'),
        ),
      );
    }
    if (wo.can(WoAction.submit)) {
      buttons.add(
        FilledButton.icon(
          key: const Key('wo_submit'),
          onPressed: _busy != null ? null : () => _submit(wo),
          icon: const Icon(Icons.send_rounded),
          label: busyLabel('submit', 'Submit for review'),
        ),
      );
    }
    if (wo.can(WoAction.requestChanges)) {
      buttons.add(
        OutlinedButton(
          key: const Key('wo_request_changes'),
          onPressed: _busy != null ? null : _requestChanges,
          child: busyLabel('requestChanges', 'Request changes'),
        ),
      );
    }
    if (wo.can(WoAction.approve)) {
      buttons.add(
        FilledButton.icon(
          key: const Key('wo_approve'),
          onPressed: _busy != null ? null : _approve,
          icon: const Icon(Icons.check_rounded),
          label: busyLabel('approve', 'Approve'),
        ),
      );
    }
    if (buttons.isEmpty) return null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            for (var i = 0; i < buttons.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: SizedBox(height: 52, child: buttons[i])),
            ],
          ],
        ),
      ),
    );
  }

  Widget _body(WorkOrder wo, bool canIssue, bool canSeeDocs) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // Wraps on narrow phones instead of overflowing.
        Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            WoStatusChip(status: wo.status),
            WoPriorityBadge(priority: wo.priority),
            WoDue(dueAt: wo.dueAt, overdue: wo.isOverdue),
          ],
        ),
        const SizedBox(height: 12),
        Text(wo.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 6),
        _IconLine(icon: Icons.place_outlined, text: wo.siteName),
        if (wo.siteAddress != null)
          _IconLine(icon: Icons.map_outlined, text: wo.siteAddress!),
        _IconLine(
          icon: Icons.engineering_outlined,
          text: 'Technician: ${wo.assignee?.name ?? 'unassigned'}',
        ),
        _IconLine(
          icon: Icons.verified_user_outlined,
          text: 'Reviewer: ${wo.reviewer?.name ?? 'any supervisor'}',
        ),
        if (wo.description != null) ...[
          const SizedBox(height: 12),
          Text(wo.description!, style: muted),
        ],
        ..._banners(wo),
        _Section(
          title: 'Checklist',
          trailing: wo.checklist.isEmpty
              ? null
              : '${wo.checklistDone}/${wo.checklist.length} done',
          child: wo.checklist.isEmpty
              ? const _Empty('No checklist for this job')
              : Column(
                  children: [
                    for (final item in wo.checklist)
                      _ChecklistTile(
                        item: item,
                        enabled:
                            wo.can(WoAction.updateChecklist) && _busy == null,
                        busy: _busy == 'item_${item.id}',
                        onToggle: (done) => _run(
                          'item_${item.id}',
                          () => _ctl.setChecklistItem(item.id, done),
                        ),
                        onNote: wo.can(WoAction.updateChecklist)
                            ? () => _editNote(item)
                            : null,
                      ),
                  ],
                ),
        ),
        _Section(
          title: 'Photos',
          trailing: wo.requiredEvidence.isEmpty
              ? null
              : 'Required: ${wo.requiredEvidence.map((c) => c.label.toLowerCase()).join(', ')}',
          child: _EvidenceGrid(
            wo: wo,
            uploading: _uploadProgress,
            onAdd: wo.can(WoAction.manageEvidence) && _busy == null
                ? _addPhoto
                : null,
            onOpen: (p) => _viewPhoto(wo, p),
          ),
        ),
        _Section(
          title: 'Materials',
          action:
              canIssue &&
                  !wo.status.isClosed &&
                  wo.materials.any((m) => m.remainingQty > 0)
              ? TextButton.icon(
                  key: const Key('issue_materials'),
                  onPressed: () => context.push(
                    '/operations/new?type=ISSUE',
                    extra: IssueForWorkOrder.fromWorkOrder(wo),
                  ),
                  icon: const Icon(Icons.outbox_outlined, size: 18),
                  label: const Text('Issue'),
                )
              : null,
          child: wo.materials.isEmpty
              ? const _Empty('No materials planned')
              : Column(
                  children: [for (final m in wo.materials) _MaterialTile(m: m)],
                ),
        ),
        if (wo.documents.isNotEmpty)
          _Section(
            title: 'Stock documents',
            child: Column(
              children: [
                for (final d in wo.documents)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: TxTypeIcon(type: d.type),
                    title: Text(d.referenceNo ?? d.type.label),
                    subtitle: Text(
                      '${d.itemCount} item${d.itemCount == 1 ? '' : 's'} · '
                      '${formatDateTime(d.createdAt)}',
                    ),
                    trailing: TxStatusChip(status: d.status),
                    onTap: canSeeDocs
                        ? () => context.push('/operations/${d.id}')
                        : null,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  List<Widget> _banners(WorkOrder wo) {
    final scheme = Theme.of(context).colorScheme;
    Widget banner(IconData icon, String text, Color bg, Color fg, {Key? key}) =>
        Container(
          key: key,
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: fg, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(text, style: TextStyle(color: fg)),
              ),
            ],
          ),
        );

    return [
      if (wo.status == WoStatus.needsRevision && wo.reviewNote != null)
        banner(
          Icons.feedback_outlined,
          'Changes requested${wo.reviewedBy == null ? '' : ' by ${wo.reviewedBy!.name}'}: ${wo.reviewNote}',
          scheme.errorContainer,
          scheme.onErrorContainer,
          key: const Key('review_note'),
        ),
      if (wo.status == WoStatus.approved)
        banner(
          Icons.verified_outlined,
          'Approved${wo.reviewedBy == null ? '' : ' by ${wo.reviewedBy!.name}'}'
          '${wo.reviewedAt == null ? '' : ' · ${formatDateTime(wo.reviewedAt!)}'}',
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
        ),
      if (wo.status == WoStatus.cancelled)
        banner(
          Icons.block,
          'Cancelled: ${wo.cancelReason ?? ''}',
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
        ),
      if (wo.status == WoStatus.submitted)
        banner(
          Icons.hourglass_top_rounded,
          'Waiting for review'
          '${wo.submittedAt == null ? '' : ' · submitted ${formatDateTime(wo.submittedAt!)}'}',
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
        ),
      if (wo.submissionProblems.isNotEmpty)
        banner(
          Icons.checklist_rounded,
          'Before you can submit:\n${wo.submissionProblems.map((p) => '• $p').join('\n')}',
          scheme.surfaceContainerHigh,
          scheme.onSurface,
          key: const Key('submission_problems'),
        ),
    ];
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 17, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.trailing,
    this.action,
  });

  final String title;
  final String? trailing;
  final Widget? action;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(width: 8),
              if (trailing != null)
                Expanded(
                  child: Text(
                    trailing!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                const Spacer(),
              ?action,
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
  );
}

class _ChecklistTile extends StatelessWidget {
  const _ChecklistTile({
    required this.item,
    required this.enabled,
    required this.busy,
    required this.onToggle,
    this.onNote,
  });

  final ChecklistItem item;
  final bool enabled;
  final bool busy;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onNote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = [
      if (!item.required) 'Optional',
      if (item.note != null) 'Note: ${item.note}',
    ].join(' · ');
    return ListTile(
      key: Key('check_${item.id}'),
      contentPadding: EdgeInsets.zero,
      leading: busy
          ? const SizedBox.square(
              dimension: 40,
              child: Padding(
                padding: EdgeInsets.all(10),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : Checkbox(
              value: item.done,
              onChanged: enabled ? (v) => onToggle(v ?? false) : null,
            ),
      title: Text(
        item.title,
        style: item.done
            ? theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )
            : null,
      ),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: onNote == null
          ? null
          : IconButton(
              tooltip: 'Add note',
              icon: const Icon(Icons.edit_note_rounded),
              onPressed: enabled ? onNote : null,
            ),
      onTap: enabled ? () => onToggle(!item.done) : null,
    );
  }
}

class _MaterialTile extends StatelessWidget {
  const _MaterialTile({required this.m});

  final WoMaterial m;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.name, style: theme.textTheme.bodyLarge),
                Text(
                  '${m.sku} · planned ${m.plannedQty} · issued ${m.issuedQty} ${m.unit}',
                  style: muted,
                ),
                if (m.shortage > 0)
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 15,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Short by ${m.shortage} (on hand ${m.onHand})',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Text(
            m.remainingQty == 0 ? 'Issued' : '${m.remainingQty} to issue',
            style: theme.textTheme.labelLarge?.copyWith(
              color: m.remainingQty == 0
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _EvidenceGrid extends StatelessWidget {
  const _EvidenceGrid({
    required this.wo,
    required this.onOpen,
    this.onAdd,
    this.uploading,
  });

  final WorkOrder wo;
  final ValueChanged<WoEvidence> onOpen;
  final VoidCallback? onAdd;
  final double? uploading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (wo.evidence.isEmpty && onAdd == null && uploading == null) {
      return const _Empty('No photos yet');
    }
    const size = 96.0;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final p in wo.evidence)
          GestureDetector(
            key: Key('evidence_${p.id}'),
            onTap: () => onOpen(p),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    p.thumbnailUrl(),
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: size,
                      height: size,
                      color: scheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: scheme.outline,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      p.category.label,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (uploading != null)
          SizedBox.square(
            dimension: size,
            child: Center(
              child: CircularProgressIndicator(
                value: uploading! > 0 && uploading! < 1 ? uploading : null,
              ),
            ),
          ),
        if (onAdd != null && uploading == null)
          SizedBox.square(
            dimension: size,
            child: OutlinedButton(
              key: const Key('wo_add_photo'),
              onPressed: onAdd,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_a_photo_outlined, color: scheme.primary),
                  const SizedBox(height: 4),
                  const Text('Add photo'),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _PhotoView extends StatelessWidget {
  const _PhotoView({
    required this.photo,
    required this.canDelete,
    required this.onDelete,
  });

  final WoEvidence photo;
  final bool canDelete;
  final Future<bool> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${photo.category.label} work'),
        actions: [
          if (canDelete)
            IconButton(
              key: const Key('wo_delete_photo'),
              tooltip: 'Delete photo',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final navigator = Navigator.of(context);
                if (await onDelete()) navigator.pop();
              },
            ),
        ],
      ),
      body: InteractiveViewer(
        maxScale: 4,
        child: Center(
          child: Image.network(
            photo.url,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 56,
            ),
          ),
        ),
      ),
    );
  }
}

class _TextDialog extends StatefulWidget {
  const _TextDialog({
    required this.title,
    required this.label,
    required this.action,
    required this.required,
    this.initial,
  });

  final String title;
  final String label;
  final String action;
  final bool required;
  final String? initial;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final _text = TextEditingController(text: widget.initial);
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          key: const Key('dialog_text'),
          controller: _text,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: widget.label,
            border: const OutlineInputBorder(),
          ),
          validator: (v) {
            if (!widget.required) return null;
            final t = v?.trim() ?? '';
            if (t.isEmpty) return 'Please add a reason';
            if (t.length < 5) return 'A few more words, please';
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Back'),
        ),
        FilledButton(
          key: const Key('dialog_submit'),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _text.text.trim());
            }
          },
          child: Text(widget.action),
        ),
      ],
    );
  }
}

class _AssignDialog extends ConsumerStatefulWidget {
  const _AssignDialog({required this.wo});

  final WorkOrder wo;

  @override
  ConsumerState<_AssignDialog> createState() => _AssignDialogState();
}

class _AssignDialogState extends ConsumerState<_AssignDialog> {
  late String? _tech = widget.wo.assignee?.id;
  late String? _reviewer = widget.wo.reviewer?.id;

  @override
  Widget build(BuildContext context) {
    final techs = ref.watch(peopleProvider('TECHNICIAN')).value ?? const [];
    final sups = ref.watch(peopleProvider('SUPERVISOR')).value ?? const [];
    return AlertDialog(
      title: const Text('Assign'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String?>(
            key: const Key('assign_tech'),
            initialValue: _tech,
            decoration: const InputDecoration(labelText: 'Technician'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Unassigned')),
              for (final p in techs)
                DropdownMenuItem(value: p.id, child: Text(p.name)),
            ],
            onChanged: (v) => setState(() => _tech = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _reviewer,
            decoration: const InputDecoration(labelText: 'Reviewer'),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Any supervisor'),
              ),
              for (final p in sups)
                DropdownMenuItem(value: p.id, child: Text(p.name)),
            ],
            onChanged: (v) => setState(() => _reviewer = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Back'),
        ),
        FilledButton(
          key: const Key('assign_save'),
          onPressed: () => Navigator.pop(context, (
            assigneeId: _tech,
            reviewerId: _reviewer,
          )),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
