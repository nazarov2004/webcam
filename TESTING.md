# Testing Guide

## Automated Tests
Run static analysis and the unit/integration test suite:
```bash
flutter analyze
flutter test
```

Covered suites:
- `test/widget_test.dart` — `CameraConfiguration`, `DeviceModel`, `NetworkStatistics` serialization, validation, and bounds.
- `test/signaling_and_server_test.dart` — `SignalMessage`, `QrPairingPayload`, `LocalReceiverServer` HTTP `/health`, `/obs` token & auth enforcement, WebSocket PIN pairing, and OBS WebRTC signaling relay.

## Physical Device End-to-End Checklist
1. First launch, onboarding, and Camera/Microphone/Notification permissions.
2. Live camera preview (front & rear) + lens switching during active session.
3. QR code pairing, Wi-Fi mDNS discovery, Manual IP + PIN, and `adb reverse` USB tunnel.
4. OBS Studio Browser Source video & audio capture.
5. Wi-Fi disconnect/reconnect recovery and 10/30/60-minute thermal/battery stability.
