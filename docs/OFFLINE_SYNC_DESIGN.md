# RouteFlow — Offline Synchronization & Conflict Resolution Engine
**Architecture:** Offline-First with WorkManager & Double-Entry Replay  
**Client:** Android Room SQLite  
**Server:** Cloudflare D1 Distributed SQLite  

---

## 1. Core Principles of Offline Operation

1. **Immediate Local Mutation**: Every user action (booking order, recording cash collection, checking into shop) writes immediately to the local Room SQLite database and emits a job into `sync_queue`. The UI never blocks on network latency.
2. **Deterministic Client IDs**: All entity primary keys are generated client-side using standard RFC 4122 v4 UUIDs (`UUID.randomUUID().toString()`). This guarantees that offline created entities maintain stable references across dependencies (e.g. `order_items` referencing `orders.id` before server roundtrip).
3. **Idempotent Replay**: Every server mutation endpoint accepts an `idempotency_key` (or uses the entity's UUID primary key). Replaying the same request multiple times produces identical outcomes without duplicate records or duplicate ledger debits.

---

## 2. Sync Queue Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                       ANDROID CLIENT                        │
│                                                             │
│  [User Action] ──> [Room DB Write] ──> [sync_queue Insert]  │
│                                              │              │
│                                              ▼              │
│                                      [WorkManager Job]      │
│                                              │              │
└──────────────────────────────────────────────┼──────────────┘
                                               │
                                 HTTPS POST /api/sync/batch
                                               │
                                               ▼
┌─────────────────────────────────────────────────────────────┐
│                     BACKEND (Edge Worker)                   │
│                                                             │
│       [D1 Transaction Batch: Validate -> Apply -> Emit]      │
│                               │                             │
│                  200 OK / Per-Item Statuses                 │
└───────────────────────────────┬─────────────────────────────┘
                                │
                                ▼
         [Local Room DB: Mark COMPLETED or REVISE]
```

### Table: `sync_queue` (Room DB)
```sql
CREATE TABLE sync_queue (
    id TEXT PRIMARY KEY NOT NULL,
    entity_type TEXT NOT NULL,      -- 'order', 'collection', 'visit', 'shop'
    entity_id TEXT NOT NULL,
    action TEXT NOT NULL,           -- 'CREATE', 'UPDATE', 'DELETE'
    payload_json TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'PENDING', -- 'PENDING', 'IN_FLIGHT', 'COMPLETED', 'FAILED'
    retry_count INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL,
    last_error TEXT
);
```

---

## 3. Conflict Resolution Strategy

| Entity Type | Conflict Heuristic | Server Action | Client Remediation |
| :--- | :--- | :--- | :--- |
| **Shop Details** | Last-Write-Wins (LWW) | Compare `updated_at` timestamp. Higher timestamp overwrites. | Overwrite local cache with server state during delta pull. |
| **Sales Orders** | Server Invariant Check | Verify stock reservation and credit limits. If exceeded, return `409 Conflict`. | Move order to `BLOCKED_CREDIT` or `REJECTED_STOCK` state with notification to sales executive. |
| **Cash Collections** | Immutable Append-Only | Payments are never overwritten; each collection is an additive ledger credit. | Local queue confirms debit/credit pair. |
| **Inventory State** | Optimistic Lock (`version`) | If server `version !== client_version`, reject picking allocation. | Client re-fetches latest batch balances and prompts picker. |
