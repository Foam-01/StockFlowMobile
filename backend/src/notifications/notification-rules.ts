import { WorkOrderEventType as E } from '@prisma/client';

/** Event types that produce an in-app notification. */
export const NOTIFYING_EVENTS: ReadonlySet<E> = new Set([
  E.ASSIGNED,
  E.SUBMITTED,
  E.CHANGES_REQUESTED,
  E.APPROVED,
  E.CANCELLED,
]);

export interface Audience {
  actorId: string;
  assigneeId: string | null;
  reviewerId: string | null;
  /** All supervisors; only needed when a job without a reviewer is submitted. */
  supervisorIds: string[];
}

/**
 * Who hears about an event. Never the person who caused it.
 *
 * - assigned / changes requested / approved / cancelled → the technician
 * - submitted → the named reviewer, or every supervisor if none
 */
export function recipientsFor(type: E, a: Audience): string[] {
  let ids: (string | null)[] = [];
  switch (type) {
    case E.ASSIGNED:
    case E.CHANGES_REQUESTED:
    case E.APPROVED:
    case E.CANCELLED:
      ids = [a.assigneeId];
      break;
    case E.SUBMITTED:
      ids = a.reviewerId ? [a.reviewerId] : a.supervisorIds;
      break;
    default:
      ids = [];
  }
  return [
    ...new Set(ids.filter((id): id is string => !!id && id !== a.actorId)),
  ];
}
