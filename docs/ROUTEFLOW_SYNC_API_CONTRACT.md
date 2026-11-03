# RouteFlow — Sync API Specification & Server Contract
**Document Version:** 1.0.0  
**Phase:** RouteFlow O1.1 / B2.2 Sync Architecture  
**Author:** Antigravity Engineering (Senior Mobile & Distributed Systems)  
**Target Environment:** Flutter Mobile Client (Android/iOS) ⇄ Cloudflare Workers + D1 Edge Database  

---

## 1. Executive Architecture Topology

RouteFlow operates under an **offline-first, zero-data-loss architecture** tailored for Indian FMCG distribution. Sales representatives and delivery van drivers operate in dense urban wholesale markets and remote rural routes where 4G/5G mobile connectivity is intermittent, slow, or completely absent for hours at a time.

```
+-----------------------------------------------------------------------------------+
|                            MOBILE CLIENT (FLUTTER APP)                            |
|                                                                                   |
|  +--------------------+     Atomic SQLite Tx     +-----------------------------+  |
|  | User Action (Cart/ | -----------------------> | SQLite `outbox_mutations`   |  |
|  | GRN / Add Shop)    |                          | - Monotonic sequence_order  |  |
|  +--------------------+                          | - UUID idempotency_key      |  |
|                                                  | - Canonical JSON payload    |  |
|                                                  | - sync_status: PENDING      |  |
|                                                  +--------------+--------------+  |
+-----------------------------------------------------------------|-----------------+
                                                                  |
                                       HTTPS (JSON Batch FIFO)   |
                                       `POST /sync/push`          v
+-----------------------------------------------------------------------------------+
|                         CLOUDFLARE WORKER & D1 EDGE ENGINE                        |
|                                                                                   |
|  1. Bearer JWT Authentication & Tenant Boundary Gate (`organization_id`)         |
|  2. Idempotency Key Deduping (`idempotency_keys` table)                            |
|  3. FIFO Dependency Topological Execution (Shop -> Visit -> Order)               |
|  4. Server Master Sequence Allocation                                             |
|  5. Cloudflare D1 Atomic Batch Commit                                             |
|                                                                                   |
|  Returns: Batch push acknowledgment with Provisional ID -> Server ID mappings     |
+-----------------------------------------------------------------------------------+
```

---

## 2. Core Integrity Invariants

1. **Integer Arithmetic Everywhere:** All monetary figures are signed 64-bit integers in **paise** (₹1.00 = 100 paise, corresponding to Dart `int` and SQLite integer). All quantities are integers in **base pieces** (loose units). Floats are strictly prohibited in wire payloads and storage schemas.
2. **Offline Outbox Honesty:** Mutations are marked `PENDING` ("Saved on this phone") until the server explicitly acknowledges successful commit with HTTP 200. The client UI **never** reports "Synced to Cloud" prematurely.
3. **Strict FIFO Dependency Ordering:** All mutations for an organization are processed in the strict order of their client-allocated `sequence_order`. If mutation `N` (`CREATE_ORDER`) depends on mutation `N-1` (`CREATE_RETAILER`), `N-1` is processed and committed first.
4. **Zero Duplicate Effects (Idempotency):** Each mutation carries a persistent UUID v4 `idempotency_key`. A retry with the exact same payload returns HTTP 200 with the previously committed result. A retry with the same key but different payload fails closed with HTTP 409 Conflict.
5. **Multi-Tenant Boundary Quarantine:** Every mutation payload must declare `organization_id` matching the authenticated JWT tenant claim. Cross-tenant mutation insertion is blocked at the edge gateway.

---

## 3. Wire Protocol & Batch Sync Endpoints

### 3.1 Batch Push Endpoint: `POST /sync/push`
Transmits a chronological batch of pending outbox mutations from the phone to Cloudflare D1.

#### Request Headers
```http
POST /sync/push HTTP/1.1
Host: api.routeflow.in
Authorization: Bearer <jwt_access_token>
Content-Type: application/json
X-Client-App-Version: 2.1.0-prod
X-Device-Id: vivo-1904-android13
```

#### Request Payload
```json
{
  "clientBatchId": "batch_67890abcdef12345",
  "organizationId": "org_jodhpur_dist",
  "userId": "usr_sales_imran",
  "clientTimestampEpochMs": 1793682000000,
  "mutations": [
    {
      "mutationId": "out_018f45a1-4321-789a-bcde-0123456789ab",
      "sequenceOrder": 101,
      "idempotencyKey": "idem_shop_018f45a1-9876",
      "mutationType": "CREATE_RETAILER",
      "provisionalBusinessId": "LOCAL-SHP-1793681900000",
      "createdAtEpochMs": 1793681900000,
      "payload": {
        "shopName": "Mahalaxmi Kirana",
        "ownerName": "Suresh Kumar",
        "phone": "9829012345",
        "gstin": "08ABCDE1234F1Z5",
        "address": "Opp. Railway Station, Sojati Gate",
        "landmark": "Near Clock Tower",
        "pincode": "342001",
        "route": "Sojati Gate Beat",
        "latitude": 26.2915,
        "longitude": 73.0185,
        "accuracyMeters": 14.5,
        "classification": "NEW",
        "defaultCreditLimitPaise": 0
      }
    },
    {
      "mutationId": "out_018f45a2-5678-789a-bcde-0123456789ac",
      "sequenceOrder": 102,
      "idempotencyKey": "idem_order_018f45a2-1111",
      "mutationType": "CREATE_ORDER",
      "provisionalBusinessId": "LOCAL-ORD-1793681950000",
      "createdAtEpochMs": 1793681950000,
      "payload": {
        "retailerId": "LOCAL-SHP-1793681900000",
        "paymentMode": "COD",
        "items": [
          {
            "productId": "KURK-01",
            "productName": "Kurkure Masala Munch",
            "orderedQuantity": 2,
            "orderedUnit": "box",
            "unitPricePaise": 77520,
            "lineTotalPaise": 155040,
            "totalPieces": 200,
            "gstRate": 5.0
          }
        ],
        "totals": {
          "taxableAmountPaise": 147657,
          "gstAmountPaise": 7383,
          "totalAmountPaise": 155040
        }
      }
    }
  ]
}
```

#### Response: HTTP 200 OK (Batch Committed)
```json
{
  "success": true,
  "clientBatchId": "batch_67890abcdef12345",
  "processedCount": 2,
  "serverProcessedEpochMs": 1793682000450,
  "results": [
    {
      "mutationId": "out_018f45a1-4321-789a-bcde-0123456789ab",
      "status": "COMMITTED",
      "provisionalBusinessId": "LOCAL-SHP-1793681900000",
      "serverBusinessId": "ret_jodhpur_890123",
      "serverSequence": 4501
    },
    {
      "mutationId": "out_018f45a2-5678-789a-bcde-0123456789ac",
      "status": "COMMITTED",
      "provisionalBusinessId": "LOCAL-ORD-1793681950000",
      "serverBusinessId": "ord_srv_901234",
      "serverSequence": 4502
    }
  ]
}
```

#### Response: HTTP 409 Conflict (Payload Mismatch on Idempotency Key)
```json
{
  "success": false,
  "error": "IDEMPOTENCY_PAYLOAD_MISMATCH",
  "mutationId": "out_018f45a2-5678-789a-bcde-0123456789ac",
  "message": "Idempotency key idem_order_018f45a2-1111 was previously registered with a different order payload snapshot."
}
```

---

### 3.2 Delta Pull Endpoint: `POST /sync/pull`
Retrieves master data changes and server transactions that occurred since the client's last acknowledged cursor.

#### Request Payload
```json
{
  "organizationId": "org_jodhpur_dist",
  "lastServerSequence": 4500,
  "limit": 100
}
```

#### Response: HTTP 200 OK
```json
{
  "success": true,
  "latestServerSequence": 4550,
  "hasMore": false,
  "delta": {
    "products": [],
    "classSettings": [
      {
        "className": "NEW",
        "defaultCreditLimitPaise": 0,
        "creditDays": 0,
        "visitFrequencyDays": 7,
        "updatedAt": 1793681000000
      }
    ],
    "orderStatusUpdates": [
      {
        "serverOrderId": "ord_srv_901234",
        "provisionalId": "LOCAL-ORD-1793681950000",
        "newStage": "ready_stock",
        "assignedCarNumber": "RJ-19-GA-1122"
      }
    ]
  }
}
```

---

## 4. Supported Outbox Mutation Types

| Mutation Type | Triggering Screen / Flow | Invariants Enforced |
|---|---|---|
| `CREATE_RETAILER` | Add Shop Sheet (Pillar A) | Duplicate detection check, mandatory 10-digit mobile, default credit limit = 0 |
| `CREATE_ORDER` | Checkout Review (Pillar B) | Stock piece availability verified, unit pricing from `unit_prices`, COD/Cash only for Class D & NEW |
| `RECEIVE_GRN` | Receive Stock View (Pillar C2) | Damaged cartons quarantined, positive piece quantities, append-only ledger row |
| `RECORD_VISIT` | Active Shop Visit (Pillar B) | Durable outcome (`STOCK_FULL`, `SHOP_CLOSED`), GPS timestamp recorded |
| `UPDATE_CLASS_SETTINGS` | Owner Control Room (Pillar C) | Sovereign owner permission required, non-negative credit limits and days |

---

## 5. Cloudflare D1 Migration Schema

```sql
-- D1 Migration: 0024_offline_sync_outbox_support.sql

-- 1. Server Outbox Mutations Ledger (Stores deduplicated wire mutations)
CREATE TABLE IF NOT EXISTS server_outbox_audit (
    id TEXT PRIMARY KEY,
    organization_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    idempotency_key TEXT NOT NULL,
    mutation_type TEXT NOT NULL,
    payload_hash TEXT NOT NULL,
    payload_json TEXT NOT NULL,
    provisional_business_id TEXT,
    server_business_id TEXT,
    client_sequence_order INTEGER NOT NULL,
    server_sequence_order INTEGER NOT NULL,
    processed_at_epoch_ms INTEGER NOT NULL,
    CONSTRAINT unq_org_idempotency UNIQUE (organization_id, idempotency_key)
);

CREATE INDEX IF NOT EXISTS idx_server_outbox_org_seq 
ON server_outbox_audit (organization_id, server_sequence_order);

-- 2. Retailer Classification Governance Table
CREATE TABLE IF NOT EXISTS retailer_class_settings (
    organization_id TEXT NOT NULL,
    class_name TEXT NOT NULL,
    default_credit_limit_paise INTEGER NOT NULL DEFAULT 0,
    credit_days INTEGER NOT NULL DEFAULT 0,
    visit_frequency_days INTEGER NOT NULL DEFAULT 7,
    updated_at_epoch_ms INTEGER NOT NULL,
    PRIMARY KEY (organization_id, class_name)
);

-- Pre-seed default FMCG classes
INSERT OR IGNORE INTO retailer_class_settings (organization_id, class_name, default_credit_limit_paise, credit_days, visit_frequency_days, updated_at_epoch_ms)
VALUES 
    ('default', 'Class A', 5000000, 15, 7, 1793680000000),
    ('default', 'Class B', 2500000, 10, 7, 1793680000000),
    ('default', 'Class C', 1000000, 7, 14, 1793680000000),
    ('default', 'Class D', 0, 0, 14, 1793680000000),
    ('default', 'NEW', 0, 0, 7, 1793680000000);
```

---

## 6. Mobile Sync Worker Lifecycle & Backoff

```
[Phone Online] -> Check Pending Outbox Queue -> Send Batch (max 50)
                      |
           +----------+----------+
           |                     |
     [HTTP 200 OK]       [Network Failure / 5xx]
           |                     |
  Update SQLite status     Trigger Exponential Backoff:
  to 'SYNCED' with         2s -> 4s -> 8s -> 16s (max 300s)
  Server Sequence          Leave status as 'PENDING'
```

1. **Batch Sizing:** Maximum 50 mutations per batch to ensure sub-500ms Cloudflare Worker execution limits.
2. **Retry Policy:** Exponential backoff with random jitter ($T_{wait} = \min(300, 2^{\text{attempt}} + \text{jitter})$).
3. **Quarantine Safety:** If a mutation fails with a permanent non-retryable 4xx error (e.g. invalid signature), it is moved to `FAILED_TERMINAL` and flagged in the Owner Control Room, without halting the remaining independent queue items.
