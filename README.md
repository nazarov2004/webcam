# LensCast

**Professional Smartphone-to-Webcam Ecosystem** — Flutter + WebRTC + Windows Desktop Receiver + OBS Studio Integration.

LensCast turns your Android smartphone into a low-latency, studio-grade webcam for **OBS Studio**, **Zoom**, **Google Meet**, **Microsoft Teams**, **Discord**, and **Telegram Desktop**.

## Key Features

### Mobile (Android)
- **Single-Pipeline Camera Capture**: `CameraService` owns one `MediaStream` shared by the local preview and WebRTC peers—no camera conflicts.
- **Studio Camera Controls**: Switch Front/Rear lens, Zoom, Exposure (when hardware-supported), Torch, Mirror, Rotate 90°, Mic Mute, and Quality Profiles (480p24, 720p30, 1080p30, 720p60, 4K30).
- **Flexible Pairing**:
  - **QR Code**: One-scan pairing with session token & PIN.
  - **Auto-Discovery**: mDNS/NSD (`_lenscast._tcp`) on the same LAN.
  - **Manual IP + 6-digit PIN**: Works even when mDNS is blocked by firewalls.
  - **USB Networking**: Supports USB Tethering and `adb reverse tcp:8765 tcp:8765`.
- **Adaptive Bitrate & Auto-Reconnect**: Monitors `RTCStatsReport` (FPS, bitrate, RTT, packet loss, jitter) and adjusts target bitrate automatically.

### Desktop (Windows 10/11)
- **Studio Control Panel**: Live WebRTC preview, real-time transport telemetry, and remote camera controls (switch lens, mirror, rotate, torch, mic, quality, zoom).
- **Local Signaling & HTTP Server**: Binds port `8765` with session-token and 6-digit PIN authentication.
- **OBS Studio Browser Source**: Generates a loopback-only `http://127.0.0.1:8765/obs?token=...` URL for zero-UI, low-latency video + audio capture in OBS.

## Documentation
- [ARCHITECTURE.md](ARCHITECTURE.md) — System & WebRTC signaling architecture
- [OBS_SETUP.md](OBS_SETUP.md) — OBS Studio & Virtual Camera setup guide
- [ANDROID_BUILD.md](ANDROID_BUILD.md) — Building the Android APK
- [WINDOWS_BUILD.md](WINDOWS_BUILD.md) — Building the Windows executable
- [TESTING.md](TESTING.md) — Automated & device test plan
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) — Common network, firewall & camera fixes
