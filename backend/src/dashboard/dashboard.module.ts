import {
  Controller,
  Get,
  Injectable,
  Module,
  ParseIntPipe,
  DefaultValuePipe,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiQuery, ApiTags } from '@nestjs/swagger';
import { Role, TxStatus, WorkOrderStatus } from '@prisma/client';
import { Roles } from '../auth/decorators/index.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { dailyFlow, stockUrgency } from './dashboard-logic.js';

const FLOW_DAYS = 7;

@Injectable()
export class DashboardService {
  constructor(private readonly prisma: PrismaService) {}

  async summary(offsetMinutes: number) {
    const db = this.prisma.db;
    const now = new Date();
    const since = new Date(now.getTime() - FLOW_DAYS * 86_400_000);

    const [products, pendingDrafts, flowLines, recent, woByStatus, woOverdue] =
      await Promise.all([
        db.product.findMany({
          select: {
            id: true,
            sku: true,
            name: true,
            unit: true,
            onHand: true,
            minStock: true,
          },
        }),
        db.stockTransaction.count({ where: { status: TxStatus.DRAFT } }),
        db.stockTransactionItem.findMany({
          where: {
            transaction: {
              status: TxStatus.CONFIRMED,
              confirmedAt: { gte: since },
            },
          },
          select: {
            quantity: true,
            transaction: { select: { type: true, confirmedAt: true } },
          },
        }),
        db.stockTransaction.findMany({
          where: { status: TxStatus.CONFIRMED },
          orderBy: { confirmedAt: 'desc' },
          take: 5,
          select: {
            id: true,
            type: true,
            referenceNo: true,
            confirmedAt: true,
            confirmedBy: { select: { name: true } },
            _count: { select: { items: true } },
          },
        }),
        db.workOrder.groupBy({ by: ['status'], _count: { _all: true } }),
        db.workOrder.count({
          where: {
            dueAt: { lt: now },
            status: {
              notIn: [WorkOrderStatus.APPROVED, WorkOrderStatus.CANCELLED],
            },
          },
        }),
      ]);

    const outOfStock = products.filter((p) => p.onHand <= 0);
    const low = products.filter((p) => p.onHand > 0 && p.onHand <= p.minStock);

    return {
      workOrders: {
        ...Object.fromEntries(
          Object.values(WorkOrderStatus).map((st) => [
            st,
            woByStatus.find((g) => g.status === st)?._count._all ?? 0,
          ]),
        ),
        overdue: woOverdue,
      },
      totals: {
        products: products.length,
        unitsOnHand: products.reduce((s, p) => s + p.onHand, 0),
        lowStock: low.length,
        outOfStock: outOfStock.length,
        pendingDrafts,
      },
      flow: dailyFlow(
        flowLines.map((l) => ({
          type: l.transaction.type,
          quantity: l.quantity,
          confirmedAt: l.transaction.confirmedAt!,
        })),
        { days: FLOW_DAYS, now, offsetMinutes },
      ),
      needsAttention: [...outOfStock, ...low]
        .sort((a, b) => stockUrgency(a) - stockUrgency(b))
        .slice(0, 5),
      recentActivity: recent.map(({ _count, confirmedBy, ...t }) => ({
        ...t,
        confirmedBy: confirmedBy?.name ?? null,
        itemCount: _count.items,
      })),
    };
  }
}

@ApiTags('dashboard')
@ApiBearerAuth()
@Controller('dashboard')
export class DashboardController {
  constructor(private readonly dashboard: DashboardService) {}

  @Roles(Role.ADMIN, Role.STAFF, Role.SUPERVISOR)
  @Get()
  @ApiQuery({
    name: 'tzOffset',
    required: false,
    description:
      'Client UTC offset in minutes (Bangkok = 420), for day buckets',
  })
  summary(
    @Query('tzOffset', new DefaultValuePipe(420), ParseIntPipe)
    tzOffset: number,
  ) {
    return this.dashboard.summary(Math.max(-720, Math.min(840, tzOffset)));
  }
}

@Module({
  controllers: [DashboardController],
  providers: [DashboardService],
})
export class DashboardModule {}
