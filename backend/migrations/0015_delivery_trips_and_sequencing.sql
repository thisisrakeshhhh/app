-- 0015_delivery_trips_and_sequencing.sql
-- Delivery trip management, stop sequencing, driver assignment, and live dispatch tracking.

-- 1. Delivery Trips table
CREATE TABLE IF NOT EXISTS delivery_trips (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL,
    trip_number TEXT NOT NULL,
    driver_user_id TEXT NOT NULL,
    vehicle_number TEXT,
    route_area TEXT,
    status TEXT NOT NULL DEFAULT 'PLANNED', -- PLANNED, OUT_FOR_DELIVERY, COMPLETED, CANCELLED
    started_at INTEGER,
    completed_at INTEGER,
    total_orders INTEGER NOT NULL DEFAULT 0,
    delivered_orders INTEGER NOT NULL DEFAULT 0,
    failed_orders INTEGER NOT NULL DEFAULT 0,
    total_amount_paise INTEGER NOT NULL DEFAULT 0,
    collected_cash_paise INTEGER NOT NULL DEFAULT 0,
    notes TEXT,
    created_by TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    FOREIGN KEY (company_id) REFERENCES companies(id),
    FOREIGN KEY (driver_user_id) REFERENCES users(id),
    FOREIGN KEY (created_by) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_trips_company_status ON delivery_trips(company_id, status);
CREATE INDEX IF NOT EXISTS idx_trips_driver_status ON delivery_trips(company_id, driver_user_id, status);

-- 2. Delivery Trip Stops table
CREATE TABLE IF NOT EXISTS delivery_trip_stops (
    id TEXT PRIMARY KEY,
    trip_id TEXT NOT NULL,
    company_id TEXT NOT NULL,
    order_id TEXT NOT NULL,
    retailer_id TEXT NOT NULL,
    stop_sequence INTEGER NOT NULL,
    status TEXT NOT NULL DEFAULT 'PENDING', -- PENDING, ARRIVED, DELIVERED, PARTIALLY_DELIVERED, FAILED, SKIPPED
    arrived_at INTEGER,
    completed_at INTEGER,
    failure_reason TEXT,
    notes TEXT,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (trip_id) REFERENCES delivery_trips(id),
    FOREIGN KEY (order_id) REFERENCES orders(id),
    FOREIGN KEY (retailer_id) REFERENCES retailers(id),
    FOREIGN KEY (company_id) REFERENCES companies(id)
);

CREATE INDEX IF NOT EXISTS idx_trip_stops_trip ON delivery_trip_stops(trip_id, stop_sequence);
CREATE INDEX IF NOT EXISTS idx_trip_stops_order ON delivery_trip_stops(order_id);

-- 3. Add trip reference columns to orders
ALTER TABLE orders ADD COLUMN trip_id TEXT REFERENCES delivery_trips(id);
ALTER TABLE orders ADD COLUMN stop_sequence INTEGER;
