# Android build output

The Android internal-testing preset targets `build/alpha_crush_internal.aab`.
The bundle is intentionally not included in source archives; generate it from the Godot editor after installing the matching Android export templates, JDK/Android SDK, and configuring the appropriate signing credentials.

## One-time Android setup in the editor

The preset exports an Android App Bundle (`gradle_build/export_format=1`), which requires the Gradle build
template: in the editor choose **Project → Install Android Build Template…** once, then set the Android SDK /
JDK paths in **Editor Settings → Export → Android** and add your keystore in the preset's *Keystore* fields.
