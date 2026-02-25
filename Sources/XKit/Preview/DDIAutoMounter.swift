#if os(Linux)
import Foundation

/// Attempts to mount the Developer Disk Image on a connected
/// iOS device using the `ideviceimagemounter` CLI tool from
/// libimobiledevice.
///
/// The screenshotr service requires a mounted DDI on all iOS
/// versions:
/// - iOS 16 and below: traditional DeveloperDiskImage.dmg
/// - iOS 17+: Personalized Developer Disk Image (downloaded
///   automatically and mounted via `ideviceimagemounter mount`)
enum DDIAutoMounter {
    enum MountError: LocalizedError {
        case toolNotFound
        case alreadyMounted
        case downloadFailed(String)
        case mountFailed(String)

        var errorDescription: String? {
            switch self {
            case .toolNotFound:
                return """
                    ideviceimagemounter not found. \
                    Install libimobiledevice from source \
                    or with: \
                    apt install libimobiledevice-utils
                    """
            case .alreadyMounted:
                return "Developer Disk Image is already mounted"
            case .downloadFailed(let detail):
                return """
                    Failed to download Developer Disk Image: \
                    \(detail)
                    """
            case .mountFailed(let detail):
                return """
                    Failed to mount Developer Disk Image: \
                    \(detail)
                    """
            }
        }
    }

    // MARK: - DDI Cache

    private static let ddiRepo =
        "doronz88/DeveloperDiskImage"
    private static let ddiBranch = "main"
    private static let ddiSubpath =
        "PersonalizedImages/Xcode_iOS_DDI_Personalized"
    private static let ddiFiles = [
        "BuildManifest.plist",
        "Image.dmg",
        "Image.dmg.trustcache",
    ]

    private static var ddiCacheDir: String {
        let home = FileManager.default
            .homeDirectoryForCurrentUser.path
        return "\(home)/.xtool/ddi"
    }

    // MARK: - Public API

    /// Check if DDI is already mounted by listing images.
    static func isDDIMounted(udid: String) -> Bool {
        guard let tool = findTool(
            "ideviceimagemounter"
        ) else {
            return false
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = ["-u", udid, "list"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            if let pipe = process.standardOutput as? Pipe {
                let data = pipe.fileHandleForReading
                    .readDataToEndOfFile()
                let output = String(
                    data: data, encoding: .utf8
                ) ?? ""
                return output.contains("ImagePresent")
                    || output.contains("ImageSignature")
            }
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// Attempt to auto-mount the DDI. Returns true if
    /// mount succeeded or was already mounted.
    @discardableResult
    static func autoMount(
        udid: String
    ) async throws -> Bool {
        // Skip if already mounted
        if isDDIMounted(udid: udid) { return true }

        guard let tool = findTool(
            "ideviceimagemounter"
        ) else {
            throw MountError.toolNotFound
        }

        // Download DDI files if not cached
        print("Downloading Developer Disk Image...")
        try ensureDDICached()

        // Mount the DDI
        print("Mounting Developer Disk Image...")
        return try await mount(
            tool: tool, udid: udid,
            ddiPath: ddiCacheDir
        )
    }

    // MARK: - Download

    private static func ensureDDICached() throws {
        let dir = ddiCacheDir
        let fm = FileManager.default

        let allCached = ddiFiles.allSatisfy {
            fm.fileExists(atPath: "\(dir)/\($0)")
        }
        if allCached {
            print("Using cached DDI from \(dir)")
            return
        }

        try fm.createDirectory(
            atPath: dir,
            withIntermediateDirectories: true
        )

        let baseURL = "https://raw.githubusercontent.com"
            + "/\(ddiRepo)/\(ddiBranch)/\(ddiSubpath)"

        for file in ddiFiles {
            let url = "\(baseURL)/\(file)"
            let dest = "\(dir)/\(file)"
            print("  Downloading \(file)...")
            try downloadFile(from: url, to: dest)
        }
    }

    private static func downloadFile(
        from url: String, to dest: String
    ) throws {
        let process = Process()
        process.executableURL = URL(
            fileURLWithPath: "/usr/bin/curl"
        )
        process.arguments = [
            "-fsSL", "--retry", "3", "-o", dest, url,
        ]
        let errPipe = Pipe()
        process.standardError = errPipe
        process.standardOutput = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errData = errPipe.fileHandleForReading
                .readDataToEndOfFile()
            let stderr = String(
                data: errData, encoding: .utf8
            ) ?? "unknown error"
            try? FileManager.default.removeItem(
                atPath: dest
            )
            throw MountError.downloadFailed(
                "\(url): \(stderr)"
            )
        }
    }

    // MARK: - Mount

    private static func mount(
        tool: String, udid: String, ddiPath: String
    ) async throws -> Bool {
        try await withCheckedThrowingContinuation {
            continuation in
            let process = Process()
            process.executableURL = URL(
                fileURLWithPath: tool
            )
            process.arguments = [
                "-u", udid, "mount", ddiPath,
            ]

            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe

            process.terminationHandler = { proc in
                let outData = outPipe.fileHandleForReading
                    .readDataToEndOfFile()
                let errData = errPipe.fileHandleForReading
                    .readDataToEndOfFile()
                let stdout = String(
                    data: outData, encoding: .utf8
                ) ?? ""
                let stderr = String(
                    data: errData, encoding: .utf8
                ) ?? ""
                let combined = stdout + stderr

                if proc.terminationStatus == 0 {
                    continuation.resume(returning: true)
                } else if combined.contains(
                    "already mounted"
                ) || combined.contains("ImagePresent") {
                    continuation.resume(returning: true)
                } else {
                    let msg = combined.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    continuation.resume(
                        throwing: MountError.mountFailed(
                            msg.isEmpty
                                ? "exit \(proc.terminationStatus)"
                                : msg
                        )
                    )
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(
                    throwing: MountError.mountFailed(
                        "\(error)"
                    )
                )
            }
        }
    }

    // MARK: - Tool Resolution

    private static func findTool(
        _ name: String
    ) -> String? {
        var paths: [String] = []
        // Check AppImage bundle first (avoids ABI mismatch
        // with system libimobiledevice)
        if let appDir = ProcessInfo.processInfo
            .environment["APPDIR"] {
            paths.append("\(appDir)/usr/bin/\(name)")
        }
        // Check next to current executable
        let execDir = URL(
            fileURLWithPath: CommandLine.arguments[0]
        ).deletingLastPathComponent().path
        paths.append("\(execDir)/\(name)")
        paths += [
            "/usr/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/sbin/\(name)",
        ]
        return paths.first {
            FileManager.default.isExecutableFile(atPath: $0)
        }
    }
}
#endif
