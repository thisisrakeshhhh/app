-- 0026_retailers_contact_index.sql
-- RouteFlow Checkpoint 3: Tenant-scoped index and atomic duplicate-phone prevention trigger

CREATE INDEX IF NOT EXISTS idx_retailers_company_contact ON retailers(company_id, contact_number);

-- Atomic duplicate-protection trigger scoped to company_id (safe on existing data: only fires on new INSERTs)
CREATE TRIGGER IF NOT EXISTS trg_prevent_duplicate_retailer_phone
BEFORE INSERT ON retailers
FOR EACH ROW
WHEN NEW.contact_number IS NOT NULL AND NEW.contact_number != ''
BEGIN
  SELECT RAISE(ABORT, 'DUPLICATE_RETAILER_PHONE: A retailer with this contact number already exists in this organization')
  WHERE EXISTS (
    SELECT 1 FROM retailers
    WHERE company_id = NEW.company_id
      AND contact_number = NEW.contact_number
  );
END;
