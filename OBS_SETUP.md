# OBS Studio & Virtual Camera Setup

## 1. Add LensCast as an OBS Browser Source
1. Open **LensCast Desktop** on Windows and pair your phone (via QR code, Wi-Fi discovery, or Manual IP + PIN).
2. Open the **OBS Integration** tab in LensCast Desktop and click **Copy URL**.
   - The URL looks like: `http://127.0.0.1:8765/obs?token=<SESSION_TOKEN>&audio=1&clean=1`
3. Open **OBS Studio**.
4. In the **Sources** dock, click **+** → **Browser**.
5. Name it `LensCast Camera` and click **OK**.
6. Paste the copied URL into **URL**.
7. Set **Width** to `1920` and **Height** to `1080` (or `1280` × `720` to match 720p).
8. Set **FPS** to `30` (or `60` if using the Smooth 60 FPS profile).
9. Check **Control audio via OBS** if you want to route your phone's microphone through OBS.
10. Click **OK**. Your phone's live camera feed will appear immediately.

## 2. Use LensCast in Zoom, Google Meet, Teams, or Discord
1. With the LensCast Browser Source active in OBS Studio, click **Start Virtual Camera** in the **Controls** dock of OBS.
2. In Zoom / Google Meet / Microsoft Teams / Discord / Telegram Desktop, open **Video Settings** and select **OBS Virtual Camera** as your webcam.
3. *(Note)* A standalone signed Windows DirectShow/Media Foundation virtual camera driver is planned for Phase 7. In v1.0, OBS Virtual Camera is the supported path for conferencing apps.
