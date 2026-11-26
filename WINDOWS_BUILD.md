# Windows Build Guide

## Prerequisites
- Flutter SDK `3.44.2`+ with Windows desktop enabled
- Visual Studio 2022 Community (Desktop development with C++)
- Windows 10/11 SDK

## Build Commands
```powershell
flutter pub get
flutter build windows --release
```

Output executable location:
- `build/windows/x64/runner/Release/lenscast.exe`

## Firewall Note
When launching `lenscast.exe` for the first time on Windows, allow it through Windows Defender Firewall for **Private networks** so your phone can reach TCP port `8765` and WebRTC UDP ports.
