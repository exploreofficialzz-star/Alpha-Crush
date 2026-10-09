# Android build output

The Android internal-testing preset targets `build/alpha_crush_internal.aab`.
The production APK preset targets `build/alpha_crush_production.apk`.
CI exports both artifacts with the configured release keystore and uploads them together as the `alpha-crush-android-<commit>` workflow artifact. The binaries are intentionally not included in source archives.

## One-time Android setup in the editor

The Android presets use the Gradle build template: in the editor choose **Project → Install Android Build Template…** once, then set the Android SDK / JDK paths in **Editor Settings → Export → Android** and add your keystore in the preset's *Keystore* fields. The AAB uses `gradle_build/export_format=1`; the production APK uses `gradle_build/export_format=0`.
