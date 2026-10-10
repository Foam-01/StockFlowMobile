# Testing

How StockFlow is tested, how to run it, and what is **not** covered yet.

## Summary

| Suite | Where | Count | Runs in CI |
|---|---|---|---|
| Backend unit tests (Vitest) | `backend/src/**/*.spec.ts` | 33 | ✅ |
| Backend API tests (Vitest + supertest, real Postgres) | `backend/test/*.e2e-spec.ts` | 27 | ✅ (Postgres service container) |
| Flutter widget + unit tests | `mobile/test/` | 54 | ✅ |
| Release APK build | `mobile/` | — | ✅ (artifact `stockflow-apk`) |

Counts are from the latest local run; CI runs the same suites on every push
and pull request (`.github/workflows/ci.yml`).

## Running the tests

```bash
# Backend unit tests (no database needed)
cd backend && npm test

# Backend API tests: need a disposable local Postgres
docker run -d --name stockflow-test-db -p 55432:5432 \
  -e POSTGRES_USER=test -e POSTGRES_PASSWORD=test -e POSTGRES_DB=stockflow_test \
  postgres:16-alpine
cd backend && npm run test:e2e

# Flutter
cd mobile && flutter test
```

`npm run test:e2e` applies all migrations to the test database, builds the
app and boots it in-process. It **refuses to run unless the database host is
local** (`localhost`, `127.0.0.1`, `::1` or the CI service `postgres`), so it
can never touch a real database. Override the URL with `TEST_DATABASE_URL`.

## What each suite proves

### Backend unit tests: pure rules, no I/O

| File | Covers |
|---|---|
| `stock/stock-logic.spec.ts` | signed quantities, item validation, net deltas, "never below zero", ledger balance, running balances, allowed status transitions |
| `dashboard/dashboard-logic.spec.ts` | 7-day buckets in the client's time zone, ADJUST excluded, attention ordering |
| `attachments/cloudinary.spec.ts` | signature matches Cloudinary's published example; upload asset validation (host, account, folder, traversal); format/size limits are inside the signature |
| `prisma/retry.spec.ts` | transient DB errors are retried with backoff; business errors are not; retry limit |

### Backend API tests: real HTTP, real Postgres

| Area | Tests |
|---|---|
| Authentication | no token → 401, forged token → 401, wrong password → 401, `/health` public, password hash never returned |
| Authorization | STAFF cannot confirm, create products or audit (403); cannot cancel another user's draft |
| Validation | zero/negative/fractional quantities, empty items, unknown type, unexpected fields, unknown product, malformed ids → 400 |
| Ledger | stock changes only on confirm; `onHand == ledger` after receive/issue/adjust; running balances in order |
| Rollback | multi-line issue where one line lacks stock → 400, **nothing** applied, document stays DRAFT |
| State rules | confirm twice → 409; cancel a confirmed document → 409 |
| Idempotency | same `clientUuid` (sequential and 5 in parallel) → one document; another user can't reuse it (409) |
| **Concurrency** | 10 parallel confirms of 3 units each on 10 in stock → exactly 3 succeed, 7 rejected, 1 left, ledger consistent; 5 parallel confirms of one draft → applied once |
| Evidence photos | only images in this transaction's folder on our account; creator/admin only; not on cancelled documents; signed fields carry the limits and never the secret |
| Rate limiting | repeated wrong logins → 429 while `/health` stays available |

The concurrency test was checked to have teeth: with the conditional stock
update (`WHERE onHand >= qty`) removed, all 10 confirms succeed and the test
fails.

### Flutter tests

| File | Covers |
|---|---|
| `widget_test.dart` | login validation, server errors, sign in/out, session restore; product list, search debounce, filters, empty/error/retry, detail |
| `operations_test.dart` | list, creating an issue (blocked above stock on hand), admin confirm, failed confirm |
| `draft_test.dart` | client-side rules per document type, projected stock |
| `history_test.dart` | recent movements, paged history, retry |
| `scanner_test.dart` | scan opens product, unknown barcode, cancel, scan-to-add increments |
| `dashboard_test.dart` | KPIs, chart readout per day, table view, deep links to filtered lists, error/retry |
| `evidence_test.dart` | attach from camera, upload failure message, permissions, delete |
| `server_settings_test.dart` | URL normalisation/validation, test connection, save |
| `offline_logic_test.dart` | sync engine rules, SQLite outbox and product cache (in-memory SQLite), offline fallback that never hides server errors |
| `offline_flow_test.dart` | save offline → queued → sync fails → sync succeeds with the **same clientUuid**; rejected item marked failed and discarded; offline banner; server errors not queued |

Camera, image picker and network are behind Riverpod providers that tests
override, so no test needs a device.

## Verified manually (not automated)

- Live Cloudinary upload: `.txt` rejected (400), upload without
  `allowed_formats` rejected (401 invalid signature), PNG accepted, delete
  removes the asset (checked through the Cloudinary Admin API).
- Request logs contain method, path, status, duration and user id only: no
  token, password or search term (checked on a running instance).
- Neon cold start: the first requests after idle used to fail with `P1017`;
  now retried. Covered by unit tests; the real suspend/resume cycle was not
  reproduced on demand.

## Not covered yet

- **On-device testing** (real Android phone): camera permission prompts,
  scanner pause/resume when the app goes to the background, switching
  networks, the offline flow with a real connection drop.
- **End-to-end UI tests** driving the real app against the real API
  (Flutter `integration_test`).
- Load/performance testing beyond the concurrency tests above.
