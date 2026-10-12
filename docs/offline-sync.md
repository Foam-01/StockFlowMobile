# Offline sync

How the app keeps working without a connection, and why it never creates
duplicates. Diagram: [architecture.md → Offline mode](architecture.md#offline-mode).

## Scope

| Works offline | Online only (on purpose) |
|---|---|
| Creating RECEIVE / ISSUE / ADJUST **drafts** | Confirming or cancelling a document |
| Viewing a work order **opened before** on this device (saved copy, marked "offline") | Drafts linked to a work order (the queue can't carry the link yet, so they are never queued without it) |
| Ticking / unticking **checklist items** and editing their notes | Start, photos, submit, approve, request changes, cancel, assignment |
| Searching products, picking items, barcode lookup (from cache) | Dashboard, history, photos |

Confirming changes real stock and needs the server's current balance, so it
is never queued. Syncing a draft therefore **does not** change stock; an
admin still confirms it online.

## Storage (SQLite)

| Table | Holds |
|---|---|
| `wo_cache` | last server copy of each work order opened on the device |
| `wo_checklist_ops` | queued checklist edits, one per item, with `expectedDone` and the last refusal |
| `outbox` | documents saved offline: `client_uuid` (PK), type, lines (with product names for display), reference, note, created time, `status` (`pending` / `failed`), last error, attempts |
| `product_cache` | the last-known version of every product the app has loaded |

On web (no SQLite) the same interfaces use in-memory stores.

## Saving a document

1. The form generates a `clientUuid` **once** when it opens.
2. Save tries `POST /transactions` with that `clientUuid`.
3. Network error (no response) → the document goes into the outbox as
   `pending`; the user sees "Saved on this device".
   Any other error (e.g. 400) is shown on the form and **not** queued, so the
   user can fix it.

## Sync

**When:** network comes back, app returns to the foreground, after login, or
"Sync now".

**Order:** oldest first, one at a time.

**Per item:**

| Server result | What happens |
|---|---|
| 201 (created, or the existing draft for this `clientUuid`) | removed from the outbox |
| No response / 5xx | attempts +1, item stays `pending`, **the pass stops** (later items would fail the same way) |
| Other 4xx (e.g. product deleted, validation) | item marked `failed` with the server's message; the pass **continues** |

Failed items show the reason; the user can **Retry** (back to pending) or
**Discard**. They never block the rest of the queue. Only one sync pass runs
at a time.

## Work orders (checklist only)

**Saved copies.** Every full work order the server returns is stored in
`wo_cache` (the JSON as received). Offline, a job opened before is shown from
that copy with a banner and the time it was saved; a job never opened on the
device shows the normal connection error, never invented data.

**Queued edits.** `wo_checklist_ops` holds **one row per checklist item**: a
second edit of the same item replaces the first, and changing an item back to
the server's value removes the row. Each row keeps `expectedDone`, the value
the server had when the user made the change.

**Sending.** Runs with the stock outbox (same triggers, same rules): accepted →
removed; no connection / 5xx → stop and keep; refused → kept with the server's
message, shown on the item with **Use server value**. A refused edit is never
retried on its own.

**Why old edits can't overwrite newer data.** The server only applies the
edit if the item still has `expectedDone` (409 otherwise). Repeating an edit
that already landed (uncertain timeout) returns success without a second
audit event. Setting a value is naturally idempotent, so no extra key is
needed.

**Submit** is disabled while any checklist edit is unsynced, so the server
decides on what the user actually sees. The server checks again anyway.

Not offline: photos (files and signed uploads), start/submit/review (server
decisions), and the job list (shows the connection error offline).

## Why there are no duplicates

The server treats `clientUuid` as an idempotency key (unique column): a
second create with the same key returns the original draft instead of a new
one, including when several retries race (tested with 5 parallel requests).
That covers the tricky cases:

- **The request reached the server but the response was lost** (or the app
  was killed before removing the item): the item is still `pending`; the next
  sync sends the same `clientUuid` and gets the existing draft back, then
  removes it.
- **Online save timed out but actually succeeded**: the queued copy carries
  the same `clientUuid`, so syncing it is harmless.

A `clientUuid` already used by **another** user is rejected (409), so keys
can't be hijacked.

## Stale data

- The outbox only **creates drafts**; it never updates or deletes server
  data, so an old queued item can't overwrite newer server state.
- The product cache is read-only on the device and refreshed by every
  successful online load. Stock numbers shown offline may be stale; the
  server re-validates when the draft is confirmed, and confirming never
  happens offline.

## Tests

`mobile/test/offline_logic_test.dart` (engine rules, SQLite tables via
in-memory SQLite, cache fallback) and `mobile/test/offline_flow_test.dart`
(full UI flow: save offline → sync fails → sync succeeds with the same
`clientUuid`; rejected item → failed → discard). Server-side idempotency:
`backend/test/stock.e2e-spec.ts`.

## Not done

- Work orders: photos, notes on the job itself and state changes are online
  only; the job list is not cached.

- No `syncing` state per item in storage (a pass is in memory; an
  interrupted pass simply resumes from `pending`).
- No background sync while the app is closed (e.g. WorkManager).
- Not yet exercised with a real connection drop on a physical phone.
