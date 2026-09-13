# RouteFlow — Milestone 1

Native Android employee app for warehouse-to-retailer distribution in Jaipur, Rajasthan. This milestone is a **local demonstration**, not production authentication or a working order/payment system.

## What is implemented

- RouteFlow application identity: `com.routeflow.app`.
- Material 3 light/dark theme and scrollable phone layouts with 48dp or larger interactive targets.
- Demo role selection, four role-specific placeholder homes, a shared role-aware app bar and Change role action.
- In-memory Jaipur sample employees supplied through a repository interface and Hilt.
- MVVM, Coroutines, StateFlow, lifecycle-aware state collection and Navigation Compose.
- Shared loading, safe error/retry and empty-state components.
- Unit tests for all role destinations, fake employees and login state behavior; Compose instrumentation tests for selection, change-role and Back/recreation.

| Demo role | Fictional employee | Home |
| --- | --- | --- |
| Owner / Admin | Amit Sharma | Business overview |
| Salesperson | Rakesh Kumar | Your sales day |
| Warehouse Manager | Manoj Kumar | Warehouse desk |
| Delivery Executive | Suresh Yadav | Your delivery day |

Company: Jaipur Wholesale Distributors. Warehouse: Jaipur Main Warehouse. Sample beat: Mansarovar West, BEAT-04. No passwords or demo credentials are needed.

## Setup on Windows

1. Open this directory in Android Studio (tested toolchain versions below).
2. Install Android SDK Platform **36.1**, Build Tools **35.0.0**, and Platform Tools through SDK Manager. Install an emulator/system image or connect a device running API 26 or newer.
3. Set Android Studio's Gradle JDK to **21**. The existing Gradle daemon criteria request JDK 21; Java and Kotlin bytecode targets are explicitly aligned to 11.
4. Let Android Studio create `local.properties` with the SDK path. This file is machine-specific and ignored. The inspected machine uses `sdk.dir=D\:\\AndroidSDK`.
5. Run Gradle Sync and select the `app` run configuration.

From PowerShell in the project directory:

```powershell
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
.\gradlew.bat assembleDebug
.\gradlew.bat testDebugUnitTest
.\gradlew.bat lintDebug
.\gradlew.bat assembleDebugAndroidTest
```

If Java is installed elsewhere, use that JDK 21 path. The wrapper downloads its own pinned Gradle distribution. The first build needs access to Gradle, Google Maven, Maven Central and the Gradle Plugin Portal. A download timeout, UnknownHostException or proxy error is a network/setup failure: fix connectivity and retry the same versions. The wrapper timeout is 60 seconds.

On Windows, an old Gradle daemon can retain lint JAR locks after changing toolchains. Stop that daemon and retry with `--no-daemon`; do not disable the affected lint checks. Build logs redirected with PowerShell may wrap stderr in `NativeCommandError`; inspect the Gradle exit code and final result.

## Run and test the demo

Install/run `app` from Android Studio or run `.\gradlew.bat installDebug` with one connected device. The APK is `app/build/outputs/apk/debug/app-debug.apk`.

1. Select a role. Open demo workspace becomes enabled.
2. Open the workspace and verify the employee, role in the app bar and correct home title.
3. Use Change role or Android Back to return to the picker. The previous selection is cleared.
4. At the picker, Android Back exits normally. Rotation keeps the current ViewModel session. Process death/force-stop resets the demo session; a restored navigation destination cannot recover access on its own.
5. Repeat with all four roles. Verify on a 360dp-wide device, with larger font settings, in dark mode and landscape.

To run device tests:

```powershell
.\gradlew.bat connectedDebugAndroidTest
```

These tests need a connected device/emulator. Compiling the test APK does **not** mean the tests ran. See [validation results](docs/VALIDATION.md) for the actual checks performed.

## Toolchain decisions

| Component | Version |
| --- | --- |
| AGP / Gradle | 8.13.2 / 8.13 |
| Kotlin / Compose compiler | 2.2.10 |
| Compose BOM | 2026.02.01 (preserved) |
| compileSdk / targetSdk / minSdk | 36.1 / 36 / 26 |
| Activity Compose | 1.10.1 |
| Lifecycle | 2.9.4 |
| Navigation Compose | 2.9.4 |
| Dagger Hilt / KSP | 2.57.2 / 2.2.10-2.0.2 |
| Coroutines | 1.9.0 |

AGP 8.13 supports the installed API 36.1 platform and documents Gradle 8.13 as its default/minimum. Keeping Kotlin 2.2.10 and the Compose BOM avoids an unnecessary AGP 9/built-in Kotlin migration. The Kotlin Android plugin is applied explicitly. Activity/Lifecycle/Navigation versions provide the lifecycle-aware Compose and navigation integration used here; KSP matches the existing Kotlin version. Hilt uses KSP rather than kapt.

- [AGP compatibility](https://developer.android.com/build/releases/agp-8-13-0-release-notes)
- [Lifecycle release notes](https://developer.android.com/jetpack/androidx/releases/lifecycle)
- [Navigation release notes](https://developer.android.com/jetpack/androidx/releases/navigation)
- [Hilt setup](https://dagger.dev/hilt/gradle-setup.html)
- [KSP release](https://github.com/google/ksp/releases/tag/2.2.10-2.0.2)

## Architecture and boundaries

One Gradle app module with packages under `app/src/main/java/com/routeflow/app`:

```text
app/                 Application, Activity and Hilt bindings
core/design/         Theme, icons, shared states and home layout
domain/model/        Employee and EmployeeRole
domain/repository/   EmployeeRepository contract
data/repository/     FakeEmployeeRepository
feature/auth/        DemoLoginViewModel, immutable state and picker
feature/owner/       Owner placeholder
feature/sales/       Salesperson placeholder
feature/warehouse/   Warehouse placeholder
feature/delivery/    Delivery placeholder
navigation/          Exhaustive role mapping and NavHost
```

UI actions flow to the ViewModel; immutable StateFlow values flow back to Compose. Hilt injects a fake repository. Navigation follows the active employee and clears the old back stack on role changes. Role routing is **not server authorization**. The domain/repository boundary permits a later API implementation, but real authentication will require a dedicated session/authentication contract.

Room, WorkManager, DataStore, Keystore and location packages are intentionally not empty scaffolds or unused dependencies. Add them when there is a confirmed persistence, sync, preference or security use case. This milestone has no business records, disk-backed login, queue or sensitive local material.

The banner says Offline demo because all data is local; it does not pretend to measure connectivity. There is no synchronization or pending-sync counter yet. Homes use honest empty placeholders, not fake sales totals or working business buttons.

## Security and release boundary

- No production API, Firebase, authentication, OTP, payment, location or camera integration.
- No app-declared runtime permissions. HTTPS-only network policy is set for future integration; INTERNET is not requested in this milestone.
- The demo stores no credentials, tokens, employee locations or business records. UI errors never expose repository exception details.
- Backup is disabled. Revisit encrypted storage, Keystore, backup/transfer exclusions and session handling before introducing sensitive data.
- `.gitignore` excludes local settings, environment files, signing keystores, private key files and service-account configuration. This workspace currently has no Git metadata; no commit or remote push was performed.
- R8 and resource shrinking are enabled for release. `app/proguard-rules.pro` is the project rule file; library consumer rules are applied normally.
- `.\gradlew.bat bundleRelease` prepares an **unsigned** release AAB in `app/build/outputs/bundle/release/`. No release signing key is created or embedded. For a future production build, use Android Studio's Generate Signed Bundle flow with a privately held upload key, then Play App Signing. Do not publish this demo as a finished distribution product.
- Development/staging/production API environments, real account access, privacy policy, Play disclosures and signing configuration belong to later production milestones. Target API 36 alone does not establish Google Play compliance.

## Next milestone

**Milestone 2: local read-only directory and beat foundation.** Define retailer, product and beat domain models; add a Room database with schema export/migration tests; seed clearly fake Jaipur data; expose repository flows; let the salesperson view BEAT-04 shops and product details offline. Use integer paise or BigDecimal for monetary values. Keep production authentication, writes/sync, GPS and payments out until their contracts are agreed. Finish outstanding device acceptance checks for Milestone 1 first.

See the [original audit and plan](docs/REPOSITORY_AUDIT.md), [changed-file inventory](docs/CHANGES.md) and [validation results](docs/VALIDATION.md).
# app
