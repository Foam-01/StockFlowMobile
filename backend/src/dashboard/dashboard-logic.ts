import { TxType } from '@prisma/client';

export interface DayFlow {
  /** Local calendar date, YYYY-MM-DD. */
  date: string;
  received: number;
  issued: number;
}

/** YYYY-MM-DD of `d` in a zone `offsetMinutes` ahead of UTC. */
export function localDate(d: Date, offsetMinutes: number): string {
  return new Date(d.getTime() + offsetMinutes * 60_000)
    .toISOString()
    .slice(0, 10);
}

/**
 * Units received and issued per local day for the last `days` days
 * (oldest first, today last). Days with no movement are zero, not missing.
 * ADJUST is excluded: it is a correction, not goods flowing in or out.
 */
export function dailyFlow(
  lines: { type: TxType; quantity: number; confirmedAt: Date }[],
  {
    days,
    now,
    offsetMinutes,
  }: { days: number; now: Date; offsetMinutes: number },
): DayFlow[] {
  const buckets = new Map<string, DayFlow>();
  for (let i = days - 1; i >= 0; i--) {
    const date = localDate(
      new Date(now.getTime() - i * 86_400_000),
      offsetMinutes,
    );
    buckets.set(date, { date, received: 0, issued: 0 });
  }
  for (const l of lines) {
    const b = buckets.get(localDate(l.confirmedAt, offsetMinutes));
    if (!b) continue;
    if (l.type === TxType.RECEIVE) b.received += l.quantity;
    if (l.type === TxType.ISSUE) b.issued += l.quantity;
  }
  return [...buckets.values()];
}

/** Lower = more urgent. Out of stock first, then by how far below minimum. */
export function stockUrgency(p: { onHand: number; minStock: number }): number {
  if (p.onHand <= 0) return -1;
  return p.minStock > 0 ? p.onHand / p.minStock : Number.POSITIVE_INFINITY;
}
