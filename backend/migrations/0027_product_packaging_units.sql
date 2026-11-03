-- 0027_product_packaging_units.sql
-- RouteFlow Phase C: Master Packaging Units & Conversion Hierarchy

CREATE TABLE IF NOT EXISTS product_units (
    id TEXT PRIMARY KEY,
    organization_id TEXT NOT NULL,
    product_id TEXT NOT NULL,
    unit_name TEXT NOT NULL,
    multiplier_to_base INTEGER NOT NULL,
    is_base_unit INTEGER NOT NULL DEFAULT 0,
    allow_loose_sale INTEGER NOT NULL DEFAULT 1,
    can_buy INTEGER NOT NULL DEFAULT 1,
    can_sell INTEGER NOT NULL DEFAULT 1,
    price_paise INTEGER NOT NULL,
    mrp_paise INTEGER,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (organization_id) REFERENCES companies(id),
    FOREIGN KEY (product_id) REFERENCES products(id),
    CONSTRAINT unq_org_prod_unit UNIQUE (organization_id, product_id, unit_name)
);

-- Seed default packaging units for core seed products
INSERT OR IGNORE INTO product_units (id, organization_id, product_id, unit_name, multiplier_to_base, is_base_unit, allow_loose_sale, can_buy, can_sell, price_paise, mrp_paise, created_at)
VALUES 
    ('unit_p1_piece', 'comp_1', 'prod_1', 'piece', 1, 1, 1, 1, 1, 5000, 6000, 1726243200000),
    ('unit_p1_box', 'comp_1', 'prod_1', 'box', 20, 0, 1, 1, 1, 95000, 120000, 1726243200000),
    ('unit_p1_crate', 'comp_1', 'prod_1', 'crate', 24, 0, 0, 1, 1, 114000, 144000, 1726243200000),
    ('unit_p2_piece', 'comp_1', 'prod_2', 'piece', 1, 1, 1, 1, 1, 3500, 4000, 1726243200000),
    ('unit_p2_box', 'comp_1', 'prod_2', 'box', 10, 0, 1, 1, 1, 33000, 40000, 1726243200000);
