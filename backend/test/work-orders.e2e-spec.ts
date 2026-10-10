import { randomUUID } from 'node:crypto';
import {
  auth,
  createTestApp,
  createTx,
  onHand,
  productWithStock,
  TestContext,
  Who,
} from './helpers.js';

let ctx: TestContext;
let templateId: string;

beforeAll(async () => {
  ctx = await createTestApp();
  const t = await ctx.prisma.checklistTemplate.create({
    data: {
      name: 'AC install',
      items: {
        create: [
          { title: 'Mount indoor unit', required: true, position: 1 },
          { title: 'Test airflow', required: true, position: 2 },
          { title: 'Tidy area', required: false, position: 3 },
        ],
      },
    },
  });
  templateId = t.id;
});
afterAll(async () => {
  await ctx?.app.close();
});

const http = (
  who: Who,
  method: 'get' | 'post' | 'put' | 'patch' | 'delete',
  path: string,
) => auth(ctx, who, ctx.http()[method](path));

/** Creates a work order assigned to `tech`, optionally with materials. */
async function workOrder(
  extra: Record<string, unknown> = {},
): Promise<{ id: string; [k: string]: any }> {
  const res = await http('admin', 'post', '/work-orders')
    .send({
      title: 'Install AC',
      siteName: 'Test site',
      templateId,
      assigneeId: ctx.ids.tech,
      requiredEvidence: ['AFTER'],
      ...extra,
    })
    .expect(201);
  return res.body;
}

const photo = (woId: string, category = 'AFTER') => {
  const publicId = `stockflow/work-orders/${woId}/${randomUUID().slice(0, 8)}`;
  return {
    category,
    publicId,
    url: `https://res.cloudinary.com/e2e-cloud/image/upload/v1/${publicId}.jpg`,
  };
};

/** Takes a fresh work order to SUBMITTED the legitimate way. */
async function submitted(extra: Record<string, unknown> = {}) {
  const wo = await workOrder(extra);
  await http('tech', 'post', `/work-orders/${wo.id}/start`).expect(200);
  for (const item of wo.checklist.filter((i: any) => i.required)) {
    await http('tech', 'put', `/work-orders/${wo.id}/checklist/${item.id}`)
      .send({ done: true })
      .expect(200);
  }
  await http('tech', 'post', `/work-orders/${wo.id}/evidence`)
    .send(photo(wo.id))
    .expect(201);
  const res = await http('tech', 'post', `/work-orders/${wo.id}/submit`).expect(
    200,
  );
  expect(res.body.status).toBe('SUBMITTED');
  return wo;
}

const events = async (id: string) =>
  (await http('admin', 'get', `/work-orders/${id}/events`).expect(200))
    .body as {
    type: string;
    note: string | null;
  }[];

describe('creating', () => {
  it('admin creates with a checklist snapshot, materials and a code', async () => {
    const p = await productWithStock(ctx, 10);
    const wo = await workOrder({
      materials: [{ productId: p.id, plannedQty: 3 }],
    });

    expect(wo.status).toBe('OPEN');
    expect(wo.code).toMatch(/^WO-\d{5}$/);
    expect(wo.checklist.map((i: any) => i.title)).toEqual([
      'Mount indoor unit',
      'Test airflow',
      'Tidy area',
    ]);
    expect(wo.materials[0]).toMatchObject({
      plannedQty: 3,
      issuedQty: 0,
      remainingQty: 3,
      shortage: 0,
    });
    expect((await events(wo.id)).map((e) => e.type)).toEqual([
      'CREATED',
      'ASSIGNED',
    ]);
  });

  it('the snapshot is independent of later template changes', async () => {
    const wo = await workOrder();
    await ctx.prisma.checklistTemplateItem.updateMany({
      where: { templateId, position: 1 },
      data: { title: 'Changed later' },
    });
    const now = await http('tech', 'get', `/work-orders/${wo.id}`).expect(200);
    expect(now.body.checklist[0].title).toBe('Mount indoor unit');
    await ctx.prisma.checklistTemplateItem.updateMany({
      where: { templateId, position: 1 },
      data: { title: 'Mount indoor unit' },
    });
  });

  it('only admin can create; inputs and people are validated', async () => {
    for (const who of ['staff', 'tech', 'sup'] as const) {
      await http(who, 'post', '/work-orders')
        .send({ title: 'x', siteName: 'y' })
        .expect(403);
    }
    await http('admin', 'post', '/work-orders')
      .send({ siteName: 'y' })
      .expect(400);
    await http('admin', 'post', '/work-orders')
      .send({ title: 'x', siteName: 'y', assigneeId: ctx.ids.staff })
      .expect(400); // assignee must be a technician
    await http('admin', 'post', '/work-orders')
      .send({ title: 'x', siteName: 'y', reviewerId: ctx.ids.tech })
      .expect(400); // reviewer must be a supervisor
    await http('admin', 'post', '/work-orders')
      .send({ title: 'x', siteName: 'y', status: 'APPROVED' })
      .expect(400); // can't set status directly
  });

  it('clientUuid makes create idempotent', async () => {
    const clientUuid = randomUUID();
    const a = await workOrder({ clientUuid });
    const b = await workOrder({ clientUuid });
    expect(b.id).toBe(a.id);
    expect(await ctx.prisma.workOrder.count({ where: { clientUuid } })).toBe(1);
  });
});

describe('visibility', () => {
  it('technicians only see their own; others get 404, not 403', async () => {
    const wo = await workOrder();
    await http('tech', 'get', `/work-orders/${wo.id}`).expect(200);
    await http('tech2', 'get', `/work-orders/${wo.id}`).expect(404);
    await http('tech2', 'get', `/work-orders/${wo.id}/events`).expect(404);
    await http('tech2', 'post', `/work-orders/${wo.id}/start`).expect(404);

    const list = await http('tech2', 'get', '/work-orders?limit=100').expect(
      200,
    );
    expect(list.body.items.map((w: any) => w.id)).not.toContain(wo.id);
    const mine = await http('tech', 'get', '/work-orders?limit=100').expect(
      200,
    );
    expect(
      mine.body.items.every((w: any) => w.assignee?.id === ctx.ids.tech),
    ).toBe(true);
  });

  it('staff and supervisors can view; allowedActions reflects the role', async () => {
    const wo = await workOrder();
    const asStaff = await http('staff', 'get', `/work-orders/${wo.id}`).expect(
      200,
    );
    expect(asStaff.body.allowedActions).toEqual([]);
    const asTech = await http('tech', 'get', `/work-orders/${wo.id}`).expect(
      200,
    );
    expect(asTech.body.allowedActions).toEqual(['start']);
    const asAdmin = await http('admin', 'get', `/work-orders/${wo.id}`).expect(
      200,
    );
    expect(asAdmin.body.allowedActions).toEqual(['assign', 'cancel']);
  });

  it('reassigning moves access to the new technician', async () => {
    const wo = await workOrder();
    await http('admin', 'patch', `/work-orders/${wo.id}/assignment`)
      .send({ assigneeId: ctx.ids.tech2 })
      .expect(200);
    await http('tech', 'get', `/work-orders/${wo.id}`).expect(404);
    await http('tech2', 'get', `/work-orders/${wo.id}`).expect(200);
    await http('sup', 'patch', `/work-orders/${wo.id}/assignment`)
      .send({ assigneeId: ctx.ids.tech })
      .expect(403);
  });

  it('search finds by code and site', async () => {
    const wo = await workOrder({ siteName: 'Unique Plaza 77' });
    const byCode = await http(
      'admin',
      'get',
      `/work-orders?q=${wo.code}`,
    ).expect(200);
    expect(byCode.body.items.map((w: any) => w.id)).toEqual([wo.id]);
    const bySite = await http('admin', 'get', '/work-orders?q=plaza 77').expect(
      200,
    );
    expect(bySite.body.items.map((w: any) => w.id)).toContain(wo.id);
  });
});

describe('doing the work', () => {
  it('starting never touches stock', async () => {
    const p = await productWithStock(ctx, 10);
    const wo = await workOrder({
      materials: [{ productId: p.id, plannedQty: 4 }],
    });
    await http('tech', 'post', `/work-orders/${wo.id}/start`).expect(200);
    expect(await onHand(ctx, p.id)).toBe(10);
  });

  it('start is idempotent (one STARTED event)', async () => {
    const wo = await workOrder();
    await http('tech', 'post', `/work-orders/${wo.id}/start`).expect(200);
    await http('tech', 'post', `/work-orders/${wo.id}/start`).expect(200);
    expect(
      (await events(wo.id)).filter((e) => e.type === 'STARTED'),
    ).toHaveLength(1);
  });

  it('only the assignee works on it, and only while in progress', async () => {
    const wo = await workOrder();
    const item = wo.checklist[0].id;
    const path = `/work-orders/${wo.id}/checklist/${item}`;

    await http('tech', 'put', path).send({ done: true }).expect(409); // not started
    await http('tech', 'post', `/work-orders/${wo.id}/start`).expect(200);
    await http('sup', 'put', path).send({ done: true }).expect(403);
    await http('admin', 'put', path).send({ done: true }).expect(403);
    await http('tech', 'put', `/work-orders/${wo.id}/checklist/${randomUUID()}`)
      .send({ done: true })
      .expect(404);

    const res = await http('tech', 'put', path)
      .send({ done: true, note: 'Bracket OK' })
      .expect(200);
    expect(res.body.checklist[0]).toMatchObject({
      done: true,
      note: 'Bracket OK',
    });
    expect(res.body.checklist[0].completedBy.id).toBe(ctx.ids.tech);
  });

  it('checklist items of another work order are rejected', async () => {
    const a = await workOrder();
    const b = await workOrder();
    await http('tech', 'post', `/work-orders/${a.id}/start`).expect(200);
    await http(
      'tech',
      'put',
      `/work-orders/${a.id}/checklist/${b.checklist[0].id}`,
    )
      .send({ done: true })
      .expect(404);
  });

  it('submit is refused until required items and photos are there', async () => {
    const wo = await workOrder({ requiredEvidence: ['BEFORE', 'AFTER'] });
    await http('tech', 'post', `/work-orders/${wo.id}/start`).expect(200);

    let res = await http('tech', 'post', `/work-orders/${wo.id}/submit`).expect(
      400,
    );
    expect(res.body.problems).toEqual([
      'Checklist: "Mount indoor unit" is not done',
      'Checklist: "Test airflow" is not done',
      'Photo required: before work',
      'Photo required: after work',
    ]);

    for (const i of wo.checklist.slice(0, 2)) {
      await http('tech', 'put', `/work-orders/${wo.id}/checklist/${i.id}`)
        .send({ done: true })
        .expect(200);
    }
    await http('tech', 'post', `/work-orders/${wo.id}/evidence`)
      .send(photo(wo.id, 'BEFORE'))
      .expect(201);
    res = await http('tech', 'post', `/work-orders/${wo.id}/submit`).expect(
      400,
    );
    expect(res.body.problems).toEqual(['Photo required: after work']);

    await http('tech', 'post', `/work-orders/${wo.id}/evidence`)
      .send(photo(wo.id, 'AFTER'))
      .expect(201);
    res = await http('tech', 'post', `/work-orders/${wo.id}/submit`).expect(
      200,
    );
    expect(res.body.status).toBe('SUBMITTED');
    // Submitted work is frozen.
    await http(
      'tech',
      'put',
      `/work-orders/${wo.id}/checklist/${wo.checklist[0].id}`,
    )
      .send({ done: false })
      .expect(409);
  });

  it('photos must be ours, in this work order’s folder, from the assignee', async () => {
    const wo = await workOrder();
    const other = await workOrder();
    await http('tech', 'post', `/work-orders/${wo.id}/start`).expect(200);
    const path = `/work-orders/${wo.id}/evidence`;

    await http('tech', 'post', path).send(photo(other.id)).expect(400);
    await http('tech', 'post', path)
      .send({
        ...photo(wo.id),
        url: photo(wo.id).url.replace('e2e-cloud', 'evil'),
      })
      .expect(400);
    await http('tech2', 'post', path).send(photo(wo.id)).expect(404);

    const sig = await http('tech', 'post', `${path}/signature`)
      .send({ category: 'AFTER' })
      .expect(200);
    expect(sig.body.fields).toMatchObject({
      folder: `stockflow/work-orders/${wo.id}`,
      allowed_formats: 'jpg,jpeg,png,webp,heic',
    });
    expect(JSON.stringify(sig.body)).not.toContain('e2e-secret');

    const saved = await http('tech', 'post', path)
      .send(photo(wo.id))
      .expect(201);
    expect(saved.body.evidence).toHaveLength(1);
  });
});

describe('review', () => {
  it('only reviewers approve; approval is recorded once', async () => {
    const wo = await submitted();
    for (const who of ['staff', 'tech', 'tech2'] as const) {
      // Role check on the endpoint: 403 for every non-reviewer role.
      await http(who, 'post', `/work-orders/${wo.id}/approve`)
        .send({})
        .expect(403);
    }
    const res = await http('sup', 'post', `/work-orders/${wo.id}/approve`)
      .send({ note: 'Good job' })
      .expect(200);
    expect(res.body).toMatchObject({
      status: 'APPROVED',
      reviewedBy: { id: ctx.ids.sup },
    });
    expect(res.body.reviewedAt).toBeTruthy();

    await http('sup', 'post', `/work-orders/${wo.id}/approve`)
      .send({})
      .expect(200); // repeat
    const approvals = (await events(wo.id)).filter(
      (e) => e.type === 'APPROVED',
    );
    expect(approvals).toHaveLength(1);
    expect(approvals[0].note).toBe('Good job');

    // Terminal: no more changes.
    await http('sup', 'post', `/work-orders/${wo.id}/request-changes`)
      .send({ reason: 'Too late now' })
      .expect(409);
    await http('admin', 'post', `/work-orders/${wo.id}/cancel`)
      .send({ reason: 'Too late now' })
      .expect(409);
  });

  it('a named reviewer is the only supervisor who may decide', async () => {
    const wo = await submitted({ reviewerId: ctx.ids.sup2 });
    await http('sup', 'post', `/work-orders/${wo.id}/approve`)
      .send({})
      .expect(403);
    await http('sup2', 'post', `/work-orders/${wo.id}/approve`)
      .send({})
      .expect(200);
  });

  it('request changes needs a reason, then the technician resumes and resubmits', async () => {
    const wo = await submitted();
    await http('sup', 'post', `/work-orders/${wo.id}/request-changes`)
      .send({})
      .expect(400);
    await http('sup', 'post', `/work-orders/${wo.id}/request-changes`)
      .send({ reason: 'ok' })
      .expect(400);

    const res = await http(
      'sup',
      'post',
      `/work-orders/${wo.id}/request-changes`,
    )
      .send({ reason: 'After photo is blurry' })
      .expect(200);
    expect(res.body).toMatchObject({
      status: 'NEEDS_REVISION',
      reviewNote: 'After photo is blurry',
    });

    // Can't approve work that was sent back without it being resubmitted.
    await http('sup', 'post', `/work-orders/${wo.id}/approve`)
      .send({})
      .expect(409);

    await http('tech', 'post', `/work-orders/${wo.id}/start`).expect(200);
    await http('tech', 'post', `/work-orders/${wo.id}/evidence`)
      .send(photo(wo.id))
      .expect(201);
    await http('tech', 'post', `/work-orders/${wo.id}/submit`).expect(200);
    await http('sup', 'post', `/work-orders/${wo.id}/approve`)
      .send({})
      .expect(200);

    const types = (await events(wo.id)).map((e) => e.type);
    expect(types).toEqual([
      'CREATED',
      'ASSIGNED',
      'STARTED',
      'CHECKLIST_UPDATED',
      'CHECKLIST_UPDATED',
      'EVIDENCE_ADDED',
      'SUBMITTED',
      'CHANGES_REQUESTED',
      'STARTED',
      'EVIDENCE_ADDED',
      'SUBMITTED',
      'APPROVED',
    ]);
  });

  it('concurrent approvals apply once', async () => {
    const wo = await submitted();
    const results = await Promise.all(
      Array.from({ length: 5 }, () =>
        http('sup', 'post', `/work-orders/${wo.id}/approve`).send({}),
      ),
    );
    expect(results.every((r) => r.status === 200)).toBe(true);
    expect(
      (await events(wo.id)).filter((e) => e.type === 'APPROVED'),
    ).toHaveLength(1);
  });

  it('approve racing request-changes: exactly one decision wins', async () => {
    const wo = await submitted();
    const [a, b] = await Promise.all([
      http('sup', 'post', `/work-orders/${wo.id}/approve`).send({}),
      http('sup2', 'post', `/work-orders/${wo.id}/request-changes`).send({
        reason: 'Missing label',
      }),
    ]);
    expect([a.status, b.status].sort()).toEqual([200, 409]);
    const decisions = (await events(wo.id)).filter((e) =>
      ['APPROVED', 'CHANGES_REQUESTED'].includes(e.type),
    );
    expect(decisions).toHaveLength(1);
  });
});

describe('cancelling', () => {
  it('admin only, with a reason; never after submission', async () => {
    const wo = await workOrder();
    await http('tech', 'post', `/work-orders/${wo.id}/cancel`)
      .send({ reason: 'No longer needed' })
      .expect(403);
    await http('admin', 'post', `/work-orders/${wo.id}/cancel`)
      .send({})
      .expect(400);
    const res = await http('admin', 'post', `/work-orders/${wo.id}/cancel`)
      .send({ reason: 'Customer cancelled' })
      .expect(200);
    expect(res.body).toMatchObject({
      status: 'CANCELLED',
      cancelReason: 'Customer cancelled',
    });
    await http('tech', 'post', `/work-orders/${wo.id}/start`).expect(409);

    const sub = await submitted();
    await http('admin', 'post', `/work-orders/${sub.id}/cancel`)
      .send({ reason: 'Customer cancelled' })
      .expect(409);
  });
});

describe('inventory link', () => {
  it('materials are issued with a confirmed ISSUE document, recorded on the work order', async () => {
    const p = await productWithStock(ctx, 10);
    const wo = await workOrder({
      materials: [{ productId: p.id, plannedQty: 4 }],
    });

    const draft = await createTx(ctx, 'staff', 'ISSUE', p.id, 3, {
      workOrderId: wo.id,
      referenceNo: 'REQ-9',
    });
    expect(await onHand(ctx, p.id)).toBe(10); // draft: no effect
    await http('admin', 'post', `/transactions/${draft.id}/confirm`).expect(
      200,
    );
    expect(await onHand(ctx, p.id)).toBe(7);

    const detail = await http('tech', 'get', `/work-orders/${wo.id}`).expect(
      200,
    );
    expect(detail.body.materials[0]).toMatchObject({
      plannedQty: 4,
      issuedQty: 3,
      remainingQty: 1,
    });
    expect(detail.body.stockTransactions).toHaveLength(1);
    const issued = (await events(wo.id)).find(
      (e) => e.type === 'MATERIAL_ISSUED',
    );
    expect(issued?.note).toMatch(/^Issued 3 × T-.* \(REQ-9\)$/);
  });

  it('shortage is shown when stock cannot cover what is still needed', async () => {
    const p = await productWithStock(ctx, 2);
    const wo = await workOrder({
      materials: [{ productId: p.id, plannedQty: 5 }],
    });
    const detail = await http('admin', 'get', `/work-orders/${wo.id}`).expect(
      200,
    );
    expect(detail.body.materials[0]).toMatchObject({
      remainingQty: 5,
      shortage: 3,
    });
  });

  it('cannot link to closed work orders or link adjustments', async () => {
    const p = await productWithStock(ctx, 5);
    const done = await submitted();
    await http('sup', 'post', `/work-orders/${done.id}/approve`)
      .send({})
      .expect(200);
    const res = await http('staff', 'post', '/transactions').send({
      type: 'ISSUE',
      workOrderId: done.id,
      items: [{ productId: p.id, quantity: 1 }],
    });
    expect(res.status).toBe(400);
    const open = await workOrder();
    await http('staff', 'post', '/transactions')
      .send({
        type: 'ADJUST',
        workOrderId: open.id,
        items: [{ productId: p.id, quantity: 1 }],
      })
      .expect(400);
  });
});

describe('role boundaries for the new roles', () => {
  it('technicians cannot use inventory documents or the dashboard', async () => {
    const p = await productWithStock(ctx, 5);
    await http('tech', 'post', '/transactions')
      .send({ type: 'ISSUE', items: [{ productId: p.id, quantity: 1 }] })
      .expect(403);
    await http('tech', 'get', '/transactions').expect(403);
    await http('tech', 'get', '/dashboard').expect(403);
    await http('tech', 'get', '/products').expect(200); // read-only catalogue
  });

  it('supervisors can read stock documents but not create them', async () => {
    const p = await productWithStock(ctx, 5);
    await http('sup', 'get', '/transactions').expect(200);
    await http('sup', 'post', '/transactions')
      .send({ type: 'RECEIVE', items: [{ productId: p.id, quantity: 1 }] })
      .expect(403);
  });

  it('user directory: admin only, no emails or hashes', async () => {
    await http('staff', 'get', '/users').expect(403);
    const res = await http('admin', 'get', '/users?role=TECHNICIAN').expect(
      200,
    );
    expect(res.body.map((u: any) => u.name).sort()).toEqual(['tech', 'tech2']);
    expect(Object.keys(res.body[0]).sort()).toEqual(['id', 'name', 'role']);
  });

  it('checklist templates: admin only', async () => {
    await http('tech', 'get', '/checklist-templates').expect(403);
    const res = await http('admin', 'get', '/checklist-templates').expect(200);
    expect(res.body[0].items).toHaveLength(3);
  });
});
