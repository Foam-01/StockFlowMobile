import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AttachmentsModule } from './attachments/attachments.module.js';
import { AuthModule } from './auth/auth.module.js';
import { CategoriesModule } from './categories/categories.module.js';
import { DashboardModule } from './dashboard/dashboard.module.js';
import { HealthController } from './health.controller.js';
import { PrismaModule } from './prisma/prisma.module.js';
import { ProductsModule } from './products/products.module.js';
import { StockModule } from './stock/stock.module.js';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    AuthModule,
    CategoriesModule,
    ProductsModule,
    StockModule,
    DashboardModule,
    AttachmentsModule,
  ],
  controllers: [HealthController],
})
export class AppModule {}
