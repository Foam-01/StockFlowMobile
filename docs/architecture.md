# Architecture

**English** | [ภาษาไทย](architecture.th.md)

## System overview

```mermaid
flowchart LR
  subgraph Phone["Flutter app"]
    UI["Screens<br/>(Riverpod + go_router)"]
    Repo["Repositories<br/>(Dio + JWT interceptor)"]
    Cam["Camera<br/>scanner · photos"]
    UI --> Repo
    Cam --> UI
  end

  subgraph API["NestJS API"]
    Guards["JwtAuthGuard → RolesGuard"]
    Modules["auth · products · stock<br/>dashboard · attachments"]
    Logic["Pure domain logic<br/>(stock rules, ledger, flow)"]
    Prisma["Prisma client<br/>+ retry on transient errors"]
    Guards --> Modules --> Logic
    Modules --> Prisma
  end

  DB[("Neon<br/>PostgreSQL")]
  CDN[("Cloudinary<br/>images")]

  Repo -- "REST + Bearer JWT" --> Guards
  Prisma --> DB
  Repo -- "signed direct upload" --> CDN
  Modules -. "sign / verify / delete" .-> CDN
```

- The app only talks to the API (plus direct image uploads). No database
  credentials or Cloudinary secret are ever on the phone.
- **Business rules live in the API**, in plain functions with no Nest/Prisma
  imports (`stock-logic.ts`, `dashboard-logic.ts`, `cloudinary.ts`) so they
  are easy to unit test.

## Stock is a ledger

`products.onHand` is a cache. The source of truth is the sum of **confirmed**
transaction lines:

| Type | Effect on stock |
|---|---|
| `RECEIVE` | `+quantity` |
| `ISSUE` | `−quantity` |
| `ADJUST` | signed `quantity` (correction after a count) |

`GET /products/:id/audit` recomputes the ledger and compares it with
`onHand`; `GET /products/:id/movements` returns each movement with the
running balance, ordered by **confirmation** time.

### Confirming a document

```mermaid
sequenceDiagram
  autonumber
  actor Admin
  participant App
  participant API
  participant DB as PostgreSQL

  Admin->>App: Confirm
  App->>API: POST /transactions/:id/confirm
  API->>DB: BEGIN
  API->>DB: UPDATE tx SET status=CONFIRMED<br/>WHERE id=:id AND status=DRAFT
  alt 0 rows (already confirmed/cancelled)
    API-->>App: 409 Conflict
  end
  loop each product (net quantity)
    API->>DB: UPDATE product SET onHand = onHand − q<br/>WHERE id=:p AND onHand >= q
    alt 0 rows (not enough stock)
      API->>DB: ROLLBACK
      API-->>App: 400 Insufficient stock
    end
  end
  API->>DB: COMMIT
  API-->>App: 200 confirmed transaction
```

Both guards are **conditional updates**, so two people confirming at the same
time can never double-apply a document or drive stock below zero, without
explicit locks.

### Lifecycle

```mermaid
stateDiagram-v2
  [*] --> DRAFT: create (any user)
  DRAFT --> CONFIRMED: confirm (ADMIN) · applies stock
  DRAFT --> CANCELLED: cancel (creator or ADMIN)
  CONFIRMED --> [*]
  CANCELLED --> [*]
```

Creating a draft with a `clientUuid` the server has already seen returns the
original draft, so a retried request (including the offline queue) never
creates duplicates.

## Evidence photos

```mermaid
sequenceDiagram
  autonumber
  participant App
  participant API
  participant CDN as Cloudinary

  App->>API: POST /transactions/:id/attachments/signature
  API-->>App: folder, timestamp, signature (SHA-1, secret stays on server)
  App->>CDN: upload file + signature
  CDN-->>App: public_id, secure_url
  App->>API: POST /transactions/:id/attachments {publicId, url}
  Note over API: verify host, account,<br/>folder = this transaction
  API-->>App: 201 saved
```

Limits: 5 photos per transaction; only the creator or an admin can add or
delete; not on cancelled transactions. Thumbnails use Cloudinary on-the-fly
transforms (`c_fill,w_300,h_300,q_auto,f_auto`).

## Offline mode

```mermaid
flowchart TD
  Save["Save document"] --> Try{"POST /transactions<br/>(clientUuid)"}
  Try -- "201" --> Done["Open draft"]
  Try -- "network error" --> Q[("SQLite outbox")]
  Try -- "4xx / 5xx" --> Err["Show error, stay on form"]
  Q --> Trig["Trigger: reconnect · app resume ·<br/>login · Sync now"]
  Trig --> Send{"Re-send with<br/>same clientUuid"}
  Send -- "ok (or existing draft)" --> Rm["Remove from outbox"]
  Send -- "network / 5xx" --> Wait["Stop pass, keep pending"]
  Send -- "other 4xx" --> Fail["Mark failed:<br/>retry or discard"]
```

- **Outbox** (`outbox` table): documents saved without a connection, sent
  oldest-first. A network error stops the pass, since everything after it
  would fail too. A rejected item is marked *failed* with the server's reason
  and never blocks the rest of the queue.
- **No duplicates:** the `clientUuid` is created once per form. If the first
  attempt actually reached the server but the response was lost, the retry
  gets the same draft back.
- **Product cache** (`product_cache` table): every product the app sees is
  cached, so search, the item picker and barcode scanning keep working
  offline. Server errors (e.g. 404) are never hidden by the cache.
- Confirming and cancelling stay **online-only** on purpose: they change real
  stock, which needs the server's current balance.

## Data model

```mermaid
erDiagram
  User ||--o{ StockTransaction : creates
  User ||--o{ StockTransaction : confirms
  User ||--o{ Attachment : uploads
  Category ||--o{ Product : groups
  Product ||--o{ StockTransactionItem : "moves in"
  StockTransaction ||--|{ StockTransactionItem : contains
  StockTransaction ||--o{ Attachment : "has photos"

  User {
    uuid id
    string email UK
    string passwordHash
    enum role "ADMIN | STAFF"
  }
  Product {
    uuid id
    string sku UK
    string barcode UK
    int onHand "cache of ledger"
    int minStock
  }
  StockTransaction {
    uuid id
    string clientUuid UK "idempotency"
    enum type "RECEIVE | ISSUE | ADJUST"
    enum status "DRAFT | CONFIRMED | CANCELLED"
    datetime confirmedAt
  }
  StockTransactionItem {
    uuid id
    int quantity
  }
  Attachment {
    uuid id
    string publicId UK
    string url
  }
```

## Mobile app structure

Feature-first, each feature split into `data` (API + DTOs), `domain`
(models, pure rules) and `presentation` (screens + Riverpod providers):

```
lib/
  core/        api client, config (server URL), errors, router, shared widgets
  features/
    auth/ dashboard/ products/ operations/ history/ scanner/ profile/
```

- Every screen handles **loading, empty and error** states with retry.
- Devices and services that can't run in tests (camera, image picker,
  network) sit behind providers that tests override.

## Reliability notes

- **Neon cold starts:** the compute sleeps when idle and drops pooled
  connections. The API retries connection errors (`P1001/P1002/P1017/P2024`)
  with backoff, retries the confirm transaction as a whole, and recycles idle
  connections (`max_idle_connection_lifetime=60`).
- **Time zones:** dashboard day buckets use the phone's UTC offset.
