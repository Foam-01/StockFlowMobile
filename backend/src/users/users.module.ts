import { Controller, Get, Injectable, Module, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiPropertyOptional, ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';
import { IsEnum, IsOptional } from 'class-validator';
import { Roles } from '../auth/decorators/index.js';
import { PrismaService } from '../prisma/prisma.service.js';

export class UserQueryDto {
  @ApiPropertyOptional({ enum: Role })
  @IsOptional()
  @IsEnum(Role)
  role?: Role;
}

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  /** Minimal directory for assignment pickers: no emails or hashes. */
  list(role?: Role) {
    return this.prisma.db.user.findMany({
      where: { role },
      orderBy: { name: 'asc' },
      select: { id: true, name: true, role: true },
    });
  }
}

@ApiTags('users')
@ApiBearerAuth()
@Controller('users')
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Roles(Role.ADMIN)
  @Get()
  list(@Query() { role }: UserQueryDto) {
    return this.users.list(role);
  }
}

@Module({
  controllers: [UsersController],
  providers: [UsersService],
})
export class UsersModule {}
