# StockFlow Mobile

**English** | [ภาษาไทย](README.th.md)

[![CI](https://github.com/Foam-01/StockFlowMobile/actions/workflows/ci.yml/badge.svg)](https://github.com/Foam-01/StockFlowMobile/actions/workflows/ci.yml)

A mobile inventory app for receiving, issuing and adjusting stock: barcode
scanning, photo evidence, a live dashboard and a full, auditable movement
history per product.

- **Mobile:** Flutter · Riverpod · go_router · Dio · mobile_scanner · sqflite
- **Backend:** NestJS · Prisma · PostgreSQL (Neon) · JWT · Cloudinary
- Built as a portfolio / demo project, run locally

| Dashboard | Products | Product & history |
|---|---|---|
| <img src="docs/screenshots/dashboard.png" width="250" alt="Dashboard"> | <img src="docs/screenshots/products.png" width="250" alt="Products"> | <img src="docs/screenshots/product-detail.png" width="250" alt="Product detail with movements"> |

| Operations | New document | Sign in |
|---|---|---|
| <img src="docs/screenshots/operations.png" width="250" alt="Stock operations"> | <img src="docs/screenshots/new-operation.png" width="250" alt="New issue form"> | <img src="docs/screenshots/login.png" width="250" alt="Sign in"> |

## Features

- **Roles:** JWT login with `ADMIN` / `STAFF`; the token is kept in secure storage
- **Dashboard:** stock KPIs, received vs issued over the last 7 days, products that need attention, recent activity
- **Products:** search, category and low-stock filters, stock-level badges, infinite scroll
- **Barcode scanner:** scan to open a product, or scan items into a document (re-scan adds +1)
- **Stock documents:** `RECEIVE`, `ISSUE` and `ADJUST`; `DRAFT` → `CONFIRMED` / `CANCELLED`
  - stock only changes on confirm (admin), and can never be issued below zero, even with concurrent confirms
  - resending a document with the same `clientUuid` never creates a duplicate
- **Evidence photos:** camera or gallery, uploaded straight to Cloudinary with server-signed requests
- **Offline mode:** documents saved without a connection are queued in SQLite and synced automatically (no duplicates); products stay searchable and scannable offline
- **History & audit:** movements per product with running balance; ledger vs cached stock check
- Loading, empty and error states with retry on every screen
- API docs via Swagger

See **[docs/architecture.md](docs/architecture.md)** for diagrams: system overview, confirm flow, upload flow, offline sync and data model.

## Project structure

```
.
├── .github/workflows/ci.yml   # backend + Flutter checks, release APK
├── backend/   # NestJS API
│   ├── prisma/          # schema, migrations, seed, demo history
│   └── src/             # auth, products, stock, dashboard, attachments
├── docs/      # architecture diagrams
└── mobile/    # Flutter app
    └── lib/
        ├── core/        # api client, server URL config, router, widgets
        └── features/    # auth, dashboard, products, operations, history, scanner, offline, profile
```

## Getting started

### Prerequisites

- Node.js 22+ (CI uses 24)
- Flutter 3.47+ (Dart 3.13)
- A PostgreSQL database ([Neon](https://neon.tech) has a free tier)
- A [Cloudinary](https://cloudinary.com) account for photos (optional; free tier)
- An Android phone or emulator

### 1. Backend

```bash
cd backend
npm install
cp .env.example .env      # fill in DATABASE_URL, DIRECT_URL, JWT_SECRET, CLOUDINARY_*
npx prisma migrate deploy
npx prisma db seed        # demo accounts and products
npm run seed:history      # optional: 6 days of demo movements for the dashboard
npm run start:dev
```

- API: `http://localhost:3000`
- Swagger: `http://localhost:3000/docs`
- Health check: `http://localhost:3000/health`

Without `CLOUDINARY_*`, everything works except photo upload, which reports
"not configured". `seed:history` is safe to re-run: it replaces its own
demo rows and keeps the ledger consistent.

**Demo accounts** (passwords come from `SEED_ADMIN_PASSWORD` / `SEED_STAFF_PASSWORD` in `.env`)

| Email | Role | Can |
|---|---|---|
| `admin@stockflow.dev` | ADMIN | everything, including confirming documents and editing products |
| `staff@stockflow.dev` | STAFF | create drafts, scan, attach photos to own documents |

### 2. Mobile

```bash
cd mobile
flutter pub get
flutter run
```

**Server address.** On the login screen, tap **Server** to set the API URL and
**Test connection**. The setting is saved on the device.

| Running on | API URL |
|---|---|
| Android emulator | `http://10.0.2.2:3000` (default) |
| Web / desktop | `http://localhost:3000` (default) |
| Physical phone | `http://<your PC's Wi-Fi IP>:3000` |

For a physical phone: same Wi-Fi as the PC, and allow inbound TCP 3000 in the
PC's firewall. You can also bake the URL in at build time with
`--dart-define=API_URL=http://192.168.1.10:3000`.

### APK

Every push to `main` builds a release APK in GitHub Actions. Download it from
the **stockflow-apk** artifact of the latest
[CI run](https://github.com/Foam-01/StockFlowMobile/actions/workflows/ci.yml).
To build one locally:

```bash
cd mobile
flutter build apk --release   # build/app/outputs/flutter-apk/app-release.apk
```

The APK is signed with the debug key, which is fine for a demo install but
not for Play Store release.

## Main API endpoints

| Method | Path | Description |
|---|---|---|
| POST | `/auth/login` | Log in |
| GET | `/auth/me` | Current user |
| GET | `/dashboard` | KPIs, 7-day flow, needs attention, recent activity |
| GET | `/products` | List / search / filter products |
| GET | `/products/barcode/:barcode` | Find a product by barcode |
| POST / PATCH / DELETE | `/products/:id` | Manage products (admin) |
| POST | `/transactions` | Create a draft (idempotent with `clientUuid`) |
| GET | `/transactions` | List documents |
| POST | `/transactions/:id/confirm` | Confirm, which applies stock (admin) |
| POST | `/transactions/:id/cancel` | Cancel a draft |
| POST | `/transactions/:id/attachments/signature` | Sign a photo upload |
| POST / DELETE | `/transactions/:id/attachments` | Save / delete a photo |
| GET | `/products/:id/movements` | Movement history with running balance |
| GET | `/products/:id/audit` | Ledger vs cached stock (admin) |
| GET | `/health` | Liveness check (no auth) |

See Swagger at `/docs` for the full reference.

## Tests

```bash
cd backend && npm test          # unit tests (Vitest): stock rules, ledger, dashboard, signing, retry
cd mobile && flutter test       # widget / unit tests for every screen and flow
```

CI runs typecheck, lint, tests and build for the backend, plus format check,
analyze and tests for the app, on every push and pull request.

## Demo

<!-- Add a short screen recording link here (e.g. YouTube / Google Drive). -->
_Demo video coming soon._
