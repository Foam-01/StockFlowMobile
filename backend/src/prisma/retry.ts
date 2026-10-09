import { Prisma } from '@prisma/client';

/**
 * Connection-level errors that are safe to retry. Neon suspends its compute
 * when idle, which closes pooled connections; the first query after that
 * fails with one of these and succeeds on retry.
 */
const TRANSIENT_CODES = new Set([
  'P1001', // can't reach database server
  'P1002', // database server timed out
  'P1017', // server has closed the connection
  'P2024', // timed out fetching a connection from the pool
]);

export function isTransientDbError(e: unknown): boolean {
  if (e instanceof Prisma.PrismaClientKnownRequestError) {
    return TRANSIENT_CODES.has(e.code);
  }
  if (e instanceof Prisma.PrismaClientInitializationError) {
    return e.errorCode ? TRANSIENT_CODES.has(e.errorCode) : false;
  }
  return false;
}

export async function withRetry<T>(
  fn: () => Promise<T>,
  { retries = 3, baseDelayMs = 300 } = {},
): Promise<T> {
  for (let attempt = 0; ; attempt++) {
    try {
      return await fn();
    } catch (e) {
      if (attempt >= retries || !isTransientDbError(e)) throw e;
      // 300ms, 600ms, 1200ms — enough for a Neon compute to wake up.
      await new Promise((r) => setTimeout(r, baseDelayMs * 2 ** attempt));
    }
  }
}
