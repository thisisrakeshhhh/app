-- 0025_retailers_sync_enhancements.sql
-- RouteFlow Phase O1.1 / C1: Support for Sync Retailer Classification, GSTIN & Owner Name

ALTER TABLE retailers ADD COLUMN classification TEXT NOT NULL DEFAULT 'NEW';
ALTER TABLE retailers ADD COLUMN gstin TEXT;
ALTER TABLE retailers ADD COLUMN owner_name TEXT;
