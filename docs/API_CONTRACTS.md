# RouteFlow — Core API Contracts & Specification
**Protocol:** HTTPS / JSON REST  
**Authentication:** `Authorization: Bearer <jwt>`  
**Base URL:** `https://api.routeflow.internal` (or Cloudflare Worker route)  

---

## 1. Authentication & Tenant Context

### POST `/api/auth/login`
Authenticates a user via phone or email and returns a signed JWT session.
- **Request Body**:
  ```json
  {
    "username": "9876543210",
    "password": "SecurePassword123!",
    "device_info": "Vivo 1935 / Android 11"
  }
  ```
- **Response `200 OK`**:
  ```json
  {
    "token": "eyJhbGciOi...",
    "user": {
      "id": "usr_9981",
      "full_name": "Ramesh Kumar",
      "role": "SALES",
      "company_id": "cmp_001",
      "organization_id": "org_001"
    },
    "organizations": [
      { "id": "org_001", "name": "Delhi Central FMCG Traders", "role": "SALES" }
    ]
  }
  ```

---

## 2. Order Lifecycle Endpoints

### POST `/api/orders`
Creates a draft or submitted order from mobile sales visit or retailer portal.
- **Request Body**:
  ```json
  {
    "shop_id": "shp_102",
    "notes": "Urgent morning delivery",
    "items": [
      {
        "product_id": "prd_204",
        "quantity": 10,
        "unit_price": 45.00,
        "gst_rate": 18.0
      }
    ]
  }
  ```
- **Response `201 Created`**:
  ```json
  {
    "order_id": "ord_8820",
    "status": "SUBMITTED",
    "total_taxable": 450.00,
    "total_gst": 81.00,
    "grand_total": 531.00
  }
  ```

### POST `/api/orders/:id/approve`
Owner / Admin approves order; reserves stock and places order in Warehouse queue.
- **Headers**: `Authorization: Bearer <jwt>`
- **Response `200 OK`**:
  ```json
  {
    "order_id": "ord_8820",
    "status": "APPROVED",
    "inventory_reserved": true,
    "picklist_id": "pkl_304"
  }
  ```

### POST `/api/orders/:id/pack`
Warehouse manager confirms batch allocations and prints packing slip.
- **Request Body**:
  ```json
  {
    "batches": [
      { "item_id": "itm_501", "batch_id": "bat_902", "picked_qty": 10 }
    ]
  }
  ```
- **Response `200 OK`**:
  ```json
  {
    "order_id": "ord_8820",
    "status": "PACKED",
    "ready_for_dispatch": true
  }
  ```

---

## 3. Delivery & Verification Endpoints

### POST `/api/trips/:id/deliver-stop`
Driver confirms delivery with OTP verification and payment collection.
- **Request Body**:
  ```json
  {
    "order_id": "ord_8820",
    "verification_type": "OTP",
    "otp_entered": "4912",
    "collection": {
      "cash_amount": 531.00,
      "upi_amount": 0.00,
      "credit_amount": 0.00
    },
    "coordinates": { "latitude": 28.6139, "longitude": 77.2090 }
  }
  ```
- **Response `200 OK`**:
  ```json
  {
    "status": "DELIVERED",
    "khata_updated": true,
    "receipt_id": "rcp_7741"
  }
  ```

---

## 4. Retailer Khata Ledger Endpoints

### GET `/api/shops/:id/ledger`
Returns complete double-entry transaction history with running balances.
- **Response `200 OK`**:
  ```json
  {
    "shop_id": "shp_102",
    "shop_name": "Gupta Kirana Store",
    "current_balance": 12450.00,
    "credit_limit": 50000.00,
    "transactions": [
      {
        "id": "led_1",
        "entry_type": "INVOICE_DEBIT",
        "amount": 531.00,
        "running_balance": 12450.00,
        "created_at": "2026-10-19T09:30:00Z"
      }
    ]
  }
  ```
