import { execSync } from 'node:child_process';
import { assertLocalDatabase, e2eEnv, TEST_DATABASE_URL } from './e2e-env.js';

/**
 * Builds the app and applies all migrations to the (fresh, disposable) test
 * database. Rows are cleared per test file in helpers.ts.
 */
export default function setup() {
  assertLocalDatabase(TEST_DATABASE_URL);
  const env = { ...process.env, ...e2eEnv };
  // On a new database this proves the schema is created by migrations alone.
  execSync('npx prisma migrate deploy', {
    env,
    stdio: 'inherit',
  });
  // Tests boot the compiled app: tsc emits the decorator metadata Nest's DI
  // needs, which Vitest's transpiler does not.
  execSync('npx nest build', { env, stdio: 'inherit' });
}
