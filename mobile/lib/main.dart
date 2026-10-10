import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter/foundation.dart';

import 'core/config.dart';
import 'core/l10n.dart';
import 'features/offline/data/local_store.dart';
import 'core/router.dart';
import 'core/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final savedServerUrl = await ServerUrlStore.read();
  final savedLocale = await LocaleStore.read();
  // SQLite for the offline queue and product cache (web uses memory).
  final db = kIsWeb ? null : await openLocalDatabase();
  runApp(
    ProviderScope(
      // Show errors immediately with a Retry button instead of silent auto-retry.
      retry: (_, _) => null,
      overrides: [
        savedServerUrlProvider.overrideWithValue(savedServerUrl),
        savedLocaleProvider.overrideWithValue(savedLocale),
        localDatabaseProvider.overrideWithValue(db),
      ],
      child: const StockFlowApp(),
    ),
  );
}

class StockFlowApp extends ConsumerWidget {
  const StockFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'StockFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: ref.watch(routerProvider),
      // Null follows the device language (Thai or English).
      locale: ref.watch(localeProvider),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      builder: (context, child) {
        setCurrentL10n(L10n.of(context));
        return child!;
      },
    );
  }
}
