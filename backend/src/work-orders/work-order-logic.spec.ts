import { Role, WorkOrderStatus } from '@prisma/client';
import {
  Actor,
  allowedActions,
  can,
  canView,
  issuedByProduct,
  submissionProblems,
  TRANSITIONS,
  WorkOrderFacts,
  workOrderCode,
} from './work-order-logic.js';

const admin: Actor = { id: 'admin', role: Role.ADMIN };
const staff: Actor = { id: 'staff', role: Role.STAFF };
const tech: Actor = { id: 'tech', role: Role.TECHNICIAN };
const otherTech: Actor = { id: 'tech2', role: Role.TECHNICIAN };
const sup: Actor = { id: 'sup', role: Role.SUPERVISOR };
const otherSup: Actor = { id: 'sup2', role: Role.SUPERVISOR };

const wo = (
  status: WorkOrderStatus,
  extra: Partial<WorkOrderFacts> = {},
): WorkOrderFacts => ({
  status,
  assigneeId: 'tech',
  reviewerId: null,
  ...extra,
});

describe('canView', () => {
  it('technicians only see their own work orders', () => {
    expect(canView(tech, wo('OPEN'))).toBe(true);
    expect(canView(otherTech, wo('OPEN'))).toBe(false);
    expect(canView(tech, wo('OPEN', { assigneeId: null }))).toBe(false);
  });

  it('admin, staff and supervisors see all', () => {
    for (const a of [admin, staff, sup])
      expect(canView(a, wo('OPEN'))).toBe(true);
  });
});

describe('can: who does what in which state', () => {
  it('only the assigned technician starts, works and submits', () => {
    expect(can(tech, 'start', wo('OPEN'))).toBe(true);
    expect(can(otherTech, 'start', wo('OPEN'))).toBe(false);
    expect(can(admin, 'start', wo('OPEN'))).toBe(false);
    expect(can(tech, 'updateChecklist', wo('IN_PROGRESS'))).toBe(true);
    expect(can(tech, 'manageEvidence', wo('IN_PROGRESS'))).toBe(true);
    expect(can(tech, 'submit', wo('IN_PROGRESS'))).toBe(true);
  });

  it('work can only change while IN_PROGRESS', () => {
    for (const s of [
      'OPEN',
      'SUBMITTED',
      'NEEDS_REVISION',
      'APPROVED',
      'CANCELLED',
    ] as const) {
      expect(can(tech, 'updateChecklist', wo(s))).toBe(false);
      expect(can(tech, 'manageEvidence', wo(s))).toBe(false);
      expect(can(tech, 'submit', wo(s))).toBe(false);
    }
  });

  it('resuming after changes were requested', () => {
    expect(can(tech, 'start', wo('NEEDS_REVISION'))).toBe(true);
    expect(can(tech, 'start', wo('IN_PROGRESS'))).toBe(false);
  });

  it('review by any supervisor, or only the named one', () => {
    expect(can(sup, 'approve', wo('SUBMITTED'))).toBe(true);
    expect(can(admin, 'approve', wo('SUBMITTED'))).toBe(true);
    expect(can(tech, 'approve', wo('SUBMITTED'))).toBe(false);
    expect(can(staff, 'approve', wo('SUBMITTED'))).toBe(false);
    const named = wo('SUBMITTED', { reviewerId: 'sup' });
    expect(can(sup, 'requestChanges', named)).toBe(true);
    expect(can(otherSup, 'requestChanges', named)).toBe(false);
    expect(can(sup, 'approve', wo('IN_PROGRESS'))).toBe(false);
  });

  it('only admin assigns and cancels, never terminal or submitted work', () => {
    expect(can(admin, 'assign', wo('OPEN'))).toBe(true);
    expect(can(admin, 'assign', wo('SUBMITTED'))).toBe(false);
    expect(can(admin, 'assign', wo('APPROVED'))).toBe(false);
    expect(can(sup, 'assign', wo('OPEN'))).toBe(false);
    expect(can(admin, 'cancel', wo('IN_PROGRESS'))).toBe(true);
    expect(can(admin, 'cancel', wo('SUBMITTED'))).toBe(false);
    expect(can(admin, 'cancel', wo('APPROVED'))).toBe(false);
    expect(can(tech, 'cancel', wo('OPEN'))).toBe(false);
  });

  it('terminal states allow nothing', () => {
    for (const a of [admin, tech, sup]) {
      expect(allowedActions(a, wo('APPROVED'))).toEqual([]);
      expect(allowedActions(a, wo('CANCELLED'))).toEqual([]);
    }
  });

  it('allowedActions matches can()', () => {
    expect(allowedActions(tech, wo('IN_PROGRESS'))).toEqual([
      'updateChecklist',
      'manageEvidence',
      'submit',
    ]);
    expect(allowedActions(otherTech, wo('IN_PROGRESS'))).toEqual([]);
  });
});

describe('TRANSITIONS', () => {
  it('matches the documented state machine', () => {
    expect(TRANSITIONS.start).toEqual({
      from: ['OPEN', 'NEEDS_REVISION'],
      to: 'IN_PROGRESS',
    });
    expect(TRANSITIONS.submit).toEqual({
      from: ['IN_PROGRESS'],
      to: 'SUBMITTED',
    });
    expect(TRANSITIONS.approve).toEqual({
      from: ['SUBMITTED'],
      to: 'APPROVED',
    });
    expect(TRANSITIONS.requestChanges).toEqual({
      from: ['SUBMITTED'],
      to: 'NEEDS_REVISION',
    });
    expect(TRANSITIONS.cancel.to).toBe('CANCELLED');
  });
});

describe('submissionProblems', () => {
  const checklist = [
    { title: 'Mount unit', required: true, done: true },
    { title: 'Test airflow', required: true, done: false },
    { title: 'Tidy area', required: false, done: false },
  ];

  it('lists unfinished required items and missing photo categories', () => {
    expect(
      submissionProblems(
        checklist,
        ['BEFORE', 'AFTER'],
        [{ category: 'BEFORE' }],
      ),
    ).toEqual([
      'Checklist: "Test airflow" is not done',
      'Photo required: after work',
    ]);
  });

  it('optional items and OTHER photos do not count', () => {
    const done = checklist.map((c) => ({ ...c, done: c.required }));
    expect(
      submissionProblems(done, ['AFTER'], [{ category: 'OTHER' }]),
    ).toEqual(['Photo required: after work']);
    expect(
      submissionProblems(done, ['AFTER'], [{ category: 'AFTER' }]),
    ).toEqual([]);
  });
});

describe('issuedByProduct', () => {
  it('counts confirmed issues minus returns, ignoring drafts and cancelled', () => {
    const issued = issuedByProduct([
      {
        type: 'ISSUE',
        status: 'CONFIRMED',
        items: [{ productId: 'a', quantity: 5 }],
      },
      {
        type: 'ISSUE',
        status: 'DRAFT',
        items: [{ productId: 'a', quantity: 100 }],
      },
      {
        type: 'ISSUE',
        status: 'CANCELLED',
        items: [{ productId: 'a', quantity: 100 }],
      },
      {
        type: 'RECEIVE',
        status: 'CONFIRMED',
        items: [{ productId: 'a', quantity: 2 }],
      },
      {
        type: 'ISSUE',
        status: 'CONFIRMED',
        items: [{ productId: 'b', quantity: 1 }],
      },
    ]);
    expect(issued.get('a')).toBe(3);
    expect(issued.get('b')).toBe(1);
  });
});

it('formats work-order codes', () => {
  expect(workOrderCode(42)).toBe('WO-00042');
});
