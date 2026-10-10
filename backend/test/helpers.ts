import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { Role } from '@prisma/client';
import bcrypt from 'bcryptjs';
import request from 'supertest';
// Compiled app (see global-setup.ts).
import { AppModule } from '../dist/app.module.js';
import { PrismaService } from '../dist/prisma/prisma.service.js';
import { assertLocalDatabase } from './e2e-env.js';

export interface TestContext {
  app: INestApplication;
  prisma: PrismaService;
  http: () => ReturnType<typeof request>;
  tokens: { admin: string; staff: string; staff2: string };
}

/** Boots the API exactly like main.ts, against an empty test database. */
export async function createTestApp(): Promise<TestContext> {
  assertLocalDatabase(process.env.DATABASE_URL!);
  const moduleRef = await Test.createTestingModule({
    imports: [AppModule],
  }).compile();
  const app = moduleRef.createNestApplication({ logger: false });
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );
  await app.init();
  const prisma = app.get(PrismaService);
  await resetData(prisma);

  const password = 'Passw0rd!';
  const hash = await bcrypt.hash(password, 4);
  for (const [email, role] of [
    ['admin@test.dev', Role.ADMIN],
    ['staff@test.dev', Role.STAFF],
    ['staff2@test.dev', Role.STAFF],
  ] as const) {
    await prisma.user.create({
      data: { email, name: email.split('@')[0], role, passwordHash: hash },
    });
  }

  const http = () => request(app.getHttpServer());
  const login = async (email: string) =>
    (await http().post('/auth/login').send({ email, password })).body
      .accessToken as string;

  return {
    app,
    prisma,
    http,
    tokens: {
      admin: await login('admin@test.dev'),
      staff: await login('staff@test.dev'),
      staff2: await login('staff2@test.dev'),
    },
  };
}

export async function resetData(prisma: PrismaService) {
  await prisma.attachment.deleteMany();
  await prisma.stockTransactionItem.deleteMany();
  await prisma.stockTransaction.deleteMany();
  await prisma.product.deleteMany();
  await prisma.category.deleteMany();
  await prisma.user.deleteMany();
}

let sku = 0;
/** A product with `onHand` stock that is backed by a confirmed RECEIVE, so
 * the ledger audit holds from the start. */
export async function productWithStock(ctx: TestContext, onHand: number) {
  const category = await ctx.prisma.category.upsert({
    where: { name: 'Test' },
    update: {},
    create: { name: 'Test' },
  });
  const product = await ctx.prisma.product.create({
    data: {
      sku: `T-${++sku}-${Date.now()}`,
      name: `Product ${sku}`,
      categoryId: category.id,
      minStock: 0,
    },
  });
  if (onHand > 0) {
    const tx = await createTx(ctx, 'staff', 'RECEIVE', product.id, onHand);
    await auth(
      ctx,
      'admin',
      ctx.http().post(`/transactions/${tx.id}/confirm`),
    ).expect(200);
  }
  return product;
}

export function auth(
  ctx: TestContext,
  who: keyof TestContext['tokens'],
  req: request.Test,
) {
  return req.set('Authorization', `Bearer ${ctx.tokens[who]}`);
}

export async function createTx(
  ctx: TestContext,
  who: keyof TestContext['tokens'],
  type: 'RECEIVE' | 'ISSUE' | 'ADJUST',
  productId: string,
  quantity: number,
  extra: Record<string, unknown> = {},
) {
  const res = await auth(ctx, who, ctx.http().post('/transactions'))
    .send({ type, items: [{ productId, quantity }], ...extra })
    .expect(201);
  return res.body as { id: string; status: string };
}

export async function onHand(ctx: TestContext, productId: string) {
  return (
    await ctx.prisma.product.findUniqueOrThrow({ where: { id: productId } })
  ).onHand;
}

export async function audit(ctx: TestContext, productId: string) {
  return (
    await auth(
      ctx,
      'admin',
      ctx.http().get(`/products/${productId}/audit`),
    ).expect(200)
  ).body as { onHand: number; ledgerBalance: number; consistent: boolean };
}
