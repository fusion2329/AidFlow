# AidFlow Android Lite

This is a deliberately reduced Android port target for AidFlow. It keeps the field workflow usable while avoiding high-cost platform-specific parity work in the first pass.

## Current scope

- Jetpack Compose native Android app.
- Home, Arrival, CPR, Timeline, Handover, and History screens.
- Local-only JSON persistence in the app private files directory.
- CPR counter state with an ongoing notification when notification permission is granted.
- Data model names are kept close to the iOS app where practical.

## Deferred

- Pupil camera / LiDAR / machine-learning observation tooling.
- Map and location capture.
- Android widgets and foreground-service CPR parity.
- Cloud sync.
- Full iOS feature parity.

## Open in Android Studio

Open the `android/` directory as a separate Android Studio project and let Gradle sync download the Android Gradle Plugin, Kotlin, and Compose dependencies.

The local Codex environment used to create this scaffold did not have `gradle` or `adb` on `PATH`, so device/emulator verification still needs to be run from Android Studio.
