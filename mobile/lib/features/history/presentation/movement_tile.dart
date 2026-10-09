import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../operations/presentation/widgets/tx_widgets.dart';
import '../domain/movement.dart';

class MovementTile extends StatelessWidget {
  const MovementTile({super.key, required this.movement, required this.unit});

  final Movement movement;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = movement;
    final by = m.confirmedBy == null || m.confirmedBy == m.createdBy
        ? m.createdBy
        : '${m.createdBy} → ${m.confirmedBy}';

    return ListTile(
      leading: TxTypeIcon(type: m.type),
      title: Text(m.referenceNo ?? m.type.label),
      subtitle: Text(
        '${formatDateTime(m.confirmedAt)} · $by',
        style: theme.textTheme.bodySmall,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SignedQty(value: m.change),
          Text(
            'bal. ${m.balanceAfter} $unit',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      onTap: () => context.push('/operations/${m.transactionId}'),
    );
  }
}
