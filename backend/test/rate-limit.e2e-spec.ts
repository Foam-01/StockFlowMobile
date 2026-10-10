import { createTestApp, TestContext } from './helpers.js';

// Own app instance with a low login limit (read at request time).
let ctx: TestContext;
const previous = process.env.LOGIN_RATE_LIMIT_PER_MINUTE;

let setupLogins = 0;

beforeAll(async () => {
  ctx = await createTestApp(); // logs in every test user
  setupLogins = Object.keys(ctx.tokens).length;
  // Budget: the setup logins plus 2 more attempts.
  process.env.LOGIN_RATE_LIMIT_PER_MINUTE = String(setupLogins + 2);
});
afterAll(async () => {
  process.env.LOGIN_RATE_LIMIT_PER_MINUTE = previous;
  await ctx?.app.close();
});

it('blocks repeated login attempts with 429', async () => {
  const attempt = () =>
    ctx
      .http()
      .post('/auth/login')
      .send({ email: 'admin@test.dev', password: 'wrong-guess' });

  const statuses: number[] = [];
  for (let i = 0; i < 4; i++) statuses.push((await attempt()).status);
  // The budget runs out on the 3rd attempt.
  expect(statuses).toEqual([401, 401, 429, 429]);
});

it('keeps /health available while login is limited', async () => {
  await ctx.http().get('/health').expect(200);
});
