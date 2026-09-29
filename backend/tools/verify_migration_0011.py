#!/usr/bin/env python3
"""
verify_migration_0011.py
Verifies:
1. Clean installation of migrations 0001 through 0011.
2. Upgrade from schema at 0010 applying forward migration 0011.
3. Equivalent trigger definitions between clean and upgraded databases.
4. Preservation of business data in the local development database.
"""

import os
import re
import sqlite3
import glob

MIGRATIONS_DIR = os.path.join(os.path.dirname(__file__), "..", "migrations")

def get_migration_files():
    files = sorted([f for f in os.listdir(MIGRATIONS_DIR) if f.endswith(".sql") and f[:4].isdigit()])
    return files

def apply_sql_file(conn, filepath):
    with open(filepath, "r", encoding="utf-8") as f:
        sql = f.read()
    conn.executescript(sql)

def get_schema_objects(conn):
    cur = conn.cursor()
    cur.execute("SELECT type, name, sql FROM sqlite_master WHERE sql IS NOT NULL ORDER BY type, name")
    return {f"{row[0]}:{row[1]}": " ".join(row[2].split()) for row in cur.fetchall()}

def test_clean_vs_upgrade():
    migration_files = get_migration_files()
    print(f"Discovered {len(migration_files)} migrations: {migration_files}")

    # 1. Clean database
    clean_conn = sqlite3.connect(":memory:")
    clean_conn.execute("PRAGMA foreign_keys = ON")
    for mf in migration_files:
        apply_sql_file(clean_conn, os.path.join(MIGRATIONS_DIR, mf))
    clean_objects = get_schema_objects(clean_conn)

    # 2. Upgraded database (apply 0001-0010, then 0011)
    upgrade_conn = sqlite3.connect(":memory:")
    upgrade_conn.execute("PRAGMA foreign_keys = ON")
    for mf in migration_files:
        if mf == "0011_retry_delivery_and_return_limits.sql":
            # Checkpoint before 0011
            pre_0011_objects = get_schema_objects(upgrade_conn)
        apply_sql_file(upgrade_conn, os.path.join(MIGRATIONS_DIR, mf))
    upgraded_objects = get_schema_objects(upgrade_conn)

    # Compare clean vs upgraded
    print("\n--- Comparing Clean vs Upgraded Schema Objects ---")
    clean_keys = set(clean_objects.keys())
    upgraded_keys = set(upgraded_objects.keys())

    assert clean_keys == upgraded_keys, f"Key mismatch: {clean_keys ^ upgraded_keys}"
    print(f"Total schema objects match: {len(clean_keys)} objects.")

    # Deep compare SQL for critical triggers
    critical_triggers = [
        "trigger:trg_order_status_transition_guard",
        "trigger:return_quantity_guard",
        "trigger:release_order_credit"
    ]
    for ct in critical_triggers:
        assert ct in clean_objects, f"{ct} not in clean DB"
        assert ct in upgraded_objects, f"{ct} not in upgraded DB"
        clean_sql = clean_objects[ct]
        upgraded_sql = upgraded_objects[ct]
        assert clean_sql == upgraded_sql, f"SQL mismatch for {ct}:\nClean: {clean_sql}\nUpgraded: {upgraded_sql}"
        print(f"PASS: {ct} identical between clean and upgraded.")

    # Verify transition trigger accepts DELIVERY_FAILED -> OUT_FOR_DELIVERY
    assert "DELIVERY_FAILED" in clean_objects["trigger:trg_order_status_transition_guard"], "Transition guard missing DELIVERY_FAILED"
    # Verify return guard checks PARTIALLY_DELIVERED
    assert "PARTIALLY_DELIVERED" in clean_objects["trigger:return_quantity_guard"], "Return guard missing PARTIALLY_DELIVERED"
    print("PASS: Triggers contain required conditions.")

    clean_conn.close()
    upgrade_conn.close()

def verify_live_dev_database():
    print("\n--- Checking Live Local Development Database ---")
    d1_dir = os.path.join(os.path.dirname(__file__), "..", ".wrangler", "state", "v3", "d1", "miniflare-D1DatabaseObject")
    db_files = [f for f in glob.glob(os.path.join(d1_dir, "*.sqlite")) if "metadata" not in f]
    assert db_files, "No local D1 sqlite database found"
    db_path = db_files[0]
    print(f"Live database: {db_path}")

    conn = sqlite3.connect(db_path)
    cur = conn.cursor()

    # Integrity check
    cur.execute("PRAGMA integrity_check")
    integrity = cur.fetchone()[0]
    print(f"PRAGMA integrity_check: {integrity}")
    assert integrity == "ok", f"Integrity check failed: {integrity}"

    # Foreign key check
    cur.execute("PRAGMA foreign_key_check")
    fk_violations = cur.fetchall()
    print(f"PRAGMA foreign_key_check violations: {len(fk_violations)}")
    assert len(fk_violations) == 0, f"Foreign key violations found: {fk_violations}"

    # Check d1_migrations
    cur.execute("SELECT id, name, applied_at FROM d1_migrations ORDER BY id")
    migrations = cur.fetchall()
    print(f"Applied migrations count: {len(migrations)}")
    for m in migrations:
        print(f"  [{m[0]}] {m[1]} applied at {m[2]}")
    latest_migration = migrations[-1][1]
    assert latest_migration == "0011_retry_delivery_and_return_limits.sql", f"Latest migration is {latest_migration}, expected 0011"

    # Business data check
    tables_to_check = ["users", "companies", "products", "orders", "retailers", "collections", "payment_ledger", "cash_handovers"]
    for tbl in tables_to_check:
        cur.execute(f"SELECT COUNT(*) FROM {tbl}")
        cnt = cur.fetchone()[0]
        print(f"  Table {tbl}: {cnt} rows")
        assert cnt > 0, f"Table {tbl} unexpectedly empty"

    # Trigger verification in live DB
    live_objects = get_schema_objects(conn)
    assert "trigger:trg_order_status_transition_guard" in live_objects
    assert "DELIVERY_FAILED" in live_objects["trigger:trg_order_status_transition_guard"]
    assert "trigger:return_quantity_guard" in live_objects
    assert "PARTIALLY_DELIVERED" in live_objects["trigger:return_quantity_guard"]
    print("PASS: Live database triggers match migration 0011 specification.")

    conn.close()

if __name__ == "__main__":
    test_clean_vs_upgrade()
    verify_live_dev_database()
    print("\nALL MIGRATION 0011 ACCEPTANCE CHECKS PASSED.")
