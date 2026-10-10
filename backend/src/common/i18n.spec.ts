import { describe, expect, it } from 'vitest';
import { toThai, wantsThai } from './i18n.js';

describe('toThai', () => {
  it('translates fixed messages', () => {
    expect(toThai('Work order not found')).toBe('ไม่พบใบงาน');
  });

  it('translates messages with values', () => {
    expect(toThai('Checklist: "Clean filters" is not done')).toBe(
      'เช็กลิสต์ “Clean filters” ยังไม่เสร็จ',
    );
    expect(toThai('Photo required: after work')).toBe('ต้องมีรูปหลังทำงาน');
    expect(toThai('Work order is needs revision; cannot approve')).toBe(
      'ใบงานอยู่ในสถานะ “ต้องแก้ไข” จึงอนุมัติไม่ได้',
    );
    expect(
      toThai('Insufficient stock for product abc: on hand 2, requested 5'),
    ).toBe('สต็อกไม่พอ: คงเหลือ 2 แต่ต้องการ 5');
  });

  it('leaves unknown messages unchanged', () => {
    expect(toThai('quantity must be a positive number')).toBe(
      'quantity must be a positive number',
    );
  });
});

describe('wantsThai', () => {
  it('reads the primary language only', () => {
    expect(wantsThai('th')).toBe(true);
    expect(wantsThai('th-TH,en;q=0.8')).toBe(true);
    expect(wantsThai('en-US,th;q=0.5')).toBe(false);
    expect(wantsThai(undefined)).toBe(false);
  });
});
