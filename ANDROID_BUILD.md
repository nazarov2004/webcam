# Android Build Guide

## Prerequisites
- Flutter SDK `3.44.2`+
- Android SDK (compileSdk / targetSdk configured in `android/app/build.gradle.kts`)
- Java 17+ / JDK 21

## Build Commands
```bash
flutter pub get
flutter build apk --release
```

Output APK location:
- `build/app/outputs/flutter-apk/app-release.apk`

## Install on a Connected Android Device
```bash
flutter install --release
# or:
adb install -r build/app/outputs/flutter-apk/app-release.apk
```
