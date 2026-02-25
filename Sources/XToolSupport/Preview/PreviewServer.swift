import Foundation
import NIOCore
import NIOPosix
import NIOHTTP1
import NIOWebSocket
import XKit

// MARK: - Build Status

/// Tracks build/install status for live reload SSE broadcasting.
actor BuildStatusBroadcaster {
    enum Status: String, Sendable, Encodable {
        case idle
        case building
        case installing
        case ready
        case error
    }

    struct Event: Sendable {
        let status: Status
        let message: String
        let sequence: UInt64
    }

    private(set) var latest = Event(
        status: .idle, message: "", sequence: 0
    )

    func update(_ status: Status, message: String = "") {
        latest = Event(
            status: status,
            message: message,
            sequence: latest.sequence + 1
        )
    }
}

// MARK: - Frame Producer

/// Captures frames from the device at a fixed interval and makes them
/// available to all connected clients (MJPEG + WebSocket).
actor FrameProducer {
    private let captureSource: any ScreenCaptureSource
    private let interval: TimeInterval
    private var captureTask: Task<Void, Never>?
    private(set) var latestFrame: Frame?
    private var subscriberCount = 0

    struct Frame {
        let compressed: JPEGCompressor.CompressedFrame
        let sequence: UInt64
        let timestamp: ContinuousClock.Instant
    }

    init(captureSource: any ScreenCaptureSource, fps: Int) {
        self.captureSource = captureSource
        self.interval = 1.0 / Double(max(fps, 1))
    }

    func start() async throws {
        try await captureSource.start()
    }

    func subscribe() {
        subscriberCount += 1
        startCaptureIfNeeded()
    }

    func unsubscribe() {
        subscriberCount -= 1
        if subscriberCount <= 0 {
            subscriberCount = 0
            captureTask?.cancel()
            captureTask = nil
        }
    }

    func stop() async throws {
        captureTask?.cancel()
        captureTask = nil
        try await captureSource.stop()
    }

    private func startCaptureIfNeeded() {
        guard captureTask == nil else { return }
        var seq: UInt64 = latestFrame?.sequence ?? 0
        let source = captureSource
        let interval = self.interval

        captureTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    let raw = try await source.captureFrame()
                    let compressed = JPEGCompressor.compress(raw)
                    seq += 1
                    await self?.setFrame(Frame(
                        compressed: compressed,
                        sequence: seq,
                        timestamp: .now
                    ))
                    try await Task.sleep(
                        nanoseconds: UInt64(interval * 1_000_000_000)
                    )
                } catch is CancellationError {
                    break
                } catch {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
            }
        }
    }

    private func setFrame(_ frame: Frame) {
        latestFrame = frame
    }
}

// MARK: - Preview Server

/// HTTP + WebSocket server for live iOS device screen preview.
///
/// Endpoints:
/// - `GET /`       -> iPhone frame HTML viewer
/// - `GET /stream` -> MJPEG multipart stream (legacy)
/// - `GET /frame`  -> Single screenshot
/// - `GET /api/info` -> Device info JSON
/// - `GET /ws`     -> WebSocket upgrade for binary frame push
actor PreviewServer {
    let frameProducer: FrameProducer
    let buildStatus: BuildStatusBroadcaster
    let host: String
    let port: Int
    let fps: Int
    let deviceName: String
    let deviceUDID: String
    let displayInfo: DeviceDisplayInfo

    private var channel: Channel?

    init(
        captureSource: any ScreenCaptureSource,
        host: String = "0.0.0.0",
        port: Int = 8034,
        fps: Int = 5,
        deviceName: String = "iPhone",
        deviceUDID: String = "",
        displayInfo: DeviceDisplayInfo? = nil
    ) {
        self.frameProducer = FrameProducer(
            captureSource: captureSource, fps: fps
        )
        self.buildStatus = BuildStatusBroadcaster()
        self.host = host
        self.port = port
        self.fps = fps
        self.deviceName = deviceName
        self.deviceUDID = deviceUDID
        self.displayInfo = displayInfo
            ?? DeviceModelDatabase.displayInfo(forProductType: "")
    }

    func start() async throws {
        try await frameProducer.start()

        let producer = frameProducer
        let statusBroadcaster = buildStatus
        let targetFPS = fps
        let name = deviceName
        let udid = deviceUDID
        let display = displayInfo

        let wsUpgrader = NIOWebSocketServerUpgrader(
            shouldUpgrade: { channel, head in
                guard head.uri == "/ws" else {
                    return channel.eventLoop.makeSucceededFuture(nil)
                }
                return channel.eventLoop.makeSucceededFuture(
                    HTTPHeaders()
                )
            },
            upgradePipelineHandler: { channel, _ in
                channel.pipeline.addHandler(
                    WebSocketStreamHandler(
                        frameProducer: producer,
                        fps: targetFPS
                    )
                )
            }
        )

        let bootstrap = ServerBootstrap(
            group: MultiThreadedEventLoopGroup.singleton
        )
        .serverChannelOption(.backlog, value: 256)
        .serverChannelOption(.socketOption(.so_reuseaddr), value: 1)
        .childChannelInitializer { channel in
            let upgradeConfig = NIOHTTPServerUpgradeConfiguration(
                upgraders: [wsUpgrader],
                completionHandler: { _ in }
            )
            return channel.pipeline.configureHTTPServerPipeline(
                withServerUpgrade: upgradeConfig
            ).flatMap {
                channel.pipeline.addHandler(
                    PreviewHTTPHandler(
                        frameProducer: producer,
                        buildStatus: statusBroadcaster,
                        fps: targetFPS,
                        deviceName: name,
                        deviceUDID: udid,
                        displayInfo: display
                    )
                )
            }
        }
        .childChannelOption(.socketOption(.so_reuseaddr), value: 1)

        self.channel = try await bootstrap.bind(
            host: host, port: port
        ).get()
    }

    func waitUntilStopped() async throws {
        try await channel?.closeFuture.get()
    }

    func stop() async throws {
        try await channel?.close()
        try await frameProducer.stop()
    }

    func updateBuildStatus(
        _ status: BuildStatusBroadcaster.Status,
        message: String = ""
    ) async {
        await buildStatus.update(status, message: message)
    }
}

// MARK: - WebSocket Stream Handler

private final class WebSocketStreamHandler:
    ChannelInboundHandler, @unchecked Sendable
{
    typealias InboundIn = WebSocketFrame
    typealias OutboundOut = WebSocketFrame

    private let frameProducer: FrameProducer
    private let fps: Int
    private var streamTask: Task<Void, Never>?

    init(frameProducer: FrameProducer, fps: Int) {
        self.frameProducer = frameProducer
        self.fps = fps
    }

    func channelActive(context: ChannelHandlerContext) {
        Task { await frameProducer.subscribe() }
        startStreaming(context: context)
    }

    func channelInactive(context: ChannelHandlerContext) {
        streamTask?.cancel()
        streamTask = nil
        Task { await frameProducer.unsubscribe() }
        context.fireChannelInactive()
    }

    func channelRead(
        context: ChannelHandlerContext, data: NIOAny
    ) {
        let frame = unwrapInboundIn(data)
        switch frame.opcode {
        case .connectionClose:
            streamTask?.cancel()
            var closeFrame = WebSocketFrame(
                fin: true, opcode: .connectionClose, data: .init()
            )
            closeFrame.data = frame.unmaskedData
            context.writeAndFlush(
                wrapOutboundOut(closeFrame), promise: nil
            )
            context.close(promise: nil)
        case .ping:
            let pong = WebSocketFrame(
                fin: true, opcode: .pong, data: frame.unmaskedData
            )
            context.writeAndFlush(
                wrapOutboundOut(pong), promise: nil
            )
        default:
            break
        }
    }

    private func startStreaming(context: ChannelHandlerContext) {
        let producer = frameProducer
        let interval = 1.0 / Double(fps)
        var lastSeq: UInt64 = 0

        streamTask = Task {
            while !Task.isCancelled {
                do {
                    if let frame = await producer.latestFrame,
                       frame.sequence > lastSeq
                    {
                        lastSeq = frame.sequence
                        let frameData = frame.compressed.data

                        var buffer = context.channel.allocator.buffer(
                            capacity: frameData.count
                        )
                        buffer.writeBytes(frameData)
                        let wsFrame = WebSocketFrame(
                            fin: true, opcode: .binary, data: buffer
                        )

                        let promise = context.eventLoop.makePromise(
                            of: Void.self
                        )
                        context.eventLoop.execute {
                            context.writeAndFlush(
                                self.wrapOutboundOut(wsFrame),
                                promise: promise
                            )
                        }
                        try await promise.futureResult.get()
                    }

                    try await Task.sleep(
                        nanoseconds: UInt64(interval * 1_000_000_000)
                    )
                } catch {
                    break
                }
            }
        }
    }
}

// MARK: - HTTP Handler

// swiftlint:disable type_body_length
private final class PreviewHTTPHandler:
    ChannelInboundHandler, @unchecked Sendable
{
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private let frameProducer: FrameProducer
    private let buildStatus: BuildStatusBroadcaster
    private let fps: Int
    private let deviceName: String
    private let deviceUDID: String
    private let displayInfo: DeviceDisplayInfo
    private let boundary = "xtool-preview-frame"

    private var isStreaming = false
    private var streamTask: Task<Void, Never>?
    private var sseTask: Task<Void, Never>?

    init(
        frameProducer: FrameProducer,
        buildStatus: BuildStatusBroadcaster,
        fps: Int,
        deviceName: String,
        deviceUDID: String,
        displayInfo: DeviceDisplayInfo
    ) {
        self.frameProducer = frameProducer
        self.buildStatus = buildStatus
        self.fps = fps
        self.deviceName = deviceName
        self.deviceUDID = deviceUDID
        self.displayInfo = displayInfo
    }

    func channelRead(
        context: ChannelHandlerContext, data: NIOAny
    ) {
        let reqPart = unwrapInboundIn(data)
        guard case .head(let head) = reqPart else { return }

        let path = head.uri.split(separator: "?").first
            .map(String.init) ?? head.uri

        switch path {
        case "/":
            serveHTML(context: context)
        case "/stream":
            startMJPEGStream(context: context)
        case "/frame":
            serveSingleFrame(context: context)
        case "/api/info":
            serveDeviceInfo(context: context)
        case "/api/events":
            startSSEStream(context: context)
        default:
            serve404(context: context)
        }
    }

    func channelInactive(context: ChannelHandlerContext) {
        if isStreaming {
            streamTask?.cancel()
            streamTask = nil
            isStreaming = false
            Task { await frameProducer.unsubscribe() }
        }
        sseTask?.cancel()
        sseTask = nil
        context.fireChannelInactive()
    }

    // MARK: - Route Handlers

    private func serveHTML(context: ChannelHandlerContext) {
        let html = PreviewHTML.page(
            deviceName: deviceName,
            deviceUDID: deviceUDID,
            displayInfo: displayInfo
        )
        sendText(
            context: context,
            text: html,
            contentType: "text/html; charset=utf-8"
        )
    }

    private func startMJPEGStream(
        context: ChannelHandlerContext
    ) {
        isStreaming = true
        Task { await frameProducer.subscribe() }

        let headers = HTTPHeaders([
            ("Content-Type",
             "multipart/x-mixed-replace; boundary=\(boundary)"),
            ("Cache-Control", "no-cache, no-store, must-revalidate"),
            ("Pragma", "no-cache"),
            ("Connection", "keep-alive"),
        ])
        let head = HTTPResponseHead(
            version: .http1_1, status: .ok, headers: headers
        )
        context.writeAndFlush(
            wrapOutboundOut(.head(head)), promise: nil
        )

        let producer = frameProducer
        let bnd = boundary
        let interval = 1.0 / Double(fps)
        var lastSeq: UInt64 = 0

        streamTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    if let frame = await producer.latestFrame,
                       frame.sequence > lastSeq
                    {
                        lastSeq = frame.sequence
                        guard let self, self.isStreaming else {
                            break
                        }

                        let ct = frame.compressed.contentType
                        let d = frame.compressed.data
                        let hdr = "--\(bnd)\r\n"
                            + "Content-Type: \(ct)\r\n"
                            + "Content-Length: \(d.count)\r\n\r\n"
                        var buffer =
                            context.channel.allocator.buffer(
                                capacity: hdr.utf8.count + d.count + 2
                            )
                        buffer.writeString(hdr)
                        buffer.writeBytes(d)
                        buffer.writeString("\r\n")

                        let promise =
                            context.eventLoop.makePromise(
                                of: Void.self
                            )
                        context.eventLoop.execute {
                            context.writeAndFlush(
                                self.wrapOutboundOut(
                                    .body(.byteBuffer(buffer))
                                ),
                                promise: promise
                            )
                        }
                        try await promise.futureResult.get()
                    }

                    try await Task.sleep(
                        nanoseconds: UInt64(
                            interval * 1_000_000_000
                        )
                    )
                } catch {
                    break
                }
            }
        }
    }

    private func serveSingleFrame(
        context: ChannelHandlerContext
    ) {
        let producer = frameProducer
        Task {
            await producer.subscribe()
            defer { Task { await producer.unsubscribe() } }

            // Wait briefly for a frame if none available yet
            var attempts = 0
            while await producer.latestFrame == nil, attempts < 20 {
                try? await Task.sleep(nanoseconds: 100_000_000)
                attempts += 1
            }

            guard let frame = await producer.latestFrame else {
                context.eventLoop.execute {
                    self.serve500(
                        context: context,
                        message: "No frame available"
                    )
                }
                return
            }

            let d = frame.compressed.data
            var buffer = context.channel.allocator.buffer(
                capacity: d.count
            )
            buffer.writeBytes(d)

            let ct = frame.compressed.contentType
            let headers = HTTPHeaders([
                ("Content-Type", ct),
                ("Content-Length", "\(buffer.readableBytes)"),
                ("Cache-Control", "no-cache"),
            ])
            let head = HTTPResponseHead(
                version: .http1_1, status: .ok, headers: headers
            )
            context.eventLoop.execute {
                context.write(
                    self.wrapOutboundOut(.head(head)), promise: nil
                )
                context.write(
                    self.wrapOutboundOut(.body(.byteBuffer(buffer))),
                    promise: nil
                )
                context.writeAndFlush(
                    self.wrapOutboundOut(.end(nil)), promise: nil
                )
            }
        }
    }

    private func serveDeviceInfo(
        context: ChannelHandlerContext
    ) {
        let encoder = JSONEncoder()
        struct Info: Encodable {
            let deviceName: String
            let udid: String
            let fps: Int
            let display: DeviceDisplayInfo
        }
        let info = Info(
            deviceName: deviceName,
            udid: deviceUDID,
            fps: fps,
            display: displayInfo
        )
        let json = (try? encoder.encode(info))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        sendText(
            context: context,
            text: json,
            contentType: "application/json"
        )
    }

    // MARK: - SSE Stream

    private func startSSEStream(
        context: ChannelHandlerContext
    ) {
        let headers = HTTPHeaders([
            ("Content-Type", "text/event-stream"),
            ("Cache-Control", "no-cache"),
            ("Connection", "keep-alive"),
        ])
        let head = HTTPResponseHead(
            version: .http1_1, status: .ok, headers: headers
        )
        context.writeAndFlush(
            wrapOutboundOut(.head(head)), promise: nil
        )

        let broadcaster = buildStatus
        sseTask = Task { [weak self] in
            var lastSeq: UInt64 = 0
            while !Task.isCancelled {
                let event = await broadcaster.latest
                if event.sequence > lastSeq {
                    lastSeq = event.sequence
                    let msg = Self.escapeJSON(event.message)
                    let json = "{\"status\":\""
                        + "\(event.status.rawValue)\","
                        + "\"message\":\"\(msg)\"}"
                    let line = "data: \(json)\n\n"
                    var buffer =
                        context.channel.allocator.buffer(
                            capacity: line.utf8.count
                        )
                    buffer.writeString(line)
                    let promise =
                        context.eventLoop.makePromise(
                            of: Void.self
                        )
                    context.eventLoop.execute {
                        guard let self else { return }
                        context.writeAndFlush(
                            self.wrapOutboundOut(
                                .body(.byteBuffer(buffer))
                            ),
                            promise: promise
                        )
                    }
                    do {
                        try await promise.futureResult.get()
                    } catch {
                        break
                    }
                }
                try? await Task.sleep(
                    nanoseconds: 250_000_000
                )
            }
        }
    }

    private static func escapeJSON(
        _ string: String
    ) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    // MARK: - Helpers

    private func sendText(
        context: ChannelHandlerContext,
        text: String,
        contentType: String,
        status: HTTPResponseStatus = .ok
    ) {
        var buffer = context.channel.allocator.buffer(
            capacity: text.utf8.count
        )
        buffer.writeString(text)

        let headers = HTTPHeaders([
            ("Content-Type", contentType),
            ("Content-Length", "\(buffer.readableBytes)"),
            ("Cache-Control", "no-cache"),
        ])
        let head = HTTPResponseHead(
            version: .http1_1, status: status, headers: headers
        )
        context.write(wrapOutboundOut(.head(head)), promise: nil)
        context.write(
            wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil
        )
        context.writeAndFlush(
            wrapOutboundOut(.end(nil)), promise: nil
        )
    }

    private func serve404(context: ChannelHandlerContext) {
        sendText(
            context: context, text: "Not Found",
            contentType: "text/plain", status: .notFound
        )
    }

    private func serve500(
        context: ChannelHandlerContext, message: String
    ) {
        sendText(
            context: context, text: message,
            contentType: "text/plain",
            status: .internalServerError
        )
    }
}
// swiftlint:enable type_body_length
