/**
 * Demo field-service data: installation parts in stock and one work order in
 * each status, with audit events that match the history.
 *
 * Run after `npx prisma db seed`. Re-runnable: rows from a previous run
 * (clientUuid starting with "demo-wo-") are removed first and their stock
 * effects reversed, in one transaction, so onHand always equals the ledger.
 * No photos are faked: evidence is added live in the app.
 */
import {
  Prisma,
  PrismaClient,
  TxStatus,
  TxType,
  WorkOrderEventType as E,
  WorkOrderPriority,
  WorkOrderStatus as S,
} from '@prisma/client';

import {
  NOTIFYING_EVENTS,
  recipientsFor,
} from '../src/notifications/notification-rules.js';

process.loadEnvFile?.('.env');

const prisma = new PrismaClient();
const DEMO = 'demo-wo-';
const HOUR = 3_600_000;
const ago = (h: number) => new Date(Date.now() - h * HOUR);

type Db = Prisma.TransactionClient;
const signed = (type: TxType, q: number) => (type === TxType.ISSUE ? -q : q);

async function removePrevious(db: Db) {
  const orders = await db.workOrder.findMany({
    where: { clientUuid: { startsWith: DEMO } },
    select: { id: true },
  });
  const orderIds = orders.map((o) => o.id);
  const docs = await db.stockTransaction.findMany({
    where: {
      OR: [
        { clientUuid: { startsWith: DEMO } },
        { workOrderId: { in: orderIds } },
      ],
    },
    include: { items: true },
  });
  // Undo what confirmed demo documents did to stock.
  const undo = new Map<string, number>();
  for (const d of docs) {
    if (d.status !== TxStatus.CONFIRMED) continue;
    for (const i of d.items) {
      undo.set(
        i.productId,
        (undo.get(i.productId) ?? 0) - signed(d.type, i.quantity),
      );
    }
  }
  for (const [id, delta] of undo) {
    await db.product.update({
      where: { id },
      data: { onHand: { increment: delta } },
    });
  }
  await db.stockTransaction.deleteMany({
    where: { id: { in: docs.map((d) => d.id) } },
  });
  await db.notification.deleteMany({
    where: { event: { workOrderId: { in: orderIds } } },
  });
  await db.workOrderEvent.deleteMany({
    where: { workOrderId: { in: orderIds } },
  });
  await db.workOrder.deleteMany({ where: { id: { in: orderIds } } });
}

async function main() {
  const user = (email: string) =>
    prisma.user.findUniqueOrThrow({ where: { email } });
  const [admin, staff, tech, tech2, sup] = await Promise.all([
    user('admin@stockflow.dev'),
    user('staff@stockflow.dev'),
    user('tech@stockflow.dev'),
    user('tech2@stockflow.dev'),
    user('supervisor@stockflow.dev'),
  ]).catch(() => {
    throw new Error('Run `npx prisma db seed` first (users missing)');
  });
  const tpl = (name: string) =>
    prisma.checklistTemplate.findUniqueOrThrow({
      where: { name },
      include: { items: { orderBy: { position: 'asc' } } },
    });
  const acInstall = await tpl('ติดตั้งแอร์แยกส่วน');
  const acService = await tpl('ล้างและบำรุงรักษาแอร์');
  const network = await tpl('ติดตั้งจุดแลน');
  const sku = (s: string) =>
    prisma.product.findUniqueOrThrow({ where: { sku: s } });
  const [pipe, bracket, tape, ties] = await Promise.all(
    ['INS-001', 'INS-002', 'INS-003', 'INS-004'].map(sku),
  );

  await prisma.$transaction(
    async (db) => {
      await removePrevious(db);

      // Parts arrive in the warehouse (a confirmed RECEIVE keeps the ledger true).
      const receipt: [typeof pipe, number][] = [
        [pipe, 12],
        [bracket, 8],
        [tape, 30],
        [ties, 10],
      ];
      await db.stockTransaction.create({
        data: {
          clientUuid: `${DEMO}receive`,
          type: TxType.RECEIVE,
          status: TxStatus.CONFIRMED,
          referenceNo: 'PO-PARTS-001',
          note: 'ตัวอย่าง: รับอะไหล่งานติดตั้ง',
          createdById: staff.id,
          confirmedById: admin.id,
          createdAt: ago(80),
          confirmedAt: ago(79),
          items: {
            create: receipt.map(([p, q]) => ({ productId: p.id, quantity: q })),
          },
        },
      });
      for (const [p, q] of receipt) {
        await db.product.update({
          where: { id: p.id },
          data: { onHand: { increment: q } },
        });
      }

      let n = 0;
      /** Creates a work order and replays its history as events. */
      async function order(spec: {
        title: string;
        siteName: string;
        siteAddress?: string;
        description?: string;
        priority: WorkOrderPriority;
        dueInHours: number | null;
        template: typeof acInstall;
        assignee?: typeof tech;
        status: S;
        doneItems?: number;
        requiredEvidence?: ('BEFORE' | 'AFTER')[];
        materials?: [typeof pipe, number][];
        reviewNote?: string;
        createdHoursAgo: number;
      }) {
        n++;
        const t0 = spec.createdHoursAgo;
        const started = (
          [S.IN_PROGRESS, S.SUBMITTED, S.NEEDS_REVISION, S.APPROVED] as S[]
        ).includes(spec.status);
        const submitted = (
          [S.SUBMITTED, S.NEEDS_REVISION, S.APPROVED] as S[]
        ).includes(spec.status);
        const reviewed = ([S.NEEDS_REVISION, S.APPROVED] as S[]).includes(
          spec.status,
        );
        const done = spec.doneItems ?? 0;

        const wo = await db.workOrder.create({
          data: {
            clientUuid: `${DEMO}${n}`,
            title: spec.title,
            description: spec.description,
            siteName: spec.siteName,
            siteAddress: spec.siteAddress,
            priority: spec.priority,
            status: spec.status,
            dueAt:
              spec.dueInHours === null
                ? null
                : new Date(Date.now() + spec.dueInHours * HOUR),
            requiredEvidence: spec.requiredEvidence ?? [],
            templateId: spec.template.id,
            createdById: admin.id,
            assigneeId: spec.assignee?.id,
            createdAt: ago(t0),
            startedAt: started ? ago(t0 - 2) : null,
            submittedAt: submitted ? ago(t0 - 5) : null,
            reviewedAt: reviewed ? ago(t0 - 6) : null,
            reviewedById: reviewed ? sup.id : null,
            reviewNote:
              spec.status === S.NEEDS_REVISION ? spec.reviewNote : null,
            checklist: {
              create: spec.template.items.map((i, idx) => ({
                title: i.title,
                description: i.description,
                required: i.required,
                position: i.position,
                done: idx < done,
                completedById: idx < done ? spec.assignee?.id : null,
                completedAt: idx < done ? ago(t0 - 3) : null,
              })),
            },
            materials: {
              create: (spec.materials ?? []).map(([p, q]) => ({
                productId: p.id,
                plannedQty: q,
              })),
            },
          },
        });

        const events: Prisma.WorkOrderEventCreateManyInput[] = [];
        const ev = (
          h: number,
          type: E,
          actorId: string,
          extra: Partial<Prisma.WorkOrderEventCreateManyInput> = {},
        ) =>
          events.push({
            workOrderId: wo.id,
            actorId,
            type,
            createdAt: ago(h),
            ...extra,
          });
        ev(t0, E.CREATED, admin.id, { toStatus: S.OPEN });
        if (spec.assignee) {
          ev(t0 - 0.1, E.ASSIGNED, admin.id, {
            note: `ช่าง: ${spec.assignee.name} · ผู้ตรวจ: หัวหน้างานคนใดก็ได้`,
          });
        }
        if (started)
          ev(t0 - 2, E.STARTED, spec.assignee!.id, {
            fromStatus: S.OPEN,
            toStatus: S.IN_PROGRESS,
          });
        spec.template.items.slice(0, done).forEach((i) =>
          ev(t0 - 3, E.CHECKLIST_UPDATED, spec.assignee!.id, {
            note: `เสร็จ: ${i.title}`,
          }),
        );
        if (submitted)
          ev(t0 - 5, E.SUBMITTED, spec.assignee!.id, {
            fromStatus: S.IN_PROGRESS,
            toStatus: S.SUBMITTED,
          });
        if (spec.status === S.NEEDS_REVISION) {
          ev(t0 - 6, E.CHANGES_REQUESTED, sup.id, {
            fromStatus: S.SUBMITTED,
            toStatus: S.NEEDS_REVISION,
            note: spec.reviewNote,
          });
        }
        if (spec.status === S.APPROVED) {
          ev(t0 - 6, E.APPROVED, sup.id, {
            fromStatus: S.SUBMITTED,
            toStatus: S.APPROVED,
            note: 'งานเรียบร้อย ขอบคุณครับ',
          });
        }
        await db.workOrderEvent.createMany({ data: events });
        return wo;
      }

      const inProgress = await order({
        title: 'ติดตั้งแอร์ 18,000 BTU – ห้องประชุม',
        siteName: 'อาคารสำนักงานรัชดา ชั้น 12',
        siteAddress: 'ถนนรัชดาภิเษก กรุงเทพฯ',
        description:
          'ลูกค้าต้องการติดคอยล์เย็นเหนือหน้าต่าง จอดรถได้ที่ชั้น B2',
        priority: WorkOrderPriority.HIGH,
        dueInHours: 6,
        template: acInstall,
        assignee: tech,
        status: S.IN_PROGRESS,
        doneItems: 3,
        requiredEvidence: ['BEFORE', 'AFTER'],
        materials: [
          [pipe, 1],
          [bracket, 1],
          [tape, 2],
        ],
        createdHoursAgo: 26,
      });

      // Warehouse issued the parts for it (confirmed, linked, ledger-consistent).
      const issue: [typeof pipe, number][] = [
        [pipe, 1],
        [bracket, 1],
        [tape, 2],
      ];
      await db.stockTransaction.create({
        data: {
          clientUuid: `${DEMO}issue-1`,
          type: TxType.ISSUE,
          status: TxStatus.CONFIRMED,
          referenceNo: 'REQ-WO-001',
          createdById: staff.id,
          confirmedById: admin.id,
          createdAt: ago(25),
          confirmedAt: ago(24.5),
          workOrderId: inProgress.id,
          items: {
            create: issue.map(([p, q]) => ({ productId: p.id, quantity: q })),
          },
        },
      });
      for (const [p, q] of issue) {
        await db.product.update({
          where: { id: p.id },
          data: { onHand: { decrement: q } },
        });
      }
      await db.workOrderEvent.create({
        data: {
          workOrderId: inProgress.id,
          actorId: admin.id,
          type: E.MATERIAL_ISSUED,
          note: 'เบิก INS-001 ×1, INS-002 ×1, INS-003 ×2 (REQ-WO-001)',
          createdAt: ago(24.5),
        },
      });

      await order({
        title: 'ติดตั้งแอร์ – ห้องนอน 2',
        siteName: 'หมู่บ้านบ้านสวน บ้านเลขที่ 45/7',
        priority: WorkOrderPriority.NORMAL,
        dueInHours: 30,
        template: acInstall,
        assignee: tech,
        status: S.OPEN,
        requiredEvidence: ['AFTER'],
        materials: [
          [pipe, 1],
          [bracket, 1],
          [tape, 2],
          [ties, 1],
        ],
        createdHoursAgo: 4,
      });
      await order({
        title: 'ล้างแอร์ตามรอบไตรมาส – 4 เครื่อง',
        siteName: 'ร้านกาแฟกรีนลีฟ อารีย์',
        priority: WorkOrderPriority.LOW,
        dueInHours: 72,
        template: acService,
        status: S.OPEN,
        createdHoursAgo: 2,
      });
      await order({
        title: 'เพิ่มจุดแลน 2 จุด – แผนกต้อนรับ',
        siteName: 'คลินิกสาทร',
        priority: WorkOrderPriority.NORMAL,
        dueInHours: -2,
        template: network,
        assignee: tech2,
        status: S.SUBMITTED,
        doneItems: network.items.length,
        materials: [[ties, 1]],
        createdHoursAgo: 30,
      });
      await order({
        title: 'ล้างแอร์ – ห้องเซิร์ฟเวอร์',
        siteName: 'สำนักงานคลังสินค้าบางนา',
        priority: WorkOrderPriority.URGENT,
        dueInHours: 3,
        template: acService,
        assignee: tech,
        status: S.NEEDS_REVISION,
        doneItems: acService.items.length,
        reviewNote: 'กรุณาจดค่าแรงดันน้ำยาไว้ในหมายเหตุด้วย',
        createdHoursAgo: 20,
      });
      await order({
        title: 'ติดตั้งแอร์ – ห้องผู้จัดการ',
        siteName: 'อาคารสำนักงานรัชดา ชั้น 12',
        priority: WorkOrderPriority.NORMAL,
        dueInHours: -48,
        template: acInstall,
        assignee: tech2,
        status: S.APPROVED,
        doneItems: acInstall.items.length,
        createdHoursAgo: 70,
      });
      // Inbox entries derived from the same rules the API uses.
      const supervisorIds = (
        await db.user.findMany({
          where: { role: 'SUPERVISOR' },
          select: { id: true },
        })
      ).map((u) => u.id);
      const events = await db.workOrderEvent.findMany({
        where: {
          workOrder: { clientUuid: { startsWith: DEMO } },
          type: { in: [...NOTIFYING_EVENTS] },
        },
        include: {
          workOrder: { select: { assigneeId: true, reviewerId: true } },
        },
      });
      const notices = events.flatMap((e) =>
        recipientsFor(e.type, {
          actorId: e.actorId,
          assigneeId: e.workOrder.assigneeId,
          reviewerId: e.workOrder.reviewerId,
          supervisorIds,
        }).map((userId) => ({
          userId,
          eventId: e.id,
          createdAt: e.createdAt,
          // Anything older than two days has been seen already.
          readAt: e.createdAt < ago(48) ? e.createdAt : null,
        })),
      );
      await db.notification.createMany({ data: notices });

      console.log(
        `Demo work orders: ${n} (one per status), parts received and issued, ${notices.length} notifications`,
      );
    },
    { timeout: 300_000, maxWait: 30_000 },
  );
}

main()
  .catch((e) => {
    console.error(e);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
