-- ============================================================================
-- 0023_daily_planned_routes.sql
-- RouteFlow Phase 2: Owner-Controlled Manual Route Planning with OSRM
-- ============================================================================

CREATE TABLE IF NOT EXISTS planned_routes (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL REFERENCES companies(id),
    route_date TEXT NOT NULL,
    name TEXT NOT NULL,
    salesperson_id TEXT NOT NULL REFERENCES users(id),
    salesperson_name TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT', 'PUBLISHED', 'CANCELLED')),
    total_stops INTEGER NOT NULL DEFAULT 0,
    road_distance_meters REAL NOT NULL DEFAULT 0.0,
    road_duration_seconds REAL NOT NULL DEFAULT 0.0,
    route_geometry TEXT,
    routing_provider TEXT NOT NULL DEFAULT 'OSRM',
    routing_calculated_at INTEGER,
    version INTEGER NOT NULL DEFAULT 1,
    published_at INTEGER,
    published_by TEXT,
    cancelled_at INTEGER,
    cancelled_by TEXT,
    cancellation_reason TEXT,
    created_by TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS planned_route_stops (
    id TEXT PRIMARY KEY,
    route_id TEXT NOT NULL REFERENCES planned_routes(id) ON DELETE CASCADE,
    company_id TEXT NOT NULL,
    retailer_id TEXT NOT NULL REFERENCES retailers(id),
    retailer_name TEXT NOT NULL,
    stop_sequence INTEGER NOT NULL CHECK (stop_sequence >= 1),
    address TEXT,
    contact_number TEXT,
    latitude REAL NOT NULL,
    longitude REAL NOT NULL,
    status TEXT NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'VISITED', 'SKIPPED')),
    visited_at INTEGER,
    notes TEXT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    UNIQUE(route_id, retailer_id),
    UNIQUE(route_id, stop_sequence)
);

CREATE INDEX IF NOT EXISTS idx_planned_routes_company_date
ON planned_routes(company_id, route_date);

CREATE INDEX IF NOT EXISTS idx_planned_routes_salesperson
ON planned_routes(company_id, salesperson_id, status);

CREATE INDEX IF NOT EXISTS idx_planned_route_stops_route
ON planned_route_stops(route_id, stop_sequence);

CREATE INDEX IF NOT EXISTS idx_planned_route_stops_retailer
ON planned_route_stops(company_id, retailer_id);

CREATE TRIGGER IF NOT EXISTS trg_planned_route_status_guard
BEFORE UPDATE OF status ON planned_routes
FOR EACH ROW
BEGIN
    SELECT CASE
        WHEN OLD.status = 'DRAFT' AND NEW.status NOT IN ('DRAFT', 'PUBLISHED', 'CANCELLED')
            THEN RAISE(ABORT, 'Draft routes can only transition to PUBLISHED or CANCELLED')
        WHEN OLD.status = 'PUBLISHED' AND NEW.status NOT IN ('PUBLISHED', 'CANCELLED')
            THEN RAISE(ABORT, 'Published routes can only transition to CANCELLED')
        WHEN OLD.status = 'CANCELLED' AND NEW.status != 'CANCELLED'
            THEN RAISE(ABORT, 'Cancelled routes cannot be modified or reopened')
    END;

    SELECT CASE
        WHEN NEW.status = 'PUBLISHED' AND NEW.total_stops < 1
            THEN RAISE(ABORT, 'Cannot publish a route with zero stops')
    END;
END;
