import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service.js';
import {
  CreateProductDto,
  ProductQueryDto,
  UpdateProductDto,
} from './dto/product.dto.js';

@Injectable()
export class ProductsService {
  constructor(private readonly prisma: PrismaService) {}

  async findAll({ q, categoryId, lowStock, page, limit }: ProductQueryDto) {
    const where: Prisma.ProductWhereInput = {
      categoryId,
      ...(q && {
        OR: [
          { name: { contains: q, mode: 'insensitive' } },
          { sku: { contains: q, mode: 'insensitive' } },
          { barcode: { contains: q } },
        ],
      }),
      ...(lowStock && {
        onHand: { lte: this.prisma.db.product.fields.minStock },
      }),
    };

    const [items, total] = await Promise.all([
      this.prisma.db.product.findMany({
        where,
        include: { category: true },
        orderBy: { name: 'asc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
      this.prisma.db.product.count({ where }),
    ]);
    return { items, total, page, limit };
  }

  async findOne(id: string) {
    const product = await this.prisma.db.product.findUnique({
      where: { id },
      include: { category: true },
    });
    if (!product) throw new NotFoundException('Product not found');
    return product;
  }

  async findByBarcode(barcode: string) {
    const product = await this.prisma.db.product.findUnique({
      where: { barcode },
      include: { category: true },
    });
    if (!product) throw new NotFoundException('No product with this barcode');
    return product;
  }

  create(dto: CreateProductDto) {
    return this.write(() => this.prisma.db.product.create({ data: dto }));
  }

  async update(id: string, dto: UpdateProductDto) {
    await this.findOne(id);
    return this.write(() =>
      this.prisma.db.product.update({ where: { id }, data: dto }),
    );
  }

  async remove(id: string) {
    await this.findOne(id);
    await this.write(() => this.prisma.db.product.delete({ where: { id } }));
  }

  /** Map Prisma constraint errors to HTTP errors. */
  private async write<T>(op: () => Promise<T>): Promise<T> {
    try {
      return await op();
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError) {
        if (e.code === 'P2002') {
          throw new ConflictException(
            `Duplicate value for ${(e.meta?.target as string[])?.join(', ')}`,
          );
        }
        if (e.code === 'P2003') {
          throw new ConflictException(
            'Invalid category, or product is referenced by stock transactions',
          );
        }
      }
      throw e;
    }
  }
}
