import { EvidenceCategory, Role, WorkOrderStatus } from '@prisma/client';

/**
 * Work-order rules as pure functions: who may do what, which transitions
 * exist, and what a submission needs. No Nest/Prisma here, so every rule is
 * unit-testable; the service only loads data and applies the result.
 */

export interface Actor {
  id: string;
  role: Role;
}

/** The fields the rules look at. */
export interface WorkOrderFacts {
  status: WorkOrderStatus;
  assigneeId: string | null;
  reviewerId: string | null;
}

export type WorkOrderAction =
  | 'assign'
  | 'start'
  | 'updateChecklist'
  | 'manageEvidence'
  | 'submit'
  | 'approve'
  | 'requestChanges'
  | 'cancel';

const { OPEN, IN_PROGRESS, SUBMITTED, NEEDS_REVISION, APPROVED, CANCELLED } =
  WorkOrderStatus;

/** Which statuses each state-changing action may start from, and where it goes. */
export const TRANSITIONS = {
  start: { from: [OPEN, NEEDS_REVISION], to: IN_PROGRESS },
  submit: { from: [IN_PROGRESS], to: SUBMITTED },
  approve: { from: [SUBMITTED], to: APPROVED },
  requestChanges: { from: [SUBMITTED], to: NEEDS_REVISION },
  cancel: { from: [OPEN, IN_PROGRESS, NEEDS_REVISION], to: CANCELLED },
} as const satisfies Record<
  string,
  { from: readonly WorkOrderStatus[]; to: WorkOrderStatus }
>;

export type TransitionName = keyof typeof TRANSITIONS;

export const TERMINAL: readonly WorkOrderStatus[] = [APPROVED, CANCELLED];

/** Visibility: technicians only see work assigned to them. */
export function canView(actor: Actor, wo: Pick<WorkOrderFacts, 'assigneeId'>) {
  switch (actor.role) {
    case Role.ADMIN:
    case Role.SUPERVISOR:
    case Role.STAFF:
      return true;
    case Role.TECHNICIAN:
      return wo.assigneeId === actor.id;
    default:
      return false; // deny by default
  }
}

const isAssignee = (actor: Actor, wo: WorkOrderFacts) =>
  actor.role === Role.TECHNICIAN && wo.assigneeId === actor.id;

const isReviewer = (actor: Actor, wo: WorkOrderFacts) =>
  actor.role === Role.ADMIN ||
  (actor.role === Role.SUPERVISOR &&
    (wo.reviewerId === null || wo.reviewerId === actor.id));

/**
 * Whether `actor` may perform `action` on `wo` right now: role, ownership
 * and current status together. The single source of truth for both the API
 * checks and the `allowedActions` sent to the app.
 */
export function can(
  actor: Actor,
  action: WorkOrderAction,
  wo: WorkOrderFacts,
): boolean {
  if (!canView(actor, wo)) return false;
  const s = wo.status;
  switch (action) {
    case 'assign':
      return (
        actor.role === Role.ADMIN && !TERMINAL.includes(s) && s !== SUBMITTED
      );
    case 'cancel':
      return (
        actor.role === Role.ADMIN &&
        TRANSITIONS.cancel.from.includes(s as never)
      );
    case 'start':
      return (
        isAssignee(actor, wo) && TRANSITIONS.start.from.includes(s as never)
      );
    case 'updateChecklist':
    case 'manageEvidence':
      return isAssignee(actor, wo) && s === IN_PROGRESS;
    case 'submit':
      return isAssignee(actor, wo) && s === IN_PROGRESS;
    case 'approve':
    case 'requestChanges':
      return isReviewer(actor, wo) && s === SUBMITTED;
  }
}

export function allowedActions(
  actor: Actor,
  wo: WorkOrderFacts,
): WorkOrderAction[] {
  const all: WorkOrderAction[] = [
    'assign',
    'start',
    'updateChecklist',
    'manageEvidence',
    'submit',
    'approve',
    'requestChanges',
    'cancel',
  ];
  return all.filter((a) => can(actor, a, wo));
}

/**
 * What still blocks submission: unfinished required checklist items and
 * missing required photo categories. Empty list = ready to submit.
 */
export function submissionProblems(
  checklist: { title: string; required: boolean; done: boolean }[],
  requiredEvidence: EvidenceCategory[],
  evidence: { category: EvidenceCategory }[],
): string[] {
  const problems: string[] = [];
  for (const item of checklist) {
    if (item.required && !item.done)
      problems.push(`Checklist: "${item.title}" is not done`);
  }
  for (const category of new Set(requiredEvidence)) {
    if (!evidence.some((e) => e.category === category)) {
      problems.push(`Photo required: ${category.toLowerCase()} work`);
    }
  }
  return problems;
}

/** Human-readable code shown in the app: WO-00042. */
export const workOrderCode = (n: number) => `WO-${String(n).padStart(5, '0')}`;

/**
 * Issued quantity per product from documents linked to the work order:
 * confirmed ISSUE adds, confirmed RECEIVE (a return) subtracts.
 */
export function issuedByProduct(
  docs: {
    type: 'RECEIVE' | 'ISSUE' | 'ADJUST';
    status: 'DRAFT' | 'CONFIRMED' | 'CANCELLED';
    items: { productId: string; quantity: number }[];
  }[],
): Map<string, number> {
  const issued = new Map<string, number>();
  for (const d of docs) {
    if (d.status !== 'CONFIRMED') continue;
    const sign = d.type === 'ISSUE' ? 1 : d.type === 'RECEIVE' ? -1 : 0;
    for (const i of d.items) {
      issued.set(
        i.productId,
        (issued.get(i.productId) ?? 0) + sign * i.quantity,
      );
    }
  }
  return issued;
}
