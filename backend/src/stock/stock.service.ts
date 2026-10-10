import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  Prisma,
  Role,
  TxStatus,
  TxType,
  WorkOrderEventType,
  WorkOrderStatus,
} from '@prisma/client';
import { AuthUser } from '../auth/decorators/index.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { withRetry } from '../prisma/retry.js';
import { CreateTxDto, TxQueryDto } from './dto/stock.dto.js';
import {
  InsufficientStockError,
  ledgerBalance,
  netDeltas,
  runningBalances,
  signedDelta,
  StockRuleError,
  validateItems,
} from './stock-logic.js';

const txInclude = {
  items: {
    include: {
      product: { select: { id: true, sku: true, name: true, unit: true } },
    },
  },
  createdBy: { select: { id: true, name: true } },
  confirmedBy: { select: { id: true, name: true } },
  attachments: true,
  workOrder: { select: { id: true, number: true, title: true, status: true } },
} satisfies Prisma.StockTransactionInclude;

@Injectable()
export class StockService {
  constructor(private readonly prisma: PrismaService) {}

  async create(dto: CreateTxDto, user: AuthUser) {
    // Idempotent: an offline client retrying the same clientUuid gets the original back.
    if (dto.clientUuid) {
      const existing = await this.prisma.db.stockTransaction.findUnique({
        where: { clientUuid: dto.clientUuid },
        include: txInclude,
      });
      if (existing) {
        if (existing.createdById !== user.id) {
          throw new ConflictException('clientUuid already used');
        }
        return existing;
      }
    }

    this.guardRules(() => validateItems(dto.type, dto.items));

    const productIds = [...new Set(dto.items.map((i) => i.productId))];
    const found = await this.prisma.db.product.count({
      where: { id: { in: productIds } },
    });
    if (found !== productIds.length) {
      throw new BadRequestException('One or more products do not exist');
    }
    if (dto.workOrderId)
      await this.checkWorkOrderLink(dto.type, dto.workOrderId);

    return this.prisma.db.stockTransaction.create({
      data: {
        type: dto.type,
        clientUuid: dto.clientUuid,
        referenceNo: dto.referenceNo,
        note: dto.note,
        createdById: user.id,
        workOrderId: dto.workOrderId,
        items: { create: dto.items },
      },
      include: txInclude,
    });
  }

  async findAll({ type, status, productId, page, limit }: TxQueryDto) {
    const where: Prisma.StockTransactionWhereInput = {
      type,
      status,
      ...(productId && { items: { some: { productId } } }),
    };
    const [items, total] = await Promise.all([
      this.prisma.db.stockTransaction.findMany({
        where,
        include: txInclude,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
      this.prisma.db.stockTransaction.count({ where }),
    ]);
    return { items, total, page, limit };
  }

  async findOne(id: string) {
    const tx = await this.prisma.db.stockTransaction.findUnique({
      where: { id },
      include: txInclude,
    });
    if (!tx) throw new NotFoundException('Transaction not found');
    return tx;
  }

  /**
   * Confirms a draft and applies it to products.onHand in ONE database
   * transaction. Decrements are conditional (onHand >= qty) so concurrent
   * confirms can never drive stock negative.
   */
  async confirm(id: string, user: AuthUser) {
    const tx = await this.findOne(id);
    const deltas = netDeltas(tx.type, tx.items);

    // Retry the whole transaction (it rolls back on failure), not single queries.
    await withRetry(() =>
      this.prisma.$transaction(async (db) => {
        const claimed = await db.stockTransaction.updateMany({
          where: { id, status: TxStatus.DRAFT },
          data: {
            status: TxStatus.CONFIRMED,
            confirmedById: user.id,
            confirmedAt: new Date(),
          },
        });
        if (claimed.count === 0) {
          throw new ConflictException(
            'Only DRAFT transactions can be confirmed',
          );
        }

        for (const [productId, delta] of deltas) {
          if (delta >= 0) {
            await db.product.update({
              where: { id: productId },
              data: { onHand: { increment: delta } },
            });
            continue;
          }
          const res = await db.product.updateMany({
            where: { id: productId, onHand: { gte: -delta } },
            data: { onHand: { decrement: -delta } },
          });
          if (res.count === 0) {
            const p = await db.product.findUnique({ where: { id: productId } });
            throw new BadRequestException(
              new InsufficientStockError(productId, p?.onHand ?? 0, -delta)
                .message,
            );
          }
        }

        // Linked to a work order: record it in its audit trail, atomically.
        if (tx.workOrderId) {
          const lines = tx.items
            .map((i) => `${i.quantity} × ${i.product.sku}`)
            .join(', ');
          await db.workOrderEvent.create({
            data: {
              workOrderId: tx.workOrderId,
              actorId: user.id,
              type: WorkOrderEventType.MATERIAL_ISSUED,
              note: `${tx.type === TxType.ISSUE ? 'Issued' : 'Returned'} ${lines}${tx.referenceNo ? ` (${tx.referenceNo})` : ''}`,
            },
          });
        }
      }),
    );

    return this.findOne(id);
  }

  async cancel(id: string, user: AuthUser) {
    const tx = await this.findOne(id);
    if (user.role !== Role.ADMIN && tx.createdById !== user.id) {
      throw new ForbiddenException('Only the creator or an admin can cancel');
    }
    const res = await this.prisma.db.stockTransaction.updateMany({
      where: { id, status: TxStatus.DRAFT },
      data: { status: TxStatus.CANCELLED },
    });
    if (res.count === 0) {
      throw new ConflictException('Only DRAFT transactions can be cancelled');
    }
    return this.findOne(id);
  }

  /** Recomputes balance from the ledger and compares it to the cached onHand. */
  async auditProduct(productId: string) {
    const product = await this.prisma.db.product.findUnique({
      where: { id: productId },
    });
    if (!product) throw new NotFoundException('Product not found');

    const lines = await this.prisma.db.stockTransactionItem.findMany({
      where: { productId },
      select: {
        quantity: true,
        transaction: { select: { type: true, status: true } },
      },
    });
    const ledger = ledgerBalance(
      lines.map((l) => ({ quantity: l.quantity, ...l.transaction })),
    );
    return {
      productId,
      onHand: product.onHand,
      ledgerBalance: ledger,
      consistent: ledger === product.onHand,
    };
  }

  /**
   * Confirmed stock movements for one product, newest first, each with the
   * balance right after it (computed from the ledger in confirmation order).
   */
  async productMovements(productId: string, page: number, limit: number) {
    const product = await this.prisma.db.product.findUnique({
      where: { id: productId },
      select: { id: true, unit: true, onHand: true },
    });
    if (!product) throw new NotFoundException('Product not found');

    const lines = await this.prisma.db.stockTransactionItem.findMany({
      where: { productId, transaction: { status: TxStatus.CONFIRMED } },
      select: {
        quantity: true,
        transaction: {
          select: {
            id: true,
            type: true,
            referenceNo: true,
            note: true,
            confirmedAt: true,
            createdBy: { select: { name: true } },
            confirmedBy: { select: { name: true } },
          },
        },
      },
      orderBy: [
        { transaction: { confirmedAt: 'asc' } },
        { transaction: { id: 'asc' } },
      ],
    });

    const balances = runningBalances(
      lines.map((l) => ({ type: l.transaction.type, quantity: l.quantity })),
    );
    const movements = lines
      .map(({ quantity, transaction: t }, i) => ({
        transactionId: t.id,
        type: t.type,
        referenceNo: t.referenceNo,
        note: t.note,
        change: signedDelta(t.type, quantity),
        balanceAfter: balances[i],
        confirmedAt: t.confirmedAt,
        createdBy: t.createdBy.name,
        confirmedBy: t.confirmedBy?.name ?? null,
      }))
      .reverse();

    return {
      items: movements.slice((page - 1) * limit, page * limit),
      total: movements.length,
      page,
      limit,
      unit: product.unit,
      onHand: product.onHand,
    };
  }

  /** Materials can be issued to (or returned from) an active work order only. */
  private async checkWorkOrderLink(type: TxType, workOrderId: string) {
    if (type === TxType.ADJUST) {
      throw new BadRequestException(
        'Only ISSUE or RECEIVE documents can be linked to a work order',
      );
    }
    const wo = await this.prisma.db.workOrder.findUnique({
      where: { id: workOrderId },
      select: { status: true },
    });
    if (!wo) throw new BadRequestException('Work order not found');
    if (
      wo.status === WorkOrderStatus.APPROVED ||
      wo.status === WorkOrderStatus.CANCELLED
    ) {
      throw new BadRequestException(
        `Work order is ${wo.status.toLowerCase()}; materials can no longer be linked`,
      );
    }
  }

  private guardRules(fn: () => void) {
    try {
      fn();
    } catch (e) {
      if (e instanceof StockRuleError) throw new BadRequestException(e.message);
      throw e;
    }
  }
}
