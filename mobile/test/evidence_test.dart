import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockflow/core/errors.dart';
import 'package:stockflow/core/token_storage.dart';
import 'package:stockflow/features/auth/data/auth_repository.dart';
import 'package:stockflow/features/auth/domain/user.dart';
import 'package:stockflow/features/dashboard/data/dashboard_repository.dart';
import 'package:stockflow/features/operations/data/attachments_repository.dart';
import 'package:stockflow/features/operations/data/operations_repository.dart';
import 'package:stockflow/features/operations/domain/stock_transaction.dart';
import 'package:stockflow/features/operations/presentation/evidence_photos.dart';
import 'package:stockflow/features/products/domain/product.dart';
import 'package:stockflow/features/notifications/data/notifications_repository.dart';
import 'package:stockflow/main.dart';

import 'fakes.dart';

class MockAuth extends Mock implements AuthRepository {}

class MockOps extends Mock implements OperationsRepository {}

class MockAttachments extends Mock implements AttachmentsRepository {}

class MemoryTokenStorage implements TokenStorage {
  String? token = 'saved';
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String t) async => token = t;
  @override
  Future<void> clear() async => token = null;
}

const _photo = Attachment(
  id: 'a1',
  url: 'https://res.cloudinary.com/demo/image/upload/v1/stockflow/transactions/t1/x.jpg',
);

StockTransaction _tx({List<Attachment> photos = const []}) => StockTransaction(
  id: 't1',
  type: TxType.receive,
  status: TxStatus.confirmed,
  referenceNo: 'PO-1',
  items: const [
    TxItem(
      productId: 'p1',
      productName: 'Drinking water 600ml',
      sku: 'BEV-001',
      unit: 'bottle',
      quantity: 30,
    ),
  ],
  createdById: 'u2',
  createdByName: 'Staff',
  createdAt: DateTime(2026, 10, 9, 9),
  attachments: photos,
);

User _user(String id, Role role) =>
    User(id: id, email: '$id@stockflow.dev', name: id, role: role);

void main() {
  late MockAuth auth;
  late MockOps ops;
  late MockAttachments attachments;
  late List<Attachment> serverPhotos;

  setUpAll(() => registerFallbackValue(Uint8List(0)));

  setUp(() {
    auth = MockAuth();
    ops = MockOps();
    attachments = MockAttachments();
    serverPhotos = [];
    when(
      () => ops.list(
        status: any(named: 'status'),
        page: any(named: 'page'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => Paged(items: [_tx()], total: 1, page: 1));
    when(() => ops.get('t1'))
        .thenAnswer((_) async => _tx(photos: List.of(serverPhotos)));
  });

  Future<void> openTx(WidgetTester tester, User user) async {
    when(() => auth.me()).thenAnswer((_) async => user);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          dashboardRepositoryProvider.overrideWithValue(
            EmptyDashboardRepository(),
          ),
          operationsRepositoryProvider.overrideWithValue(ops),
          attachmentsRepositoryProvider.overrideWithValue(attachments),
          tokenStorageProvider.overrideWithValue(MemoryTokenStorage()),
          notificationsRepositoryProvider.overrideWithValue(
            FakeNotificationsRepository(),
          ),
          imagePickerProvider.overrideWithValue(
            (source) async =>
                (bytes: Uint8List.fromList([1, 2, 3]), name: 'proof.jpg'),
          ),
        ],
        child: const StockFlowApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(navTab('Operations'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PO-1'));
    await tester.pumpAndSettle();
  }

  testWidgets('creator attaches a photo from the camera', (tester) async {
    when(
      () => attachments.upload(
        't1',
        any(),
        any(),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer((_) async => serverPhotos.add(_photo));
    await openTx(tester, _user('u2', Role.staff));

    expect(find.text('Evidence photos (0/5)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('add_photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take photo'));
    await tester.pumpAndSettle();

    final captured = verify(
      () => attachments.upload(
        't1',
        captureAny(),
        'proof.jpg',
        onProgress: any(named: 'onProgress'),
      ),
    ).captured;
    expect(captured.single, [1, 2, 3]);
    expect(find.text('Photo attached'), findsOneWidget);
    expect(find.text('Evidence photos (1/5)'), findsOneWidget);
    expect(find.byKey(const Key('photo_a1')), findsOneWidget);
  });

  testWidgets('shows the server message when upload fails', (tester) async {
    when(
      () => attachments.upload(
        any(),
        any(),
        any(),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenThrow(ApiException('Photo upload is not configured on the server'));
    await openTx(tester, _user('u2', Role.staff));

    await tester.tap(find.byKey(const Key('add_photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from gallery'));
    await tester.pumpAndSettle();

    expect(
      find.text('Photo upload is not configured on the server'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('add_photo')), findsOneWidget);
  });

  testWidgets('other staff can view but not add photos', (tester) async {
    await openTx(tester, _user('someone-else', Role.staff));
    expect(find.byKey(const Key('add_photo')), findsNothing);
    expect(find.text('No photos attached'), findsOneWidget);
  });

  testWidgets('admin deletes a photo from the viewer', (tester) async {
    serverPhotos.add(_photo);
    when(() => attachments.delete('t1', 'a1')).thenAnswer((_) async {
      serverPhotos.clear();
    });
    await openTx(tester, _user('admin', Role.admin));

    await tester.tap(find.byKey(const Key('photo_a1')));
    await tester.pumpAndSettle();
    expect(find.text('1 / 1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('delete_photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    verify(() => attachments.delete('t1', 'a1')).called(1);
    expect(find.text('Photo deleted'), findsOneWidget);
    expect(find.text('Evidence photos (0/5)'), findsOneWidget);
  });
}
