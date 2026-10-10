# ADR 003: Conditional updates for stock concurrency

**Status:** accepted

## Context

Two admins can confirm issues for the same product at the same time. A
plain "read balance → check → write balance" inside a transaction is **not**
enough under PostgreSQL's default READ COMMITTED isolation: both requests can
read the same balance, both pass the check, and stock goes negative. The same
race can also apply one document twice.

## Decision

Inside one database transaction, confirming a document:

1. **Claims the document** with a conditional update:
   `UPDATE … SET status = CONFIRMED WHERE id = :id AND status = DRAFT`.
   0 rows → someone else confirmed or cancelled it → `409`.
2. **Decrements stock conditionally** for each product:
   `UPDATE product SET onHand = onHand − q WHERE id = :p AND onHand >= q`.
   0 rows → not enough stock → throw, which **rolls back** the whole
   transaction (including step 1) → `400`.
3. Increments need no condition.

The row-level write locks taken by these `UPDATE`s serialise concurrent
confirms for the same rows; the `WHERE` re-check after the lock makes the
outcome correct without explicit `SELECT … FOR UPDATE` or SERIALIZABLE
isolation.

`products.onHand` is a cache; the source of truth is the ledger (sum of
confirmed lines). `GET /products/:id/audit` recomputes and compares them.

## Alternatives considered

- **`SELECT … FOR UPDATE` then check in code:** also correct, more round
  trips and easy to get wrong (forgetting a lock).
- **SERIALIZABLE isolation + retry on serialization failure:** correct but
  needs retry logic for every conflict.
- **No cached balance, always sum the ledger:** simplest invariants, but the
  check-then-insert race remains and reads get slower as history grows.

## Consequences

- Verified by API tests against real Postgres: 10 parallel confirms of 3
  units on 10 in stock → exactly 3 succeed, stock ends at 1, ledger
  consistent; 5 parallel confirms of one draft → applied once.
- Verified the test fails if the `onHand >= q` condition is removed.
- A transient database error retries the **whole** transaction, never a
  single statement inside it.
