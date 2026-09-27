import sqlite3
import glob
import os
import tempfile

clean_db = os.path.join(tempfile.gettempdir(), 'clean_routeflow_test.sqlite')
if os.path.exists(clean_db):
    os.remove(clean_db)

con_clean = sqlite3.connect(clean_db)
cur_clean = con_clean.cursor()

# Run all migrations in sorted order strictly
for m in sorted(glob.glob(r'D:\app\backend\migrations\*.sql')):
    base = os.path.basename(m)
    if base.startswith('0007'):
        with open(r'D:\app\backend\seeds\dev_seeds.sql', 'r', encoding='utf-8') as f:
            con_clean.executescript(f.read())
    with open(m, 'r', encoding='utf-8') as f:
        con_clean.executescript(f.read())
con_clean.commit()

dev_db = r'D:\app\backend\.wrangler\state\v3\d1\miniflare-D1DatabaseObject\375634d678c996ae430f25b6d6e647334f27927de84135ea4b7b9e884d21d0b2.sqlite'
con_dev = sqlite3.connect(dev_db)
cur_dev = con_dev.cursor()

def get_schema(con):
    c = con.cursor()
    c.execute("""
        SELECT type, name, tbl_name, sql 
        FROM sqlite_master 
        WHERE name NOT LIKE 'sqlite_%' AND name NOT LIKE '_cf_%' AND name != 'd1_migrations'
        ORDER BY type, name
    """)
    return c.fetchall()

clean_schema = get_schema(con_clean)
dev_schema = get_schema(con_dev)

clean_dict = {(r[0], r[1]): r[3] for r in clean_schema}
dev_dict = {(r[0], r[1]): r[3] for r in dev_schema}

missing_in_dev = set(clean_dict.keys()) - set(dev_dict.keys())
extra_in_dev = set(dev_dict.keys()) - set(clean_dict.keys())

print('=== SCHEMA COMPARISON ===')
print('Missing in Dev:', missing_in_dev)
print('Extra in Dev:', extra_in_dev)

# Check columns for common tables
common_tables = [name for (t, name) in clean_dict.keys() if t == 'table' and (t, name) in dev_dict]
column_diffs = []
for t in common_tables:
    cur_clean.execute(f'PRAGMA table_info({t})')
    cols_clean = {r[1]: (r[2], r[3], r[4], r[5]) for r in cur_clean.fetchall()}
    cur_dev.execute(f'PRAGMA table_info({t})')
    cols_dev = {r[1]: (r[2], r[3], r[4], r[5]) for r in cur_dev.fetchall()}
    if cols_clean != cols_dev:
        column_diffs.append((t, set(cols_clean.keys()) - set(cols_dev.keys()), set(cols_dev.keys()) - set(cols_clean.keys())))

print('Column Diffs (table, missing_in_dev, extra_in_dev):', column_diffs)

# Check foreign keys
fk_diffs = []
for t in common_tables:
    cur_clean.execute(f'PRAGMA foreign_key_list({t})')
    fk_clean = cur_clean.fetchall()
    cur_dev.execute(f'PRAGMA foreign_key_list({t})')
    fk_dev = cur_dev.fetchall()
    if fk_clean != fk_dev:
        fk_diffs.append((t, fk_clean, fk_dev))
print('FK Diffs:', fk_diffs)

# Check triggers
clean_triggers = {name: clean_dict[('trigger', name)] for (t, name) in clean_dict.keys() if t == 'trigger'}
dev_triggers = {name: dev_dict[('trigger', name)] for (t, name) in dev_dict.keys() if t == 'trigger'}
print('Missing triggers in dev:', set(clean_triggers.keys()) - set(dev_triggers.keys()))
print('Extra triggers in dev:', set(dev_triggers.keys()) - set(clean_triggers.keys()))

# Check indexes
clean_indexes = {name: clean_dict[('index', name)] for (t, name) in clean_dict.keys() if t == 'index'}
dev_indexes = {name: dev_dict[('index', name)] for (t, name) in dev_dict.keys() if t == 'index'}
print('Missing indexes in dev:', set(clean_indexes.keys()) - set(dev_indexes.keys()))
print('Extra indexes in dev:', set(dev_indexes.keys()) - set(clean_indexes.keys()))

print('Schema verification complete!')
