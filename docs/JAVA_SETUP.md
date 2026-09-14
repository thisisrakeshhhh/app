# Gradle JDK and missing jlink

The Android build needs a full JDK, including `bin/java.exe`, `bin/javac.exe` and `bin/jlink.exe`.

On the inspected Windows machine, VS Code's Red Hat Java extension bundles a Java 21 runtime with `javac.exe` but without `jlink.exe`. A Gradle daemon selected from that runtime fails Android's JDK image transform. This is a JDK-selection problem, not an application-code or Gradle-version problem.

The project daemon criteria require **JetBrains Java 21**, provided by Android Studio's full bundled JDK. Version-only criteria previously allowed the incomplete VS Code runtime. Old download URLs were removed because they were generated without the JetBrains vendor constraint; install JBR 21 locally rather than downloading a mismatched runtime. No Gradle, AGP, Kotlin or SDK version was changed for this repair.

On this machine the verified JDK directory is:

```text
C:\Program Files\Android\Android Studio\jbr
```

Android Studio's local `GRADLE_LOCAL_JAVA_HOME` value is stored in ignored `.gradle/config.properties`. The shared daemon criteria file contains no machine-specific absolute path. On another machine, install Android Studio with JBR 21 and configure its local JDK path.

This machine also needs an explicit discovery entry in `D:\GradleCache\gradle.properties` (its `GRADLE_USER_HOME`). It is a local setting, outside source control, and preserves other existing installation paths:

```properties
org.gradle.java.installations.paths=C:/Program Files/Android/Android Studio/jbr
```

This registers an available JDK; it does not change the required Java version for other projects. Without this entry, a Gradle wrapper started from the VS Code runtime did not discover Android Studio's installation. With the entry, Gradle selected the verified JetBrains JDK even when the wrapper's launcher was the incomplete VS Code Java.

In Android Studio, open **Settings > Build, Execution, Deployment > Build Tools > Gradle**. For projects showing **Gradle JVM criteria**, choose version **21**, vendor **JetBrains**. For the **Gradle JDK** field, choose **GRADLE_LOCAL_JAVA_HOME** or the full Android Studio `jbr` directory. Do not select the VS Code extension runtime. Sync the project after changing these settings.

To verify from PowerShell:

```powershell
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
& "$env:JAVA_HOME\bin\jlink.exe" --version
.\gradlew.bat --version
.\gradlew.bat assembleDebug testDebugUnitTest lintDebug --no-daemon
```

Daemon JVM criteria take precedence over `JAVA_HOME` and `org.gradle.java.home`; setting JAVA_HOME alone cannot fix an incompatible daemon selection. See [Gradle daemon selection](https://docs.gradle.org/current/userguide/gradle_daemon.html) and [Android build JDK settings](https://developer.android.com/build/jdks).

## Verification on 14 September 2026

The wrapper was deliberately launched with `JAVA_HOME` pointing to the reported Red Hat extension runtime. The Gradle log confirmed the actual build daemon and test executor used `C:\Program Files\Android\Android Studio\jbr\bin\java.exe`, JetBrains 21.0.10. `jlink.exe --version` returned `21.0.10`.

`gradlew.bat assembleDebug testDebugUnitTest --rerun lintDebug --no-daemon --info --console=plain` completed with **BUILD SUCCESSFUL** in 38 seconds. All 11 unit tests passed. The build log is `jlink-fix-build.log` (ignored local output).
