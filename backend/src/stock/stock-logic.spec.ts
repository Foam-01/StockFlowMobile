import { TxStatus, TxType } from '@prisma/client';
import {
  applyDeltas,
  canTransition,
  InsufficientStockError,
  ledgerBalance,
  netDeltas,
  runningBalances,
  signedDelta,
  StockRuleError,
  validateItems,
} from './stock-logic.js';

describe('signedDelta', () => {
  it('receive adds, issue subtracts, adjust keeps sign', () => {
    expect(signedDelta(TxType.RECEIVE, 5)).toBe(5);
    expect(signedDelta(TxType.ISSUE, 5)).toBe(-5);
    expect(signedDelta(TxType.ADJUST, -3)).toBe(-3);
    expect(signedDelta(TxType.ADJUST, 4)).toBe(4);
  });
});

describe('validateItems', () => {
  it('rejects empty transactions', () => {
    expect(() => validateItems(TxType.RECEIVE, [])).toThrow(StockRuleError);
  });

  it.each([0, -1])(
    'rejects non-positive quantity %i for RECEIVE/ISSUE',
    (q) => {
      expect(() =>
        validateItems(TxType.RECEIVE, [{ productId: 'a', quantity: q }]),
      ).toThrow(StockRuleError);
      expect(() =>
        validateItems(TxType.ISSUE, [{ productId: 'a', quantity: q }]),
      ).toThrow(StockRuleError);
    },
  );

  it('rejects non-integer quantities', () => {
    expect(() =>
      validateItems(TxType.RECEIVE, [{ productId: 'a', quantity: 1.5 }]),
    ).toThrow(StockRuleError);
  });

  it('allows negative but not zero for ADJUST', () => {
    expect(() =>
      validateItems(TxType.ADJUST, [{ productId: 'a', quantity: -2 }]),
    ).not.toThrow();
    expect(() =>
      validateItems(TxType.ADJUST, [{ productId: 'a', quantity: 0 }]),
    ).toThrow(StockRuleError);
  });
});

describe('netDeltas', () => {
  it('sums duplicate product lines', () => {
    const d = netDeltas(TxType.ISSUE, [
      { productId: 'a', quantity: 2 },
      { productId: 'b', quantity: 1 },
      { productId: 'a', quantity: 3 },
    ]);
    expect(d.get('a')).toBe(-5);
    expect(d.get('b')).toBe(-1);
  });
});

describe('applyDeltas', () => {
  const onHand = new Map([
    ['a', 10],
    ['b', 0],
  ]);

  it('applies receive and issue', () => {
    const next = applyDeltas(
      onHand,
      new Map([
        ['a', -4],
        ['b', 7],
      ]),
    );
    expect(next.get('a')).toBe(6);
    expect(next.get('b')).toBe(7);
  });

  it('allows issuing exactly what is on hand', () => {
    expect(applyDeltas(onHand, new Map([['a', -10]])).get('a')).toBe(0);
  });

  it('never allows issuing more than on hand', () => {
    expect(() => applyDeltas(onHand, new Map([['a', -11]]))).toThrow(
      InsufficientStockError,
    );
  });

  it('treats unknown products as zero stock', () => {
    expect(() => applyDeltas(onHand, new Map([['zzz', -1]]))).toThrow(
      InsufficientStockError,
    );
  });

  it('reports product, on-hand and requested amounts', () => {
    try {
      applyDeltas(onHand, new Map([['a', -12]]));
      expect.unreachable();
    } catch (e) {
      expect(e).toMatchObject({ productId: 'a', onHand: 10, requested: 12 });
    }
  });

  it('does not mutate the input map', () => {
    applyDeltas(onHand, new Map([['a', -1]]));
    expect(onHand.get('a')).toBe(10);
  });
});

describe('ledgerBalance', () => {
  it('only counts confirmed lines', () => {
    expect(
      ledgerBalance([
        { type: TxType.RECEIVE, status: TxStatus.CONFIRMED, quantity: 10 },
        { type: TxType.ISSUE, status: TxStatus.CONFIRMED, quantity: 3 },
        { type: TxType.ADJUST, status: TxStatus.CONFIRMED, quantity: -1 },
        { type: TxType.RECEIVE, status: TxStatus.DRAFT, quantity: 100 },
        { type: TxType.ISSUE, status: TxStatus.CANCELLED, quantity: 100 },
      ]),
    ).toBe(6);
  });
});

describe('runningBalances', () => {
  it('accumulates signed deltas in order', () => {
    expect(
      runningBalances([
        { type: TxType.RECEIVE, quantity: 30 },
        { type: TxType.ISSUE, quantity: 4 },
        { type: TxType.ADJUST, quantity: -2 },
        { type: TxType.RECEIVE, quantity: 6 },
      ]),
    ).toEqual([30, 26, 24, 30]);
  });

  it('is empty for no movements', () => {
    expect(runningBalances([])).toEqual([]);
  });
});

describe('canTransition', () => {
  it('only drafts can be confirmed or cancelled', () => {
    expect(canTransition(TxStatus.DRAFT, TxStatus.CONFIRMED)).toBe(true);
    expect(canTransition(TxStatus.DRAFT, TxStatus.CANCELLED)).toBe(true);
    expect(canTransition(TxStatus.CONFIRMED, TxStatus.CANCELLED)).toBe(false);
    expect(canTransition(TxStatus.CANCELLED, TxStatus.CONFIRMED)).toBe(false);
    expect(canTransition(TxStatus.CONFIRMED, TxStatus.CONFIRMED)).toBe(false);
  });
});
