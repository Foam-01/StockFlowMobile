import { TxStatus, TxType } from '@prisma/client';

/**
 * Pure stock rules, kept free of Nest/Prisma so they are easy to unit test.
 *
 * Quantity convention:
 *  - RECEIVE / ISSUE: quantity is a positive amount; direction comes from type.
 *  - ADJUST: quantity is a signed delta (e.g. -3 after a stock count).
 */

export interface LineItem {
  productId: string;
  quantity: number;
}

export class StockRuleError extends Error {}

export class InsufficientStockError extends StockRuleError {
  constructor(
    readonly productId: string,
    readonly onHand: number,
    readonly requested: number,
  ) {
    super(
      `Insufficient stock for product ${productId}: on hand ${onHand}, requested ${requested}`,
    );
  }
}

export function signedDelta(type: TxType, quantity: number): number {
  switch (type) {
    case TxType.RECEIVE:
      return quantity;
    case TxType.ISSUE:
      return -quantity;
    case TxType.ADJUST:
      return quantity;
  }
}

/** Throws StockRuleError if the line items are not valid for this type. */
export function validateItems(type: TxType, items: LineItem[]): void {
  if (items.length === 0) {
    throw new StockRuleError('Transaction must have at least one item');
  }
  for (const { productId, quantity } of items) {
    if (!Number.isInteger(quantity)) {
      throw new StockRuleError(`Quantity for ${productId} must be an integer`);
    }
    if (type === TxType.ADJUST ? quantity === 0 : quantity <= 0) {
      throw new StockRuleError(
        type === TxType.ADJUST
          ? `Adjustment for ${productId} must not be zero`
          : `Quantity for ${productId} must be greater than zero`,
      );
    }
  }
}

/** Net stock change per product (duplicate lines are summed). */
export function netDeltas(
  type: TxType,
  items: LineItem[],
): Map<string, number> {
  const deltas = new Map<string, number>();
  for (const { productId, quantity } of items) {
    deltas.set(
      productId,
      (deltas.get(productId) ?? 0) + signedDelta(type, quantity),
    );
  }
  return deltas;
}

/**
 * Applies deltas to current balances. Throws InsufficientStockError if any
 * product would go below zero — stock can never be issued beyond what is on hand.
 */
export function applyDeltas(
  onHand: Map<string, number>,
  deltas: Map<string, number>,
): Map<string, number> {
  const next = new Map<string, number>();
  for (const [productId, delta] of deltas) {
    const current = onHand.get(productId) ?? 0;
    if (current + delta < 0) {
      throw new InsufficientStockError(productId, current, -delta);
    }
    next.set(productId, current + delta);
  }
  return next;
}

/**
 * Source of truth: balance = sum of confirmed ledger lines.
 * products.onHand is a cache that must always equal this.
 */
export function ledgerBalance(
  lines: { type: TxType; status: TxStatus; quantity: number }[],
): number {
  return lines
    .filter((l) => l.status === TxStatus.CONFIRMED)
    .reduce((sum, l) => sum + signedDelta(l.type, l.quantity), 0);
}

/**
 * Given confirmed movements in confirmation order (oldest first), returns the
 * stock balance right after each one.
 */
export function runningBalances(
  movements: { type: TxType; quantity: number }[],
): number[] {
  let balance = 0;
  return movements.map((m) => (balance += signedDelta(m.type, m.quantity)));
}

export function canTransition(from: TxStatus, to: TxStatus): boolean {
  return (
    from === TxStatus.DRAFT &&
    (to === TxStatus.CONFIRMED || to === TxStatus.CANCELLED)
  );
}
