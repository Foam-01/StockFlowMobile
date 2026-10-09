import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/state_views.dart';
import '../../products/domain/product.dart';
import 'operations_controller.dart';

/// Bottom sheet to search and pick a product. Returns the chosen [Product].
Future<Product?> showProductPicker(
  BuildContext context, {
  Set<String> exclude = const {},
}) => showModalBottomSheet<Product>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _ProductPicker(exclude: exclude),
);

class _ProductPicker extends ConsumerStatefulWidget {
  const _ProductPicker({required this.exclude});

  final Set<String> exclude;

  @override
  ConsumerState<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends ConsumerState<_ProductPicker> {
  String _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(productPickerProvider(_query));

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              key: const Key('picker_search'),
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search product',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(
                  const Duration(milliseconds: 300),
                  () => setState(() => _query = v.trim()),
                );
              },
            ),
          ),
          Expanded(
            child: results.when(
              data: (items) {
                final visible = items
                    .where((p) => !widget.exclude.contains(p.id))
                    .toList();
                if (visible.isEmpty) {
                  return const MessageView(
                    icon: Icons.search_off,
                    title: 'No products found',
                  );
                }
                return ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, i) {
                    final p = visible[i];
                    return ListTile(
                      title: Text(p.name),
                      subtitle: Text(p.sku),
                      trailing: Text('${p.onHand} ${p.unit}'),
                      onTap: () => Navigator.pop(context, p),
                    );
                  },
                );
              },
              error: (e, _) => ErrorView(
                error: e,
                onRetry: () => ref.invalidate(productPickerProvider(_query)),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }
}
