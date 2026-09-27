"""
deep_compare_schemas.py - Comprehensive schema comparison between two SQLite databases.
Compares:
1. Tables & Columns (name, type, notnull, dflt_value, pk)
2. Foreign Keys (table, from, to, on_update, on_delete)
3. Full Index SQL definitions
4. Full Trigger SQL definitions
"""
import sqlite3
import sys
import re

def normalize_sql(sql):
    if not sql:
        return ""
    # Normalize whitespace
    return re.sub(r'\s+', ' ', sql.strip()).lower()

def extract_schema_details(db_path):
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    
    # 1. Tables & Columns
    cur.execute("SELECT name, sql FROM sqlite_master WHERE type='table' AND name NOT LIKE 'd1_%' AND name NOT LIKE 'sqlite_%' ORDER BY name;")
    tables = {}
    table_sql = {}
    for tbl, sql in cur.fetchall():
        table_sql[tbl] = normalize_sql(sql)
        cur.execute(f"PRAGMA table_info('{tbl}');")
        # cid, name, type, notnull, dflt_value, pk
        cols = {row[1]: {'type': row[2].upper(), 'notnull': row[3], 'dflt': row[4], 'pk': row[5]} for row in cur.fetchall()}
        tables[tbl] = cols
        
    # 2. Foreign Keys
    foreign_keys = {}
    for tbl in tables:
        cur.execute(f"PRAGMA foreign_key_list('{tbl}');")
        # id, seq, table, from, to, on_update, on_delete, match
        fks = [(row[2], row[3], row[4], row[5], row[6]) for row in cur.fetchall()]
        foreign_keys[tbl] = sorted(fks)
        
    # 3. Indexes & Definitions
    cur.execute("SELECT name, tbl_name, sql FROM sqlite_master WHERE type='index' AND name NOT LIKE 'sqlite_%' AND sql IS NOT NULL ORDER BY name;")
    indexes = {}
    for name, tbl, sql in cur.fetchall():
        indexes[name] = {'tbl': tbl, 'sql': normalize_sql(sql)}
        
    # 4. Triggers & Definitions
    cur.execute("SELECT name, tbl_name, sql FROM sqlite_master WHERE type='trigger' ORDER BY name;")
    triggers = {}
    for name, tbl, sql in cur.fetchall():
        triggers[name] = {'tbl': tbl, 'sql': normalize_sql(sql)}
        
    conn.close()
    return {
        'tables': tables,
        'table_sql': table_sql,
        'foreign_keys': foreign_keys,
        'indexes': indexes,
        'triggers': triggers
    }

def deep_compare(db1_path, db2_path, name1="DB1", name2="DB2"):
    s1 = extract_schema_details(db1_path)
    s2 = extract_schema_details(db2_path)
    
    differences = []
    
    # 1. Compare tables
    t1_set = set(s1['tables'].keys())
    t2_set = set(s2['tables'].keys())
    if t1_set != t2_set:
        differences.append(f"Tables mismatch: {name1} has {t1_set - t2_set}, {name2} has {t2_set - t1_set}")
    for tbl in t1_set.intersection(t2_set):
        cols1 = s1['tables'][tbl]
        cols2 = s2['tables'][tbl]
        if cols1 != cols2:
            differences.append(f"Table '{tbl}' column mismatch: {name1}={cols1} vs {name2}={cols2}")
            
    # 2. Compare foreign keys
    for tbl in t1_set.intersection(t2_set):
        fk1 = s1['foreign_keys'].get(tbl, [])
        fk2 = s2['foreign_keys'].get(tbl, [])
        if fk1 != fk2:
            differences.append(f"Table '{tbl}' foreign keys mismatch:\n  {name1}: {fk1}\n  {name2}: {fk2}")
            
    # 3. Compare indexes (definitions)
    idx1_set = set(s1['indexes'].keys())
    idx2_set = set(s2['indexes'].keys())
    if idx1_set != idx2_set:
        differences.append(f"Index names mismatch: {name1} has {idx1_set - idx2_set}, {name2} has {idx2_set - idx1_set}")
    for idx in idx1_set.intersection(idx2_set):
        sql1 = s1['indexes'][idx]['sql']
        sql2 = s2['indexes'][idx]['sql']
        if sql1 != sql2:
            differences.append(f"Index '{idx}' SQL definition mismatch:\n  {name1}: {sql1}\n  {name2}: {sql2}")
            
    # 4. Compare triggers (definitions)
    trg1_set = set(s1['triggers'].keys())
    trg2_set = set(s2['triggers'].keys())
    if trg1_set != trg2_set:
        differences.append(f"Trigger names mismatch: {name1} has {trg1_set - trg2_set}, {name2} has {trg2_set - trg1_set}")
    for trg in trg1_set.intersection(trg2_set):
        sql1 = s1['triggers'][trg]['sql']
        sql2 = s2['triggers'][trg]['sql']
        if sql1 != sql2:
            differences.append(f"Trigger '{trg}' SQL definition mismatch:\n  {name1}: {sql1}\n  {name2}: {sql2}")
            
    print(f"=== DEEP SCHEMA COMPARISON: {name1} vs {name2} ===")
    print(f"Tables count: {len(s1['tables'])} vs {len(s2['tables'])}")
    print(f"Indexes count: {len(s1['indexes'])} vs {len(s2['indexes'])}")
    print(f"Triggers count: {len(s1['triggers'])} vs {len(s2['triggers'])}")
    
    if differences:
        print(f"\nFOUND {len(differences)} DIFFERENCE(S):")
        for d in differences:
            print(f"- {d}")
        return False
    else:
        print("\nSUCCESS: 100% schema match! All tables, columns, foreign keys, index definitions, and trigger definitions are identical.")
        return True

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python deep_compare_schemas.py <db1> <db2> [name1] [name2]")
        sys.exit(1)
    name1 = sys.argv[3] if len(sys.argv) > 3 else "DB1"
    name2 = sys.argv[4] if len(sys.argv) > 4 else "DB2"
    success = deep_compare(sys.argv[1], sys.argv[2], name1, name2)
    sys.exit(0 if success else 1)
