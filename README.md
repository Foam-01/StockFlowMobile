# StockFlow Mobile

**English** | [ภาษาไทย](README.th.md)

A mobile inventory app for receiving, issuing and adjusting stock, with a full movement history per product.

- **Mobile:** Flutter · Riverpod · go_router · Dio
- **Backend:** NestJS · Prisma · PostgreSQL (Neon) · JWT
- Built as a portfolio / demo project, run locally

## Features

- JWT login with `ADMIN` / `STAFF` roles (token kept in secure storage)
- Product list with search and barcode lookup, plus stock-level badges
- Three kinds of stock documents: `RECEIVE`, `ISSUE` and `ADJUST`
- Documents move from `DRAFT` to `CONFIRMED` or `CANCELLED`; stock changes only on confirm
- Per-product movement history and audit
- API docs via Swagger

## Project structure

```
.
├── backend/   # NestJS API
│   ├── prisma/          # schema, migrations, seed
│   └── src/             # auth, products, categories, stock
└── mobile/    # Flutter app
    └── lib/
        ├── core/        # api client, config, router, token storage
        └── features/    # auth, products, operations, history, profile
```

## Getting started

### Prerequisites

- Node.js 20+
- Flutter SDK (Dart 3.x)
- A PostgreSQL database ([Neon](https://neon.tech) has a free tier)
- Android Studio with an emulator, or an Android phone

### 1. Backend

```bash
cd backend
npm install
cp .env.example .env      # then fill in DATABASE_URL, DIRECT_URL, JWT_SECRET
npx prisma migrate deploy
npx prisma db seed        # creates demo accounts and sample data
npm run start:dev
```

The API runs at `http://localhost:3000`, with Swagger at `http://localhost:3000/docs`.

**Demo accounts** (passwords come from `SEED_ADMIN_PASSWORD` / `SEED_STAFF_PASSWORD` in `.env`)

| Email | Role |
|---|---|
| `admin@stockflow.dev` | ADMIN |
| `staff@stockflow.dev` | STAFF |

### 2. Mobile

```bash
cd mobile
flutter pub get
flutter devices                 # find your device id
flutter run -d emulator-5554    # Android emulator
```

The app picks the API URL automatically (see `mobile/lib/core/config.dart`):

| Running on | API URL |
|---|---|
| Android emulator | `http://10.0.2.2:3000` |
| Web / desktop | `http://localhost:3000` |
| Physical phone | Your PC's LAN IP (same Wi-Fi) |

On a physical phone:

```bash
flutter run --dart-define=API_URL=http://192.168.1.10:3000
```

## Main API endpoints

| Method | Path | Description |
|---|---|---|
| POST | `/auth/login` | Log in |
| GET | `/auth/me` | Current user |
| GET | `/products` | List products |
| GET | `/products/barcode/:barcode` | Find a product by barcode |
| POST / PATCH / DELETE | `/products/:id` | Manage products |
| POST | `/transactions` | Create a document (draft) |
| GET | `/transactions` | List documents |
| POST | `/transactions/:id/confirm` | Confirm a document (applies stock) |
| POST | `/transactions/:id/cancel` | Cancel a document |
| GET | `/products/:id/movements` | Movement history |
| GET | `/products/:id/audit` | Product audit |

See Swagger at `/docs` for the full reference.

## Tests

```bash
cd backend && npm test          # unit tests (Vitest)
cd mobile && flutter test       # widget / unit tests
```
