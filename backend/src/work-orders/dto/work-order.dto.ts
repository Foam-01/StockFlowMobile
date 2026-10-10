import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  EvidenceCategory,
  WorkOrderPriority,
  WorkOrderStatus,
} from '@prisma/client';
import { Transform, Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayUnique,
  IsArray,
  IsBoolean,
  IsDateString,
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUrl,
  IsUUID,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';

export class MaterialDto {
  @ApiProperty()
  @IsUUID()
  productId: string;

  @ApiProperty({ example: 2 })
  @IsInt()
  @Min(1)
  @Max(100_000)
  plannedQty: number;
}

export class CreateWorkOrderDto {
  @ApiPropertyOptional({ description: 'Makes retries safe (idempotency key)' })
  @IsOptional()
  @IsUUID()
  clientUuid?: string;

  @ApiProperty({ example: 'Install split-type air conditioner' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  title: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  description?: string;

  @ApiProperty({ example: 'Sukhumvit office, 3rd floor' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  siteName: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(300)
  siteAddress?: string;

  @ApiPropertyOptional({ enum: WorkOrderPriority, default: 'NORMAL' })
  @IsOptional()
  @IsEnum(WorkOrderPriority)
  priority?: WorkOrderPriority;

  @ApiPropertyOptional({ example: '2026-10-20T09:00:00.000Z' })
  @IsOptional()
  @IsDateString()
  dueAt?: string;

  @ApiPropertyOptional({ description: 'TECHNICIAN user id' })
  @IsOptional()
  @IsUUID()
  assigneeId?: string;

  @ApiPropertyOptional({ description: 'Specific SUPERVISOR; otherwise any' })
  @IsOptional()
  @IsUUID()
  reviewerId?: string;

  @ApiPropertyOptional({ description: 'Checklist template to copy' })
  @IsOptional()
  @IsUUID()
  templateId?: string;

  @ApiPropertyOptional({ enum: EvidenceCategory, isArray: true })
  @IsOptional()
  @IsArray()
  @ArrayUnique()
  @IsEnum(EvidenceCategory, { each: true })
  requiredEvidence?: EvidenceCategory[];

  @ApiPropertyOptional({ type: [MaterialDto] })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(50)
  @ValidateNested({ each: true })
  @Type(() => MaterialDto)
  materials?: MaterialDto[];
}

export class AssignDto {
  @ApiPropertyOptional({
    description: 'TECHNICIAN user id, or null to unassign',
    nullable: true,
  })
  @IsOptional()
  @IsUUID()
  assigneeId?: string | null;

  @ApiPropertyOptional({
    description: 'SUPERVISOR user id, or null for any',
    nullable: true,
  })
  @IsOptional()
  @IsUUID()
  reviewerId?: string | null;
}

export class ChecklistUpdateDto {
  @ApiProperty()
  @IsBoolean()
  done: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  note?: string;
}

export class ReasonDto {
  @ApiProperty({ example: 'After photo does not show the outdoor unit' })
  @IsString()
  @MinLength(5)
  @MaxLength(1000)
  reason: string;
}

export class ApproveDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  note?: string;
}

export class EvidenceSignatureDto {
  @ApiProperty({ enum: EvidenceCategory })
  @IsEnum(EvidenceCategory)
  category: EvidenceCategory;
}

export class SaveEvidenceDto {
  @ApiProperty({ enum: EvidenceCategory })
  @IsEnum(EvidenceCategory)
  category: EvidenceCategory;

  @ApiProperty()
  @IsString()
  @MaxLength(300)
  publicId: string;

  @ApiProperty()
  @IsUrl({ protocols: ['https'], require_protocol: true })
  @MaxLength(1000)
  url: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;
}

export class WorkOrderQueryDto {
  @ApiPropertyOptional({ enum: WorkOrderStatus, isArray: true })
  @IsOptional()
  @Transform(({ value }) =>
    typeof value === 'string' ? value.split(',') : value,
  )
  @IsArray()
  @IsEnum(WorkOrderStatus, { each: true })
  status?: WorkOrderStatus[];

  @ApiPropertyOptional({ enum: WorkOrderPriority })
  @IsOptional()
  @IsEnum(WorkOrderPriority)
  priority?: WorkOrderPriority;

  @ApiPropertyOptional({ description: 'Search code, title or site' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  q?: string;

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
  @Max(100)
  limit = 20;
}
