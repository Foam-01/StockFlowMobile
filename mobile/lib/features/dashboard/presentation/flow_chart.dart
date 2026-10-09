import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/dashboard.dart';

/// Series colours (validated categorical slots 1–2, light and dark steps).
class FlowColors {
  static Color received(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF3987E5) : const Color(0xFF2A78D6);
  static Color issued(Brightness b) =>
      b == Brightness.dark ? const Color(0xFFD95926) : const Color(0xFFEB6834);
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _dayLabel(DateTime d) => _weekdays[d.weekday - 1];

/// Received vs issued units per day: grouped bars on a single axis.
/// Tap a day to see its values; the table toggle offers the same data as text.
class FlowChart extends StatefulWidget {
  const FlowChart({super.key, required this.flow});

  final List<DayFlow> flow;

  @override
  State<FlowChart> createState() => _FlowChartState();
}

class _FlowChartState extends State<FlowChart> {
  late int _selected = widget.flow.length - 1; // today
  bool _table = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = theme.brightness;
    final flow = widget.flow;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _LegendItem(color: FlowColors.received(b), label: 'Received'),
            const SizedBox(width: 16),
            _LegendItem(color: FlowColors.issued(b), label: 'Issued'),
            const Spacer(),
            IconButton(
              key: const Key('flow_table_toggle'),
              tooltip: _table ? 'Show chart' : 'Show table',
              visualDensity: VisualDensity.compact,
              icon: Icon(_table ? Icons.bar_chart : Icons.table_rows_outlined),
              onPressed: () => setState(() => _table = !_table),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_table)
          _FlowTable(flow: flow)
        else ...[
          _Readout(day: flow[_selected]),
          const SizedBox(height: 8),
          SizedBox(
            height: 160,
            child: _Bars(
              flow: flow,
              selected: _selected,
              onSelect: (i) => setState(() => _selected = i),
            ),
          ),
        ],
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.labelMedium),
    ],
  );
}

/// Values for the selected day, in text colours (swatches carry identity).
class _Readout extends StatelessWidget {
  const _Readout({required this.day});

  final DayFlow day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = theme.brightness;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    Widget value(Color c, String label, int v) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, color: c),
        const SizedBox(width: 6),
        Text('$label ', style: muted),
        Text(
          '$v',
          style: theme.textTheme.titleSmall?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
    return Row(
      children: [
        Text(
          '${_dayLabel(day.date)} ${day.date.day}/${day.date.month}',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(width: 16),
        value(FlowColors.received(b), 'In', day.received),
        const SizedBox(width: 12),
        value(FlowColors.issued(b), 'Out', day.issued),
      ],
    );
  }
}

class _Bars extends StatelessWidget {
  const _Bars({
    required this.flow,
    required this.selected,
    required this.onSelect,
  });

  final List<DayFlow> flow;
  final int selected;
  final ValueChanged<int> onSelect;

  /// A round axis maximum: 1, 2, 5 × 10ⁿ.
  static int niceMax(int v) {
    if (v <= 0) return 4;
    final mag = math.pow(10, (math.log(v) / math.ln10).floor()).toInt();
    for (final m in [1, 2, 5, 10]) {
      if (v <= m * mag) return m * mag;
    }
    return 10 * mag;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = theme.brightness;
    final peak = flow.fold(
      0,
      (m, d) => math.max(m, math.max(d.received, d.issued)),
    );
    final max = niceMax(peak);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final grid = theme.colorScheme.outlineVariant.withValues(alpha: 0.5);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Y axis: 0, half, max.
        SizedBox(
          width: 28,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$max', style: labelStyle),
              const Spacer(),
              Text('${max ~/ 2}', style: labelStyle),
              const Spacer(),
              Text('0', style: labelStyle),
              const SizedBox(height: 18), // day labels
            ],
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Stack(
            children: [
              // Recessive grid lines at max and half; solid baseline.
              Positioned.fill(
                bottom: 18,
                child: Column(
                  children: [
                    Divider(height: 1, color: grid),
                    const Spacer(),
                    Divider(height: 1, color: grid),
                    const Spacer(),
                    Divider(height: 1, color: theme.colorScheme.outline),
                  ],
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < flow.length; i++)
                    Expanded(
                      child: _DayGroup(
                        day: flow[i],
                        max: max,
                        selected: i == selected,
                        received: FlowColors.received(b),
                        issued: FlowColors.issued(b),
                        labelStyle: labelStyle,
                        onTap: () => onSelect(i),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayGroup extends StatelessWidget {
  const _DayGroup({
    required this.day,
    required this.max,
    required this.selected,
    required this.received,
    required this.issued,
    required this.labelStyle,
    required this.onTap,
  });

  final DayFlow day;
  final int max;
  final bool selected;
  final Color received;
  final Color issued;
  final TextStyle? labelStyle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget bar(int v, Color c) => Expanded(
      child: FractionallySizedBox(
        alignment: Alignment.bottomCenter,
        heightFactor: (v / max).clamp(0.0, 1.0),
        child: Container(
          constraints: const BoxConstraints(minHeight: 0),
          decoration: BoxDecoration(
            color: c,
            // Rounded data end, square at the baseline.
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      label:
          '${_dayLabel(day.date)} ${day.date.day}/${day.date.month}: '
          'received ${day.received}, issued ${day.issued}',
      excludeSemantics: true,
      child: InkWell(
        // Whole column is the hit target, bigger than the bars.
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.onSurface.withValues(alpha: 0.06)
                : null,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            children: [
              Expanded(
                child: Align(
                  // Anchored to the baseline; marks stay thin on wide screens.
                  alignment: Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 42),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        bar(day.received, received),
                        const SizedBox(width: 2), // surface gap between fills
                        bar(day.issued, issued),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 18,
                child: Center(
                  child: Text(
                    _dayLabel(day.date),
                    style: selected
                        ? labelStyle?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                          )
                        : labelStyle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlowTable extends StatelessWidget {
  const _FlowTable({required this.flow});

  final List<DayFlow> flow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    TableRow row(List<String> cells, {bool header = false}) => TableRow(
      children: [
        for (var i = 0; i < cells.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              cells[i],
              textAlign: i == 0 ? TextAlign.start : TextAlign.end,
              style: header
                  ? theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )
                  : theme.textTheme.bodyMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
            ),
          ),
      ],
    );
    return Table(
      children: [
        row(['Day', 'Received', 'Issued'], header: true),
        for (final d in flow.reversed)
          row([
            '${_dayLabel(d.date)} ${d.date.day}/${d.date.month}',
            '${d.received}',
            '${d.issued}',
          ]),
      ],
    );
  }
}
