import { randomUUID } from 'node:crypto';
import {
  audit,
  auth,
  createTestApp,
  createTx,
  onHand,
  productWithStock,
  TestContext,
} from './helpers.js';

let ctx: TestContext;

beforeAll(async () => {
  ctx = await createTestApp();
});
afterAll(async () => {
  await ctx?.app.close();
});

const confirm = (who: keyof TestContext['tokens'], id: string) =>
  auth(ctx, who, ctx.http().post(`/transactions/${id}/confirm`));

describe('authentication', () => {
  it('rejects requests without a token', async () => {
    await ctx.http().get('/products').expect(401);
  });

  it('rejects a wrong password', async () => {
    await ctx
      .http()
      .post('/auth/login')
      .send({ email: 'admin@test.dev', password: 'nope' })
      .expect(401);
  });

  it('rejects a forged token', async () => {
    await ctx
      .http()
      .get('/auth/me')
      .set('Authorization', 'Bearer not.a.jwt')
      .expect(401);
  });

  it('leaves /health public', async () => {
    await ctx
      .http()
      .get('/health')
      .expect(200, { status: 'ok', service: 'stockflow-api' });
  });

  it('never returns the password hash', async () => {
    const res = await auth(ctx, 'staff', ctx.http().get('/auth/me')).expect(
      200,
    );
    expect(res.body.email).toBe('staff@test.dev');
    expect(res.body).not.toHaveProperty('passwordHash');
  });
});

describe('authorization (roles)', () => {
  it('STAFF cannot confirm, create products or audit', async () => {
    const p = await productWithStock(ctx, 5);
    const tx = await createTx(ctx, 'staff', 'ISSUE', p.id, 1);

    await confirm('staff', tx.id).expect(403);
    await auth(ctx, 'staff', ctx.http().post('/products'))
      .send({ sku: 'X-1', name: 'X', categoryId: p.categoryId })
      .expect(403);
    await auth(ctx, 'staff', ctx.http().get(`/products/${p.id}/audit`)).expect(
      403,
    );
    expect(await onHand(ctx, p.id)).toBe(5);
  });

  it("STAFF cannot cancel another user's draft; the creator and ADMIN can", async () => {
    const p = await productWithStock(ctx, 5);
    const a = await createTx(ctx, 'staff', 'ISSUE', p.id, 1);
    const b = await createTx(ctx, 'staff', 'ISSUE', p.id, 1);

    await auth(
      ctx,
      'staff2',
      ctx.http().post(`/transactions/${a.id}/cancel`),
    ).expect(403);
    await auth(
      ctx,
      'staff',
      ctx.http().post(`/transactions/${a.id}/cancel`),
    ).expect(200);
    await auth(
      ctx,
      'admin',
      ctx.http().post(`/transactions/${b.id}/cancel`),
    ).expect(200);
  });
});

describe('validation', () => {
  it.each([
    ['zero quantity', { type: 'ISSUE', items: [{ quantity: 0 }] }],
    ['negative receive', { type: 'RECEIVE', items: [{ quantity: -3 }] }],
    ['fractional quantity', { type: 'RECEIVE', items: [{ quantity: 1.5 }] }],
    ['no items', { type: 'RECEIVE', items: [] }],
    ['unknown type', { type: 'STEAL', items: [{ quantity: 1 }] }],
    [
      'unexpected field',
      { type: 'RECEIVE', items: [{ quantity: 1 }], onHand: 999 },
    ],
  ])('rejects %s with 400', async (_name, body) => {
    const p = await productWithStock(ctx, 0);
    const payload = {
      ...body,
      items: (body.items as object[]).map((i) => ({ productId: p.id, ...i })),
    };
    await auth(ctx, 'staff', ctx.http().post('/transactions'))
      .send(payload)
      .expect(400);
  });

  it('rejects a product that does not exist', async () => {
    await auth(ctx, 'staff', ctx.http().post('/transactions'))
      .send({
        type: 'RECEIVE',
        items: [{ productId: randomUUID(), quantity: 1 }],
      })
      .expect(400);
  });

  it('rejects malformed ids', async () => {
    await confirm('admin', 'not-a-uuid').expect(400);
  });
});

describe('stock ledger', () => {
  it('only changes stock on confirm, and onHand always equals the ledger', async () => {
    const p = await productWithStock(ctx, 0);

    const receive = await createTx(ctx, 'staff', 'RECEIVE', p.id, 10);
    expect(await onHand(ctx, p.id)).toBe(0); // draft: no effect yet
    await confirm('admin', receive.id).expect(200);
    expect(await onHand(ctx, p.id)).toBe(10);

    const issue = await createTx(ctx, 'staff', 'ISSUE', p.id, 4);
    await confirm('admin', issue.id).expect(200);
    const adjust = await createTx(ctx, 'staff', 'ADJUST', p.id, -1);
    await confirm('admin', adjust.id).expect(200);

    expect(await onHand(ctx, p.id)).toBe(5);
    expect(await audit(ctx, p.id)).toMatchObject({
      onHand: 5,
      ledgerBalance: 5,
      consistent: true,
    });

    const moves = await auth(
      ctx,
      'staff',
      ctx.http().get(`/products/${p.id}/movements`),
    ).expect(200);
    expect(
      moves.body.items.map((m: { change: number; balanceAfter: number }) => [
        m.change,
        m.balanceAfter,
      ]),
    ).toEqual([
      [-1, 5],
      [-4, 6],
      [10, 10],
    ]);
  });

  it('rolls back completely when stock is insufficient', async () => {
    const p = await productWithStock(ctx, 3);
    const q = await productWithStock(ctx, 50);
    // Two lines: the first would succeed, the second must fail -> nothing applies.
    const res = await auth(ctx, 'staff', ctx.http().post('/transactions'))
      .send({
        type: 'ISSUE',
        items: [
          { productId: q.id, quantity: 10 },
          { productId: p.id, quantity: 4 },
        ],
      })
      .expect(201);

    await confirm('admin', res.body.id).expect(400);

    expect(await onHand(ctx, q.id)).toBe(50);
    expect(await onHand(ctx, p.id)).toBe(3);
    const tx = await auth(
      ctx,
      'staff',
      ctx.http().get(`/transactions/${res.body.id}`),
    ).expect(200);
    expect(tx.body.status).toBe('DRAFT');
  });

  it('cannot confirm twice or cancel a confirmed document', async () => {
    const p = await productWithStock(ctx, 0);
    const tx = await createTx(ctx, 'staff', 'RECEIVE', p.id, 2);
    await confirm('admin', tx.id).expect(200);
    await confirm('admin', tx.id).expect(409);
    await auth(
      ctx,
      'admin',
      ctx.http().post(`/transactions/${tx.id}/cancel`),
    ).expect(409);
    expect(await onHand(ctx, p.id)).toBe(2);
  });
});

describe('idempotency (clientUuid)', () => {
  it('resending the same document returns the original', async () => {
    const p = await productWithStock(ctx, 0);
    const clientUuid = randomUUID();
    const first = await createTx(ctx, 'staff', 'RECEIVE', p.id, 7, {
      clientUuid,
    });
    const again = await createTx(ctx, 'staff', 'RECEIVE', p.id, 7, {
      clientUuid,
    });

    expect(again.id).toBe(first.id);
    expect(
      await ctx.prisma.stockTransaction.count({ where: { clientUuid } }),
    ).toBe(1);
  });

  it('parallel retries of the same document still create one', async () => {
    const p = await productWithStock(ctx, 0);
    const clientUuid = randomUUID();
    const results = await Promise.all(
      Array.from({ length: 5 }, () =>
        auth(ctx, 'staff', ctx.http().post('/transactions')).send({
          type: 'RECEIVE',
          clientUuid,
          items: [{ productId: p.id, quantity: 1 }],
        }),
      ),
    );
    // Racing inserts: one wins, the rest get the original or a conflict —
    // never a second document.
    expect(results.some((r) => r.status === 201)).toBe(true);
    expect(
      await ctx.prisma.stockTransaction.count({ where: { clientUuid } }),
    ).toBe(1);
  });

  it("another user can't reuse someone's clientUuid", async () => {
    const p = await productWithStock(ctx, 0);
    const clientUuid = randomUUID();
    await createTx(ctx, 'staff', 'RECEIVE', p.id, 1, { clientUuid });
    await auth(ctx, 'staff2', ctx.http().post('/transactions'))
      .send({
        type: 'RECEIVE',
        clientUuid,
        items: [{ productId: p.id, quantity: 1 }],
      })
      .expect(409);
  });
});

describe('concurrency', () => {
  it('parallel confirms never issue more than is on hand', async () => {
    const p = await productWithStock(ctx, 10);
    // 10 drafts × 3 units = 30 requested, only 10 on hand.
    const drafts = [];
    for (let i = 0; i < 10; i++)
      drafts.push(await createTx(ctx, 'staff', 'ISSUE', p.id, 3));

    const results = await Promise.all(
      drafts.map((d) => confirm('admin', d.id)),
    );
    const ok = results.filter((r) => r.status === 200).length;
    const rejected = results.filter((r) => r.status === 400).length;

    expect(ok).toBe(3); // 3 × 3 = 9 ≤ 10
    expect(rejected).toBe(7);
    expect(await onHand(ctx, p.id)).toBe(1);
    expect((await audit(ctx, p.id)).consistent).toBe(true);
  });

  it('confirming the same draft concurrently applies it exactly once', async () => {
    const p = await productWithStock(ctx, 0);
    const tx = await createTx(ctx, 'staff', 'RECEIVE', p.id, 5);

    const results = await Promise.all(
      Array.from({ length: 5 }, () => confirm('admin', tx.id)),
    );
    expect(results.filter((r) => r.status === 200)).toHaveLength(1);
    expect(results.filter((r) => r.status === 409)).toHaveLength(4);
    expect(await onHand(ctx, p.id)).toBe(5);
  });
});

describe('evidence photos', () => {
  const asset = (txId: string) => ({
    publicId: `stockflow/transactions/${txId}/abc123`,
    url: `https://res.cloudinary.com/e2e-cloud/image/upload/v1/stockflow/transactions/${txId}/abc123.jpg`,
  });

  it('accepts only images from this transaction’s folder on our account', async () => {
    const p = await productWithStock(ctx, 0);
    const tx = await createTx(ctx, 'staff', 'RECEIVE', p.id, 1);
    const other = await createTx(ctx, 'staff', 'RECEIVE', p.id, 1);
    const path = `/transactions/${tx.id}/attachments`;

    await auth(ctx, 'staff', ctx.http().post(path))
      .send(asset(other.id))
      .expect(400);
    await auth(ctx, 'staff', ctx.http().post(path))
      .send({
        ...asset(tx.id),
        url: asset(tx.id).url.replace('e2e-cloud', 'evil'),
      })
      .expect(400);
    await auth(ctx, 'staff', ctx.http().post(path))
      .send(asset(tx.id))
      .expect(201);
  });

  it('only the creator or an admin can attach, and never to a cancelled document', async () => {
    const p = await productWithStock(ctx, 0);
    const tx = await createTx(ctx, 'staff', 'RECEIVE', p.id, 1);
    const path = `/transactions/${tx.id}/attachments`;

    await auth(ctx, 'staff2', ctx.http().post(`${path}/signature`)).expect(403);
    const sig = await auth(
      ctx,
      'staff',
      ctx.http().post(`${path}/signature`),
    ).expect(200);
    expect(sig.body).toMatchObject({
      folder: `stockflow/transactions/${tx.id}`,
    });
    expect(sig.body).not.toHaveProperty('apiSecret');

    await auth(
      ctx,
      'staff',
      ctx.http().post(`/transactions/${tx.id}/cancel`),
    ).expect(200);
    await auth(ctx, 'staff', ctx.http().post(`${path}/signature`)).expect(409);
  });
});
