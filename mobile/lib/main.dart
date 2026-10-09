import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';

void main() {
  runApp(
    // Show errors immediately with a Retry button instead of silent auto-retry.
    ProviderScope(retry: (_, _) => null, child: const StockFlowApp()),
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
