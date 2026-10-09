/**
 * Demo stock history for the last 6 days (not today), so the dashboard chart
 * and per-product history look realistic.
 *
 * Re-runnable: previous demo rows (clientUuid starting with "demo-") are
 * removed and their effect on onHand reversed before new ones are created.
 * Ledger rule is preserved: onHand changes by exactly the net of the
 * confirmed rows created here, inside one database transaction.
 */
import { PrismaClient, TxStatus, TxType } from '@prisma/client';

const prisma = new PrismaClient();
const DEMO = 'demo-';
const DAYS = 6;
const BKK_OFFSET_H = 7;

/** Small deterministic PRNG so every run produces the same story. */
function rng(seed: number) {
  return () => {
    seed = (seed * 1664525 + 1013904223) % 2 ** 32;
    return seed / 2 ** 32;
  };
}

/** `daysAgo` days back, at `hour`:`minute` Bangkok time, as a UTC Date. */
function at(daysAgo: number, hour: number, minute: number): Date {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() - daysAgo);
  d.setUTCHours(hour - BKK_OFFSET_H, minute, 0, 0);
  return d;
}

const signed = (type: TxType, q: number) => (type === TxType.ISSUE ? -q : q);

async function main() {
  const admin = await prisma.user.findUniqueOrThrow({
    where: { email: 'admin@stockflow.dev' },
  });
  const staff = await prisma.user.findUniqueOrThrow({
    where: { email: 'staff@stockflow.dev' },
  });
  const products = await prisma.product.findMany({ orderBy: { sku: 'asc' } });
  if (products.length === 0) throw new Error('Run `npx prisma db seed` first');

  // Plan the history in memory: receive in the morning, issue in the afternoon,
  // never issuing more than the running demo balance.
  const rand = rng(42);
  const balance = new Map(products.map((p) => [p.id, 0]));
  type Planned = {
    type: TxType;
    ref: string;
    at: Date;
    items: { productId: string; quantity: number }[];
  };
  const plan: Planned[] = [];
  let po = 1;
  let req = 1;

  for (let daysAgo = DAYS; daysAgo >= 1; daysAgo--) {
    // Morning delivery covering a few products.
    const delivered = products.filter(
      (p) => (balance.get(p.id) ?? 0) < p.minStock * 2 && rand() < 0.6,
    );
    if (delivered.length) {
      const items = delivered.map((p) => ({
        productId: p.id,
        quantity:
          Math.max(p.minStock, 6) + Math.round(rand() * p.minStock * 1.5),
      }));
      plan.push({
        type: TxType.RECEIVE,
        ref: `PO-DEMO-${String(po++).padStart(3, '0')}`,
        at: at(daysAgo, 9, Math.round(rand() * 50)),
        items,
      });
      for (const i of items) {
        balance.set(i.productId, (balance.get(i.productId) ?? 0) + i.quantity);
      }
    }

    // One or two issue requests in the afternoon.
    const requests = 1 + Math.round(rand());
    for (let r = 0; r < requests; r++) {
      const items = products
        .filter((p) => (balance.get(p.id) ?? 0) > 0 && rand() < 0.45)
        .map((p) => {
          const bal = balance.get(p.id)!;
          return {
            productId: p.id,
            quantity: Math.max(
              1,
              Math.min(bal, Math.round(bal * (0.2 + rand() * 0.4))),
            ),
          };
        });
      if (!items.length) continue;
      plan.push({
        type: TxType.ISSUE,
        ref: `REQ-DEMO-${String(req++).padStart(3, '0')}`,
        at: at(daysAgo, 13 + r * 3, Math.round(rand() * 50)),
        items,
      });
      for (const i of items) {
        balance.set(i.productId, balance.get(i.productId)! - i.quantity);
      }
    }
  }

  await prisma.$transaction(
    async (db) => {
      // 1. Undo previous demo history.
      const old = await db.stockTransaction.findMany({
        where: { clientUuid: { startsWith: DEMO }, status: TxStatus.CONFIRMED },
        include: { items: true },
      });
      const undo = new Map<string, number>();
      for (const tx of old) {
        for (const i of tx.items) {
          undo.set(
            i.productId,
            (undo.get(i.productId) ?? 0) - signed(tx.type, i.quantity),
          );
        }
      }
      for (const [productId, delta] of undo) {
        await db.product.update({
          where: { id: productId },
          data: { onHand: { increment: delta } },
        });
      }
      await db.stockTransaction.deleteMany({
        where: { clientUuid: { startsWith: DEMO } },
      });

      // 2. Create the new history and apply its net effect.
      const net = new Map<string, number>();
      for (const [n, p] of plan.entries()) {
        await db.stockTransaction.create({
          data: {
            clientUuid: `${DEMO}${String(n).padStart(4, '0')}`,
            type: p.type,
            status: TxStatus.CONFIRMED,
            referenceNo: p.ref,
            note: 'Demo history',
            createdById: staff.id,
            confirmedById: admin.id,
            createdAt: new Date(p.at.getTime() - 20 * 60_000),
            confirmedAt: p.at,
            items: { create: p.items },
          },
        });
        for (const i of p.items) {
          net.set(
            i.productId,
            (net.get(i.productId) ?? 0) + signed(p.type, i.quantity),
          );
        }
      }
      for (const [productId, delta] of net) {
        await db.product.update({
          where: { id: productId },
          data: { onHand: { increment: delta } },
        });
      }
    },
    { timeout: 60_000 },
  );

  console.log(
    `Demo history: ${plan.length} confirmed transactions over the last ${DAYS} days`,
  );
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
