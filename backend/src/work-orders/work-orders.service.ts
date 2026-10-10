import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  Prisma,
  Role,
  WorkOrderEventType,
  WorkOrderStatus,
} from '@prisma/client';
import type { AuthUser } from '../auth/decorators/index.js';
import {
  cloudinaryFromEnv,
  destroyAsset,
  folderUploadParams,
  signParams,
  validateUploadedAsset,
  workOrderFolder,
} from '../attachments/cloudinary.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { withRetry } from '../prisma/retry.js';
import {
  AssignDto,
  ChecklistUpdateDto,
  CreateWorkOrderDto,
  EvidenceSignatureDto,
  SaveEvidenceDto,
  WorkOrderQueryDto,
} from './dto/work-order.dto.js';
import {
  allowedActions,
  can,
  canView,
  issuedByProduct,
  submissionProblems,
  TRANSITIONS,
  TransitionName,
  WorkOrderAction,
  workOrderCode,
} from './work-order-logic.js';

const MAX_EVIDENCE = 10;

const userBrief = { select: { id: true, name: true, role: true } } as const;

const detailInclude = {
  assignee: userBrief,
  reviewer: userBrief,
  reviewedBy: userBrief,
  createdBy: userBrief,
  template: { select: { id: true, name: true } },
  checklist: {
    orderBy: { position: 'asc' },
    include: { completedBy: userBrief },
  },
  materials: {
    include: {
      product: {
        select: {
          id: true,
          sku: true,
          name: true,
          unit: true,
          onHand: true,
          imageUrl: true,
        },
      },
    },
  },
  evidence: {
    orderBy: { createdAt: 'asc' },
    include: { uploadedBy: userBrief },
  },
  stockTransactions: {
    orderBy: { createdAt: 'desc' },
    select: {
      id: true,
      type: true,
      status: true,
      referenceNo: true,
      createdAt: true,
      confirmedAt: true,
      items: { select: { productId: true, quantity: true } },
    },
  },
} satisfies Prisma.WorkOrderInclude;

type WorkOrderDetail = Prisma.WorkOrderGetPayload<{
  include: typeof detailInclude;
}>;

@Injectable()
export class WorkOrdersService {
  private readonly logger = new Logger(WorkOrdersService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  // ------------------------------------------------------------- reads

  async list(actor: AuthUser, query: WorkOrderQueryDto) {
    const { status, priority, q, page, limit } = query;
    const code = q?.trim().match(/^(?:wo-?)?0*(\d{1,9})$/i);
    const where: Prisma.WorkOrderWhereInput = {
      // Scope first: technicians only ever see their own work.
      ...(actor.role === Role.TECHNICIAN && { assigneeId: actor.id }),
      ...(status?.length && { status: { in: status } }),
      ...(priority && { priority }),
      ...(q?.trim() && {
        OR: [
          { title: { contains: q.trim(), mode: 'insensitive' } },
          { siteName: { contains: q.trim(), mode: 'insensitive' } },
          ...(code ? [{ number: Number(code[1]) }] : []),
        ],
      }),
    };
    if (!this.mayList(actor)) throw new ForbiddenException();

    const [rows, total] = await Promise.all([
      this.prisma.db.workOrder.findMany({
        where,
        orderBy: [
          { dueAt: { sort: 'asc', nulls: 'last' } },
          { number: 'desc' },
        ],
        skip: (page - 1) * limit,
        take: limit,
        include: {
          assignee: userBrief,
          _count: {
            select: {
              checklist: true,
              evidence: true,
            },
          },
          checklist: { where: { done: true }, select: { id: true } },
        },
      }),
      this.prisma.db.workOrder.count({ where }),
    ]);

    return {
      items: rows.map(({ checklist, _count, ...wo }) => ({
        ...wo,
        code: workOrderCode(wo.number),
        checklistDone: checklist.length,
        checklistTotal: _count.checklist,
        evidenceCount: _count.evidence,
      })),
      total,
      page,
      limit,
    };
  }

  async detail(actor: AuthUser, id: string) {
    return this.present(actor, await this.load(actor, id));
  }

  async events(actor: AuthUser, id: string) {
    await this.load(actor, id); // access check
    return this.prisma.db.workOrderEvent.findMany({
      where: { workOrderId: id },
      orderBy: { createdAt: 'asc' },
      include: { actor: userBrief },
    });
  }

  templates() {
    return this.prisma.db.checklistTemplate.findMany({
      orderBy: { name: 'asc' },
      include: { items: { orderBy: { position: 'asc' } } },
    });
  }

  // ------------------------------------------------------------- create

  async create(actor: AuthUser, dto: CreateWorkOrderDto) {
    if (dto.clientUuid) {
      const existing = await this.prisma.db.workOrder.findUnique({
        where: { clientUuid: dto.clientUuid },
      });
      if (existing) {
        if (existing.createdById !== actor.id) {
          throw new ConflictException('clientUuid already used');
        }
        return this.detail(actor, existing.id);
      }
    }

    await this.checkPeople(dto.assigneeId, dto.reviewerId);
    const template = dto.templateId
      ? await this.prisma.db.checklistTemplate.findUnique({
          where: { id: dto.templateId },
          include: { items: { orderBy: { position: 'asc' } } },
        })
      : null;
    if (dto.templateId && !template) {
      throw new BadRequestException('Checklist template not found');
    }
    const materials = dto.materials ?? [];
    const productIds = new Set(materials.map((m) => m.productId));
    if (productIds.size !== materials.length) {
      throw new BadRequestException(
        'Each product may appear once in materials',
      );
    }
    if (productIds.size) {
      const found = await this.prisma.db.product.count({
        where: { id: { in: [...productIds] } },
      });
      if (found !== productIds.size) {
        throw new BadRequestException('One or more products do not exist');
      }
    }

    const created = await withRetry(() =>
      this.prisma.$transaction(async (db) => {
        const wo = await db.workOrder.create({
          data: {
            clientUuid: dto.clientUuid,
            title: dto.title.trim(),
            description: dto.description?.trim() || null,
            siteName: dto.siteName.trim(),
            siteAddress: dto.siteAddress?.trim() || null,
            priority: dto.priority,
            dueAt: dto.dueAt ? new Date(dto.dueAt) : null,
            requiredEvidence: dto.requiredEvidence ?? [],
            templateId: template?.id,
            createdById: actor.id,
            assigneeId: dto.assigneeId,
            reviewerId: dto.reviewerId,
            // Snapshot: later template edits never change this work order.
            checklist: {
              create: (template?.items ?? []).map((i) => ({
                title: i.title,
                description: i.description,
                required: i.required,
                position: i.position,
              })),
            },
            materials: { create: materials },
          },
        });
        await db.workOrderEvent.create({
          data: {
            workOrderId: wo.id,
            actorId: actor.id,
            type: WorkOrderEventType.CREATED,
            toStatus: WorkOrderStatus.OPEN,
          },
        });
        if (dto.assigneeId) {
          await db.workOrderEvent.create({
            data: {
              workOrderId: wo.id,
              actorId: actor.id,
              type: WorkOrderEventType.ASSIGNED,
              note: await this.assignmentNote(
                db,
                dto.assigneeId,
                dto.reviewerId,
              ),
            },
          });
        }
        return wo;
      }),
    );
    return this.detail(actor, created.id);
  }

  // ---------------------------------------------------------- assignment

  async assign(actor: AuthUser, id: string, dto: AssignDto) {
    const wo = await this.load(actor, id);
    this.require(actor, 'assign', wo);
    await this.checkPeople(dto.assigneeId, dto.reviewerId);

    const data: Prisma.WorkOrderUncheckedUpdateManyInput = {};
    if (dto.assigneeId !== undefined) data.assigneeId = dto.assigneeId;
    if (dto.reviewerId !== undefined) data.reviewerId = dto.reviewerId;
    if (!Object.keys(data).length) return this.present(actor, wo);

    await withRetry(() =>
      this.prisma.$transaction(async (db) => {
        // Guard against a concurrent submit/approve/cancel.
        const res = await db.workOrder.updateMany({
          where: {
            id,
            status: {
              in: [
                WorkOrderStatus.OPEN,
                WorkOrderStatus.IN_PROGRESS,
                WorkOrderStatus.NEEDS_REVISION,
              ],
            },
          },
          data,
        });
        if (res.count === 0) {
          throw new ConflictException('Work order can no longer be reassigned');
        }
        await db.workOrderEvent.create({
          data: {
            workOrderId: id,
            actorId: actor.id,
            type: WorkOrderEventType.ASSIGNED,
            note: await this.assignmentNote(
              db,
              dto.assigneeId === undefined ? wo.assigneeId : dto.assigneeId,
              dto.reviewerId === undefined ? wo.reviewerId : dto.reviewerId,
            ),
          },
        });
      }),
    );
    return this.detail(actor, id);
  }

  // --------------------------------------------------------- transitions

  start(actor: AuthUser, id: string) {
    return this.transition(actor, id, 'start', 'start', {
      event: WorkOrderEventType.STARTED,
      data: (wo) => (wo.startedAt ? {} : { startedAt: new Date() }),
    });
  }

  submit(actor: AuthUser, id: string) {
    return this.transition(actor, id, 'submit', 'submit', {
      event: WorkOrderEventType.SUBMITTED,
      data: () => ({ submittedAt: new Date() }),
      // Re-checked inside the transaction against the latest data.
      precheck: async (db) => {
        const fresh = await db.workOrder.findUniqueOrThrow({
          where: { id },
          select: {
            requiredEvidence: true,
            checklist: { select: { title: true, required: true, done: true } },
            evidence: { select: { category: true } },
          },
        });
        const problems = submissionProblems(
          fresh.checklist,
          fresh.requiredEvidence,
          fresh.evidence,
        );
        if (problems.length) {
          throw new BadRequestException({
            message: 'Work order is not ready to submit',
            problems,
          });
        }
      },
    });
  }

  approve(actor: AuthUser, id: string, note?: string) {
    return this.transition(actor, id, 'approve', 'approve', {
      event: WorkOrderEventType.APPROVED,
      note,
      data: () => ({
        reviewedById: actor.id,
        reviewedAt: new Date(),
        reviewNote: null,
      }),
    });
  }

  requestChanges(actor: AuthUser, id: string, reason: string) {
    return this.transition(actor, id, 'requestChanges', 'requestChanges', {
      event: WorkOrderEventType.CHANGES_REQUESTED,
      note: reason.trim(),
      data: () => ({
        reviewedById: actor.id,
        reviewedAt: new Date(),
        reviewNote: reason.trim(),
      }),
    });
  }

  cancel(actor: AuthUser, id: string, reason: string) {
    return this.transition(actor, id, 'cancel', 'cancel', {
      event: WorkOrderEventType.CANCELLED,
      note: reason.trim(),
      data: () => ({ cancelReason: reason.trim() }),
    });
  }

  /**
   * Applies a state transition safely:
   * 1. permission check on the loaded work order,
   * 2. conditional update (`status IN from`) so concurrent requests can't
   *    both win,
   * 3. audit event in the same database transaction.
   * Repeating a transition that already happened returns the current state
   * without a second event (idempotent).
   */
  private async transition(
    actor: AuthUser,
    id: string,
    name: TransitionName,
    action: WorkOrderAction,
    opts: {
      event: WorkOrderEventType;
      note?: string;
      data: (wo: WorkOrderDetail) => Prisma.WorkOrderUncheckedUpdateManyInput;
      precheck?: (db: Prisma.TransactionClient) => Promise<void>;
    },
  ) {
    const { from, to } = TRANSITIONS[name];
    const wo = await this.load(actor, id);

    if (wo.status === to && this.couldHave(actor, action, wo, from[0])) {
      return this.present(actor, wo); // already done: idempotent
    }
    this.require(actor, action, wo);

    const applied = await withRetry(() =>
      this.prisma.$transaction(async (db) => {
        await opts.precheck?.(db);
        const res = await db.workOrder.updateMany({
          where: { id, status: { in: [...from] } },
          data: { status: to, ...opts.data(wo) },
        });
        if (res.count === 0) return false;
        await db.workOrderEvent.create({
          data: {
            workOrderId: id,
            actorId: actor.id,
            type: opts.event,
            fromStatus: wo.status,
            toStatus: to,
            note: opts.note,
          },
        });
        return true;
      }),
    );

    if (!applied) {
      // Lost a race: fine if the other request did the same thing.
      const now = await this.load(actor, id);
      if (now.status === to) return this.present(actor, now);
      throw new ConflictException(
        `Work order is ${now.status.toLowerCase().replace('_', ' ')}; cannot ${name}`,
      );
    }
    return this.detail(actor, id);
  }

  // ----------------------------------------------------------- checklist

  async updateChecklist(
    actor: AuthUser,
    id: string,
    itemId: string,
    dto: ChecklistUpdateDto,
  ) {
    const wo = await this.load(actor, id);
    this.require(actor, 'updateChecklist', wo);
    const item = wo.checklist.find((i) => i.id === itemId);
    if (!item) throw new NotFoundException('Checklist item not found');

    await withRetry(() =>
      this.prisma.$transaction(async (db) => {
        // Only while still in progress and still assigned to this user.
        const res = await db.workOrderChecklistItem.updateMany({
          where: {
            id: itemId,
            workOrder: {
              id,
              status: WorkOrderStatus.IN_PROGRESS,
              assigneeId: actor.id,
            },
          },
          data: {
            done: dto.done,
            note: dto.note === undefined ? undefined : dto.note.trim() || null,
            completedById: dto.done ? actor.id : null,
            completedAt: dto.done ? new Date() : null,
          },
        });
        if (res.count === 0) {
          throw new ConflictException('Work order is no longer in progress');
        }
        if (item.done !== dto.done) {
          await db.workOrderEvent.create({
            data: {
              workOrderId: id,
              actorId: actor.id,
              type: WorkOrderEventType.CHECKLIST_UPDATED,
              note: `${dto.done ? 'Done' : 'Not done'}: ${item.title}`,
            },
          });
        }
      }),
    );
    return this.detail(actor, id);
  }

  // ------------------------------------------------------------ evidence

  async signEvidence(actor: AuthUser, id: string, dto: EvidenceSignatureDto) {
    const cfg = this.cloudinary();
    const wo = await this.load(actor, id);
    this.require(actor, 'manageEvidence', wo);
    if (wo.evidence.length >= MAX_EVIDENCE) {
      throw new ConflictException(
        `At most ${MAX_EVIDENCE} photos per work order`,
      );
    }
    const params = folderUploadParams(workOrderFolder(id));
    const signature = signParams(params, cfg.apiSecret);
    return {
      category: dto.category,
      uploadUrl: `https://api.cloudinary.com/v1_1/${cfg.cloudName}/image/upload`,
      fields: { ...params, api_key: cfg.apiKey, signature },
    };
  }

  async saveEvidence(actor: AuthUser, id: string, dto: SaveEvidenceDto) {
    const cfg = this.cloudinary();
    const wo = await this.load(actor, id);
    this.require(actor, 'manageEvidence', wo);
    const error = validateUploadedAsset(dto, {
      cloudName: cfg.cloudName,
      folder: workOrderFolder(id),
    });
    if (error) throw new BadRequestException(error);

    const existing = await this.prisma.db.workOrderEvidence.findUnique({
      where: { publicId: dto.publicId },
    });
    if (existing) return this.detail(actor, id); // retried save
    if (wo.evidence.length >= MAX_EVIDENCE) {
      throw new ConflictException(
        `At most ${MAX_EVIDENCE} photos per work order`,
      );
    }

    await this.prisma.$transaction(async (db) => {
      await db.workOrderEvidence.create({
        data: {
          workOrderId: id,
          category: dto.category,
          publicId: dto.publicId,
          url: dto.url,
          note: dto.note?.trim() || null,
          uploadedById: actor.id,
        },
      });
      await db.workOrderEvent.create({
        data: {
          workOrderId: id,
          actorId: actor.id,
          type: WorkOrderEventType.EVIDENCE_ADDED,
          note: `${dto.category.toLowerCase()} photo`,
        },
      });
    });
    return this.detail(actor, id);
  }

  async removeEvidence(actor: AuthUser, id: string, evidenceId: string) {
    const cfg = this.cloudinary();
    const wo = await this.load(actor, id);
    this.require(actor, 'manageEvidence', wo);
    const photo = wo.evidence.find((e) => e.id === evidenceId);
    if (!photo) throw new NotFoundException('Photo not found');

    await this.prisma.$transaction(async (db) => {
      await db.workOrderEvidence.delete({ where: { id: evidenceId } });
      await db.workOrderEvent.create({
        data: {
          workOrderId: id,
          actorId: actor.id,
          type: WorkOrderEventType.EVIDENCE_REMOVED,
          note: `${photo.category.toLowerCase()} photo`,
        },
      });
    });
    // Best effort: the record is gone either way.
    await destroyAsset(photo.publicId, cfg).catch((e) =>
      this.logger.warn(`Cloudinary destroy failed: ${e}`),
    );
    return this.detail(actor, id);
  }

  // ------------------------------------------------------------- helpers

  /** Loads a work order the actor may see; 404 otherwise (no existence leak). */
  private async load(actor: AuthUser, id: string): Promise<WorkOrderDetail> {
    if (!this.mayList(actor))
      throw new NotFoundException('Work order not found');
    const wo = await this.prisma.db.workOrder.findUnique({
      where: { id },
      include: detailInclude,
    });
    if (!wo || !canView(actor, wo)) {
      throw new NotFoundException('Work order not found');
    }
    return wo;
  }

  private mayList(actor: AuthUser) {
    return (
      [Role.ADMIN, Role.STAFF, Role.TECHNICIAN, Role.SUPERVISOR] as Role[]
    ).includes(actor.role);
  }

  private require(
    actor: AuthUser,
    action: WorkOrderAction,
    wo: WorkOrderDetail,
  ) {
    if (can(actor, action, wo)) return;
    // Right person, wrong moment → 409; wrong person → 403.
    const anyState = Object.values(WorkOrderStatus).some((status) =>
      can(actor, action, { ...wo, status }),
    );
    if (anyState) {
      throw new ConflictException(
        `Not possible while the work order is ${wo.status.toLowerCase().replace('_', ' ')}`,
      );
    }
    throw new ForbiddenException('You are not allowed to do this');
  }

  /** Would `actor` have been allowed from the transition's source state? */
  private couldHave(
    actor: AuthUser,
    action: WorkOrderAction,
    wo: WorkOrderDetail,
    from: WorkOrderStatus,
  ) {
    return can(actor, action, { ...wo, status: from });
  }

  private async checkPeople(
    assigneeId?: string | null,
    reviewerId?: string | null,
  ) {
    if (assigneeId) {
      const u = await this.prisma.db.user.findUnique({
        where: { id: assigneeId },
      });
      if (!u || u.role !== Role.TECHNICIAN) {
        throw new BadRequestException('Assignee must be a technician');
      }
    }
    if (reviewerId) {
      const u = await this.prisma.db.user.findUnique({
        where: { id: reviewerId },
      });
      if (!u || u.role !== Role.SUPERVISOR) {
        throw new BadRequestException('Reviewer must be a supervisor');
      }
    }
  }

  private async assignmentNote(
    db: Prisma.TransactionClient,
    assigneeId?: string | null,
    reviewerId?: string | null,
  ) {
    const name = async (id?: string | null) =>
      id ? ((await db.user.findUnique({ where: { id } }))?.name ?? '?') : null;
    const parts = [
      `Technician: ${(await name(assigneeId)) ?? 'unassigned'}`,
      `Reviewer: ${(await name(reviewerId)) ?? 'any supervisor'}`,
    ];
    return parts.join(' · ');
  }

  private cloudinary() {
    const cfg = cloudinaryFromEnv((k) => this.config.get<string>(k));
    if (!cfg) {
      throw new ServiceUnavailableException(
        'Photo upload is not configured on the server',
      );
    }
    return cfg;
  }

  /** API shape: adds code, materials progress, allowed actions and problems. */
  private present(actor: AuthUser, wo: WorkOrderDetail) {
    const issued = issuedByProduct(wo.stockTransactions);
    const actions = allowedActions(actor, wo);
    return {
      ...wo,
      code: workOrderCode(wo.number),
      materials: wo.materials.map((m) => {
        const issuedQty = issued.get(m.productId) ?? 0;
        return {
          ...m,
          issuedQty,
          remainingQty: Math.max(m.plannedQty - issuedQty, 0),
          // Not enough in stock to issue what is still needed.
          shortage: Math.max(m.plannedQty - issuedQty - m.product.onHand, 0),
        };
      }),
      stockTransactions: wo.stockTransactions.map(({ items, ...t }) => ({
        ...t,
        itemCount: items.length,
      })),
      allowedActions: actions,
      // Shown to the assignee before submitting.
      submissionProblems: actions.includes('submit')
        ? submissionProblems(wo.checklist, wo.requiredEvidence, wo.evidence)
        : [],
    };
  }
}
