import {
  Controller,
  Get,
  HttpCode,
  Injectable,
  Module,
  NotFoundException,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiPropertyOptional, ApiTags } from '@nestjs/swagger';
import { Prisma, Role, WorkOrderEventType } from '@prisma/client';
import { Transform, Type } from 'class-transformer';
import { IsBoolean, IsInt, IsOptional, Max, Min } from 'class-validator';
import { CurrentUser, type AuthUser } from '../auth/decorators/index.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { workOrderCode } from '../work-orders/work-order-logic.js';
import { NOTIFYING_EVENTS, recipientsFor } from './notification-rules.js';

export class NotificationQueryDto {
  @ApiPropertyOptional({ description: 'Only unread notifications' })
  @IsOptional()
  @Transform(({ value }) => value === true || value === 'true')
  @IsBoolean()
  unread?: boolean;

  @ApiPropertyOptional({ default: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page = 1;

  @ApiPropertyOptional({ default: 20 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit = 20;
}

/**
 * Creates notifications for a work-order event inside the caller's
 * transaction, so a notice exists exactly when its event does.
 */
export async function notifyForEvent(
  db: Prisma.TransactionClient,
  event: { id: string; type: WorkOrderEventType; actorId: string },
  people: { assigneeId: string | null; reviewerId: string | null },
) {
  if (!NOTIFYING_EVENTS.has(event.type)) return;
  const supervisorIds =
    event.type === WorkOrderEventType.SUBMITTED && !people.reviewerId
      ? (
          await db.user.findMany({
            where: { role: Role.SUPERVISOR },
            select: { id: true },
          })
        ).map((u) => u.id)
      : [];
  const userIds = recipientsFor(event.type, {
    actorId: event.actorId,
    ...people,
    supervisorIds,
  });
  if (!userIds.length) return;
  await db.notification.createMany({
    data: userIds.map((userId) => ({ userId, eventId: event.id })),
    skipDuplicates: true,
  });
}

@Injectable()
export class NotificationsService {
  constructor(private readonly prisma: PrismaService) {}

  async list(user: AuthUser, q: NotificationQueryDto) {
    const where: Prisma.NotificationWhereInput = {
      userId: user.id,
      ...(q.unread ? { readAt: null } : {}),
    };
    const [rows, total, unread] = await Promise.all([
      this.prisma.db.notification.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (q.page - 1) * q.limit,
        take: q.limit,
        relationLoadStrategy: 'join',
        include: {
          event: {
            select: {
              type: true,
              note: true,
              actor: { select: { id: true, name: true } },
              workOrder: { select: { id: true, number: true, title: true } },
            },
          },
        },
      }),
      this.prisma.db.notification.count({ where }),
      this.prisma.db.notification.count({
        where: { userId: user.id, readAt: null },
      }),
    ]);
    return {
      items: rows.map((n) => ({
        id: n.id,
        type: n.event.type,
        note: n.event.note,
        actor: n.event.actor,
        workOrder: {
          id: n.event.workOrder.id,
          code: workOrderCode(n.event.workOrder.number),
          title: n.event.workOrder.title,
        },
        read: n.readAt !== null,
        createdAt: n.createdAt,
      })),
      total,
      unread,
      page: q.page,
    };
  }

  async unreadCount(user: AuthUser) {
    return {
      unread: await this.prisma.db.notification.count({
        where: { userId: user.id, readAt: null },
      }),
    };
  }

  /** Marks one of the caller's notifications read; others' are invisible (404). */
  async markRead(user: AuthUser, id: string) {
    const res = await this.prisma.db.notification.updateMany({
      where: { id, userId: user.id },
      data: { readAt: new Date() },
    });
    if (res.count === 0) throw new NotFoundException('Notification not found');
    return this.unreadCount(user);
  }

  async markAllRead(user: AuthUser) {
    await this.prisma.db.notification.updateMany({
      where: { userId: user.id, readAt: null },
      data: { readAt: new Date() },
    });
    return { unread: 0 };
  }
}

/** Every signed-in role has a personal inbox. */
@ApiTags('notifications')
@ApiBearerAuth()
@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  @Get()
  list(@CurrentUser() user: AuthUser, @Query() q: NotificationQueryDto) {
    return this.notifications.list(user, q);
  }

  @Get('unread-count')
  unreadCount(@CurrentUser() user: AuthUser) {
    return this.notifications.unreadCount(user);
  }

  @Post(':id/read')
  @HttpCode(200)
  markRead(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.notifications.markRead(user, id);
  }

  @Post('read-all')
  @HttpCode(200)
  markAllRead(@CurrentUser() user: AuthUser) {
    return this.notifications.markAllRead(user);
  }
}

@Module({
  controllers: [NotificationsController],
  providers: [NotificationsService],
})
export class NotificationsModule {}
