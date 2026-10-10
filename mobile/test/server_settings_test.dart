import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockflow/core/config.dart';
import 'package:stockflow/core/token_storage.dart';
import 'package:stockflow/features/auth/presentation/server_settings.dart';
import 'package:stockflow/features/notifications/data/notifications_repository.dart';
import 'package:stockflow/main.dart';

import 'fakes.dart';

class EmptyTokenStorage implements TokenStorage {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String t) async {}
  @override
  Future<void> clear() async {}
}

void main() {
  group('server URL helpers', () {
    test('normalizes scheme and trailing slash', () {
      expect(
        normalizeServerUrl(' 192.168.1.10:3000/ '),
        'http://192.168.1.10:3000',
      );
      expect(
        normalizeServerUrl('https://api.example.com'),
        'https://api.example.com',
      );
    });

    test('validates', () {
      expect(validateServerUrl(''), isNotNull);
      expect(validateServerUrl('ftp://x'), isNotNull);
      expect(validateServerUrl('192.168.1.10:3000'), isNull);
    });
  });

  group('server dialog', () {
    // flutter_secure_storage has no platform in tests; accept writes.
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (_) async => null,
          );
    });

    late List<String> pinged;

    Future<ProviderContainer> pump(WidgetTester tester) async {
      pinged = [];
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            tokenStorageProvider.overrideWithValue(EmptyTokenStorage()),
            notificationsRepositoryProvider.overrideWithValue(
              FakeNotificationsRepository(),
            ),
            serverHealthCheckProvider.overrideWithValue((url) async {
              pinged.add(url);
              return url.contains('10.0.0.9') ? null : 'Cannot reach';
            }),
          ],
          child: const StockFlowApp(),
        ),
      );
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(
        tester.element(find.byType(StockFlowApp)),
      );
    }

    testWidgets('tests and saves a new server address', (tester) async {
      final container = await pump(tester);

      await tester.tap(find.byKey(const Key('server_settings')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('server_url')), 'nope');
      await tester.tap(find.byKey(const Key('server_test')));
      await tester.pumpAndSettle();
      expect(find.text('Cannot reach'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('server_url')),
        '10.0.0.9:3000',
      );
      await tester.tap(find.byKey(const Key('server_test')));
      await tester.pumpAndSettle();
      expect(pinged.last, 'http://10.0.0.9:3000');
      expect(find.text('Connected'), findsOneWidget);

      await tester.tap(find.byKey(const Key('server_save')));
      await tester.pumpAndSettle();
      expect(container.read(serverUrlProvider), 'http://10.0.0.9:3000');
      expect(find.text('Server: 10.0.0.9:3000'), findsOneWidget);
    });

    testWidgets('rejects an invalid address', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('server_settings')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('server_url')), 'ftp://x');
      await tester.tap(find.byKey(const Key('server_save')));
      await tester.pumpAndSettle();
      expect(find.text('e.g. http://192.168.1.10:3000'), findsOneWidget);
    });
  });
}
