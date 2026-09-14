# Repository audit and Milestone 1 plan

Audit performed on 13 September 2026, before feature implementation.

| Item | Original state |
| --- | --- |
| App name | My Application |
| Namespace / application ID | com.example.myapplication |
| Kotlin / Compose compiler | 2.2.10 |
| Android Gradle Plugin | 8.7.3 |
| Gradle wrapper | 9.4.1 |
| compileSdk / targetSdk / minSdk | 35 / 35 / 24 |
| UI | Compose enabled; Material 3; BOM 2026.02.01 |
| Java bytecode | 11; Gradle daemon requests JDK 21 |
| Structure | One app module; duplicate com.example.myapplication and com.example.route starters |
| Tests | Two arithmetic unit tests and two package-name instrumentation tests |
| Version control | No .git directory in this workspace |

## Findings

1. The Kotlin Android plugin was absent with AGP 8.7.3. APK assembly completed but no activity/composable classes were generated. Unit tests reported NO-SOURCE.
2. Lint failed with IncompatibleClassChangeError in the Compose FrequentlyChangingValue detector. This was a tooling failure, not a successful lint result.
3. The route instrumentation test expected com.example.route although the app ID was com.example.myapplication.
4. settings.gradle.kts included the app twice. Release configuration referenced a missing proguard-rules.pro.
5. The manifest and Kotlin files mixed two starter identities. Neither had business features.
6. Android Studio Sync itself was not exercised. Command-line Gradle configured the original project, but that did not establish a working Kotlin build.
7. No connected Android device or configured AVD was available during inspection.

## Build repair decision

Keep Kotlin 2.2.10 and Compose BOM 2026.02.01. Explicitly apply the Kotlin Android plugin. Pin AGP 8.13.2 and Gradle 8.13, a documented pair supporting the newest installed platform, API 36.1. Set target API 36 and minimum API 26. Do not suppress lint crashes or SDK compatibility checks.

References:
- https://developer.android.com/build/releases/agp-8-13-0-release-notes
- https://developer.android.com/build/migrate-to-built-in-kotlin
- https://kotlinlang.org/docs/gradle-configure-project.html

The first wrapper download timed out after 10 seconds. Official Gradle and Google Maven endpoints were reachable; the same Gradle version was retried with a 60-second timeout. No version was changed in response to a network failure.

## Implementation plan

1. Repair and validate the existing starter before implementing features.
2. Rename root/app identity, namespace, application ID, source/test packages, manifest activity and theme references to RouteFlow / com.routeflow.app. Remove the duplicate starter files.
3. Keep one module. Add domain role/employee models and a repository interface, with a Hilt-bound fake implementation containing four clearly fake Jaipur employees.
4. Add a StateFlow/ViewModel-driven role picker, Navigation Compose routing and four role-specific placeholder homes using shared Material 3 design and state components.
5. Test routing, repository/ViewModel behavior and role-selection UI; validate debug compilation, tests, lint and release packaging. Attempt device testing and distinguish unavailable checks from passing ones.
6. Document setup, dependencies, architecture, demo boundaries, validation and the next milestone. Review ignore rules and permissions.

Room, WorkManager, DataStore, Keystore, location, backend authentication and business workflows will be added only when a subsequent milestone needs them. Milestone 1 stores no credentials or business transactions.
