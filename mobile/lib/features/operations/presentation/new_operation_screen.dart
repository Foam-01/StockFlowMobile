import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors.dart';
import '../../scanner/presentation/barcode_lookup.dart';
import '../domain/draft.dart';
import '../domain/stock_transaction.dart';
import 'operations_controller.dart';
import 'product_picker_sheet.dart';
import 'widgets/tx_widgets.dart';

class NewOperationScreen extends ConsumerStatefulWidget {
  const NewOperationScreen({super.key, required this.initialType});

  final TxType initialType;

  @override
  ConsumerState<NewOperationScreen> createState() => _NewOperationScreenState();
}

class _NewOperationScreenState extends ConsumerState<NewOperationScreen> {
  late TxType _type = widget.initialType;
  final _lines = <DraftLine>[];
  final _reference = TextEditingController();
  final _note = TextEditingController();

  /// Generated once per form so a retried submit never creates a duplicate.
  final _clientUuid = const Uuid().v4();

  bool _submitted = false;
  bool _saving = false;

  @override
  void dispose() {
    _reference.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _addProduct() async {
    final product = await showProductPicker(
      context,
      exclude: _lines.map((l) => l.product.id).toSet(),
    );
    if (product == null) return;
    setState(() => _lines.add(DraftLine(product: product, quantity: 1)));
  }

  /// Scanning an item already on the list adds 1 to it, like a till.
  Future<void> _scanProduct() async {
    final product = await scanProduct(context, ref, title: 'Scan item');
    if (product == null || !mounted) return;
    final i = _lines.indexWhere((l) => l.product.id == product.id);
    setState(() {
      if (i == -1) {
        _lines.add(DraftLine(product: product, quantity: 1));
      } else {
        _lines[i] = _lines[i].withQuantity(_lines[i].quantity + 1);
      }
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text(
            i == -1
                ? 'Added ${product.name}'
                : '${product.name}: ${_lines[i].quantity}',
          ),
        ),
      );
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    final v = validateDraft(_type, _lines);
    if (v.form != null || v.lines.isNotEmpty) return;

    setState(() => _saving = true);
    try {
      final tx = await ref
          .read(txActionsProvider)
          .create(
            clientUuid: _clientUuid,
            type: _type,
            referenceNo: _reference.text.trim(),
            note: _note.text.trim(),
            items: [
              for (final l in _lines)
                (productId: l.product.id, quantity: l.quantity),
            ],
          );
      if (!mounted) return;
      context.pushReplacement('/operations/${tx.id}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(ApiException.from(e).message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = validateDraft(_type, _lines);
    final showErrors = _submitted;

    return Scaffold(
      appBar: AppBar(title: Text('New ${_type.label.toLowerCase()}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          SegmentedButton<TxType>(
            segments: [
              for (final t in TxType.values)
                ButtonSegment(
                  value: t,
                  label: Text(t.label),
                  icon: Icon(t.icon),
                ),
            ],
            selected: {_type},
            onSelectionChanged: _saving
                ? null
                : (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 8),
          Text(
            switch (_type) {
              TxType.receive => 'Quantities are added to stock.',
              TxType.issue => 'Quantities are removed from stock.',
              TxType.adjust =>
                'Enter the difference: positive adds, negative removes.',
            },
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _reference,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Reference no. (optional)',
              hintText: 'e.g. PO-2026-0001',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            enabled: !_saving,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text('Items', style: theme.textTheme.titleMedium),
              const Spacer(),
              TextButton.icon(
                key: const Key('scan_item'),
                onPressed: _saving ? null : _scanProduct,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan'),
              ),
              TextButton.icon(
                key: const Key('add_item'),
                onPressed: _saving ? null : _addProduct,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          if (_lines.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No products added',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: showErrors && v.form != null
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          for (var i = 0; i < _lines.length; i++)
            _LineCard(
              key: ValueKey(_lines[i].product.id),
              type: _type,
              line: _lines[i],
              error: showErrors ? v.lines[_lines[i].product.id] : null,
              enabled: !_saving,
              onChanged: (q) =>
                  setState(() => _lines[i] = _lines[i].withQuantity(q)),
              onRemove: () => setState(() => _lines.removeAt(i)),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            key: const Key('save_draft'),
            onPressed: _saving ? null : _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: _saving
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : const Text('Save as draft'),
          ),
        ),
      ),
    );
  }
}

class _LineCard extends StatefulWidget {
  const _LineCard({
    super.key,
    required this.type,
    required this.line,
    required this.error,
    required this.enabled,
    required this.onChanged,
    required this.onRemove,
  });

  final TxType type;
  final DraftLine line;
  final String? error;
  final bool enabled;
  final ValueChanged<int> onChanged;
  final VoidCallback onRemove;

  @override
  State<_LineCard> createState() => _LineCardState();
}

class _LineCardState extends State<_LineCard> {
  late final _qty = TextEditingController(text: '${widget.line.quantity}');

  /// Keep the field in sync when the quantity changes from outside
  /// (e.g. scanning the same item again).
  @override
  void didUpdateWidget(_LineCard old) {
    super.didUpdateWidget(old);
    if ((int.tryParse(_qty.text) ?? 0) != widget.line.quantity) {
      _qty.text = '${widget.line.quantity}';
    }
  }

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  void _step(int by) {
    final next = widget.line.quantity + by;
    if (widget.type != TxType.adjust && next < 1) return;
    _qty.text = '$next';
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = widget.line.product;
    final projected = projectedOnHand(widget.type, widget.line);
    final allowNegative = widget.type == TxType.adjust;

    return Card.outlined(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: theme.textTheme.titleSmall),
                      Text(
                        '${p.sku} · on hand ${p.onHand} → $projected ${p.unit}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Remove',
                  onPressed: widget.enabled ? widget.onRemove : null,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton.outlined(
                  tooltip: 'Decrease',
                  onPressed: widget.enabled ? () => _step(-1) : null,
                  icon: const Icon(Icons.remove),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 96,
                  child: TextField(
                    key: Key('qty_${p.id}'),
                    controller: _qty,
                    enabled: widget.enabled,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.numberWithOptions(
                      signed: allowNegative,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(allowNegative ? r'^-?\d*' : r'^\d*'),
                      ),
                    ],
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => widget.onChanged(int.tryParse(v) ?? 0),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Increase',
                  onPressed: widget.enabled ? () => _step(1) : null,
                  icon: const Icon(Icons.add),
                ),
                const SizedBox(width: 12),
                Text(p.unit),
                const Spacer(),
                if (widget.line.quantity != 0)
                  SignedQty(
                    value: widget.type == TxType.issue
                        ? -widget.line.quantity
                        : widget.line.quantity,
                  ),
              ],
            ),
            if (widget.error != null) ...[
              const SizedBox(height: 6),
              Text(
                widget.error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
