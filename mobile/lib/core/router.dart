import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/domain/user.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/history/presentation/product_history_screen.dart';
import '../features/offline/presentation/sync_controller.dart';
import '../features/operations/domain/stock_transaction.dart';
import '../features/operations/presentation/new_operation_screen.dart';
import '../features/operations/presentation/operation_detail_screen.dart';
import '../features/operations/presentation/operations_screen.dart';
import '../features/products/presentation/product_detail_screen.dart';
import '../features/products/presentation/products_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/scanner/presentation/barcode_lookup.dart';
import '../features/work_orders/presentation/create_work_order_screen.dart';
import '../features/work_orders/presentation/issue_materials.dart';
import '../features/work_orders/presentation/work_order_activity_screen.dart';
import '../features/work_orders/presentation/work_order_detail_screen.dart';
import '../features/work_orders/presentation/work_orders_screen.dart';
import 'widgets/floating_nav.dart';
import 'l10n.dart';

final _rootKey = GlobalKey<NavigatorState>();

/// Shell branches, in this order.
enum _Branch { dashboard, products, operations, workOrders, profile }

/// First screen after sign-in.
String homeFor(Role role) => switch (role) {
  Role.technician || Role.supervisor => '/work-orders',
  _ => '/dashboard',
};

/// Tabs per role (the floating bar fits up to 4; admins and warehouse staff
/// reach Profile from the dashboard avatar). The server enforces the same
/// boundaries; hiding a tab is only convenience.
List<_Branch> _tabsFor(Role role) => switch (role) {
  Role.admin || Role.staff => [
    _Branch.dashboard,
    _Branch.products,
    _Branch.operations,
    _Branch.workOrders,
  ],
  Role.supervisor => [
    _Branch.workOrders,
    _Branch.dashboard,
    _Branch.products,
    _Branch.profile,
  ],
  Role.technician => [_Branch.workOrders, _Branch.products, _Branch.profile],
};

final routerProvider = Provider<GoRouter>((ref) {
  // Re-run redirects whenever auth state changes, without rebuilding the router.
  final refresh = ValueNotifier(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/dashboard',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;

      if (auth.isLoading && !auth.hasValue) {
        return loc == '/splash' ? null : '/splash';
      }
      final user = auth.value;
      if (user == null) return loc == '/login' ? null : '/login';
      if (loc == '/login' || loc == '/splash' || loc == '/') {
        return homeFor(user.role);
      }
      // Technicians have no inventory screens (the API refuses them too).
      if (user.role == Role.technician &&
          (loc.startsWith('/dashboard') || loc.startsWith('/operations'))) {
        return '/work-orders';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const _SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => _HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (_, _) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/products',
                builder: (_, _) => const ProductsScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, state) => ProductDetailScreen(
                      productId: state.pathParameters['id']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'history',
                        builder: (_, state) => ProductHistoryScreen(
                          productId: state.pathParameters['id']!,
                          productName: state.extra as String?,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/operations',
                builder: (_, _) => const OperationsScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    // Full-screen form, without the bottom navigation bar.
                    parentNavigatorKey: _rootKey,
                    builder: (_, state) => NewOperationScreen(
                      initialType: TxType.fromApi(
                        state.uri.queryParameters['type'] ?? 'RECEIVE',
                      ),
                      forWorkOrder: state.extra is IssueForWorkOrder
                          ? state.extra as IssueForWorkOrder
                          : null,
                    ),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (_, state) => OperationDetailScreen(
                      txId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/work-orders',
                builder: (_, _) => const WorkOrdersScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: _rootKey,
                    builder: (_, _) => const CreateWorkOrderScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    // Full screen: the action bar needs the bottom edge.
                    parentNavigatorKey: _rootKey,
                    builder: (_, state) =>
                        WorkOrderDetailScreen(id: state.pathParameters['id']!),
                    routes: [
                      GoRoute(
                        path: 'activity',
                        parentNavigatorKey: _rootKey,
                        builder: (_, state) => WorkOrderActivityScreen(
                          id: state.pathParameters['id']!,
                          code: state.extra as String?,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, _) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class _HomeShell extends ConsumerWidget {
  const _HomeShell({required this.shell});

  final StatefulNavigationShell shell;

  NavItem _item(L10n t, _Branch b, int queued) => switch (b) {
    _Branch.dashboard => NavItem(
      icon: Icons.space_dashboard_outlined,
      selectedIcon: Icons.space_dashboard_rounded,
      label: t.navDashboard,
    ),
    _Branch.products => NavItem(
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2_rounded,
      label: t.navProducts,
    ),
    _Branch.operations => NavItem(
      icon: Icons.swap_vert_rounded,
      selectedIcon: Icons.swap_vert_circle_rounded,
      label: t.navOperations,
      badge: queued,
    ),
    _Branch.workOrders => NavItem(
      icon: Icons.assignment_outlined,
      selectedIcon: Icons.assignment_rounded,
      label: t.navJobs,
    ),
    _Branch.profile => NavItem(
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: t.navProfile,
    ),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watching also starts auto-sync once the user is signed in.
    final queued = ref.watch(
      syncControllerProvider.select((s) => s.value?.queue.length ?? 0),
    );
    final role =
        ref.watch(authControllerProvider.select((a) => a.value?.role)) ??
        Role.staff;
    final tabs = _tabsFor(role);
    // A screen outside the tab set (e.g. Profile for admins) selects none.
    final selected = tabs.indexWhere((b) => b.index == shell.currentIndex);

    return Scaffold(
      body: shell,
      bottomNavigationBar: FloatingNav(
        key: const Key('app_nav'),
        selectedIndex: selected,
        onSelected: (i) {
          final branch = tabs[i].index;
          shell.goBranch(branch, initialLocation: branch == shell.currentIndex);
        },
        onScan: () async {
          final product = await scanProduct(context, ref);
          if (product != null && context.mounted) {
            context.push('/products/${product.id}');
          }
        },
        items: [for (final b in tabs) _item(context.l10n, b, queued)],
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
