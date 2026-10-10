# ADR 001: SQLite outbox for offline documents

**Status:** accepted

## Context

Stock is often received or issued where the connection is poor (back of a
warehouse, loading bay). Users must be able to record a document without a
connection and have it reach the server later, without duplicates.

## Decision

- Store unsent documents in a local **SQLite** table (`outbox`, via
  `sqflite`) and cache products in `product_cache`.
- Only **drafts** are created offline. Confirming (which changes stock)
  stays online.
- Sync oldest-first with a simple engine (`SyncEngine`): stop on network/5xx,
  mark other 4xx as failed and continue.

## Alternatives considered

- **SharedPreferences / JSON file:** simple, but no queries or indexes, and
  rewriting a whole file on every change is fragile.
- **Hive / Isar / Drift:** good options. SQLite via `sqflite` was chosen for
  a small, well-known dependency with a plain SQL schema that is easy to
  explain and to test with in-memory SQLite.
- **Full offline-first sync (e.g. CRDTs, a sync service):** far beyond what a
  draft queue needs.
- **Allow offline confirm:** rejected; two devices could each confirm
  against a stale balance and over-issue stock.

## Consequences

- Simple and testable; covered by unit and widget tests.
- Stock shown offline can be stale; the server re-checks on confirm.
- No background sync while the app is closed.
