import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

final _rootKey = GlobalKey<NavigatorState>();

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
      final signedIn = auth.value != null;
      if (!signedIn) return loc == '/login' ? null : '/login';
      if (loc == '/login' || loc == '/splash' || loc == '/') {
        return '/dashboard';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watching also starts auto-sync once the user is signed in.
    final queued = ref.watch(
      syncControllerProvider.select((s) => s.value?.queue.length ?? 0),
    );
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard),
            label: 'Dashboard',
          ),
          const NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Products',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: queued > 0,
              label: Text('$queued'),
              child: const Icon(Icons.swap_vert),
            ),
            selectedIcon: Badge(
              isLabelVisible: queued > 0,
              label: Text('$queued'),
              child: const Icon(Icons.swap_vert_circle),
            ),
            label: 'Operations',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
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
