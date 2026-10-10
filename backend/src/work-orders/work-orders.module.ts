import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Module,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Put,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';
import type { AuthUser } from '../auth/decorators/index.js';
import { CurrentUser, Roles } from '../auth/decorators/index.js';
import {
  ApproveDto,
  AssignDto,
  ChecklistUpdateDto,
  CreateWorkOrderDto,
  EvidenceSignatureDto,
  ReasonDto,
  SaveEvidenceDto,
  WorkOrderQueryDto,
} from './dto/work-order.dto.js';
import { WorkOrdersService } from './work-orders.service.js';

/**
 * Every state change is its own endpoint (no generic status PATCH), and
 * every request is re-checked by the service against role, ownership and
 * current status.
 */
@ApiTags('work-orders')
@ApiBearerAuth()
@Controller('work-orders')
export class WorkOrdersController {
  constructor(private readonly workOrders: WorkOrdersService) {}

  @Get()
  list(@CurrentUser() user: AuthUser, @Query() query: WorkOrderQueryDto) {
    return this.workOrders.list(user, query);
  }

  @Roles(Role.ADMIN)
  @Post()
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateWorkOrderDto) {
    return this.workOrders.create(user, dto);
  }

  @Get(':id')
  detail(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.workOrders.detail(user, id);
  }

  @Get(':id/events')
  events(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.workOrders.events(user, id);
  }

  @Roles(Role.ADMIN)
  @Patch(':id/assignment')
  assign(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: AssignDto,
  ) {
    return this.workOrders.assign(user, id, dto);
  }

  @Post(':id/start')
  @HttpCode(200)
  start(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.workOrders.start(user, id);
  }

  @Put(':id/checklist/:itemId')
  updateChecklist(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Param('itemId', ParseUUIDPipe) itemId: string,
    @Body() dto: ChecklistUpdateDto,
  ) {
    return this.workOrders.updateChecklist(user, id, itemId, dto);
  }

  @Post(':id/evidence/signature')
  @HttpCode(200)
  signEvidence(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: EvidenceSignatureDto,
  ) {
    return this.workOrders.signEvidence(user, id, dto);
  }

  @Post(':id/evidence')
  saveEvidence(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: SaveEvidenceDto,
  ) {
    return this.workOrders.saveEvidence(user, id, dto);
  }

  @Delete(':id/evidence/:evidenceId')
  removeEvidence(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Param('evidenceId', ParseUUIDPipe) evidenceId: string,
  ) {
    return this.workOrders.removeEvidence(user, id, evidenceId);
  }

  @Post(':id/submit')
  @HttpCode(200)
  submit(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.workOrders.submit(user, id);
  }

  @Roles(Role.ADMIN, Role.SUPERVISOR)
  @Post(':id/approve')
  @HttpCode(200)
  approve(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ApproveDto,
  ) {
    return this.workOrders.approve(user, id, dto.note);
  }

  @Roles(Role.ADMIN, Role.SUPERVISOR)
  @Post(':id/request-changes')
  @HttpCode(200)
  requestChanges(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ReasonDto,
  ) {
    return this.workOrders.requestChanges(user, id, dto.reason);
  }

  @Roles(Role.ADMIN)
  @Post(':id/cancel')
  @HttpCode(200)
  cancel(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ReasonDto,
  ) {
    return this.workOrders.cancel(user, id, dto.reason);
  }
}

@ApiTags('work-orders')
@ApiBearerAuth()
@Controller('checklist-templates')
export class ChecklistTemplatesController {
  constructor(private readonly workOrders: WorkOrdersService) {}

  @Roles(Role.ADMIN)
  @Get()
  list() {
    return this.workOrders.templates();
  }
}

@Module({
  controllers: [WorkOrdersController, ChecklistTemplatesController],
  providers: [WorkOrdersService],
})
export class WorkOrdersModule {}
