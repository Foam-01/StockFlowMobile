import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockflow/core/errors.dart';
import 'package:stockflow/core/token_storage.dart';
import 'package:stockflow/features/auth/data/auth_repository.dart';
import 'package:stockflow/features/auth/domain/user.dart';
import 'package:stockflow/features/dashboard/data/dashboard_repository.dart';
import 'package:stockflow/features/operations/data/operations_repository.dart';
import 'package:stockflow/features/operations/domain/stock_transaction.dart';
import 'package:stockflow/features/products/data/products_repository.dart';
import 'package:stockflow/features/products/domain/product.dart';
import 'package:stockflow/features/work_orders/data/work_orders_repository.dart';
import 'package:stockflow/features/work_orders/domain/work_order.dart';
import 'package:stockflow/main.dart';

import 'fakes.dart';

class MockAuth extends Mock implements AuthRepository {}

class MockWo extends Mock implements WorkOrdersRepository {}

class MockProducts extends Mock implements ProductsRepository {}

class MockOps extends Mock implements OperationsRepository {}

class FakeNewWorkOrder extends Fake implements NewWorkOrder {}

class MemoryTokenStorage implements TokenStorage {
  String? token = 'saved';
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String t) async => token = t;
  @override
  Future<void> clear() async => token = null;
}

User _user(Role role) => User(
  id: role.name,
  email: '${role.name}@x.dev',
  name: role.label,
  role: role,
);

Map<String, dynamic> _person(String id, String name, String role) => {
  'id': id,
  'name': name,
  'role': role,
};

/// A realistic API payload; override what a test cares about.
WorkOrder _wo({
  String status = 'OPEN',
  List<String> actions = const [],
  List<bool> done = const [false, false],
  List<String> problems = const [],
  String? reviewNote,
  List<Map<String, dynamic>> materials = const [],
}) => WorkOrder.fromJson({
  'id': 'wo1',
  'code': 'WO-00007',
  'title': 'Install split AC',
  'description': 'Above the window',
  'siteName': 'Ratchada tower',
  'status': status,
  'priority': 'HIGH',
  'dueAt': '2099-01-01T09:00:00.000Z',
  'requiredEvidence': ['AFTER'],
  'createdAt': '2026-10-10T08:00:00.000Z',
  'assignee': _person('technician', 'Technician', 'TECHNICIAN'),
  'reviewer': null,
  'reviewNote': reviewNote,
  'checklist': [
    for (var i = 0; i < done.length; i++)
      {
        'id': 'item$i',
        'title': 'Step ${i + 1}',
        'required': true,
        'done': done[i],
      },
  ],
  'materials': materials,
  'evidence': [],
  'stockTransactions': [],
  'allowedActions': actions,
  'submissionProblems': problems,
});

final _summary = WorkOrderSummary.fromJson({
  'id': 'wo1',
  'code': 'WO-00007',
  'title': 'Install split AC',
  'siteName': 'Ratchada tower',
  'status': 'OPEN',
  'priority': 'HIGH',
  'dueAt': '2099-01-01T09:00:00.000Z',
  'assignee': _person('technician', 'Technician', 'TECHNICIAN'),
  'checklistDone': 1,
  'checklistTotal': 2,
});

void main() {
  late MockAuth auth;
  late MockWo wo;
  late MockProducts products;
  late MockOps ops;

  setUpAll(() {
    registerFallbackValue(<WoStatus>{});
    registerFallbackValue(FakeNewWorkOrder());
    registerFallbackValue(TxType.issue);
  });

  setUp(() {
    auth = MockAuth();
    wo = MockWo();
    products = MockProducts();
    ops = MockOps();
    when(
      () => wo.list(
        statuses: any(named: 'statuses'),
        query: any(named: 'query'),
        page: any(named: 'page'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => Paged(items: [_summary], total: 1, page: 1));
    when(() => wo.events(any())).thenAnswer((_) async => []);
    when(() => products.categories()).thenAnswer((_) async => []);
    when(
      () => products.list(
        query: any(named: 'query'),
        categoryId: any(named: 'categoryId'),
        lowStock: any(named: 'lowStock'),
        page: any(named: 'page'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => const Paged(items: [], total: 0, page: 1));
    when(
      () => ops.list(
        status: any(named: 'status'),
        page: any(named: 'page'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => const Paged(items: [], total: 0, page: 1));
  });

  Future<void> pumpAs(WidgetTester tester, Role role) async {
    when(() => auth.me()).thenAnswer((_) async => _user(role));
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
          workOrdersRepositoryProvider.overrideWithValue(wo),
          productsRepositoryProvider.overrideWithValue(products),
          operationsRepositoryProvider.overrideWithValue(ops),
          tokenStorageProvider.overrideWithValue(MemoryTokenStorage()),
        ],
        child: const StockFlowApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openDetail(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('wo_wo1')));
    await tester.pumpAndSettle();
  }

  group('navigation by role', () {
    testWidgets('technicians land on their jobs; no inventory tabs', (
      tester,
    ) async {
      await pumpAs(tester, Role.technician);
      expect(find.text('My jobs'), findsOneWidget);
      expect(navTab('Jobs'), findsOneWidget);
      expect(navTab('Products'), findsOneWidget);
      expect(navTab('Profile'), findsOneWidget);
      expect(navTab('Dashboard'), findsNothing);
      expect(navTab('Operations'), findsNothing);
      // Default view: active work only.
      verify(
        () => wo.list(
          statuses: {
            WoStatus.open,
            WoStatus.inProgress,
            WoStatus.needsRevision,
          },
          query: any(named: 'query'),
          page: 1,
          limit: any(named: 'limit'),
        ),
      ).called(1);
      expect(find.text('WO-00007'), findsOneWidget);
      expect(find.text('1/2'), findsOneWidget);
    });

    testWidgets('supervisors start on the review queue', (tester) async {
      await pumpAs(tester, Role.supervisor);
      expect(find.text('Reviews & jobs'), findsOneWidget);
      verify(
        () => wo.list(
          statuses: {WoStatus.submitted},
          query: any(named: 'query'),
          page: 1,
          limit: any(named: 'limit'),
        ),
      ).called(1);
    });

    testWidgets('admin keeps inventory tabs and gets Jobs', (tester) async {
      await pumpAs(tester, Role.admin);
      for (final t in ['Dashboard', 'Products', 'Operations', 'Jobs']) {
        expect(navTab(t), findsOneWidget);
      }
      await tester.tap(navTab('Jobs'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('new_work_order')), findsOneWidget);
    });
  });

  group('technician', () {
    testWidgets('starts work and ticks the checklist', (tester) async {
      when(() => wo.get('wo1'))
          .thenAnswer((_) async => _wo(actions: ['start']));
      when(() => wo.start('wo1')).thenAnswer(
        (_) async => _wo(
          status: 'IN_PROGRESS',
          actions: ['updateChecklist', 'manageEvidence', 'submit'],
        ),
      );
      when(() => wo.setChecklistItem('wo1', 'item0', done: true, note: null))
          .thenAnswer(
            (_) async => _wo(
              status: 'IN_PROGRESS',
              done: [true, false],
              actions: ['updateChecklist', 'manageEvidence', 'submit'],
            ),
          );
      await pumpAs(tester, Role.technician);
      await openDetail(tester);

      expect(find.byKey(const Key('wo_submit')), findsNothing);
      await tester.tap(find.byKey(const Key('wo_start')));
      await tester.pumpAndSettle();
      verify(() => wo.start('wo1')).called(1);
      expect(find.text('In progress'), findsOneWidget);
      expect(find.byKey(const Key('wo_submit')), findsOneWidget);

      await tester.tap(find.byKey(const Key('check_item0')));
      await tester.pumpAndSettle();
      verify(() => wo.setChecklistItem('wo1', 'item0', done: true, note: null))
          .called(1);
      expect(find.text('1/2 done'), findsOneWidget);
    });

    testWidgets('submit shows what the server says is missing', (tester) async {
      when(() => wo.get('wo1')).thenAnswer(
        (_) async => _wo(
          status: 'IN_PROGRESS',
          actions: ['updateChecklist', 'manageEvidence', 'submit'],
          problems: ['Photo required: after work'],
        ),
      );
      when(() => wo.submit('wo1')).thenThrow(
        ApiException(
          'Work order is not ready to submit\n• Photo required: after work',
          statusCode: 400,
        ),
      );
      await pumpAs(tester, Role.technician);
      await openDetail(tester);

      expect(find.byKey(const Key('submission_problems')), findsOneWidget);
      await tester.tap(find.byKey(const Key('wo_submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm_action')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Work order is not ready'), findsOneWidget);
      expect(find.text('In progress'), findsOneWidget); // unchanged
    });

    testWidgets('sees the reason when changes were requested', (tester) async {
      when(() => wo.get('wo1')).thenAnswer(
        (_) async => _wo(
          status: 'NEEDS_REVISION',
          actions: ['start'],
          reviewNote: 'After photo is blurry',
        ),
      );
      await pumpAs(tester, Role.technician);
      await openDetail(tester);
      expect(find.byKey(const Key('review_note')), findsOneWidget);
      expect(find.textContaining('After photo is blurry'), findsOneWidget);
      expect(find.text('Resume work'), findsOneWidget);
    });
  });

  group('supervisor', () {
    testWidgets('request changes needs a reason', (tester) async {
      when(() => wo.get('wo1')).thenAnswer(
        (_) async => _wo(
          status: 'SUBMITTED',
          done: [true, true],
          actions: ['approve', 'requestChanges'],
        ),
      );
      when(() => wo.requestChanges('wo1', any())).thenAnswer(
        (_) async => _wo(status: 'NEEDS_REVISION', reviewNote: 'Fix label'),
      );
      await pumpAs(tester, Role.supervisor);
      await openDetail(tester);

      await tester.tap(find.byKey(const Key('wo_request_changes')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dialog_submit')));
      await tester.pump();
      expect(find.text('Please add a reason'), findsOneWidget);
      verifyNever(() => wo.requestChanges(any(), any()));

      await tester.enterText(find.byKey(const Key('dialog_text')), 'Fix label');
      await tester.tap(find.byKey(const Key('dialog_submit')));
      await tester.pumpAndSettle();
      verify(() => wo.requestChanges('wo1', 'Fix label')).called(1);
      expect(find.text('Needs revision'), findsOneWidget);
      expect(find.byKey(const Key('wo_approve')), findsNothing);
    });

    testWidgets('approves', (tester) async {
      when(() => wo.get('wo1')).thenAnswer(
        (_) async => _wo(
          status: 'SUBMITTED',
          done: [true, true],
          actions: ['approve', 'requestChanges'],
        ),
      );
      when(() => wo.approve('wo1', note: any(named: 'note')))
          .thenAnswer((_) async => _wo(status: 'APPROVED', done: [true, true]));
      await pumpAs(tester, Role.supervisor);
      await openDetail(tester);

      await tester.tap(find.byKey(const Key('wo_approve')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('dialog_text')), 'Neat');
      await tester.tap(find.byKey(const Key('dialog_submit')));
      await tester.pumpAndSettle();
      verify(() => wo.approve('wo1', note: 'Neat')).called(1);
      expect(find.text('Approved'), findsWidgets);
      expect(find.byKey(const Key('wo_approve')), findsNothing);
    });
  });

  group('admin', () {
    testWidgets('creates a work order after validation', (tester) async {
      when(() => wo.templates()).thenAnswer(
        (_) async => [
          const ChecklistTemplate(id: 't1', name: 'AC install', itemCount: 7),
        ],
      );
      when(() => wo.people(any())).thenAnswer(
        (_) async => [Person.maybe(_person('tech1', 'Niran', 'TECHNICIAN'))!],
      );
      when(() => wo.create(any())).thenAnswer((_) async => _wo());
      when(() => wo.get('wo1')).thenAnswer((_) async => _wo());
      await pumpAs(tester, Role.admin);
      await tester.tap(navTab('Jobs'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('new_work_order')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('wo_save')));
      await tester.pumpAndSettle();
      expect(find.text('Required'), findsNWidgets(2));
      verifyNever(() => wo.create(any()));

      await tester.enterText(find.byKey(const Key('wo_title')), 'Install AC');
      await tester.enterText(find.byKey(const Key('wo_site')), 'Office 12F');
      await tester.tap(find.byKey(const Key('wo_save')));
      await tester.pumpAndSettle();

      final sent =
          verify(() => wo.create(captureAny())).captured.single as NewWorkOrder;
      expect(sent.toJson(), containsPair('title', 'Install AC'));
      expect(sent.toJson(), containsPair('siteName', 'Office 12F'));
      expect(sent.toJson()['requiredEvidence'], ['AFTER']);
      expect(find.text('WO-00007'), findsOneWidget); // on the detail
    });

    testWidgets('staff issues remaining materials, linked to the job', (
      tester,
    ) async {
      when(() => wo.get('wo1')).thenAnswer(
        (_) async => _wo(
          materials: [
            {
              'product': {
                'id': 'p1',
                'sku': 'INS-001',
                'name': 'Copper pipe set',
                'unit': 'set',
                'onHand': 10,
              },
              'plannedQty': 3,
              'issuedQty': 1,
              'remainingQty': 2,
              'shortage': 0,
            },
          ],
        ),
      );
      when(
        () => ops.create(
          clientUuid: any(named: 'clientUuid'),
          type: any(named: 'type'),
          items: any(named: 'items'),
          referenceNo: any(named: 'referenceNo'),
          note: any(named: 'note'),
          workOrderId: any(named: 'workOrderId'),
        ),
      ).thenAnswer(
        (_) async => StockTransaction(
          id: 't9',
          type: TxType.issue,
          status: TxStatus.draft,
          items: const [],
          createdById: 'staff',
          createdByName: 'Staff',
          createdAt: DateTime(2026),
        ),
      );
      await pumpAs(tester, Role.staff);
      await tester.tap(navTab('Jobs'));
      await tester.pumpAndSettle();
      await openDetail(tester);

      // Staff sees the job read-only: no work buttons.
      expect(find.byKey(const Key('wo_start')), findsNothing);
      expect(find.text('2 to issue'), findsOneWidget);

      await tester.tap(find.byKey(const Key('issue_materials')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('linked_work_order')), findsOneWidget);
      expect(find.text('Copper pipe set'), findsOneWidget);

      await tester.tap(find.byKey(const Key('save_draft')));
      await tester.pumpAndSettle();
      final captured = verify(
        () => ops.create(
          clientUuid: any(named: 'clientUuid'),
          type: TxType.issue,
          items: captureAny(named: 'items'),
          referenceNo: 'WO-00007',
          note: any(named: 'note'),
          workOrderId: 'wo1',
        ),
      ).captured;
      expect(captured.single, [(productId: 'p1', quantity: 2)]);
      expect(
        find.text('Issue draft created for the work order'),
        findsOneWidget,
      );
    });
  });
}
