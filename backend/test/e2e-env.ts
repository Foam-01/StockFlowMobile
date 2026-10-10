/**
 * Environment for API tests. Always a throwaway local database: the setup
 * resets it, so it must never point at a real one.
 */
export const TEST_DATABASE_URL =
  process.env.TEST_DATABASE_URL ??
  'postgresql://test:test@localhost:55432/stockflow_test';

export const e2eEnv = {
  DATABASE_URL: TEST_DATABASE_URL,
  DIRECT_URL: TEST_DATABASE_URL,
  JWT_SECRET: 'e2e-secret',
  JWT_EXPIRES_IN: '1h',
  // Fake account: uploads are verified, never sent to Cloudinary in tests.
  CLOUDINARY_CLOUD_NAME: 'e2e-cloud',
  CLOUDINARY_API_KEY: '000',
  CLOUDINARY_API_SECRET: 'e2e-secret',
};

export function assertLocalDatabase(url: string) {
  const host = new URL(url).hostname;
  if (!['localhost', '127.0.0.1', '::1', 'postgres'].includes(host)) {
    throw new Error(
      `Refusing to run API tests against non-local database host "${host}". ` +
        'Set TEST_DATABASE_URL to a disposable local Postgres.',
    );
  }
}
