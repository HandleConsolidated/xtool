#if os(Linux)
import Foundation

/// Attempts to mount the Developer Disk Image on a connected
/// iOS device using the `ideviceimagemounter` CLI tool from
/// libimobiledevice.
///
/// The screenshotr service requires a mounted DDI on all iOS
/// versions:
/// - iOS 16 and below: traditional DeveloperDiskImage.dmg
/// - iOS 17+: Personalized Developer Disk Image (auto-mounted
///   by recent libimobiledevice builds)
enum DDIAutoMounter {
    enum MountError: LocalizedError {
        case toolNotFound
        case alreadyMounted
        case mountFailed(String)

        var errorDescription: String? {
            switch self {
            case .toolNotFound:
                return """
                    ideviceimagemounter not found. Install with: \
                    apt install libimobiledevice-utils
                    """
            case .alreadyMounted:
                return "Developer Disk Image is already mounted"
            case .mountFailed(let detail):
                return """
                    Failed to mount Developer Disk Image: \
                    \(detail)
                    """
            }
        }
    }

    /// Check if DDI is already mounted by querying
    /// the screenshotr service availability.
    static func isDDIMounted(udid: String) -> Bool {
        guard let tool = findTool("ideviceimagemounter") else {
            return false
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = ["-u", udid, "-l"]
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
    static func autoMount(udid: String) async throws -> Bool {
        guard let tool = findTool("ideviceimagemounter") else {
            throw MountError.toolNotFound
        }

        return try await withCheckedThrowingContinuation {
            continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: tool)
            process.arguments = ["-u", udid, "auto"]

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
                } else if combined.contains("already mounted")
                    || combined.contains("ImagePresent")
                {
                    continuation.resume(returning: true)
                } else {
                    let msg = combined.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    continuation.resume(
                        throwing: MountError.mountFailed(
                            msg.isEmpty
                                ? "exit code \(proc.terminationStatus)"
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

    private static func findTool(
        _ name: String
    ) -> String? {
        let paths = [
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
