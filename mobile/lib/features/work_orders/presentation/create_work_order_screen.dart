import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors.dart';
import '../../operations/presentation/product_picker_sheet.dart';
import '../../products/domain/product.dart';
import '../data/work_orders_repository.dart';
import '../domain/work_order.dart';
import 'widgets/wo_badges.dart';
import 'work_orders_controller.dart';

class CreateWorkOrderScreen extends ConsumerStatefulWidget {
  const CreateWorkOrderScreen({super.key});

  @override
  ConsumerState<CreateWorkOrderScreen> createState() =>
      _CreateWorkOrderScreenState();
}

class _CreateWorkOrderScreenState extends ConsumerState<CreateWorkOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _site = TextEditingController();
  final _address = TextEditingController();
  final _description = TextEditingController();

  /// Once per form: a retried save never creates a second work order.
  final _clientUuid = const Uuid().v4();

  WoPriority _priority = WoPriority.normal;
  DateTime? _dueAt;
  String? _templateId;
  String? _assigneeId;
  String? _reviewerId;
  final Set<EvidenceCategory> _required = {EvidenceCategory.after};
  final List<({Product product, int qty})> _materials = [];
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _site.dispose();
    _address.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      initialDate: _dueAt ?? now.add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueAt ?? DateTime(0, 1, 1, 9)),
    );
    if (time == null) return;
    setState(
      () => _dueAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  Future<void> _addMaterial() async {
    final product = await showProductPicker(
      context,
      exclude: _materials.map((m) => m.product.id).toSet(),
    );
    if (product != null) {
      setState(() => _materials.add((product: product, qty: 1)));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final wo = await ref
          .read(workOrdersRepositoryProvider)
          .create(
            NewWorkOrder(
              clientUuid: _clientUuid,
              title: _title.text.trim(),
              siteName: _site.text.trim(),
              siteAddress: _address.text.trim(),
              description: _description.text.trim(),
              priority: _priority,
              dueAt: _dueAt,
              templateId: _templateId,
              assigneeId: _assigneeId,
              reviewerId: _reviewerId,
              requiredEvidence: _required.toList(),
              materials: [
                for (final m in _materials)
                  (productId: m.product.id, plannedQty: m.qty),
              ],
            ),
          );
      ref.invalidate(woListProvider);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('${wo.code} created')));
      context.pushReplacement('/work-orders/${wo.id}');
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(ApiException.from(e).message)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final templates = ref.watch(checklistTemplatesProvider);
    final techs = ref.watch(peopleProvider('TECHNICIAN'));
    final sups = ref.watch(peopleProvider('SUPERVISOR'));
    String? notEmpty(String? v) =>
        (v?.trim().isEmpty ?? true) ? 'Required' : null;

    return Scaffold(
      appBar: AppBar(title: const Text('New work order')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            TextFormField(
              key: const Key('wo_title'),
              controller: _title,
              enabled: !_saving,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g. Install split AC – meeting room',
              ),
              validator: notEmpty,
            ),
            TextFormField(
              key: const Key('wo_site'),
              controller: _site,
              enabled: !_saving,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Site'),
              validator: notEmpty,
            ),
            TextFormField(
              controller: _address,
              enabled: !_saving,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText: 'Address (optional)',
              ),
            ),
            TextFormField(
              controller: _description,
              enabled: !_saving,
              maxLines: 3,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'Instructions (optional)',
              ),
            ),
            const SizedBox(height: 8),
            Text('Priority', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<WoPriority>(
              segments: [
                for (final p in WoPriority.values)
                  ButtonSegment(value: p, label: Text(p.label)),
              ],
              selected: {_priority},
              onSelectionChanged: _saving
                  ? null
                  : (s) => setState(() => _priority = s.first),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(
                _dueAt == null ? 'No due date' : 'Due ${formatDue(_dueAt!)}',
              ),
              trailing: _dueAt == null
                  ? TextButton(onPressed: _pickDue, child: const Text('Set'))
                  : IconButton(
                      tooltip: 'Clear due date',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _dueAt = null),
                    ),
              onTap: _saving ? null : _pickDue,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              key: const Key('wo_template'),
              initialValue: _templateId,
              decoration: const InputDecoration(labelText: 'Checklist'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('No checklist'),
                ),
                for (final t in templates.value ?? const <ChecklistTemplate>[])
                  DropdownMenuItem(
                    value: t.id,
                    child: Text('${t.name} (${t.itemCount})'),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (v) => setState(() => _templateId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              key: const Key('wo_assignee'),
              initialValue: _assigneeId,
              decoration: const InputDecoration(labelText: 'Technician'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Assign later'),
                ),
                for (final p in techs.value ?? const <Person>[])
                  DropdownMenuItem(value: p.id, child: Text(p.name)),
              ],
              onChanged: _saving
                  ? null
                  : (v) => setState(() => _assigneeId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _reviewerId,
              decoration: const InputDecoration(labelText: 'Reviewer'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Any supervisor'),
                ),
                for (final p in sups.value ?? const <Person>[])
                  DropdownMenuItem(value: p.id, child: Text(p.name)),
              ],
              onChanged: _saving
                  ? null
                  : (v) => setState(() => _reviewerId = v),
            ),
            const SizedBox(height: 20),
            Text('Required photos', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final c in [
                  EvidenceCategory.before,
                  EvidenceCategory.after,
                ])
                  FilterChip(
                    label: Text('${c.label} work'),
                    selected: _required.contains(c),
                    onSelected: _saving
                        ? null
                        : (on) => setState(
                            () => on ? _required.add(c) : _required.remove(c),
                          ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text('Materials', style: theme.textTheme.titleSmall),
                const Spacer(),
                TextButton.icon(
                  key: const Key('wo_add_material'),
                  onPressed: _saving ? null : _addMaterial,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
            if (_materials.isEmpty)
              Text(
                'None: work without parts is fine',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            for (var i = 0; i < _materials.length; i++)
              ListTile(
                key: Key('material_${_materials[i].product.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text(_materials[i].product.name),
                subtitle: Text(
                  '${_materials[i].product.sku} · on hand ${_materials[i].product.onHand} ${_materials[i].product.unit}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 64,
                      child: TextFormField(
                        key: Key('material_qty_${_materials[i].product.id}'),
                        initialValue: '${_materials[i].qty}',
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(isDense: true),
                        validator: (v) =>
                            (int.tryParse(v ?? '') ?? 0) < 1 ? '≥ 1' : null,
                        onChanged: (v) => _materials[i] = (
                          product: _materials[i].product,
                          qty: int.tryParse(v) ?? 0,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => setState(() => _materials.removeAt(i)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            key: const Key('wo_save'),
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: _saving
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : const Text('Create work order'),
          ),
        ),
      ),
    );
  }
}
