# LensCast Architecture

## Overview
LensCast uses a **local-first, peer-to-peer WebRTC architecture** with a dual-mode Flutter codebase (`Android` sender + `Windows` receiver).

```
┌─────────────────────────┐          WebSocket (:8765/ws)          ┌──────────────────────────────┐
│   LensCast Mobile       │ ◄────────────────────────────────────► │   LensCast Desktop (Windows) │
│   (Android)             │                                        │                              │
│                         │          WebRTC (DTLS-SRTP)            │  • LocalReceiverServer       │
│  CameraService          │ ═════════════════════════════════════► │  • WebRtcReceiverService     │
│  (Single MediaStream)   │                                        │  • DesktopDiscoveryService   │
│         │               │                                        │  • Studio Preview UI         │
│         │               │          WebRTC (DTLS-SRTP)            └──────────────┬───────────────┘
│         └───────────────┼──────────────────────────────────────┐                │
└─────────────────────────┘                                      ▼                ▼
                                                        ┌─────────────────────────────────┐
                                                        │  OBS Studio Browser Source      │
                                                        │  http://127.0.0.1:8765/obs      │
                                                        └─────────────────────────────────┘
```

## Key Design Decisions
1. **Single Camera Pipeline**: `CameraService` calls `getUserMedia` once. Both the local preview (`CameraPreview`) and `WebRtcSenderService` share that `MediaStream`. When the lens or quality changes, `replaceStreamTracks` updates active `RTCRtpSender`s without tearing down the WebRTC session.
2. **Dedicated OBS Peer**: When OBS Studio opens `/obs?token=...`, it connects to `/ws?role=obs&token=...` (loopback-only). The desktop server notifies the phone (`obs_ready`), and the phone spins up a second `RTCPeerConnection` (`target: 'obs'`) using the same `MediaStream`—giving OBS native hardware-decoded WebRTC video & audio with zero extra encoding on Windows.
3. **Security & Privacy**:
   - Local-first: no cloud account or external media server.
   - Pairing requires a cryptographic `sessionToken` (via QR) or 6-digit `pairingPin`.
   - `/obs` and `/ws?role=obs` are restricted to `127.0.0.1` / `::1` and require the active `sessionToken`.

## Directory Structure
- `lib/app/` — Theme, colors, typography, spacing, router, providers, constants
- `lib/core/` — Errors, permissions, settings, device info, `signaling_protocol.dart`
- `lib/features/` — Mobile features (`splash`, `onboarding`, `permissions`, `dashboard`, `camera`, `connection`, `streaming`, `settings`)
- `lib/desktop/` — Windows Desktop Receiver (`local_server`, `receiver`, `services`, `presentation`)
- `lib/shared/` — Shared models (`DeviceModel`, `CameraConfiguration`, `StreamingSession`, `NetworkStatistics`) and widgets
