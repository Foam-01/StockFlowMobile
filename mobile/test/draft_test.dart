import 'package:flutter_test/flutter_test.dart';
import 'package:stockflow/features/operations/domain/draft.dart';
import 'package:stockflow/features/operations/domain/stock_transaction.dart';
import 'package:stockflow/features/products/domain/product.dart';

Product _p(String id, int onHand) => Product(
  id: id,
  sku: id,
  name: id,
  unit: 'pcs',
  minStock: 0,
  onHand: onHand,
);

DraftLine _l(String id, int onHand, int qty) =>
    DraftLine(product: _p(id, onHand), quantity: qty);

void main() {
  group('validateDraft', () {
    test('requires at least one line', () {
      expect(validateDraft(TxType.receive, []).form, isNotNull);
    });

    test('receive needs positive quantities', () {
      final v = validateDraft(TxType.receive, [_l('a', 0, 0), _l('b', 0, 5)]);
      expect(v.lines.keys, ['a']);
    });

    test('issue cannot exceed on hand', () {
      expect(validateDraft(TxType.issue, [_l('a', 10, 10)]).lines, isEmpty);
      expect(
        validateDraft(TxType.issue, [_l('a', 10, 11)]).lines['a'],
        contains('Only 10'),
      );
    });

    test('adjust allows negative but not zero or below zero result', () {
      expect(validateDraft(TxType.adjust, [_l('a', 5, -5)]).lines, isEmpty);
      expect(validateDraft(TxType.adjust, [_l('a', 5, 0)]).lines, isNotEmpty);
      expect(validateDraft(TxType.adjust, [_l('a', 5, -6)]).lines, isNotEmpty);
    });
  });

  test('projectedOnHand', () {
    expect(projectedOnHand(TxType.receive, _l('a', 5, 3)), 8);
    expect(projectedOnHand(TxType.issue, _l('a', 5, 3)), 2);
    expect(projectedOnHand(TxType.adjust, _l('a', 5, -2)), 3);
  });
}
