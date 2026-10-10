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
- **CORS is open** (`enableCors()` with defaults). Restrict origins if a web
  client is deployed.
- **No refresh tokens or server-side revocation**: logout deletes the token
  on the device; a stolen token stays valid until it expires.
- **Rate limits are in memory, per instance**: fine for one server, not for
  several behind a load balancer.
- No account lockout, password reset or email verification.
- The APK is signed with the debug key.
- Secrets that were shared while developing (database password, Cloudinary
  API secret) should be rotated before the repository or a demo is made
  public.
