import {
  BadRequestException,
  Body,
  ConflictException,
  Controller,
  Delete,
  ForbiddenException,
  HttpCode,
  Injectable,
  Logger,
  Module,
  NotFoundException,
  Param,
  ParseUUIDPipe,
  Post,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ApiBearerAuth, ApiProperty, ApiTags } from '@nestjs/swagger';
import { Role, TxStatus } from '@prisma/client';
import { IsString, IsUrl, MaxLength } from 'class-validator';
import type { AuthUser } from '../auth/decorators/index.js';
import { CurrentUser } from '../auth/decorators/index.js';
import { PrismaService } from '../prisma/prisma.service.js';
import {
  CloudinaryConfig,
  signParams,
  uploadParams,
  validateUploadedAsset,
} from './cloudinary.js';

const MAX_PER_TX = 5;

export class SaveAttachmentDto {
  @ApiProperty({ description: 'public_id returned by Cloudinary' })
  @IsString()
  @MaxLength(300)
  publicId: string;

  @ApiProperty({ description: 'secure_url returned by Cloudinary' })
  @IsUrl({ protocols: ['https'], require_protocol: true })
  @MaxLength(1000)
  url: string;
}

@Injectable()
export class AttachmentsService {
  private readonly logger = new Logger(AttachmentsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  private cloudinary(): CloudinaryConfig {
    const cloudName = this.config.get<string>('CLOUDINARY_CLOUD_NAME');
    const apiKey = this.config.get<string>('CLOUDINARY_API_KEY');
    const apiSecret = this.config.get<string>('CLOUDINARY_API_SECRET');
    if (!cloudName || !apiKey || !apiSecret) {
      throw new ServiceUnavailableException(
        'Photo upload is not configured on the server',
      );
    }
    return { cloudName, apiKey, apiSecret };
  }

  /** Loads the transaction and checks the user may change its photos. */
  private async editableTx(txId: string, user: AuthUser) {
    const tx = await this.prisma.db.stockTransaction.findUnique({
      where: { id: txId },
      include: { _count: { select: { attachments: true } } },
    });
    if (!tx) throw new NotFoundException('Transaction not found');
    if (user.role !== Role.ADMIN && tx.createdById !== user.id) {
      throw new ForbiddenException(
        'Only the creator or an admin can change photos',
      );
    }
    if (tx.status === TxStatus.CANCELLED) {
      throw new ConflictException('Cancelled transactions cannot have photos');
    }
    return tx;
  }

  /** Short-lived signature for a direct upload from the app to Cloudinary. */
  async signUpload(txId: string, user: AuthUser) {
    const { cloudName, apiKey, apiSecret } = this.cloudinary();
    const tx = await this.editableTx(txId, user);
    if (tx._count.attachments >= MAX_PER_TX) {
      throw new ConflictException(
        `At most ${MAX_PER_TX} photos per transaction`,
      );
    }
    const params = uploadParams(txId);
    return {
      cloudName,
      apiKey,
      ...params,
      signature: signParams(params, apiSecret),
      uploadUrl: `https://api.cloudinary.com/v1_1/${cloudName}/image/upload`,
      // Form fields the app must send as-is (all signed).
      fields: {
        ...params,
        api_key: apiKey,
        signature: signParams(params, apiSecret),
      },
    };
  }

  async save(txId: string, dto: SaveAttachmentDto, user: AuthUser) {
    const { cloudName } = this.cloudinary();
    const tx = await this.editableTx(txId, user);
    if (tx._count.attachments >= MAX_PER_TX) {
      throw new ConflictException(
        `At most ${MAX_PER_TX} photos per transaction`,
      );
    }
    const error = validateUploadedAsset(dto, { cloudName, txId });
    if (error) throw new BadRequestException(error);

    const existing = await this.prisma.db.attachment.findUnique({
      where: { publicId: dto.publicId },
    });
    if (existing) return existing; // retried save after a flaky network

    return this.prisma.db.attachment.create({
      data: {
        transactionId: txId,
        publicId: dto.publicId,
        url: dto.url,
        uploadedById: user.id,
      },
    });
  }

  async remove(txId: string, attachmentId: string, user: AuthUser) {
    const config = this.cloudinary();
    await this.editableTx(txId, user);
    const attachment = await this.prisma.db.attachment.findFirst({
      where: { id: attachmentId, transactionId: txId },
    });
    if (!attachment) throw new NotFoundException('Photo not found');

    await this.prisma.db.attachment.delete({ where: { id: attachment.id } });
    if (attachment.publicId) {
      // Best effort: the record is gone either way.
      await this.destroy(attachment.publicId, config).catch((e) =>
        this.logger.warn(`Cloudinary destroy failed: ${e}`),
      );
    }
  }

  private async destroy(publicId: string, c: CloudinaryConfig) {
    const params = {
      public_id: publicId,
      timestamp: Math.floor(Date.now() / 1000),
    };
    const body = new URLSearchParams({
      ...Object.fromEntries(
        Object.entries(params).map(([k, v]) => [k, String(v)]),
      ),
      api_key: c.apiKey,
      signature: signParams(params, c.apiSecret),
    });
    const res = await fetch(
      `https://api.cloudinary.com/v1_1/${c.cloudName}/image/destroy`,
      { method: 'POST', body },
    );
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
  }
}

@ApiTags('attachments')
@ApiBearerAuth()
@Controller('transactions/:txId/attachments')
export class AttachmentsController {
  constructor(private readonly attachments: AttachmentsService) {}

  @Post('signature')
  @HttpCode(200)
  sign(
    @Param('txId', ParseUUIDPipe) txId: string,
    @CurrentUser() user: AuthUser,
  ) {
    return this.attachments.signUpload(txId, user);
  }

  @Post()
  save(
    @Param('txId', ParseUUIDPipe) txId: string,
    @Body() dto: SaveAttachmentDto,
    @CurrentUser() user: AuthUser,
  ) {
    return this.attachments.save(txId, dto, user);
  }

  @Delete(':id')
  @HttpCode(204)
  remove(
    @Param('txId', ParseUUIDPipe) txId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: AuthUser,
  ) {
    return this.attachments.remove(txId, id, user);
  }
}

@Module({
  controllers: [AttachmentsController],
  providers: [AttachmentsService],
})
export class AttachmentsModule {}
