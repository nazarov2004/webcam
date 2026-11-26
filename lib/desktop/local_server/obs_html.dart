/// Generates the self-contained HTML5 WebRTC receiver page for OBS Browser Source.
String buildObsReceiverHtml({
  required String token,
  required bool audioEnabled,
  required bool cleanOutput,
}) {
  final mutedAttr = audioEnabled ? '' : 'muted';
  final statusDisplay = cleanOutput ? 'none' : 'flex';
  return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>LensCast OBS Source</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    html, body {
      width: 100%;
      height: 100%;
      background: transparent;
      overflow: hidden;
      font-family: system-ui, -apple-system, Segoe UI, Roboto, sans-serif;
    }
    video {
      width: 100vw;
      height: 100vh;
      object-fit: contain;
      background: #000;
      display: block;
    }
    #status {
      position: fixed;
      top: 16px;
      left: 16px;
      display: $statusDisplay;
      align-items: center;
      gap: 8px;
      padding: 6px 12px;
      border-radius: 999px;
      background: rgba(16, 19, 24, 0.78);
      color: #F4F6FA;
      font-size: 13px;
      font-weight: 500;
      border: 1px solid rgba(255,255,255,0.1);
    }
    #dot {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: #F4B860;
    }
  </style>
</head>
<body>
  <video id="video" autoplay playsinline $mutedAttr></video>
  <div id="status"><span id="dot"></span><span id="label">Waiting for LensCast...</span></div>
  <script>
    (function () {
      const token = ${ _jsString(token) };
      const audioEnabled = ${audioEnabled ? 'true' : 'false'};
      const video = document.getElementById('video');
      const dot = document.getElementById('dot');
      const label = document.getElementById('label');

      let ws = null;
      let pc = null;
      let reconnectTimer = null;

      function setStatus(text, color) {
        label.textContent = text;
        dot.style.background = color;
      }

      function cleanupPeer() {
        if (pc) {
          try { pc.close(); } catch (_) {}
          pc = null;
        }
        video.srcObject = null;
      }

      function createPeer() {
        cleanupPeer();
        pc = new RTCPeerConnection({ iceServers: [] });
        pc.ontrack = (event) => {
          if (event.streams && event.streams[0]) {
            video.srcObject = event.streams[0];
            video.muted = !audioEnabled;
            video.play().catch(() => {});
            setStatus('Live', '#35C98A');
          }
        };
        pc.onicecandidate = (event) => {
          if (event.candidate && ws && ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify({
              type: 'ice',
              target: 'obs',
              payload: {
                candidate: event.candidate.candidate,
                sdpMid: event.candidate.sdpMid,
                sdpMLineIndex: event.candidate.sdpMLineIndex
              }
            }));
          }
        };
        pc.onconnectionstatechange = () => {
          if (!pc) return;
          if (pc.connectionState === 'connected') {
            setStatus('Live', '#35C98A');
          } else if (pc.connectionState === 'disconnected' || pc.connectionState === 'failed') {
            setStatus('Reconnecting...', '#F4B860');
          }
        };
        return pc;
      }

      function connect() {
        if (reconnectTimer) {
          clearTimeout(reconnectTimer);
          reconnectTimer = null;
        }
        const proto = location.protocol === 'https:' ? 'wss:' : 'ws:';
        const url = proto + '//' + location.host + '/ws?role=obs&token=' + encodeURIComponent(token);
        ws = new WebSocket(url);

        ws.onopen = () => {
          setStatus('Connected to receiver', '#31C8D8');
        };

        ws.onmessage = async (event) => {
          let msg;
          try { msg = JSON.parse(event.data); } catch (_) { return; }
          if (msg.type === 'offer' && msg.payload && msg.payload.sdp) {
            const peer = createPeer();
            await peer.setRemoteDescription({
              type: msg.payload.type || 'offer',
              sdp: msg.payload.sdp
            });
            const answer = await peer.createAnswer();
            await peer.setLocalDescription(answer);
            ws.send(JSON.stringify({
              type: 'answer',
              target: 'obs',
              payload: { type: answer.type, sdp: answer.sdp }
            }));
          } else if (msg.type === 'ice' && msg.payload && pc) {
            try {
              await pc.addIceCandidate(new RTCIceCandidate({
                candidate: msg.payload.candidate,
                sdpMid: msg.payload.sdpMid,
                sdpMLineIndex: msg.payload.sdpMLineIndex
              }));
            } catch (_) {}
          } else if (msg.type === 'disconnect') {
            cleanupPeer();
            setStatus('Waiting for phone...', '#F4B860');
          }
        };

        ws.onclose = () => {
          cleanupPeer();
          setStatus('Reconnecting...', '#F4B860');
          reconnectTimer = setTimeout(connect, 1500);
        };

        ws.onerror = () => {
          try { ws.close(); } catch (_) {}
        };
      }

      connect();
    })();
  </script>
</body>
</html>
''';
}

String _jsString(String value) {
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r');
  return "'$escaped'";
}
