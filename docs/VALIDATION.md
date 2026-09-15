# Validation

Final verification: 14 September 2026. This file records actual checks; pending items are not passes.

## Latest follow-up: 15 September 2026

The current working tree now includes separately added Room database/repository files and Kotlin/KSP changes. Those edits were preserved during the JDK troubleshooting follow-up; the Milestone 1 results below are historical.

`gradlew.bat assembleDebug testDebugUnitTest --rerun lintDebug --no-daemon --console=plain` completed **BUILD SUCCESSFUL in 1m 18s**. All 11 existing role/repository/ViewModel unit tests passed. Lint completed with 0 errors and 23 dependency-version notices. These tests do not exercise the new Room database at runtime. Current log: `continuation-build.log`.

The missing-jlink issue is resolved using the full JetBrains JDK 21; see [JDK setup](JAVA_SETUP.md). Device testing was attempted but failed with `No connected devices!`; the phone had disconnected before test execution. ADB again reported no devices on 15 September. Device UI tests remain pending. The release bundle was not rebuilt during this follow-up.

## Baseline repair

Command: `gradlew.bat assembleDebug testDebugUnitTest lintDebug --no-daemon --console=plain`

Result: **BUILD SUCCESSFUL**. Both original starter unit tests ran. Kotlin activity/composable compilation was restored. Lint completed after stopping old daemons that retained Windows file locks.

Resolved during baseline repair: missing Kotlin Android plugin; Java 11/Kotlin 21 target mismatch; incompatible original lint/toolchain; missing ProGuard file; duplicate app inclusion and wrong instrumentation application ID.

The first Gradle 8.13 download timed out; retrying the same version with a longer timeout succeeded. Dependency versions were not changed to bypass network failures.

## Milestone 1

Final command (PowerShell, from `D:\app`, using the installed Android Studio JDK 21):

```powershell
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
.\gradlew.bat clean assembleDebug testDebugUnitTest lintDebug assembleDebugAndroidTest bundleRelease --no-daemon --console=plain
```

Result: **BUILD SUCCESSFUL in 4m 26s**, exit code 0. 142 actionable tasks: 140 executed, 2 up-to-date. This was a clean build after the final resource changes, not a result from the previous starter APK.

| Check | Actual result |
| --- | --- |
| Gradle configuration/task graph | Passed; configuration cache stored |
| Debug Kotlin/Java compilation and APK | Passed |
| Unit tests | 11 tests, 0 failures, 0 errors |
| Debug lint | Passed; 0 errors, 18 version-update warnings |
| Instrumentation Kotlin compilation and APK | Passed; tests not executed on a device |
| Release Kotlin/Java compilation | Passed |
| R8/resource shrinking and release vital lint | Passed |
| Release AAB packaging | Passed; unsigned |
| Android Studio Sync UI | Not directly exercised; command-line configuration/build passed |
| Device launch, role-selection UI, Back and rotation | Not verified; no connected device/configured AVD available |

Unit test breakdown: 4 role-routing cases, 6 ViewModel cases (loading, explicit selection, invalid employee, logout, failure/retry, empty directory), 1 fake-directory integrity test. XML reports are in `app/build/test-results/testDebugUnitTest`; the HTML report is `app/build/reports/tests/testDebugUnitTest/index.html`.

Artifacts:

- Debug APK: `app/build/outputs/apk/debug/app-debug.apk` (12,271,148 bytes).
- Instrumentation APK: `app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk` (1,052,516 bytes).
- Release AAB: `app/build/outputs/bundle/release/app-release.aab` (2,573,414 bytes).
- Lint: `app/build/reports/lint-results-debug.html` and `.xml`.

The compiled app class JAR was inspected and contains both `com/routeflow/app/app/MainActivity.class` and `RouteFlowApplication.class`. The release AAB contains no JAR signature entries; `signReleaseBundle` appearing in Gradle output does not mean a signing key was configured. Production signing and Play publication were not performed.

## Remaining warnings

- Lint reports 18 dependency/tooling version notices: 2 `AndroidGradlePluginVersion`, 9 `GradleDependency`, 7 `NewerVersionAvailable`. No lint rules were disabled or baselined. Versions remain deliberately pinned; no automatic dependency upgrades were made just to eliminate notices.
- The installed SDK tooling reports an SDK XML v3/v4 reader mismatch. It did not prevent the clean build. Update Android SDK command-line tools through SDK Manager when maintaining the local environment.
- Hilt-generated application code emits a deprecated-API note; no application Kotlin compiler warnings were reported.
- `libandroidx.graphics.path.so` could not have debug symbols stripped and was packaged unchanged.
- Gradle daemon JVM discovery is marked incubating.

During implementation, plugin order was corrected so Android/Kotlin precede KSP/Hilt. Replacing/moving launcher resources exposed stale incremental resource entries; the final clean build resolved that failure. Earlier failures are not being reported as passes.

## Identity, permissions and secret review

- Main sources, manifest and Gradle identity have no remaining `com.example` or old theme references.
- The source manifest requests no permissions. The merged debug manifest adds only AndroidX's app-specific signature permission `com.routeflow.app.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`. No INTERNET, foreground/background location, camera, notification or storage runtime permission is requested.
- Filename/content scans of source and configuration (excluding generated caches, build outputs, IDE state and logs) found no matching credential assignments, private-key blocks, signing keystores or service-account files. This is a scoped source review, not a guarantee about files elsewhere on the machine.
- Signing/environment/private-key file patterns are ignored. There is no Git repository in this workspace, so no tracked-file audit or commit was possible.

## Device availability

`D:\AndroidSDK\platform-tools\adb.exe devices -l`: no connected devices.

`D:\AndroidSDK\emulator\emulator.exe -list-avds`: no configured AVDs.

Consequently, launch behavior, on-device Compose tests and visual/accessibility checks are not yet verified. A compiled APK or test APK does not substitute for these checks.

The ADB availability check was repeated on 14 September and still reported no devices. The ADB server started for inspection was stopped afterward. A repeated emulator-list check produced no AVD output; no emulator was created or launched.

Milestone 1 implementation and available build checks are finished. **Full acceptance remains pending device validation.** Connect an API 26+ device or configure an AVD, run `gradlew.bat connectedDebugAndroidTest`, then verify 360dp width, larger text, light/dark mode, landscape, Back from both picker/home, rotation and force-stop/relaunch. Check all four employee roles. The UI tests currently cover role selection/change and Back after Activity recreation; they have not been claimed as passing.
