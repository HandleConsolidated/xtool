// swiftlint:disable function_body_length file_length
enum PreviewHTML {
    static func page(deviceName: String, deviceUDID: String) -> String {
        """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>xtool Preview — \(escapeHTML(deviceName))</title>
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }

                body {
                    background: #1a1a2e;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    min-height: 100vh;
                    font-family: -apple-system, BlinkMacSystemFont, 'SF Pro', system-ui, sans-serif;
                    color: #e0e0e0;
                    overflow: hidden;
                }

                .container {
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                    gap: 16px;
                }

                /* iPhone 15-style frame */
                .iphone-frame {
                    position: relative;
                    width: 320px;
                    height: 693px;
                    background: #1c1c1e;
                    border-radius: 48px;
                    border: 3px solid #3a3a3c;
                    box-shadow:
                        0 0 0 1px rgba(255,255,255,0.05),
                        0 20px 60px rgba(0,0,0,0.5),
                        inset 0 0 0 1px rgba(255,255,255,0.03);
                    padding: 14px;
                    overflow: hidden;
                }

                /* Dynamic Island */
                .dynamic-island {
                    position: absolute;
                    top: 18px;
                    left: 50%;
                    transform: translateX(-50%);
                    width: 100px;
                    height: 28px;
                    background: #000;
                    border-radius: 20px;
                    z-index: 10;
                }

                /* Screen area */
                .screen {
                    width: 100%;
                    height: 100%;
                    border-radius: 36px;
                    overflow: hidden;
                    background: #000;
                    position: relative;
                }

                .screen img {
                    width: 100%;
                    height: 100%;
                    object-fit: contain;
                    display: block;
                }

                /* Loading state */
                .screen .loading {
                    position: absolute;
                    top: 0;
                    left: 0;
                    width: 100%;
                    height: 100%;
                    display: flex;
                    flex-direction: column;
                    justify-content: center;
                    align-items: center;
                    gap: 16px;
                    color: #888;
                    font-size: 14px;
                }

                .spinner {
                    width: 32px;
                    height: 32px;
                    border: 3px solid rgba(255,255,255,0.1);
                    border-top-color: #0a84ff;
                    border-radius: 50%;
                    animation: spin 0.8s linear infinite;
                }

                @keyframes spin {
                    to { transform: rotate(360deg); }
                }

                /* Side button accents */
                .iphone-frame::before {
                    content: '';
                    position: absolute;
                    right: -5px;
                    top: 140px;
                    width: 4px;
                    height: 56px;
                    background: #3a3a3c;
                    border-radius: 0 4px 4px 0;
                }

                .iphone-frame::after {
                    content: '';
                    position: absolute;
                    left: -5px;
                    top: 120px;
                    width: 4px;
                    height: 32px;
                    background: #3a3a3c;
                    border-radius: 4px 0 0 4px;
                    box-shadow: 0 48px 0 #3a3a3c, 0 88px 0 #3a3a3c;
                }

                /* Info bar */
                .info-bar {
                    display: flex;
                    align-items: center;
                    gap: 12px;
                    padding: 8px 16px;
                    background: rgba(255,255,255,0.05);
                    border-radius: 12px;
                    font-size: 12px;
                    color: #888;
                }

                .info-bar .device-name {
                    color: #e0e0e0;
                    font-weight: 600;
                }

                .status-dot {
                    width: 8px;
                    height: 8px;
                    border-radius: 50%;
                    background: #ff453a;
                    transition: background 0.3s;
                }

                .status-dot.connected {
                    background: #30d158;
                }

                .fps-counter {
                    font-variant-numeric: tabular-nums;
                    min-width: 48px;
                }

                /* Error overlay */
                .error-overlay {
                    position: absolute;
                    top: 0;
                    left: 0;
                    width: 100%;
                    height: 100%;
                    display: none;
                    flex-direction: column;
                    justify-content: center;
                    align-items: center;
                    gap: 12px;
                    background: rgba(0,0,0,0.85);
                    color: #ff453a;
                    font-size: 13px;
                    text-align: center;
                    padding: 24px;
                    border-radius: 36px;
                    z-index: 5;
                }

                .error-overlay.visible {
                    display: flex;
                }

                .error-overlay button {
                    padding: 8px 20px;
                    background: #0a84ff;
                    color: white;
                    border: none;
                    border-radius: 8px;
                    font-size: 13px;
                    cursor: pointer;
                }

                .error-overlay button:hover {
                    background: #409cff;
                }

                .branding {
                    font-size: 11px;
                    color: #555;
                    letter-spacing: 0.5px;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="iphone-frame">
                    <div class="dynamic-island"></div>
                    <div class="screen">
                        <div class="loading" id="loading">
                            <div class="spinner"></div>
                            <span>Connecting to device...</span>
                        </div>
                        <img id="stream" style="display:none" alt="Device Screen">
                        <div class="error-overlay" id="error-overlay">
                            <span id="error-message">Connection lost</span>
                            <button onclick="reconnect()">Reconnect</button>
                        </div>
                    </div>
                </div>

                <div class="info-bar">
                    <div class="status-dot" id="status-dot"></div>
                    <span class="device-name" id="device-name">\(escapeHTML(deviceName))</span>
                    <span class="fps-counter" id="fps-display">-- fps</span>
                    <span id="resolution">--</span>
                </div>

                <div class="branding">xtool preview</div>
            </div>

            <script>
                const streamImg = document.getElementById('stream');
                const loading = document.getElementById('loading');
                const statusDot = document.getElementById('status-dot');
                const fpsDisplay = document.getElementById('fps-display');
                const resDisplay = document.getElementById('resolution');
                const errorOverlay = document.getElementById('error-overlay');
                const errorMessage = document.getElementById('error-message');

                let frameCount = 0;
                let lastFpsTime = performance.now();
                let connected = false;

                function connect() {
                    loading.style.display = 'flex';
                    streamImg.style.display = 'none';
                    errorOverlay.classList.remove('visible');

                    // Use MJPEG stream — browser handles multipart natively
                    streamImg.src = '/stream?' + Date.now();

                    streamImg.onload = function() {
                        if (!connected) {
                            connected = true;
                            loading.style.display = 'none';
                            streamImg.style.display = 'block';
                            statusDot.classList.add('connected');
                        }
                        // Track FPS
                        frameCount++;
                        const now = performance.now();
                        const elapsed = now - lastFpsTime;
                        if (elapsed >= 1000) {
                            const fps = Math.round(frameCount * 1000 / elapsed);
                            fpsDisplay.textContent = fps + ' fps';
                            frameCount = 0;
                            lastFpsTime = now;
                        }
                        // Track resolution
                        if (streamImg.naturalWidth > 0) {
                            resDisplay.textContent =
                                streamImg.naturalWidth + 'x' + streamImg.naturalHeight;
                        }
                    };

                    streamImg.onerror = function() {
                        if (connected) {
                            connected = false;
                            statusDot.classList.remove('connected');
                            errorMessage.textContent = 'Connection lost';
                            errorOverlay.classList.add('visible');
                        } else {
                            // Retry connection after delay
                            setTimeout(connect, 2000);
                        }
                    };
                }

                function reconnect() {
                    connected = false;
                    connect();
                }

                // Start
                connect();

                // Keyboard shortcuts
                document.addEventListener('keydown', function(e) {
                    if (e.key === 'r' || e.key === 'R') {
                        reconnect();
                    }
                });
            </script>
        </body>
        </html>
        """
    }

    private static func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
// swiftlint:enable function_body_length file_length
