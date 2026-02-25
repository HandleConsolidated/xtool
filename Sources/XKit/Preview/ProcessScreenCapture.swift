import Foundation

/// Captures screenshots by shelling out to a CLI screenshot tool.
///
/// Supports two backends:
/// - `idevicescreenshot` (libimobiledevice, works on iOS ≤16)
/// - `pymobiledevice3` (Python, works on iOS 17+ with tunnel)
///
/// On first capture, auto-detects which tool works and sticks
/// with it for subsequent frames.
public actor ProcessScreenCapture: ScreenCaptureSource {
    public enum CaptureError: LocalizedError {
        case toolNotFound
        case captureFailed(String)
        case allToolsFailed

        public var errorDescription: String? {
            switch self {
            case .toolNotFound:
                return """
                    No screenshot tool found. Install one of: \
                    'idevicescreenshot' (apt install \
                    libimobiledevice-utils) or 'pymobiledevice3' \
                    (pip3 install pymobiledevice3)
                    """
            case .captureFailed(let detail):
                return "Screenshot capture failed: \(detail)"
            case .allToolsFailed:
                return """
                    All screenshot tools failed. On iOS 17+, \
                    a developer tunnel is required. Start one \
                    with: sudo pymobiledevice3 remote \
                    start-tunnel -- then retry.
                    """
            }
        }
    }

    /// Which CLI tool to use for screenshots.
    public enum CaptureTool: String, Sendable {
        case idevicescreenshot
        case pymobiledevice3
        case auto
    }

    private let udid: String?
    private let preferredTool: CaptureTool
    private let tempDirectory: URL
    private var frameCount: Int = 0
    private var activeTool: CaptureTool?

    public init(
        udid: String? = nil,
        tool: CaptureTool = .auto
    ) {
        self.udid = udid
        self.preferredTool = tool
        self.tempDirectory = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "xtool-preview-"
                    + "\(ProcessInfo.processInfo.processIdentifier)"
            )
    }

    public func start() async throws {
        let hasIdevice = Self.findTool(
            "idevicescreenshot"
        ) != nil
        let hasPymd3 = Self.findTool(
            "pymobiledevice3"
        ) != nil

        switch preferredTool {
        case .idevicescreenshot:
            guard hasIdevice else {
                throw CaptureError.toolNotFound
            }
        case .pymobiledevice3:
            guard hasPymd3 else {
                throw CaptureError.toolNotFound
            }
        case .auto:
            guard hasIdevice || hasPymd3 else {
                throw CaptureError.toolNotFound
            }
        }

        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
    }

    public func captureFrame() async throws -> Data {
        // If we already know which tool works, use it
        if let tool = activeTool {
            return try await capture(with: tool)
        }

        // Auto-detect: try preferred tool or both
        switch preferredTool {
        case .idevicescreenshot:
            activeTool = .idevicescreenshot
            return try await capture(with: .idevicescreenshot)
        case .pymobiledevice3:
            activeTool = .pymobiledevice3
            return try await capture(with: .pymobiledevice3)
        case .auto:
            return try await autoDetectAndCapture()
        }
    }

    public func stop() async throws {
        try? FileManager.default.removeItem(
            at: tempDirectory
        )
    }

    // MARK: - Auto Detection

    private func autoDetectAndCapture() async throws -> Data {
        // Try idevicescreenshot first (faster, no Python)
        if Self.findTool("idevicescreenshot") != nil {
            if let data = try? await capture(
                with: .idevicescreenshot
            ) {
                activeTool = .idevicescreenshot
                print("Using idevicescreenshot for capture")
                return data
            }
        }

        // Fall back to pymobiledevice3 (iOS 17+ support)
        if Self.findTool("pymobiledevice3") != nil {
            if let data = try? await capture(
                with: .pymobiledevice3
            ) {
                activeTool = .pymobiledevice3
                print("Using pymobiledevice3 for capture")
                return data
            }
        }

        throw CaptureError.allToolsFailed
    }

    // MARK: - Capture Implementations

    private func capture(
        with tool: CaptureTool
    ) async throws -> Data {
        switch tool {
        case .idevicescreenshot:
            return try await captureWithIdevicescreenshot()
        case .pymobiledevice3:
            return try await captureWithPymobiledevice3()
        case .auto:
            return try await autoDetectAndCapture()
        }
    }

    private func captureWithIdevicescreenshot(
    ) async throws -> Data {
        frameCount += 1
        let outputPath = tempDirectory
            .appendingPathComponent("frame-\(frameCount).tiff")

        let toolPath = Self.findTool("idevicescreenshot")
            ?? "/usr/bin/idevicescreenshot"

        var arguments = [outputPath.path]
        if let udid {
            arguments = ["-u", udid] + arguments
        }

        let (exitStatus, _) = try await runProcess(
            executablePath: toolPath,
            arguments: arguments
        )

        defer {
            try? FileManager.default.removeItem(at: outputPath)
        }

        guard exitStatus == 0 else {
            throw CaptureError.captureFailed(
                "idevicescreenshot exited with code "
                    + "\(exitStatus)"
            )
        }

        return try Data(contentsOf: outputPath)
    }

    private func captureWithPymobiledevice3(
    ) async throws -> Data {
        frameCount += 1
        let outputPath = tempDirectory
            .appendingPathComponent("frame-\(frameCount).png")

        let toolPath = Self.findTool("pymobiledevice3")
            ?? "/usr/local/bin/pymobiledevice3"

        var arguments = [
            "developer", "dvt", "screenshot",
            outputPath.path,
        ]
        if let udid {
            arguments += ["--udid", udid]
        }

        let (exitStatus, stderr) = try await runProcess(
            executablePath: toolPath,
            arguments: arguments,
            captureStderr: true
        )

        defer {
            try? FileManager.default.removeItem(at: outputPath)
        }

        guard exitStatus == 0 else {
            let detail = stderr.isEmpty
                ? "exit code \(exitStatus)"
                : stderr
            throw CaptureError.captureFailed(
                "pymobiledevice3: \(detail)"
            )
        }

        return try Data(contentsOf: outputPath)
    }

    // MARK: - Process Execution

    private func runProcess(
        executablePath: String,
        arguments: [String],
        captureStderr: Bool = false
    ) async throws -> (Int32, String) {
        try await withCheckedThrowingContinuation {
            continuation in
            let process = Process()
            process.executableURL = URL(
                fileURLWithPath: executablePath
            )
            process.arguments = arguments
            process.standardOutput = FileHandle.nullDevice

            let errPipe: Pipe? = captureStderr ? Pipe() : nil
            if let errPipe {
                process.standardError = errPipe
            } else {
                process.standardError = FileHandle.nullDevice
            }

            process.terminationHandler = { proc in
                var stderr = ""
                if let errPipe {
                    let data = errPipe.fileHandleForReading
                        .readDataToEndOfFile()
                    stderr = (
                        String(data: data, encoding: .utf8)
                            ?? ""
                    ).trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                }
                continuation.resume(
                    returning: (
                        proc.terminationStatus, stderr
                    )
                )
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Tool Resolution

    static func findTool(_ name: String) -> String? {
        var searchPaths: [String] = []
        if let appDir = ProcessInfo.processInfo
            .environment["APPDIR"] {
            searchPaths.append("\(appDir)/usr/bin")
        }
        let execDir = URL(
            fileURLWithPath: CommandLine.arguments[0]
        ).deletingLastPathComponent().path
        searchPaths.append(execDir)
        searchPaths += [
            "/usr/bin",
            "/usr/local/bin",
            "/usr/sbin",
        ]
        // Also check PATH for tools installed via pip etc.
        if let pathEnv = ProcessInfo.processInfo
            .environment["PATH"] {
            for dir in pathEnv.split(separator: ":") {
                let dirStr = String(dir)
                if !searchPaths.contains(dirStr) {
                    searchPaths.append(dirStr)
                }
            }
        }
        for dir in searchPaths {
            let path = "\(dir)/\(name)"
            if FileManager.default.isExecutableFile(
                atPath: path
            ) {
                return path
            }
        }
        return nil
    }
}
