# RouteFlow project check — 16 September 2026

Reviewed commit `7cadb32` against the attached client-demo requirements. This is a review of the current implementation; application code and databases were not modified during this check.

## Findings

These are source-level findings. No Android device was connected for runtime reproduction.

### P1 — Role destinations cannot construct their injected ViewModels

`navigation/RouteFlowApp.kt:159` and the other role/detail destinations call plain `androidx.lifecycle.viewmodel.compose.viewModel()`. Their owner is a navigation back-stack entry, whose default factory in the installed Navigation 2.9.4 sources is `SavedStateViewModelFactory`. The destination ViewModels require injected repository/DAO constructor arguments; the default factory cannot supply them. The Activity's Hilt annotation does not replace this navigation-entry factory. Use a Hilt-aware navigation ViewModel factory for these destinations.

Reference: [Android's Hilt and Navigation Compose integration](https://developer.android.com/develop/ui/compose/libraries#hilt-navigation).

### P1 — Existing installations cannot open the changed database

`core/database/RouteFlowDatabase.kt:29` still declares version 1 and disables schema export. Commit `6bff38f` also used version 1, but had only products and retailers, with Double money columns. The current schema adds six tables and changes money columns to Long paise. No migration is registered in `app/DatabaseModule.kt`. An installation with the previous database will fail Room's identity check; retrying login cannot repair it. Increment the version, export schemas, and migrate existing rows without deleting data. Because two different schemas now share version 1, handle both existing layouts when introducing the next version.

### P1 — Packing makes Dispatch unreachable

`feature/warehouse/PickingViewModel.kt:51` includes only APPROVED and PICKING orders. `markPacked()` changes the status to PACKED, removing the order from that list. The Dispatch button in `PickingScreen.kt:96` requires PACKED, so users cannot complete the advertised journey. Include packed orders in an accessible processing/dispatch screen.

### P1 — Searching changes the cart total and can crash submission

`feature/sales/OrderBookingViewModel.kt:33` calculates the total from the filtered products, while the cart retains all selected IDs. At line 126, submission looks up every cart item in that filtered list using `!!`. Add tea, then search for rice: tea disappears from the total and submission dereferences null. Keep a complete product lookup for cart validation, totals, and submission, independently of display filters.

### P1 — Inventory changes are neither reserved nor protected

`feature/owner/OrderApprovalViewModel.kt:67` changes status without checking or reserving stock. `feature/warehouse/PickingViewModel.kt:78` updates products individually, clamps shortages to zero, and changes status afterward, outside a shared transaction. Repeated dispatch calls can deduct stock again; partial failures can leave inventory and order status inconsistent. Free tea units are also excluded from the booking availability check. Centralize transitions in a transactional repository with stock reservations, sufficient-stock checks including free units, and repeated-call protection. Packing currently requires neither item confirmation nor a package count.

### P1 — Cash and credit delivery do not create financial records

`feature/delivery/DeliveryViewModel.kt:67` ignores the selected payment method and only changes status. It does not create an invoice, payment, delivery record, or retailer balance change. The code is validated only in the UI. Navigation returns to the delivery list before persistence completes. Implement and await one validated transaction, with exactly-once invoice/payment records and a saved confirmation.

### P2 — Back exits the entire role from detail screens

`navigation/RouteFlowApp.kt:305` registers an always-enabled workspace BackHandler after the NavHost. It clears the role even when the user is viewing a shop or order. Let detail destinations pop normally and clear the role only when leaving a role home. The in-memory booking cart is also lost when its navigation entry is removed.

### P2 — Reset is not restricted to demo rows

`data/repository/OfflineDemoRepository.kt:48` calls `clearAllTables()`. There is no demo-record marker or filter, so every record in this database is included. `isDemoDataSeeded()` treats any existing product as proof that demo seeding completed; a pre-existing non-demo product prevents retailer/demo initialization. Use a persistent seed marker and explicitly scoped demo records.

### P2 — Visits can duplicate or be attributed to the wrong screen

`feature/sales/ShopVisitViewModel.kt:67` inserts an active visit without checking for an existing one. Active visits are fetched for employee `S1`, independently of the screen's retailer. Opening another retailer during a visit therefore displays and can check out the earlier shop's visit. The employee ID also differs from the selected demo employee ID. Enforce a single active visit transactionally and present its actual retailer. The stock-check action is a TODO.

### P2 — Dashboard numbers do not reflect transactions

`feature/owner/OwnerViewModel.kt:44` always reports zero delivered sales; `feature/delivery/DeliveryViewModel.kt:41` always reports zero payments. `feature/sales/SalesViewModel.kt:21` invents achieved sales of ₹1,25,000 and never loads transaction data. Compute metrics from persisted records with the appropriate day/month and employee filters.

### P2 — Login retry retains the error

`feature/auth/DemoLoginViewModel.kt:39` does not clear `errorMessage` on retry or successful completion. `DemoLoginScreen` prioritizes this error over the employee list, so a temporary failure can leave the UI stuck on the error screen after a successful retry. The former error/retry test is commented out.

### P2 — Current tests and README overstate coverage

The unit suite contains 10 tests for employees, login, and role routing. There are no tests for money, promotions, inventory, transitions, payments, Room persistence, or migration. `RoleSelectionTest` still expects `home_OWNER` and other tags that the replacement home screens no longer expose. Compiling this test APK does not establish a passing UI test.

README still describes placeholder homes, no Room/business records, Kotlin 2.2.10, and 11 tests. The current project has Room business tables, Kotlin 2.1.0, KSP 2.1.0-1.0.29, and 10 active unit tests. It also incorrectly says there is no Git metadata.

## Other incomplete requirements

- Persisted/editable drafts and direct quantity entry.
- Central repository enforcement of roles, allowed transitions, and required rejection reasons; rejection currently discards its reason.
- SKU, reserved/available stock, seeded sample orders, and a persisted target.
- Retailer ledger and team screens; role-specific bottom navigation.
- Delivery assignment, checklist, external map action, and saved receipt details.
- Location-provider abstraction and saved optional retailer stock checks.
- Scroll/keyboard support on delivery details and verification of compact/large-font layouts.
- Error/retry handling around business-data flows and mutations.

## JDK check

The configured Gradle daemon criteria require JetBrains Java 21, and the local Gradle Java home points to Android Studio's full JBR. `C:/Program Files/Android/Android Studio/jbr/bin/jlink.exe` exists. The earlier VS Code runtime path is not the configured project JDK.

## Validation

Results are recorded below after the commands finish. Device tests cannot run because `adb devices -l` returned no devices.
