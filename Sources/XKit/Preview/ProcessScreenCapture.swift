import Foundation

/// Captures screenshots by shelling out to `idevicescreenshot` CLI tool.
///
/// This is a fallback implementation that doesn't require linking against
/// libimobiledevice at compile time. The `idevicescreenshot` tool must be
/// available in PATH (install via `apt install libimobiledevice-utils`).
public actor ProcessScreenCapture: ScreenCaptureSource {
    public enum CaptureError: LocalizedError {
        case toolNotFound
        case captureFailed(String)

        public var errorDescription: String? {
            switch self {
            case .toolNotFound:
                return """
                    'idevicescreenshot' not found in PATH. \
                    Install with: sudo apt install libimobiledevice-utils
                    """
            case .captureFailed(let detail):
                return "Screenshot capture failed: \(detail)"
            }
        }
    }

    private let udid: String?
    private let tempDirectory: URL
    private var frameCount: Int = 0

    public init(udid: String? = nil) {
        self.udid = udid
        self.tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "xtool-preview-\(ProcessInfo.processInfo.processIdentifier)"
            )
    }

    public func start() async throws {
        guard Self.findTool("idevicescreenshot") != nil else {
            throw CaptureError.toolNotFound
        }
        try FileManager.default.createDirectory(
            at: tempDirectory, withIntermediateDirectories: true
        )
    }

    public func captureFrame() async throws -> Data {
        frameCount += 1
        let outputPath = tempDirectory
            .appendingPathComponent("frame-\(frameCount).tiff")

        let toolPath = Self.findTool("idevicescreenshot")
            ?? "/usr/bin/idevicescreenshot"

        var arguments = [outputPath.path]
        if let udid {
            arguments = ["-u", udid] + arguments
        }

        let exitStatus = try await runProcess(
            executablePath: toolPath,
            arguments: arguments
        )

        defer {
            try? FileManager.default.removeItem(at: outputPath)
        }

        guard exitStatus == 0 else {
            throw CaptureError.captureFailed(
                "idevicescreenshot exited with code \(exitStatus)"
            )
        }

        return try Data(contentsOf: outputPath)
    }

    public func stop() async throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    private func runProcess(
        executablePath: String,
        arguments: [String]
    ) async throws -> Int32 {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            process.terminationHandler = { proc in
                continuation.resume(returning: proc.terminationStatus)
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private static func findTool(_ name: String) -> String? {
        let searchPaths = [
            "/usr/bin",
            "/usr/local/bin",
            "/usr/sbin",
        ]
        for dir in searchPaths {
            let path = "\(dir)/\(name)"
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }
}
