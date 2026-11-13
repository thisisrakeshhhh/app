# RouteFlow — Phase 3 Verification Report
## Real Road Route Engine, Live Navigation & Intelligent Rerouting

**Project:** RouteFlow / Routidrow  
**Application:** Flutter Distributor App (`com.routidrow.distributor.debug`)  
**Phase:** Phase 3 — Real Road Route Engine  
**Baseline Commit:** `b9a20b7` (`feat(sales): Phase 2 map foundation with custom numbered pins, cluster badges, and controls`)  
**Target Branch:** `feature/sales-inventory-shop`  
**Reference Physical Device:** Vivo 1935 (Android 10, API 29, ID `4bc99b28`)  
**Date:** November 13, 2026  
**Status:** COMPLETE & VERIFIED (28/28 Automated Tests Passed, 0 Dart Analyzer Issues, Live Device Verified)

---

## 1. Executive Summary

Phase 3 successfully transforms RouteFlow from a map visualizer into an enterprise-grade, road-following GIS route and navigation engine tailored for FMCG field sales operations in India. 

Building upon the pristine Phase 2 baseline (`b9a20b7`), Phase 3 introduces:
1. **Real Road-Following Geometry:** Accurate driving geometry via OSRM routing engine with honest approximate geodesic fallback if offline or unreachable. No synthetic straight-line shortcuts across city blocks.
2. **Authoritative Owner-Assigned Sequencing:** Strict beat preservation: Godown $\rightarrow$ Stop 1 $\rightarrow$ Stop 2 $\rightarrow$ ... $\rightarrow$ Stop N. The salesperson is never silently rerouted to skip or reorder shops.
3. **Live Distance & Driving ETA:** Dynamic aggregation of next-stop distance/time and remaining route totals directly inside a non-intrusive floating `RouteInfoPanel`.
4. **GPS Jitter & Deviation Engine:** Strict stationary filter (`speed >= 1.2 m/s`, `headingAccuracy <= 45°`), 2-consecutive off-route reading threshold ($> 60\text{ m}$ perpendicular deviation), and 15-second reroute cooldown. Recalculates *only* the active leg while preserving all subsequent stops.
5. **External Turn-by-Turn Navigation:** Native platform channel launching Google Maps (`google.navigation:q=lat,lng&mode=d`) directly from both the `RouteInfoPanel` "Navigate" button and the primary "Route Chalu Karein" button.
6. **Zero Paid Credentials / Zero Regressions:** Zero external paid API billing keys hardcoded; all existing Phase 1 & 2 workflows (beat switching, Add Shop, shop lists, bottom tabs) remain intact and fully functional.

---

## 2. Routing Provider Comparison & Architecture Audit

During the initial audit, the Google Routes API (`https://routes.googleapis.com/directions/v2:computeRoutes`) was evaluated using the Google Maps API key defined in `AndroidManifest.xml`. The Android SDK restriction on this key correctly blocks REST API calls without specific backend billing credentials (HTTP 403 Forbidden).

To ensure zero vendor lock-in, zero runtime billing costs, and high-performance routing across Indian cities, the system was architected with a decoupled `RouteProvider` interface:

| Criteria | Google Routes API (REST) | OSRM Public Driving API (Implemented) | Honest Approximate Fallback |
| :--- | :--- | :--- | :--- |
| **API Cost / Billing** | Requires Google Cloud billing & unlocked REST key | Free / Open Source | Completely Local (Zero Network) |
| **Road Following** | Excellent | Excellent (Turn-by-turn road geometry) | Direct geodesic fallback (tagged as approximate) |
| **Indian Road Coverage** | High | High (Chandigarh, Mohali, Jodhpur verified) | Complete |
| **Network Failure Behavior** | Throws Exception | Throws Exception | Never fails; ensures offline continuity |
| **Status Tagging** | `success` | `success` | `approximateFallback` |

`RouteEngineService` automatically attempts the primary provider and falls back gracefully to `approximateFallback` if offline, tagging each `RouteLeg` with its exact source (`RouteLegStatus.success`, `RouteLegStatus.cached`, or `RouteLegStatus.approximateFallback`).

---

## 3. Files Created & Modified

### New Routing Subsystem (`flutter/lib/features/sales/routing/`)
1. [route_models.dart](file:///D:/app/flutter/lib/features/sales/routing/route_models.dart): Immutable models for `RouteLeg`, `RouteLegStatus`, `BeatRoutePlan`, and `RouteWaypoint`.
2. [polyline_decoder.dart](file:///D:/app/flutter/lib/features/sales/routing/polyline_decoder.dart): High-performance zero-dependency polyline decoder, Haversine distance, and point-to-polyline perpendicular distance calculation.
3. [route_provider.dart](file:///D:/app/flutter/lib/features/sales/routing/route_provider.dart): `RouteProvider` abstract interface and `OsrmRouteProvider` implementation with network error handling and honest fallback calculations.
4. [route_cache_repository.dart](file:///D:/app/flutter/lib/features/sales/routing/route_cache_repository.dart): Route cache repository with coordinate proximity matching ($\le 60\text{ m}$) for immediate offline route restoration.
5. [route_deviation_detector.dart](file:///D:/app/flutter/lib/features/sales/routing/route_deviation_detector.dart): Stationary jitter filter (`speed >= 1.2 m/s`, `headingAccuracy <= 45°`), 2-strike off-route deviation detector ($> 60\text{ m}$), and 15s reroute throttle.
6. [external_navigation_service.dart](file:///D:/app/flutter/lib/features/sales/routing/external_navigation_service.dart): MethodChannel client for `com.routidrow.distributor/navigation`.
7. [route_engine_service.dart](file:///D:/app/flutter/lib/features/sales/routing/route_engine_service.dart): Core orchestrator combining salesperson GPS, pending beat stops, route computation, and cache persistence.
8. [route_info_panel.dart](file:///D:/app/flutter/lib/features/sales/routing/route_info_panel.dart): Responsive, glassmorphic UI card displaying Next Stop, live road distance, ETA, Navigate button, remaining stop counter, and total beat duration.

### Modified Existing Files
1. [MainActivity.kt](file:///D:/app/flutter/android/app/src/main/kotlin/com/lalacompany/distributor/lala_distributor/MainActivity.kt): Added `MethodChannel` (`com.routidrow.distributor/navigation`) to handle `launchGoogleMapsNavigation` with explicit package targeting (`com.google.android.apps.maps`) and `ACTION_VIEW` fallback.
2. [sales_dashboard.dart](file:///D:/app/flutter/lib/screens/dashboards/sales_dashboard.dart): 
   - Integrated `RouteEngineService` and `RouteDeviationDetector`.
   - Replaced visual straight lines with real decoded road polylines (`Polyline` with custom styling: Primary Cyan `#0284C7` for active leg, Muted Slate `#64748B` for future legs).
   - Embedded `RouteInfoPanel` over map with seamless collapse in fullscreen mode.
   - Connected `continue_route_btn` ("Route Chalu Karein") to `ExternalNavigationService.launchNavigation()`.
3. [route_engine_phase3_test.dart](file:///D:/app/flutter/test/route_engine_phase3_test.dart): Comprehensive automated test suite validating decoding, geometry, fallback, caching, deviation filtering, route aggregation, navigation intent, and UI rendering.

---

## 4. Key Functional Implementations

### A. Road-Following Route Geometry
- `OsrmRouteProvider` queries the driving profile (`/route/v1/driving/{lon1},{lat1};{lon2},{lat2}?overview=full&geometries=polyline`).
- `PolylineDecoder.decode()` translates standard 5-decimal encoded strings into `List<LatLng>` without third-party plugin dependencies.
- Polylines are styled distinctly:
  - **Active Leg (Rep $\rightarrow$ Next Stop):** Deep Cyan (`#0284C7`, 5px width, z-index 10) to clearly highlight immediate driving path.
  - **Remaining Legs (Stop $i \rightarrow$ Stop $i+1$):** Slate Gray (`#64748B`, 3px width, z-index 5) showing the full beat roadmap.

### B. Ordered Beat Routing
- The engine strictly respects the assigned sequence: `Godown` $\rightarrow$ `Stop 1` $\rightarrow$ `Stop 2` $\rightarrow$ ... $\rightarrow$ `Stop N`.
- When checked-in or completed, visited shops are marked as completed, and the active leg immediately repoints to the next pending stop.
- No reordering or skipping occurs.

### C. Live Distance & ETA Calculations
- Next Stop distance and duration are parsed directly from road geometry or calculated via Haversine at $25\text{ km/h}$ urban speed when approximate.
- Remaining route distance and ETA are dynamically accumulated across all pending legs:
  $$\text{Total Remaining Distance} = d_{\text{active}} + \sum_{i=\text{next}}^{N-1} d(i, i+1)$$
  $$\text{Total Remaining Time} = t_{\text{active}} + \sum_{i=\text{next}}^{N-1} t(i, i+1)$$
- Values are formatted cleanly for Indian sales reps (e.g. `12.3 km • 13 min` and `Today: 5 of 6 stops left • 25.4 km • 34 min`).

### D. GPS Filtering & Deviation Rerouting
- **Jitter Mitigation:** When `speed < 1.2 m/s` or `headingAccuracy > 45°`, GPS heading is marked unconfident to prevent spinning markers.
- **Perpendicular Distance:** Point-to-segment distance algorithm calculates the cross-track error $d_{\perp}$ in meters from the rep's current position to the active road polyline.
- **2-Consecutive Rule:** A reroute is flagged only after 2 consecutive readings exceed $60\text{ m}$.
- **Leg Isolation:** When rerouting triggers, only Leg 0 (Rep $\rightarrow$ Next Stop) is recalculated; the rest of the beat remains unchanged.

### E. External Turn-by-Turn Navigation
- Tapping **Navigate** on the `RouteInfoPanel` or **Route Chalu Karein** executes:
  ```kotlin
  val uri = Uri.parse("google.navigation:q=$lat,$lng&mode=d")
  val intent = Intent(Intent.ACTION_VIEW, uri)
  intent.setPackage("com.google.android.apps.maps")
  intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
  ```
- Directly opens Google Maps in driving turn-by-turn mode targeting the next shop coordinates.

---

## 5. Verification Results

### A. Dart Analysis
```text
$ dart analyze
Analyzing flutter...
No issues found!
```

### B. Automated Unit & Regression Tests
Executed 28 automated tests across `route_engine_phase3_test.dart`, `sales_step0_corrections_test.dart`, and `role_routing_test.dart`:
```text
00:00 +0: RouteFlow Phase 3 — 1. PolylineDecoder decodes standard encoded polyline cleanly
00:00 +1: RouteFlow Phase 3 — 2. PolylineDecoder Haversine distance and perpendicular distance to polyline
00:00 +2: RouteFlow Phase 3 — 3. OsrmRouteProvider successfully parses road route response
00:00 +3: RouteFlow Phase 3 — 4. OsrmRouteProvider falls back to honest approximate fallback on network failure
00:00 +4: RouteFlow Phase 3 — 5. RouteCacheRepository caches and retrieves legs accurately
00:00 +5: RouteFlow Phase 3 — 6. RouteDeviationDetector filters stationary jitter and detects consecutive off-route movement
00:00 +6: RouteFlow Phase 3 — 7. RouteEngineService builds ordered beat route and aggregates distance & ETA
00:00 +7: RouteFlow Phase 3 — 8. ExternalNavigationService launches navigation intent safely
00:00 +8: RouteFlow Phase 3 — 9. RouteInfoPanel renders next stop, distance, ETA, and navigation button
...
00:04 +28: All tests passed!
```
**Result: 28 Passed, 0 Failed, 0 Flaky.**

### C. Physical Device Verification (Vivo 1935, Android 10)
1. **App Installation & Startup:** Built `app-debug.apk` and installed cleanly on device `4bc99b28`.
2. **Dashboard Rendering:**
   - Map rendered with custom numbered pins, cluster badges, and salesperson position (`📍 YOU ARE HERE`).
   - `RouteInfoPanel` displayed floating on top of the map:
     - `NEXT STOP: Punjab Kirana & Departmental Store`
     - `12.3 km • 13 min`
     - Actionable `Navigate` button
     - `Today: 5 of 6 stops left • 25.4 km • 34 min`
3. **Turn-by-Turn Navigation Launch:**
   - Tapping `Navigate` invoked `com.google.android.apps.maps/com.google.android.maps.MapsActivity` directly.
   - Tapping `Route Chalu Karein` (`continue_route_btn`) invoked turn-by-turn navigation directly.
4. **Preserved Workflows:**
   - Beat switching (`Chandigarh & Mohali` vs `Jodhpur`) updates markers and route immediately.
   - Add Shop button (`+ Add Shop`) remains present and responsive.
   - Bottom navigation tabs (`Aaj`, `Dukaanein`, `Kamai`, `Aur`) navigate cleanly without state corruption.

---

## 6. Live Device Evidence

Artifact references for inspection:
- Screenshot of Live Sales Dashboard with Phase 3 Route Engine & Route Info Panel: [screen_phase3_sales.png](file:///C:/Users/Rakesh%20kumar/.gemini/antigravity/brain/809621ce-2d19-4eeb-9f07-7064006df622/screen_phase3_sales.png)
- UI Dump Hierarchy: [ui_phase3_sales.xml](file:///C:/Users/Rakesh%20kumar/.gemini/antigravity/brain/809621ce-2d19-4eeb-9f07-7064006df622/ui_phase3_sales.xml)

---

## 7. Known Limitations & Recommendations for Phase 4

1. **OSRM Public Gateway Rate Limits:** The default OSRM public server is ideal for development and standard beat planning. For dense production loads with hundreds of reps pinging routes every second, a self-hosted OSRM container or enterprise route proxy can be configured via `OsrmRouteProvider(baseUrl: ...)`.
2. **Offline Turn-by-Turn Guidance:** While route caching stores polyline coordinates offline, turn-by-turn voice prompts require Google Maps. Offline Google Maps areas can be downloaded by the salesperson on their device for offline turn-by-turn navigation.
3. **Phase 4 Alignment:** Next phase will focus on real-time visit check-in geo-fencing, proof-of-visit photo/signature capture, and sync with Cloudflare D1.
