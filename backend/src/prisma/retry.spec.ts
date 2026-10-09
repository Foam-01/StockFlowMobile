import { Prisma } from '@prisma/client';
import { isTransientDbError, withRetry } from './retry.js';

const prismaError = (code: string) =>
  new Prisma.PrismaClientKnownRequestError('db error', {
    code,
    clientVersion: 'test',
  });

describe('isTransientDbError', () => {
  it('matches connection errors only', () => {
    expect(isTransientDbError(prismaError('P1017'))).toBe(true);
    expect(isTransientDbError(prismaError('P1001'))).toBe(true);
    expect(isTransientDbError(prismaError('P2002'))).toBe(false); // unique violation
    expect(isTransientDbError(new Error('boom'))).toBe(false);
  });
});

describe('withRetry', () => {
  const fast = { baseDelayMs: 1 };

  it('retries transient errors and returns the result', async () => {
    const fn = vi
      .fn()
      .mockRejectedValueOnce(prismaError('P1017'))
      .mockRejectedValueOnce(prismaError('P1017'))
      .mockResolvedValue('ok');
    await expect(withRetry(fn, fast)).resolves.toBe('ok');
    expect(fn).toHaveBeenCalledTimes(3);
  });

  it('does not retry business errors', async () => {
    const fn = vi.fn().mockRejectedValue(prismaError('P2002'));
    await expect(withRetry(fn, fast)).rejects.toMatchObject({ code: 'P2002' });
    expect(fn).toHaveBeenCalledTimes(1);
  });

  it('gives up after the retry limit', async () => {
    const fn = vi.fn().mockRejectedValue(prismaError('P1017'));
    await expect(withRetry(fn, { ...fast, retries: 2 })).rejects.toMatchObject({
      code: 'P1017',
    });
    expect(fn).toHaveBeenCalledTimes(3);
  });
});
