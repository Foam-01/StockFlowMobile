import { WorkOrderEventType as E } from '@prisma/client';
import { describe, expect, it } from 'vitest';
import { NOTIFYING_EVENTS, recipientsFor } from './notification-rules.js';

const base = {
  actorId: 'admin',
  assigneeId: 'tech',
  reviewerId: null,
  supervisorIds: ['sup1', 'sup2'],
};

describe('recipientsFor', () => {
  it('tells the technician about assignment and decisions', () => {
    for (const t of [
      E.ASSIGNED,
      E.CHANGES_REQUESTED,
      E.APPROVED,
      E.CANCELLED,
    ]) {
      expect(recipientsFor(t, base)).toEqual(['tech']);
    }
  });

  it('sends submissions to the named reviewer only', () => {
    expect(
      recipientsFor(E.SUBMITTED, {
        ...base,
        actorId: 'tech',
        reviewerId: 'sup2',
      }),
    ).toEqual(['sup2']);
  });

  it('sends submissions to every supervisor when no reviewer is named', () => {
    expect(recipientsFor(E.SUBMITTED, { ...base, actorId: 'tech' })).toEqual([
      'sup1',
      'sup2',
    ]);
  });

  it('never notifies the person who acted', () => {
    expect(recipientsFor(E.CANCELLED, { ...base, actorId: 'tech' })).toEqual(
      [],
    );
  });

  it('skips unassigned jobs and quiet events', () => {
    expect(recipientsFor(E.ASSIGNED, { ...base, assigneeId: null })).toEqual(
      [],
    );
    expect(recipientsFor(E.STARTED, base)).toEqual([]);
    expect(NOTIFYING_EVENTS.has(E.CHECKLIST_UPDATED)).toBe(false);
  });
});
