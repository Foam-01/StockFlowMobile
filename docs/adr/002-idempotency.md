# ADR 002: Client-generated `clientUuid` as an idempotency key

**Status:** accepted

## Context

A mobile client retries: after a timeout, a lost response, an app restart
or an offline sync. Without protection, every retry of "create document"
would create another document.

## Decision

- The app generates a UUID **once per form** and sends it as `clientUuid`.
- `StockTransaction.clientUuid` is **unique** in the database.
- `POST /transactions` with a known `clientUuid` from the **same user**
  returns the existing draft (no new row). From another user: `409`.
- Racing duplicates are resolved by the unique constraint: one insert wins.

## Alternatives considered

- **`Idempotency-Key` header + separate key store:** more general (works for
  any endpoint), but needs extra storage and expiry. Only document creation
  needs it here.
- **Deduplicate by content (same items, same time):** unreliable; two real
  identical deliveries are legitimate.
- **Server-generated ids only:** the client can't know whether a lost request
  succeeded.

## Consequences

- Safe retries everywhere, including the offline outbox (see
  [offline-sync.md](../offline-sync.md)).
- Tested: sequential and 5 parallel requests with the same key create one
  document; another user's key → 409.
