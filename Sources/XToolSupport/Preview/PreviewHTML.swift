import XKit

// swiftlint:disable function_body_length file_length type_body_length
enum PreviewHTML {
    static func page(
        deviceName: String,
        deviceUDID: String,
        displayInfo: DeviceDisplayInfo
    ) -> String {
        let frameCSS = frameStyle(for: displayInfo)
        let dn = escapeHTML(deviceName)
        let modelName = escapeHTML(displayInfo.name)

        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>xtool \(dn)</title>
        <style>
        *{margin:0;padding:0;box-sizing:border-box}
        body{
          background:#1a1a2e;
          display:flex;justify-content:center;align-items:center;
          min-height:100vh;
          font-family:-apple-system,BlinkMacSystemFont,'SF Pro',system-ui,sans-serif;
          color:#e0e0e0;overflow:hidden;
        }
        .container{
          display:flex;flex-direction:column;align-items:center;gap:16px;
        }

        /* Device frame */
        .device-frame{
          position:relative;
          width:\(frameCSS.outerWidth)px;
          height:\(frameCSS.outerHeight)px;
          background:#1c1c1e;
          border-radius:\(frameCSS.outerRadius)px;
          border:3px solid #3a3a3c;
          box-shadow:0 0 0 1px rgba(255,255,255,0.05),
                     0 20px 60px rgba(0,0,0,0.5),
                     inset 0 0 0 1px rgba(255,255,255,0.03);
          padding:\(frameCSS.bezelWidth)px;
          overflow:hidden;
        }

        \(frameCSS.extraCSS)

        .screen{
          width:100%;height:100%;
          border-radius:\(frameCSS.screenRadius)px;
          overflow:hidden;background:#000;position:relative;
        }
        .screen img,.screen canvas{
          width:100%;height:100%;object-fit:contain;display:block;
        }

        .loading{
          position:absolute;top:0;left:0;width:100%;height:100%;
          display:flex;flex-direction:column;justify-content:center;
          align-items:center;gap:16px;color:#888;font-size:14px;
        }
        .spinner{
          width:32px;height:32px;
          border:3px solid rgba(255,255,255,0.1);
          border-top-color:#0a84ff;border-radius:50%;
          animation:spin 0.8s linear infinite;
        }
        @keyframes spin{to{transform:rotate(360deg)}}

        .error-overlay{
          position:absolute;top:0;left:0;width:100%;height:100%;
          display:none;flex-direction:column;justify-content:center;
          align-items:center;gap:12px;
          background:rgba(0,0,0,0.85);color:#ff453a;
          font-size:13px;text-align:center;padding:24px;
          border-radius:\(frameCSS.screenRadius)px;z-index:5;
        }
        .error-overlay.visible{display:flex}
        .error-overlay button{
          padding:8px 20px;background:#0a84ff;color:#fff;
          border:none;border-radius:8px;font-size:13px;cursor:pointer;
        }
        .error-overlay button:hover{background:#409cff}

        .info-bar{
          display:flex;align-items:center;gap:12px;
          padding:8px 16px;background:rgba(255,255,255,0.05);
          border-radius:12px;font-size:12px;color:#888;
        }
        .info-bar .device-name{color:#e0e0e0;font-weight:600}
        .status-dot{
          width:8px;height:8px;border-radius:50%;
          background:#ff453a;transition:background 0.3s;
        }
        .status-dot.connected{background:#30d158}
        .status-dot.ws{background:#0a84ff}
        .fps-counter{font-variant-numeric:tabular-nums;min-width:48px}
        .transport-badge{
          padding:2px 6px;border-radius:4px;font-size:10px;
          font-weight:600;letter-spacing:0.5px;
          background:rgba(255,255,255,0.08);
        }
        .transport-badge.ws{background:rgba(10,132,255,0.2);color:#409cff}
        .transport-badge.mjpeg{background:rgba(48,209,88,0.2);color:#30d158}
        .branding{font-size:11px;color:#555;letter-spacing:0.5px}
        .size-display{opacity:0.6}
        </style>
        </head>
        <body>
        <div class="container">
          <div class="device-frame" id="device-frame">
            \(frameCSS.innerHTML)
            <div class="screen">
              <div class="loading" id="loading">
                <div class="spinner"></div>
                <span>Connecting to \(dn)...</span>
              </div>
              <img id="stream" style="display:none" alt="Screen">
              <div class="error-overlay" id="error-overlay">
                <span id="error-message">Connection lost</span>
                <button onclick="reconnect()">Reconnect</button>
              </div>
            </div>
          </div>

          <div class="info-bar">
            <div class="status-dot" id="status-dot"></div>
            <span class="device-name">\(modelName)</span>
            <span class="transport-badge" id="transport">--</span>
            <span class="fps-counter" id="fps-display">-- fps</span>
            <span class="size-display" id="frame-size">--</span>
          </div>
          <div class="branding">xtool preview</div>
        </div>

        <script>
        const img = document.getElementById('stream');
        const loading = document.getElementById('loading');
        const statusDot = document.getElementById('status-dot');
        const fpsEl = document.getElementById('fps-display');
        const sizeEl = document.getElementById('frame-size');
        const errorOverlay = document.getElementById('error-overlay');
        const errorMsg = document.getElementById('error-message');
        const transportEl = document.getElementById('transport');

        let ws = null;
        let frameCount = 0;
        let byteCount = 0;
        let lastStatTime = performance.now();
        let connected = false;
        let prevBlobUrl = null;
        let transport = 'none';

        function updateStats(frameBytes) {
          frameCount++;
          byteCount += frameBytes;
          const now = performance.now();
          const elapsed = now - lastStatTime;
          if (elapsed >= 1000) {
            const fps = Math.round(frameCount * 1000 / elapsed);
            const kbps = Math.round(byteCount / elapsed);
            fpsEl.textContent = fps + ' fps';
            sizeEl.textContent = kbps + ' KB/s';
            frameCount = 0;
            byteCount = 0;
            lastStatTime = now;
          }
        }

        function showConnected(mode) {
          transport = mode;
          connected = true;
          loading.style.display = 'none';
          img.style.display = 'block';
          errorOverlay.classList.remove('visible');
          statusDot.classList.add('connected');
          if (mode === 'ws') statusDot.classList.add('ws');
          else statusDot.classList.remove('ws');
          transportEl.textContent = mode.toUpperCase();
          transportEl.className = 'transport-badge ' + mode;
        }

        function showDisconnected(msg) {
          connected = false;
          statusDot.classList.remove('connected','ws');
          errorMsg.textContent = msg || 'Connection lost';
          errorOverlay.classList.add('visible');
          transportEl.textContent = '--';
          transportEl.className = 'transport-badge';
        }

        // --- WebSocket transport (preferred) ---
        function connectWS() {
          const proto = location.protocol === 'https:' ? 'wss:' : 'ws:';
          ws = new WebSocket(proto + '//' + location.host + '/ws');
          ws.binaryType = 'arraybuffer';

          ws.onopen = function() { showConnected('ws'); };

          ws.onmessage = function(e) {
            const blob = new Blob([e.data], {type:'image/jpeg'});
            const url = URL.createObjectURL(blob);
            if (prevBlobUrl) URL.revokeObjectURL(prevBlobUrl);
            prevBlobUrl = url;
            img.src = url;
            updateStats(e.data.byteLength);
          };

          ws.onclose = function() {
            if (connected) showDisconnected('WebSocket closed');
            setTimeout(function() { connectWS(); }, 2000);
          };

          ws.onerror = function() {
            ws.close();
            // Fall back to MJPEG
            setTimeout(function() { connectMJPEG(); }, 1000);
          };
        }

        // --- MJPEG transport (fallback) ---
        function connectMJPEG() {
          img.src = '/stream?' + Date.now();
          img.onload = function() {
            if (!connected) showConnected('mjpeg');
            updateStats(0);
          };
          img.onerror = function() {
            if (connected) showDisconnected('Stream ended');
            else setTimeout(function() { connectWS(); }, 2000);
          };
        }

        function reconnect() {
          connected = false;
          if (ws) { ws.close(); ws = null; }
          loading.style.display = 'flex';
          img.style.display = 'none';
          errorOverlay.classList.remove('visible');
          connectWS();
        }

        // Start with WebSocket
        connectWS();

        document.addEventListener('keydown', function(e) {
          if (e.key === 'r' || e.key === 'R') reconnect();
        });
        </script>
        </body>
        </html>
        """
    }

    // MARK: - Frame Style Generation

    private struct FrameStyle {
        let outerWidth: Int
        let outerHeight: Int
        let outerRadius: Int
        let bezelWidth: Int
        let screenRadius: Int
        let extraCSS: String
        let innerHTML: String
    }

    private static func frameStyle(
        for display: DeviceDisplayInfo
    ) -> FrameStyle {
        // Scale the native resolution to a preview size
        let previewWidth = 320
        let aspectRatio = display.aspectRatio
        let previewHeight = Int(Double(previewWidth) * aspectRatio)

        switch display.displayStyle {
        case .dynamicIsland:
            return dynamicIslandStyle(
                previewWidth: previewWidth,
                previewHeight: previewHeight
            )
        case .notch:
            return notchStyle(
                previewWidth: previewWidth,
                previewHeight: previewHeight
            )
        case .homeButton:
            return homeButtonStyle(
                previewWidth: previewWidth,
                previewHeight: previewHeight
            )
        }
    }

    private static func dynamicIslandStyle(
        previewWidth: Int,
        previewHeight: Int
    ) -> FrameStyle {
        let bezel = 14
        let outerW = previewWidth + bezel * 2
        let outerH = previewHeight + bezel * 2
        return FrameStyle(
            outerWidth: outerW,
            outerHeight: outerH,
            outerRadius: 48,
            bezelWidth: bezel,
            screenRadius: 36,
            extraCSS: """
            .dynamic-island{
              position:absolute;top:18px;left:50%;
              transform:translateX(-50%);
              width:100px;height:28px;background:#000;
              border-radius:20px;z-index:10;
            }
            .device-frame::before{
              content:'';position:absolute;right:-5px;top:140px;
              width:4px;height:56px;background:#3a3a3c;
              border-radius:0 4px 4px 0;
            }
            .device-frame::after{
              content:'';position:absolute;left:-5px;top:120px;
              width:4px;height:32px;background:#3a3a3c;
              border-radius:4px 0 0 4px;
              box-shadow:0 48px 0 #3a3a3c,0 88px 0 #3a3a3c;
            }
            """,
            innerHTML: "<div class=\"dynamic-island\"></div>"
        )
    }

    private static func notchStyle(
        previewWidth: Int,
        previewHeight: Int
    ) -> FrameStyle {
        let bezel = 14
        let outerW = previewWidth + bezel * 2
        let outerH = previewHeight + bezel * 2
        return FrameStyle(
            outerWidth: outerW,
            outerHeight: outerH,
            outerRadius: 48,
            bezelWidth: bezel,
            screenRadius: 36,
            extraCSS: """
            .notch{
              position:absolute;top:14px;left:50%;
              transform:translateX(-50%);
              width:140px;height:30px;background:#1c1c1e;
              border-radius:0 0 18px 18px;z-index:10;
            }
            .device-frame::before{
              content:'';position:absolute;right:-5px;top:140px;
              width:4px;height:56px;background:#3a3a3c;
              border-radius:0 4px 4px 0;
            }
            .device-frame::after{
              content:'';position:absolute;left:-5px;top:120px;
              width:4px;height:32px;background:#3a3a3c;
              border-radius:4px 0 0 4px;
              box-shadow:0 48px 0 #3a3a3c,0 88px 0 #3a3a3c;
            }
            """,
            innerHTML: "<div class=\"notch\"></div>"
        )
    }

    private static func homeButtonStyle(
        previewWidth: Int,
        previewHeight: Int
    ) -> FrameStyle {
        let bezel = 16
        let topBar = 54
        let bottomBar = 66
        let outerW = previewWidth + bezel * 2
        let outerH = previewHeight + topBar + bottomBar
        return FrameStyle(
            outerWidth: outerW,
            outerHeight: outerH,
            outerRadius: 36,
            bezelWidth: bezel,
            screenRadius: 4,
            extraCSS: """
            .device-frame{
              padding:\(topBar)px \(bezel)px \(bottomBar)px;
            }
            .home-button{
              position:absolute;bottom:18px;left:50%;
              transform:translateX(-50%);
              width:40px;height:40px;
              border:2px solid #3a3a3c;border-radius:50%;
            }
            .earpiece{
              position:absolute;top:22px;left:50%;
              transform:translateX(-50%);
              width:44px;height:5px;background:#2c2c2e;
              border-radius:3px;
            }
            .device-frame::before{
              content:'';position:absolute;right:-5px;top:140px;
              width:4px;height:56px;background:#3a3a3c;
              border-radius:0 4px 4px 0;
            }
            .device-frame::after{
              content:'';position:absolute;left:-5px;top:100px;
              width:4px;height:28px;background:#3a3a3c;
              border-radius:4px 0 0 4px;
              box-shadow:0 40px 0 #3a3a3c,0 72px 0 #3a3a3c;
            }
            """,
            innerHTML: """
            <div class="earpiece"></div>\
            <div class="home-button"></div>
            """
        )
    }

    // MARK: - Helpers

    private static func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
// swiftlint:enable function_body_length file_length type_body_length
