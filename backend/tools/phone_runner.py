import subprocess
import xml.etree.ElementTree as ET
import os
import sys
import time
import sqlite3
import glob

sys.stdout.reconfigure(encoding='utf-8')

ADB = os.path.expandvars(r"$LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe")
DEVICE = "4bc99b28"

def adb_cmd(args):
    return subprocess.run([ADB, "-s", DEVICE] + args, capture_output=True, text=True, check=True).stdout

def tap(x, y):
    adb_cmd(["shell", "input", "tap", str(x), str(y)])
    time.sleep(1.0)

def input_text(text):
    adb_cmd(["shell", "input", "text", text])
    time.sleep(0.5)

def keyevent(code):
    adb_cmd(["shell", "input", "keyevent", str(code)])
    time.sleep(0.5)

def dump_ui():
    adb_cmd(["shell", "uiautomator", "dump", "/sdcard/window_dump.xml"])
    subprocess.run([ADB, "-s", DEVICE, "pull", "/sdcard/window_dump.xml", "current_dump.xml"], capture_output=True, check=True)
    tree = ET.parse("current_dump.xml")
    elements = []
    for node in tree.iter("node"):
        text = node.attrib.get("text", "")
        desc = node.attrib.get("content-desc", "")
        bounds = node.attrib.get("bounds", "")
        clickable = node.attrib.get("clickable", "")
        if text or desc:
            elements.append((bounds, text, desc, clickable))
    if os.path.exists("current_dump.xml"):
        os.remove("current_dump.xml")
    return elements

def print_ui():
    els = dump_ui()
    for b, t, d, c in els:
        print(f"{b} | text='{t}' | desc='{d}' | clickable={c}")
    return els

def find_element(text_substring):
    els = dump_ui()
    for b, t, d, c in els:
        if text_substring.lower() in t.lower() or text_substring.lower() in d.lower():
            # parse bounds [x1,y1][x2,y2]
            parts = b.replace("][", ",").replace("[", "").replace("]", "").split(",")
            x1, y1, x2, y2 = map(int, parts)
            cx, cy = (x1 + x2) // 2, (y1 + y2) // 2
            return (cx, cy, t or d)
    return None

def get_db_cursor():
    d1_dir = os.path.join(os.path.dirname(__file__), "..", ".wrangler", "state", "v3", "d1", "miniflare-D1DatabaseObject")
    db_files = [f for f in glob.glob(os.path.join(d1_dir, "*.sqlite")) if "metadata" not in f]
    conn = sqlite3.connect(db_files[0])
    return conn, conn.cursor()

if __name__ == "__main__":
    if len(sys.argv) > 1:
        cmd = sys.argv[1]
        if cmd == "dump":
            print_ui()
        elif cmd == "tap" and len(sys.argv) >= 4:
            tap(int(sys.argv[2]), int(sys.argv[3]))
            print_ui()
        elif cmd == "query" and len(sys.argv) >= 3:
            conn, cur = get_db_cursor()
            cur.execute(sys.argv[2])
            rows = cur.fetchall()
            for r in rows:
                print(r)
            conn.close()
        elif cmd == "find_tap" and len(sys.argv) >= 3:
            res = find_element(sys.argv[2])
            if res:
                print(f"Found '{res[2]}' at ({res[0]}, {res[1]}), tapping...")
                tap(res[0], res[1])
                time.sleep(1)
                print_ui()
            else:
                print(f"Element '{sys.argv[2]}' not found")
    else:
        print_ui()
