# Milestone 1 changed-file inventory

## Build and identity

- `settings.gradle.kts`: RouteFlow root name; single app inclusion.
- `build.gradle.kts`: explicit Kotlin Android, Hilt and KSP plugin declarations.
- `gradle/libs.versions.toml`: compatible AGP plus pinned architecture dependencies.
- `gradle/wrapper/gradle-wrapper.properties`: Gradle 8.13 and 60-second download timeout.
- `gradle.properties`: remove unnecessary Jetifier.
- `app/build.gradle.kts`: RouteFlow namespace/application ID, SDK 36.1/36/26, aligned bytecode targets, Hilt/KSP/Navigation/StateFlow dependencies, R8/resource shrinking.
- `app/proguard-rules.pro`: actual project keep-rule file referenced by the build.
- `.gitignore`: generated output, local configuration, signing and secret-file exclusions.

## Android resources

- `app/src/main/AndroidManifest.xml`: RouteFlow application/activity/theme; no runtime permissions; cleartext traffic and backup disabled.
- `app/src/main/res/values/strings.xml`: RouteFlow label.
- `app/src/main/res/values/themes.xml` and `values-night/themes.xml`: matching light/dark window themes.
- `app/src/main/res/drawable/ic_owner.xml`, `ic_sales.xml`, `ic_warehouse.xml`, `ic_delivery.xml`: labelled role-card illustrations, implemented as native vectors.
- `drawable/routeflow_icon_background.xml`, `routeflow_icon_foreground.xml` and `mipmap-anydpi/ic_launcher.xml`, `ic_launcher_round.xml`: RouteFlow adaptive launcher mark, including monochrome support.
- Removed unused starter colors, Android robot launcher vectors/bitmaps, the now-unnecessary v26 icon folder and the unused AGP 9-style `src/main/keepRules/rules.keep` template.

## Kotlin sources

All new production sources are under `app/src/main/java/com/routeflow/app/`:

- `app/MainActivity.kt`, `RouteFlowApplication.kt`, `RepositoryModule.kt`: entry point and dependency injection.
- `domain/model/EmployeeRole.kt`, `Employee.kt`, `domain/repository/EmployeeRepository.kt`: pure domain types and demo directory contract.
- `data/repository/FakeEmployeeRepository.kt`: four in-memory sample employees.
- `core/design/RouteFlowTheme.kt`, `ScreenStates.kt`, `RoleIcon.kt`, `RoleHomeScreen.kt`: shared UI.
- `feature/auth/DemoLoginViewModel.kt`, `DemoLoginScreen.kt`: state/actions and role-selection UI.
- `feature/owner/OwnerHomeScreen.kt`, `feature/sales/SalesHomeScreen.kt`, `feature/warehouse/WarehouseHomeScreen.kt`, `feature/delivery/DeliveryHomeScreen.kt`: four role-specific homes.
- `navigation/RoleDestination.kt`, `RouteFlowApp.kt`: tested exhaustive routing, shared app bar and back behavior.

The eight starter production Kotlin files under `com/example/myapplication` and `com/example/route` were replaced. The four starter test files were replaced rather than retaining arithmetic-only tests and conflicting application IDs.

## Tests and documentation

- `app/src/test/java/com/routeflow/app/navigation/RoleDestinationTest.kt`: all four destinations.
- `app/src/test/java/com/routeflow/app/core/testing/MainDispatcherRule.kt`: coroutine main-dispatcher fixture.
- `app/src/test/java/com/routeflow/app/data/repository/FakeEmployeeRepositoryTest.kt`: demo directory integrity.
- `app/src/test/java/com/routeflow/app/feature/auth/DemoLoginViewModelTest.kt`: loading, selection, invalid ID, logout, error/retry and empty data.
- `app/src/androidTest/java/com/routeflow/app/RoleSelectionTest.kt`: real Activity role selection, role changes and Back after recreation.
- `README.md`, `docs/REPOSITORY_AUDIT.md`, `docs/CHANGES.md`, `docs/VALIDATION.md`: setup, audit/plan, file inventory and actual verification.

Build logs and build outputs are generated/ignored files. `local.properties`, the JDK criteria, Gradle wrapper scripts/JAR and Android Studio settings were not rewritten.
