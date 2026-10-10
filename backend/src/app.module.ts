import { MiddlewareConsumer, Module, NestModule } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { APP_FILTER, APP_GUARD, APP_INTERCEPTOR } from '@nestjs/core';
import {
  LocalizedErrorFilter,
  LocalizedResponseInterceptor,
} from './common/i18n.js';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { AttachmentsModule } from './attachments/attachments.module.js';
import { AuthModule } from './auth/auth.module.js';
import { CategoriesModule } from './categories/categories.module.js';
import { RequestLoggerMiddleware } from './common/request-logger.middleware.js';
import { DashboardModule } from './dashboard/dashboard.module.js';
import { HealthController } from './health.controller.js';
import { PrismaModule } from './prisma/prisma.module.js';
import { ProductsModule } from './products/products.module.js';
import { StockModule } from './stock/stock.module.js';
import { UsersModule } from './users/users.module.js';
import { WorkOrdersModule } from './work-orders/work-orders.module.js';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    // Per-client request budget; tighter limits on login (see AuthController).
    ThrottlerModule.forRoot([
      {
        ttl: 60_000,
        limit: () => Number(process.env.RATE_LIMIT_PER_MINUTE ?? 120),
      },
    ]),
    PrismaModule,
    AuthModule,
    CategoriesModule,
    ProductsModule,
    StockModule,
    DashboardModule,
    AttachmentsModule,
    WorkOrdersModule,
    UsersModule,
  ],
  controllers: [HealthController],
  providers: [
    { provide: APP_GUARD, useClass: ThrottlerGuard },
    { provide: APP_FILTER, useClass: LocalizedErrorFilter },
    { provide: APP_INTERCEPTOR, useClass: LocalizedResponseInterceptor },
  ],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(RequestLoggerMiddleware).forRoutes('*path');
  }
}
