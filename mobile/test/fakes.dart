import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockflow/features/dashboard/data/dashboard_repository.dart';
import 'package:stockflow/features/dashboard/domain/dashboard.dart';

/// Dashboard with no data, for tests that don't care about it.
class EmptyDashboardRepository implements DashboardRepository {
  @override
  Future<DashboardSummary> summary() async => DashboardSummary(
    totals: const DashboardTotals(
      products: 0,
      unitsOnHand: 0,
      lowStock: 0,
      outOfStock: 0,
      pendingDrafts: 0,
    ),
    flow: [
      for (var i = 6; i >= 0; i--)
        DayFlow(
          date: DateTime(2026, 10, 9).subtract(Duration(days: i)),
          received: 0,
          issued: 0,
        ),
    ],
    needsAttention: const [],
    recentActivity: const [],
  );
}

/// The bottom-navigation tab with [label] (avoids clashing with page text).
Finder navTab(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));
