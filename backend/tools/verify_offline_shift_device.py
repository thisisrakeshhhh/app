import subprocess
import time
import json
import sqlite3
import os
import sys

ADB = r"C:\Users\Rakesh kumar\AppData\Local\Android\Sdk\platform-tools\adb.exe"
DEVICE = "4bc99b28"
D1_DB = r"D:\app\backend\.wrangler\state\v3\d1\miniflare-D1DatabaseObject\375634d678c996ae430f25b6d6e647334f27927de84135ea4b7b9e884d21d0b2.sqlite"

def adb(args):
    cmd = [ADB, "-s", DEVICE] + args
    res = subprocess.run(cmd, capture_output=True, text=True)
    return res.stdout.strip()

def get_d1_shift():
    conn = sqlite3.connect(D1_DB)
    cur = conn.cursor()
    cur.execute("SELECT id, status, start_time, end_time FROM shifts WHERE user_id='user_sales' ORDER BY start_time DESC LIMIT 1")
    row = cur.fetchone()
    conn.close()
    return row

def get_device_room_state():
    # Pull Room DB using run-as
    adb(["shell", "run-as com.routeflow.app cp databases/routeflow_db /sdcard/dev_rf.sqlite"])
    adb(["shell", "run-as com.routeflow.app cp databases/routeflow_db-wal /sdcard/dev_rf.sqlite-wal"])
    adb(["shell", "run-as com.routeflow.app cp databases/routeflow_db-shm /sdcard/dev_rf.sqlite-shm"])
    adb(["pull", "/sdcard/dev_rf.sqlite", "scratch_room.sqlite"])
    adb(["pull", "/sdcard/dev_rf.sqlite-wal", "scratch_room.sqlite-wal"])
    adb(["pull", "/sdcard/dev_rf.sqlite-shm", "scratch_room.sqlite-shm"])
    
    conn = sqlite3.connect("scratch_room.sqlite")
    cur = conn.cursor()
    try:
        cur.execute("PRAGMA wal_checkpoint(FULL);")
    except:
        pass
    cur.execute("SELECT status, startTime, endTime FROM local_shifts ORDER BY startTime DESC LIMIT 1")
    shift_row = cur.fetchone()
    
    cur.execute("SELECT type, syncState, retryCount, payload FROM sync_outbox WHERE type IN ('SHIFT_START','SHIFT_END')")
    outbox_rows = cur.fetchall()
    conn.close()
    
    for f in ["scratch_room.sqlite", "scratch_room.sqlite-wal", "scratch_room.sqlite-shm"]:
        if os.path.exists(f): 
            try: os.remove(f)
            except: pass
    return shift_row, outbox_rows

def is_tracking_service_running():
    out = adb(["shell", "dumpsys activity services com.routeflow.app"])
    return "ShiftTrackingService" in out

def main():
    print("=== Testing NEW Shift: Offline End and Recovery ===")
    
    # Ensure reverse tunnel is up for start shift
    adb(["reverse", "tcp:8787", "tcp:8787"])
    time.sleep(1)
    
    running = is_tracking_service_running()
    if not running:
        print("\n1. Starting NEW Shift through App UI...")
        # Button "Start Duty / Shift" coordinates on Vivo 1935: [579, 858]
        adb(["shell", "input tap 579 858"])
        time.sleep(4)
        running = is_tracking_service_running()
        print(f"Tracking Service running after Start Shift: {running}")
        if not running:
            print("ERROR: ShiftTrackingService did not start!")
            return False
    else:
        print("\n1. Shift is ALREADY active with ShiftTrackingService running in foreground.")
        
    d1_shift_start = get_d1_shift()
    print(f"Backend D1 Shift after start: {d1_shift_start}")
    
    room_shift, outbox = get_device_room_state()
    print(f"Device Room Shift: {room_shift}")
    print(f"Device Outbox: {outbox}")
    
    # 2. ESTABLISH TRUE OFFLINE STATE
    print("\n2. Establishing TRUE Offline State (removing reverse tunnel + network)...")
    adb(["reverse", "--remove", "tcp:8787"])
    adb(["shell", "svc wifi disable"])
    adb(["shell", "svc data disable"])
    rev_list = adb(["reverse", "--list"])
    print(f"Active Reverse Tunnels (should be empty): '{rev_list}'")
    time.sleep(2)
    
    # 3. END SHIFT THROUGH THE APP WHILE OFFLINE
    print("\n3. Ending Shift through App UI while offline...")
    # On screen, button is now "End Duty / Shift" at same position [579, 858]
    adb(["shell", "input tap 579 858"])
    time.sleep(2)
    
    # 4. VERIFY LOCAL TRACKING STOPS IMMEDIATELY
    service_after_end = is_tracking_service_running()
    print(f"Tracking Service running immediately after offline End Shift: {service_after_end}")
    if service_after_end:
        print("ERROR: Tracking service was NOT terminated locally immediately!")
        return False
    print("CONFIRMED: Local tracking stopped immediately upon End Shift!")
    
    # Inspect Room DB while offline
    room_shift_end, outbox_end = get_device_room_state()
    print(f"Device Room Shift (offline): {room_shift_end}")
    print(f"Device Outbox (offline): {outbox_end}")
    
    d1_shift_while_offline = get_d1_shift()
    print(f"Backend D1 Shift (while device is offline, should still be ON_SHIFT): {d1_shift_while_offline}")
    assert d1_shift_while_offline[1] == 'ON_SHIFT', "Server shift should still be ON_SHIFT while device is offline"
    
    # 5. RESTORE CONNECTION
    print("\n5. Restoring connection (adb reverse tcp:8787 tcp:8787 + wifi)...")
    adb(["reverse", "tcp:8787", "tcp:8787"])
    adb(["shell", "svc wifi enable"])
    time.sleep(3)
    
    # 6. OBSERVE AUTOMATIC RECOVERY
    print("\n6. Observing Automatic Recovery (waiting 20s without user interaction)...")
    time.sleep(20)
    d1_after_auto = get_d1_shift()
    room_after_auto, outbox_after_auto = get_device_room_state()
    print(f"Backend D1 Shift after 20s auto-wait: {d1_after_auto}")
    print(f"Device Outbox after 20s auto-wait: {outbox_after_auto}")
    
    auto_synced = (d1_after_auto[1] == 'OFF_SHIFT')
    print(f"Automatic Recovery result: {'SYNCED AUTOMATICALLY' if auto_synced else 'PENDING USER/NETWORK ACTION'}")
    
    # 7. OBSERVE USER-TRIGGERED RECOVERY
    if not auto_synced:
        print("\n7. Triggering User Recovery (Sync Now in App)...")
        # Navigate to Profile tab [981, 2040]
        adb(["shell", "input tap 981 2040"])
        time.sleep(2)
        # In profile screen, "Sync Now with Server" button is at [540, 1620]
        adb(["shell", "input tap 540 1620"])
        time.sleep(4)
        
        # Or resume MainActivity to trigger onResume scheduleSync
        adb(["shell", "am start -n com.routeflow.app/.app.MainActivity"])
        time.sleep(4)
        
        d1_after_user = get_d1_shift()
        room_after_user, outbox_after_user = get_device_room_state()
        print(f"Backend D1 Shift after user recovery: {d1_after_user}")
        print(f"Device Outbox after user recovery: {outbox_after_user}")
        user_synced = (d1_after_user[1] == 'OFF_SHIFT')
        print(f"User-triggered Recovery result: {'SUCCESSFULLY SYNCED' if user_synced else 'FAILED'}")
    else:
        user_synced = True
        
    print("\n=== TEST COMPLETE ===")
    return True

if __name__ == "__main__":
    main()
