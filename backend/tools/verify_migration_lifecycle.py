import sqlite3
import glob
import os
import tempfile
import sys

def run_test():
    print("Testing clean installation from scratch...")
    clean_db = os.path.join(tempfile.gettempdir(), 'verify_clean_install.sqlite')
    if os.path.exists(clean_db):
        os.remove(clean_db)
    
    con = sqlite3.connect(clean_db)
    cur = con.cursor()
    
    cur.execute("CREATE TABLE d1_migrations (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE, applied_at TEXT)")
    
    # 1. Clean installation
    for m in sorted(glob.glob(r'D:\app\backend\migrations\*.sql')):
        name = os.path.basename(m)
        if name.startswith('0007'):
            with open(r'D:\app\backend\seeds\dev_seeds.sql', 'r', encoding='utf-8') as f:
                con.executescript(f.read())
        with open(m, 'r', encoding='utf-8') as f:
            try:
                con.executescript(f.read())
                cur.execute("INSERT INTO d1_migrations (name, applied_at) VALUES (?, datetime('now'))", (name,))
                con.commit()
            except Exception as e:
                print(f"FAILED on migration {name}: {e}")
                sys.exit(1)
    
    print("Clean installation: PASS (All migrations 0001-0009 applied cleanly)")
    con.close()
    
    # 2. Upgrade test with existing business records
    print("Testing upgrade on database with existing business records...")
    upgrade_db = os.path.join(tempfile.gettempdir(), 'verify_upgrade_install.sqlite')
    if os.path.exists(upgrade_db):
        os.remove(upgrade_db)
        
    con_up = sqlite3.connect(upgrade_db)
    cur_up = con_up.cursor()
    cur_up.execute("CREATE TABLE d1_migrations (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE, applied_at TEXT)")
    
    # Apply up to 0005
    for m in sorted(glob.glob(r'D:\app\backend\migrations\*.sql')):
        name = os.path.basename(m)
        if name > '0005':
            break
        with open(m, 'r', encoding='utf-8') as f:
            con_up.executescript(f.read())
            cur_up.execute("INSERT INTO d1_migrations (name, applied_at) VALUES (?, datetime('now'))", (name,))
    con_up.commit()
    
    # Seed sample records in v5 schema
    with open(r'D:\app\backend\seeds\dev_seeds.sql', 'r', encoding='utf-8') as f:
        con_up.executescript(f.read())
    con_up.commit()
    
    # Insert an active order and payment
    cur_up.execute("INSERT OR REPLACE INTO orders (id, company_id, retailer_id, employee_id, status, total_amount_paise, created_at, updated_at) VALUES ('ord_v5_test', 'comp_1', 'R1', 'user_sales', 'SUBMITTED', 100000, 1726243200000, 1726243200000)")
    con_up.commit()
    
    # Apply 0006 through 0009
    for m in sorted(glob.glob(r'D:\app\backend\migrations\*.sql')):
        name = os.path.basename(m)
        if name <= '0005':
            continue
        with open(m, 'r', encoding='utf-8') as f:
            try:
                con_up.executescript(f.read())
                cur_up.execute("INSERT INTO d1_migrations (name, applied_at) VALUES (?, datetime('now'))", (name,))
                con_up.commit()
            except Exception as e:
                print(f"FAILED on upgrade migration {name}: {e}")
                sys.exit(1)
                
    # Verify business record survived
    cur_up.execute("SELECT id, status, total_amount_paise FROM orders WHERE id = 'ord_v5_test'")
    order = cur_up.fetchone()
    assert order == ('ord_v5_test', 'SUBMITTED', 100000), f"Order did not survive: {order}"
    
    # Verify credit reservation was created for open order
    cur_up.execute("SELECT amount_paise FROM credit_reservations WHERE order_id = 'ord_v5_test'")
    res = cur_up.fetchone()
    assert res == (100000,), f"Credit reservation missing for open order: {res}"
    
    print("Upgrade with existing records: PASS (Records preserved, 0006-0009 applied cleanly)")
    con_up.close()

if __name__ == '__main__':
    run_test()
