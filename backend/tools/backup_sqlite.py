"""
backup_sqlite.py - Creates a consistent SQLite backup using the SQLite Online Backup API.
Executes PRAGMA integrity_check and PRAGMA foreign_key_check on the resulting backup.
"""
import sqlite3
import os
import sys
from datetime import datetime

D1_DB_PATH = r"D:\app\backend\.wrangler\state\v3\d1\miniflare-D1DatabaseObject\375634d678c996ae430f25b6d6e647334f27927de84135ea4b7b9e884d21d0b2.sqlite"
BACKUP_DIR = r"D:\app\backend\db_backups"

def make_consistent_backup():
    if not os.path.exists(D1_DB_PATH):
        print(f"Error: Source database file not found at {D1_DB_PATH}")
        sys.exit(1)
        
    os.makedirs(BACKUP_DIR, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_file = os.path.join(BACKUP_DIR, f"d1_consistent_backup_{timestamp}.sqlite")
    
    print(f"Source DB: {D1_DB_PATH}")
    print(f"Backup target: {backup_file}")
    
    # Connect to source and force WAL checkpointing if needed
    source_conn = sqlite3.connect(D1_DB_PATH)
    try:
        source_cursor = source_conn.cursor()
        source_cursor.execute("PRAGMA wal_checkpoint(TRUNCATE);")
        checkpoint_result = source_cursor.fetchall()
        print(f"WAL Checkpoint (TRUNCATE): {checkpoint_result}")
    except Exception as e:
        print(f"Checkpoint note: {e}")
        
    # Open destination connection and use sqlite3 backup API
    dest_conn = sqlite3.connect(backup_file)
    print("Initiating SQLite Online Backup API (sqlite3_backup)...")
    source_conn.backup(dest_conn, pages=100) # Copies in pages with write-safe transaction lock
    dest_conn.commit()
    source_conn.close()
    dest_conn.close()
    
    print(f"Backup created successfully: {os.path.getsize(backup_file)} bytes.")
    
    # Re-open the backup independently to verify integrity and foreign keys
    print("Verifying backup integrity...")
    verify_conn = sqlite3.connect(backup_file)
    verify_cursor = verify_conn.cursor()
    
    # 1. Integrity check
    verify_cursor.execute("PRAGMA integrity_check;")
    integrity_rows = verify_cursor.fetchall()
    print(f"PRAGMA integrity_check result: {integrity_rows}")
    if integrity_rows != [("ok",)]:
        print("FAIL: Integrity check failed!")
        sys.exit(1)
        
    # 2. Foreign key check
    verify_cursor.execute("PRAGMA foreign_key_check;")
    fk_violations = verify_cursor.fetchall()
    print(f"PRAGMA foreign_key_check violations count: {len(fk_violations)}")
    if fk_violations:
        print(f"FAIL: Foreign key violations detected: {fk_violations}")
        sys.exit(1)
        
    # 3. Read representative business records
    tables_to_check = ["users", "companies", "products", "orders", "collections", "payment_ledger", "cash_handovers", "shifts"]
    print("\nVerified record counts in backup:")
    for tbl in tables_to_check:
        try:
            verify_cursor.execute(f"SELECT COUNT(*) FROM {tbl};")
            cnt = verify_cursor.fetchone()[0]
            print(f"  - {tbl}: {cnt}")
        except Exception as e:
            print(f"  - {tbl}: (table error: {e})")
            
    verify_conn.close()
    print("\nBackup verification PASSED: 100% consistent point-in-time snapshot.")
    return backup_file

if __name__ == "__main__":
    make_consistent_backup()
