# Security

What StockFlow protects, how, and the known limits. StockFlow is a
portfolio/demo project that runs locally; the limits below matter if it were
ever exposed to the internet.

## Authentication

- Email + password, hashed with **bcrypt** (cost 10). The hash is never
  returned by the API (tested).
- Login returns a **JWT** (HS256, `JWT_SECRET`, expiry `JWT_EXPIRES_IN`,
  default 1 day). Every route requires it unless marked `@Public()`
  (`/auth/login`, `/auth/register`, `/health`).
- The app stores the token in **flutter_secure_storage** (Android Keystore /
  iOS Keychain), not in SharedPreferences or SQLite.
- Any `401` from the API signs the user out in the app.
- Self-registration always creates `STAFF`; admins are seeded.

## Authorization

Checked **on the server** for every request (`JwtAuthGuard` → `RolesGuard`),
never only in the UI:

Roles: `ADMIN` (manager), `STAFF` (warehouse), `TECHNICIAN`, `SUPERVISOR`.

| Action | Who |
|---|---|
| View products, scan | all roles |
| Create stock drafts, cancel own drafts | ADMIN, STAFF |
| View stock documents, dashboard | ADMIN, STAFF, SUPERVISOR |
| Confirm a document (changes stock) | ADMIN |
| Create/edit/delete products, categories; audit | ADMIN |
| Stock document photos | the document's creator or ADMIN; never on cancelled documents |
| View work orders | ADMIN, STAFF, SUPERVISOR: all · TECHNICIAN: **only assigned to them** (others → 404) |
| Create, assign, cancel work orders | ADMIN |
| Start, checklist, photos, submit | the assigned TECHNICIAN, only while the state allows |
| Approve / request changes | SUPERVISOR (only the named one if set) or ADMIN |

Work-order rules live in pure functions (`work-order-logic.ts`) used for both
the API checks and the `allowedActions` the app receives, so the UI and the
server can't disagree. Every transition re-checks the current status inside
the database update.

All of these are covered by API tests (see [testing.md](testing.md)).

## Input validation

- Global `ValidationPipe` with `whitelist` + `forbidNonWhitelisted`:
  unexpected fields are rejected (e.g. a client can't send `onHand`).
- Types, enums, UUIDs, integer quantities and per-type quantity rules are
  validated; referenced products must exist.
- Stock can only change through a confirmed document, inside a database
  transaction with a conditional update, so it can't go negative, even with
  concurrent requests.

## File uploads (evidence photos)

- Direct-to-Cloudinary **signed uploads**: the API secret never leaves the
  server, and the signature response contains no secret (tested).
- The signature covers `folder` (one per transaction), `timestamp`,
  `allowed_formats` (jpg, jpeg, png, webp, heic) and an incoming
  `c_limit,w_2000,h_2000` transformation. Changing or dropping any of them
  invalidates the signature. Cloudinary rejects signatures older than one
  hour.
- Before saving, the API checks the reported image is `https`, on
  `res.cloudinary.com`, in **our** account and in **this transaction's**
  folder, with no path traversal. Arbitrary URLs can't be attached.
- At most 5 photos per stock document and 10 per work order (folder
  `stockflow/work-orders/<id>`, same checks). Deleting a photo also deletes
  the asset.

## Abuse protection

- Rate limit per client: `RATE_LIMIT_PER_MINUTE` (default 120), and
  `LOGIN_RATE_LIMIT_PER_MINUTE` (default 10) on login/register to slow
  password guessing (`429`, tested).
- Errors don't expose internals: unexpected errors return a generic `500`
  (Nest default); Prisma/stack details stay in server logs.

## Logging

One line per request: method, path, status, duration, user id. Headers
(including `Authorization`), query strings and bodies are **never** logged,
so tokens, passwords and search terms stay out of logs (verified on a
running instance).

## Secrets

- `backend/.env` is git-ignored; `.env.example` has placeholders only. No
  tracked file contains a real secret (checked before each commit).
- The mobile app contains no secrets; only the API URL.
- Seeded demo passwords are for local demos only.

## Known limits

These are acceptable for a local demo, not for a public deployment:

- **HTTP, not HTTPS**: the demo API runs on the LAN, and the Android app
  allows cleartext traffic for that. A deployment needs TLS and should remove
  `usesCleartextTraffic`.
- **CORS is open by default**; set `CORS_ORIGINS` for a deployed web client
  (the mobile app does not need CORS).
- **No refresh tokens or server-side revocation**: logout deletes the token
  on the device; a stolen token stays valid until it expires.
- **Rate limits are in memory, per instance**: fine for one server, not for
  several behind a load balancer.
- No account lockout, password reset or email verification.
- The APK is signed with the debug key.
- Secrets that were shared while developing (database password, Cloudinary
  API secret) should be rotated before the repository or a demo is made
  public.

## Review (2026-10-12)

Manual review of the API and app after the field-operations work, plus
`npm audit`. Each item lists the evidence and what was done. Automated
tests passing is not proof of security; this is a portfolio-level review,
not a professional audit.

| # | Severity | Finding | Evidence | Status |
|---|---|---|---|---|
| 1 | Medium | Anyone could create an account: `POST /auth/register` was public and creates `STAFF` (can create stock drafts and upload photos) | `auth.controller.ts` `@Public()` register; schema default role `STAFF` | **Fixed**: off unless `ALLOW_REGISTRATION=true` (403 otherwise); API test added |
| 2 | Low | A deployment could start with the example JWT secret | `.env.example` has `change-me`; nothing checked it | **Fixed**: with `NODE_ENV=production` the API refuses to start unless the secret has 32+ characters |
| 3 | Low | CORS allowed every origin | `app.enableCors()` | **Fixed**: `CORS_ORIGINS` allow-list; unset keeps the development behaviour |
| 4 | Low | Swagger (`/docs`) public everywhere, listing every route | `main.ts` | **Fixed**: hidden when `NODE_ENV=production` unless `SWAGGER=true` |
| 5 | Low | Demo account buttons show passwords in every build | `login_screen.dart` | **Fixed**: `--dart-define=DEMO_ACCOUNTS=false` removes them; on by default for the portfolio APK |
| 6 | Low | `npm audit`: 3 high in production dependencies, all through the Prisma CLI (`deepmerge-ts` stack exhaustion, GHSA-ggr8-5vv4-36mx) | `npm audit --omit=dev` | **Accepted for now**: the CLI runs migrations with our own schema, never untrusted input; the fix needs Prisma 7 (major). Revisit when upgrading |
| 7 | Low | Tokens can't be revoked (1-day JWT, no refresh) | `auth.module.ts` | Known limit (above) |
| 8 | Info | No security headers (helmet) | `main.ts` | JSON-only API, low value; add with a reverse proxy/TLS on deployment |

Checked and found in place (with tests): every route behind the JWT guard
unless `@Public`; role checks on stock confirm, work-order actions and
reviews; resource-level checks (other technicians' jobs, notifications and
photos return 404); state changes only through explicit transitions with
conditional updates; signed uploads limited to format/size/folder and
validated again on save; idempotent `clientUuid` creates; rate limits on
login; request logs without tokens, bodies or upload signatures; no secrets
in the app or tracked files; offline data limited to what the user could
already see (no tokens in SQLite; the token stays in secure storage).
