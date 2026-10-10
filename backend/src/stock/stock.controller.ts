import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';
import type { AuthUser } from '../auth/decorators/index.js';
import { CurrentUser, Roles } from '../auth/decorators/index.js';
import { CreateTxDto, PageQueryDto, TxQueryDto } from './dto/stock.dto.js';
import { StockService } from './stock.service.js';

@ApiTags('stock')
@ApiBearerAuth()
@Controller()
export class StockController {
  constructor(private readonly stock: StockService) {}

  @Roles(Role.ADMIN, Role.STAFF)
  @Post('transactions')
  create(@Body() dto: CreateTxDto, @CurrentUser() user: AuthUser) {
    return this.stock.create(dto, user);
  }

  @Roles(Role.ADMIN, Role.STAFF, Role.SUPERVISOR)
  @Get('transactions')
  findAll(@Query() query: TxQueryDto) {
    return this.stock.findAll(query);
  }

  @Roles(Role.ADMIN, Role.STAFF, Role.SUPERVISOR)
  @Get('transactions/:id')
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.stock.findOne(id);
  }

  @Roles(Role.ADMIN)
  @Post('transactions/:id/confirm')
  @HttpCode(200)
  confirm(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: AuthUser,
  ) {
    return this.stock.confirm(id, user);
  }

  @Roles(Role.ADMIN, Role.STAFF)
  @Post('transactions/:id/cancel')
  @HttpCode(200)
  cancel(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: AuthUser,
  ) {
    return this.stock.cancel(id, user);
  }

  @Get('products/:id/movements')
  movements(
    @Param('id', ParseUUIDPipe) id: string,
    @Query() { page, limit }: PageQueryDto,
  ) {
    return this.stock.productMovements(id, page, limit);
  }

  @Roles(Role.ADMIN)
  @Get('products/:id/audit')
  audit(@Param('id', ParseUUIDPipe) id: string) {
    return this.stock.auditProduct(id);
  }
}
