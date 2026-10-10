import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { TxStatus, TxType } from '@prisma/client';
import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  Min,
  ValidateNested,
} from 'class-validator';

export class TxItemDto {
  @ApiProperty()
  @IsUUID()
  productId: string;

  @ApiProperty({
    example: 5,
    description: 'Positive for RECEIVE/ISSUE; signed delta for ADJUST',
  })
  @IsInt()
  quantity: number;
}

export class CreateTxDto {
  @ApiProperty({ enum: TxType })
  @IsEnum(TxType)
  type: TxType;

  @ApiPropertyOptional({
    description: 'Client-generated id; resending the same id is idempotent',
  })
  @IsOptional()
  @IsUUID()
  clientUuid?: string;

  @ApiPropertyOptional({
    description:
      'Work order these materials are issued for (ISSUE) or returned from (RECEIVE)',
  })
  @IsOptional()
  @IsUUID()
  workOrderId?: string;

  @ApiPropertyOptional({ example: 'PO-2026-0001' })
  @IsOptional()
  @IsString()
  referenceNo?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  note?: string;

  @ApiProperty({ type: [TxItemDto] })
  @ValidateNested({ each: true })
  @ArrayMinSize(1)
  @Type(() => TxItemDto)
  items: TxItemDto[];
}

export class TxQueryDto {
  @ApiPropertyOptional({ enum: TxType })
  @IsOptional()
  @IsEnum(TxType)
  type?: TxType;

  @ApiPropertyOptional({ enum: TxStatus })
  @IsOptional()
  @IsEnum(TxStatus)
  status?: TxStatus;

  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID()
  productId?: string;

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

export class PageQueryDto {
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
