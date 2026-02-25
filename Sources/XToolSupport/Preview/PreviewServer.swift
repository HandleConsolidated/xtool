import Foundation
import NIOCore
import NIOPosix
import NIOHTTP1
import XKit

#if canImport(CoreGraphics) && canImport(ImageIO)
import CoreGraphics
import ImageIO
#endif

// MARK: - Preview Server

/// HTTP server that streams iOS device screenshots as MJPEG and serves
/// an iPhone-framed web viewer.
///
/// Endpoints:
/// - `GET /`       -> iPhone frame HTML viewer
/// - `GET /stream` -> MJPEG multipart stream
/// - `GET /frame`  -> Single screenshot
/// - `GET /api/info` -> Device info JSON
actor PreviewServer {
    let captureSource: any ScreenCaptureSource
    let host: String
    let port: Int
    let fps: Int
    let deviceName: String
    let deviceUDID: String

    private var channel: Channel?

    init(
        captureSource: any ScreenCaptureSource,
        host: String = "0.0.0.0",
        port: Int = 8034,
        fps: Int = 5,
        deviceName: String = "iPhone",
        deviceUDID: String = ""
    ) {
        self.captureSource = captureSource
        self.host = host
        self.port = port
        self.fps = fps
        self.deviceName = deviceName
        self.deviceUDID = deviceUDID
    }

    func start() async throws {
        try await captureSource.start()

        let capture = captureSource
        let targetFPS = fps
        let name = deviceName
        let udid = deviceUDID

        let bootstrap = ServerBootstrap(group: MultiThreadedEventLoopGroup.singleton)
            .serverChannelOption(.backlog, value: 256)
            .serverChannelOption(.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(
                        PreviewHTTPHandler(
                            captureSource: capture,
                            fps: targetFPS,
                            deviceName: name,
                            deviceUDID: udid
                        )
                    )
                }
            }
            .childChannelOption(.socketOption(.so_reuseaddr), value: 1)

        self.channel = try await bootstrap.bind(host: host, port: port).get()
    }

    func waitUntilStopped() async throws {
        try await channel?.closeFuture.get()
    }

    func stop() async throws {
        try await channel?.close()
        try await captureSource.stop()
    }
}

// MARK: - HTTP Handler

// swiftlint:disable type_body_length
private final class PreviewHTTPHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private let captureSource: any ScreenCaptureSource
    private let fps: Int
    private let deviceName: String
    private let deviceUDID: String
    private let boundary = "xtool-preview-frame"

    private var isStreaming = false
    private var streamTask: Task<Void, Never>?

    init(
        captureSource: any ScreenCaptureSource,
        fps: Int,
        deviceName: String,
        deviceUDID: String
    ) {
        self.captureSource = captureSource
        self.fps = fps
        self.deviceName = deviceName
        self.deviceUDID = deviceUDID
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let reqPart = unwrapInboundIn(data)
        guard case .head(let head) = reqPart else { return }

        switch head.uri {
        case "/":
            serveHTML(context: context)
        case "/stream":
            startMJPEGStream(context: context)
        case "/frame":
            serveSingleFrame(context: context)
        case "/api/info":
            serveDeviceInfo(context: context)
        default:
            serve404(context: context)
        }
    }

    func channelInactive(context: ChannelHandlerContext) {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        context.fireChannelInactive()
    }

    // MARK: - Route Handlers

    private func serveHTML(context: ChannelHandlerContext) {
        let html = PreviewHTML.page(
            deviceName: deviceName,
            deviceUDID: deviceUDID
        )
        sendText(context: context, text: html, contentType: "text/html; charset=utf-8")
    }

    private func startMJPEGStream(context: ChannelHandlerContext) {
        isStreaming = true
        let headers = HTTPHeaders([
            ("Content-Type", "multipart/x-mixed-replace; boundary=\(boundary)"),
            ("Cache-Control", "no-cache, no-store, must-revalidate"),
            ("Pragma", "no-cache"),
            ("Connection", "keep-alive"),
        ])
        let head = HTTPResponseHead(
            version: .http1_1, status: .ok, headers: headers
        )
        context.writeAndFlush(wrapOutboundOut(.head(head)), promise: nil)

        let capture = captureSource
        let bnd = boundary
        let interval = 1.0 / Double(fps)

        streamTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    let rawFrame = try await capture.captureFrame()
                    let imageData = ImageConverter.compressForStream(rawFrame)

                    guard let self, self.isStreaming else { break }

                    let frameHeader = "--\(bnd)\r\n"
                        + "Content-Type: \(imageData.contentType)\r\n"
                        + "Content-Length: \(imageData.data.count)\r\n\r\n"
                    var buffer = context.channel.allocator.buffer(
                        capacity: frameHeader.utf8.count + imageData.data.count + 2
                    )
                    buffer.writeString(frameHeader)
                    buffer.writeBytes(imageData.data)
                    buffer.writeString("\r\n")

                    let promise = context.eventLoop.makePromise(of: Void.self)
                    context.eventLoop.execute {
                        context.writeAndFlush(
                            self.wrapOutboundOut(.body(.byteBuffer(buffer))),
                            promise: promise
                        )
                    }
                    try await promise.futureResult.get()
                    try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                } catch {
                    break
                }
            }
        }
    }

    private func serveSingleFrame(context: ChannelHandlerContext) {
        let capture = captureSource
        Task {
            do {
                let rawFrame = try await capture.captureFrame()
                let imageData = ImageConverter.compressForStream(rawFrame)
                var buffer = context.channel.allocator.buffer(
                    capacity: imageData.data.count
                )
                buffer.writeBytes(imageData.data)

                let headers = HTTPHeaders([
                    ("Content-Type", imageData.contentType),
                    ("Content-Length", "\(buffer.readableBytes)"),
                    ("Cache-Control", "no-cache"),
                ])
                let head = HTTPResponseHead(
                    version: .http1_1, status: .ok, headers: headers
                )
                context.eventLoop.execute {
                    context.write(self.wrapOutboundOut(.head(head)), promise: nil)
                    context.write(
                        self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil
                    )
                    context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
                }
            } catch {
                context.eventLoop.execute {
                    self.serve500(
                        context: context, message: error.localizedDescription
                    )
                }
            }
        }
    }

    private func serveDeviceInfo(context: ChannelHandlerContext) {
        let json = "{\"deviceName\":\"\(deviceName)\",\"udid\":\"\(deviceUDID)\",\"fps\":\(fps)}"
        sendText(context: context, text: json, contentType: "application/json")
    }

    // MARK: - Helpers

    private func sendText(
        context: ChannelHandlerContext,
        text: String,
        contentType: String,
        status: HTTPResponseStatus = .ok
    ) {
        var buffer = context.channel.allocator.buffer(capacity: text.utf8.count)
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
        context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
    }

    private func serve404(context: ChannelHandlerContext) {
        sendText(
            context: context,
            text: "Not Found",
            contentType: "text/plain",
            status: .notFound
        )
    }

    private func serve500(context: ChannelHandlerContext, message: String) {
        sendText(
            context: context,
            text: message,
            contentType: "text/plain",
            status: .internalServerError
        )
    }
}
// swiftlint:enable type_body_length

// MARK: - Image Conversion

private enum ImageConverter {
    struct ImageData {
        let data: Data
        let contentType: String
    }

    /// Compress raw frame data for MJPEG streaming.
    /// On macOS, converts TIFF/PNG to JPEG. On Linux, passes through as-is.
    static func compressForStream(_ rawData: Data) -> ImageData {
        #if canImport(CoreGraphics) && canImport(ImageIO)
        if let jpegData = convertToJPEG(rawData, quality: 0.7) {
            return ImageData(data: jpegData, contentType: "image/jpeg")
        }
        #endif
        // Determine content type from data header
        let contentType = detectContentType(rawData)
        return ImageData(data: rawData, contentType: contentType)
    }

    #if canImport(CoreGraphics) && canImport(ImageIO)
    private static func convertToJPEG(_ imageData: Data, quality: Double) -> Data? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        let mutableData = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            mutableData, "public.jpeg" as CFString, 1, nil
        ) else {
            return nil
        }
        let options: NSDictionary = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        CGImageDestinationAddImage(dest, cgImage, options)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return mutableData as Data
    }
    #endif

    private static func detectContentType(_ data: Data) -> String {
        guard data.count >= 4 else { return "application/octet-stream" }
        let header = [UInt8](data.prefix(4))
        // PNG: 89 50 4E 47
        if header[0] == 0x89 && header[1] == 0x50 {
            return "image/png"
        }
        // JPEG: FF D8 FF
        if header[0] == 0xFF && header[1] == 0xD8 {
            return "image/jpeg"
        }
        // TIFF: 49 49 2A 00 (little-endian) or 4D 4D 00 2A (big-endian)
        if (header[0] == 0x49 && header[1] == 0x49) ||
            (header[0] == 0x4D && header[1] == 0x4D) {
            return "image/tiff"
        }
        return "image/png"
    }
}
