import { TxType } from '@prisma/client';
import { dailyFlow, localDate, stockUrgency } from './dashboard-logic.js';

const BKK = 7 * 60; // Asia/Bangkok, UTC+7

describe('localDate', () => {
  it('shifts into the local day', () => {
    // 18:30 UTC on the 9th is 01:30 on the 10th in Bangkok
    expect(localDate(new Date('2026-10-09T18:30:00Z'), BKK)).toBe('2026-10-10');
    expect(localDate(new Date('2026-10-09T16:59:00Z'), BKK)).toBe('2026-10-09');
  });
});

describe('dailyFlow', () => {
  const now = new Date('2026-10-09T05:00:00Z'); // 12:00 in Bangkok

  it('returns one zero-filled bucket per day, oldest first', () => {
    const flow = dailyFlow([], { days: 3, now, offsetMinutes: BKK });
    expect(flow).toEqual([
      { date: '2026-10-07', received: 0, issued: 0 },
      { date: '2026-10-08', received: 0, issued: 0 },
      { date: '2026-10-09', received: 0, issued: 0 },
    ]);
  });

  it('sums receive and issue by local day and ignores adjust', () => {
    const flow = dailyFlow(
      [
        {
          type: TxType.RECEIVE,
          quantity: 30,
          confirmedAt: new Date('2026-10-09T01:00:00Z'),
        },
        {
          type: TxType.RECEIVE,
          quantity: 5,
          confirmedAt: new Date('2026-10-09T02:00:00Z'),
        },
        {
          type: TxType.ISSUE,
          quantity: 4,
          confirmedAt: new Date('2026-10-09T03:00:00Z'),
        },
        {
          type: TxType.ADJUST,
          quantity: -2,
          confirmedAt: new Date('2026-10-09T03:00:00Z'),
        },
        // 23:30 on the 7th in Bangkok
        {
          type: TxType.ISSUE,
          quantity: 7,
          confirmedAt: new Date('2026-10-07T16:30:00Z'),
        },
      ],
      { days: 3, now, offsetMinutes: BKK },
    );
    expect(flow[0]).toEqual({ date: '2026-10-07', received: 0, issued: 7 });
    expect(flow[2]).toEqual({ date: '2026-10-09', received: 35, issued: 4 });
  });

  it('drops movements outside the window', () => {
    const flow = dailyFlow(
      [
        {
          type: TxType.RECEIVE,
          quantity: 9,
          confirmedAt: new Date('2026-09-01T00:00:00Z'),
        },
      ],
      { days: 7, now, offsetMinutes: BKK },
    );
    expect(flow.every((d) => d.received === 0)).toBe(true);
  });
});

describe('stockUrgency', () => {
  it('ranks out of stock first, then lowest ratio to minimum', () => {
    const items = [
      { id: 'ok', onHand: 50, minStock: 10 },
      { id: 'low', onHand: 2, minStock: 10 },
      { id: 'out', onHand: 0, minStock: 5 },
      { id: 'half', onHand: 5, minStock: 10 },
    ];
    expect(
      [...items]
        .sort((a, b) => stockUrgency(a) - stockUrgency(b))
        .map((i) => i.id),
    ).toEqual(['out', 'low', 'half', 'ok']);
  });
});
