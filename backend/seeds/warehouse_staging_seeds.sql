-- Seed staging warehouse data for comp_1
-- 5 products (2 low stock products, near-expiry batch, approved order ready to pick, packed order, driver return)

-- 1. Ensure 5 key products with barcodes and appropriate quantities
INSERT OR REPLACE INTO products (id, company_id, name, category, price_paise, stock_quantity, reserved_quantity, unit, barcode, product_image_key)
VALUES
  ('P1', 'comp_1', 'Tata Tea Gold 1kg', 'Beverages', 45000, 8, 2, '1kg Pack', '8901030000001', 'tea_gold'),
  ('P2', 'comp_1', 'Fortune Mustard Oil 1L', 'Edible Oils', 16000, 5, 0, '1L Pouch', '8901030000002', 'mustard_oil'),
  ('P3', 'comp_1', 'Aashirvaad Shudh Chakki Atta 10kg', 'Staples', 42000, 45, 5, '10kg Bag', '8901030000003', 'atta_10kg'),
  ('P4', 'comp_1', 'India Gate Basmati Rice 5kg', 'Staples', 55000, 30, 0, '5kg Bag', '8901030000004', 'rice_5kg'),
  ('P5', 'comp_1', 'Dettol Original Soap 125g (Pack of 4)', 'Personal Care', 18000, 60, 0, 'Pack', '8901030000005', 'dettol_soap');

-- 2. Batches: 1 near-expiry batch on P1 (Tata Tea Gold) expiring in 15 days, normal batch on P3 & P4
INSERT OR REPLACE INTO product_batches (id, company_id, product_id, batch_no, mfg_date, expiry_date, rack_bin, received_quantity, remaining_quantity, committed_quantity, status, received_by, damaged_quantity, supplier_name, created_at, updated_at)
VALUES
  ('B_P1_EXP', 'comp_1', 'P1', 'BAT-TEA-2026-08', 1720000000, 1792600000, 'RACK-A1-BIN2', 10, 8, 2, 'ACTIVE', 'user_warehouse', 0, 'Tata Consumer Products Ltd', 1726243200000, 1726243200000),
  ('B_P2_LOW', 'comp_1', 'P2', 'BAT-OIL-2026-01', 1725000000, 1820000000, 'RACK-B2-BIN1', 20, 5, 0, 'ACTIVE', 'user_warehouse', 1, 'Adani Wilmar Depot Jaipur', 1726243200000, 1726243200000),
  ('B_P3_NORM', 'comp_1', 'P3', 'BAT-ATT-2026-05', 1726000000, 1830000000, 'PALLET-04', 50, 45, 5, 'ACTIVE', 'user_warehouse', 0, 'ITC Foods Godown', 1726243200000, 1726243200000);

-- 3. Approved order ready to pick (Status: APPROVED)
INSERT OR REPLACE INTO orders (id, company_id, retailer_id, employee_id, status, total_amount_paise, created_at, updated_at, cartons_count, packing_notes)
VALUES
  ('ORD-WH-PICK-01', 'comp_1', 'R1', 'user_sales', 'APPROVED', 90000, 1791469200000, 1791469200000, 1, 'Handle with care - Tea boxes');

INSERT OR REPLACE INTO order_items (id, order_id, product_id, quantity, free_quantity, price_paise_at_time, is_picked, batch_id, batch_no)
VALUES
  ('OI_WH_01', 'ORD-WH-PICK-01', 'P1', 2, 0, 45000, 0, 'B_P1_EXP', 'BAT-TEA-2026-08');

-- 4. Packed order ready for dispatch (Status: PACKED, cartons_count = 3)
INSERT OR REPLACE INTO orders (id, company_id, retailer_id, employee_id, status, total_amount_paise, created_at, updated_at, cartons_count, packing_notes)
VALUES
  ('ORD-WH-PACK-02', 'comp_1', 'R2', 'user_sales', 'PACKED', 210000, 1791469000000, 1791469300000, 3, 'Packed in 3 corrugated cartons, taped and verified');

INSERT OR REPLACE INTO order_items (id, order_id, product_id, quantity, free_quantity, price_paise_at_time, is_picked, batch_id, batch_no)
VALUES
  ('OI_WH_02', 'ORD-WH-PACK-02', 'P3', 5, 0, 42000, 1, 'B_P3_NORM', 'BAT-ATT-2026-05');

-- 5. Dispatch batch created with packed order assigned to driver
INSERT OR REPLACE INTO dispatch_batches (id, company_id, batch_code, delivery_executive_id, route_id, status, total_orders, total_cartons, created_by, notes, created_at, updated_at)
VALUES
  ('DSP-2026-001', 'comp_1', 'DSP-JPR-001', 'user_delivery', 'BEAT-04', 'CREATED', 1, 3, 'user_warehouse', 'Morning dispatch route Sector 1-4', 1791469400000, 1791469400000);

INSERT OR REPLACE INTO dispatch_batch_orders (dispatch_batch_id, order_id, cartons_count, created_at)
VALUES
  ('DSP-2026-001', 'ORD-WH-PACK-02', 3, 1791469400000);

-- 6. Undelivered goods held by driver (Driver return awaiting warehouse acknowledgement)
INSERT OR REPLACE INTO undelivered_goods (id, company_id, delivery_id, driver_id, retailer_id, product_id, undelivered_paid_quantity, undelivered_free_quantity, reason, notes, status, created_at)
VALUES
  ('UG-WH-001', 'comp_1', 'DEL-PREV-01', 'user_delivery', 'R3', 'P2', 2, 0, 'SHOP_CLOSED', 'Shop was closed during evening visit, returned to depot', 'PENDING_WAREHOUSE_ACK', 1791469100000);

-- 7. Customer return RMA request
INSERT OR REPLACE INTO return_requests (id, company_id, order_id, retailer_id, status, total_refund_paise, created_at)
VALUES
  ('RET-WH-001', 'comp_1', 'ORD-PREV-00', 'R1', 'PENDING_INSPECTION', 32000, 1791469200000);

INSERT OR REPLACE INTO return_request_items (id, return_id, product_id, quantity, reason, condition)
VALUES
  ('RRI-01', 'RET-WH-001', 'P2', 2, 'Outer seal broken during transit', 'PENDING');
