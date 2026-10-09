import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
import { withRetry } from './retry.js';

@Injectable()
export class PrismaService
  extends PrismaClient
  implements OnModuleInit, OnModuleDestroy
{
  /** Same client, but every query is retried on transient connection errors. */
  readonly db = this.$extends({
    query: {
      $allOperations: ({ args, query }) => withRetry(() => query(args)),
    },
  });

  async onModuleInit() {
    await withRetry(() => this.$connect());
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }
}
