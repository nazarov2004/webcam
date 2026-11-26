# Troubleshooting

## Phone Cannot Find PC via Auto-Discovery
- Ensure both devices are on the same Wi-Fi/LAN subnet (avoid guest Wi-Fi isolation).
- Use **Scan QR Code** or **Manual Connection** with the IPv4 address shown in LensCast Desktop.
- Allow `lenscast.exe` through Windows Defender Firewall on Private networks (TCP port `8765` + UDP).

## "Connection Timed Out" or "Could Not Reach"
- Verify LensCast Desktop is running and shows `Listening on :8765`.
- If using VPN on either device, disable it or use **USB Networking** (`adb reverse tcp:8765 tcp:8765` and connect to `127.0.0.1:8765`).

## OBS Browser Source Shows Black Screen
- Ensure you copied the full URL including `?token=...` from the **OBS Integration** tab.
- Rotate/copy the URL again if you restarted LensCast Desktop (session tokens are regenerated per launch for security).
- Confirm the phone is actively streaming in LensCast Desktop's Dashboard preview.
