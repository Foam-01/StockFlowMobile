import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter/foundation.dart';

import 'core/config.dart';
import 'features/offline/data/local_store.dart';
import 'core/router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final savedServerUrl = await ServerUrlStore.read();
  // SQLite for the offline queue and product cache (web uses memory).
  final db = kIsWeb ? null : await openLocalDatabase();
  runApp(
    ProviderScope(
      // Show errors immediately with a Retry button instead of silent auto-retry.
      retry: (_, _) => null,
      overrides: [
        savedServerUrlProvider.overrideWithValue(savedServerUrl),
        localDatabaseProvider.overrideWithValue(db),
      ],
      child: const StockFlowApp(),
    ),
  );
}

class StockFlowApp extends ConsumerWidget {
  const StockFlowApp({super.key});

  static const _seed = Color(0xFF1E6F5C);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'StockFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: _seed)),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ),
      ),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
