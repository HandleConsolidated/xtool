import Foundation
import ArgumentParser
import SwiftyMobileDevice
import XKit

struct PreviewCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "preview",
        abstract: "Mirror iOS device screen to a browser window",
        discussion: """
            Captures the connected iOS device's screen and streams it to a \
            browser-based viewer styled as an iPhone frame.

            Prerequisites:
              - A connected iOS device (USB or network)
              - Developer Disk Image mounted (auto-attempted on start)
              - Developer Mode enabled on the device (iOS 17+)

            Screenshot tools (at least one required):
              - idevicescreenshot (apt install libimobiledevice-utils)
              - pymobiledevice3 (pip3 install pymobiledevice3)

            On iOS 17+, pymobiledevice3 is required with an active tunnel:
              sudo pymobiledevice3 remote start-tunnel

            The preview opens at http://localhost:<port> in your browser. \
            On WSL, this URL is accessible from Windows browsers directly.
            """
    )

    @OptionGroup var connectionOptions: ConnectionOptions

    @Option(
        name: .shortAndLong,
        help: "HTTP server port for the preview viewer"
    ) var port: Int = 8034

    @Option(
        name: .long,
        help: "Target frames per second (1-30)"
    ) var fps: Int = 5

    @Option(
        name: .long,
        help: """
            Screenshot tool: auto, idevicescreenshot, \
            or pymobiledevice3 (default: auto)
            """
    ) var captureTool: String = "auto"

    @Flag(
        name: .long,
        help: "Use CLI screenshot tools instead of native capture"
    ) var useProcessCapture = false

    @Flag(
        name: .long,
        help: "Don't auto-open browser"
    ) var noBrowser = false

    func validate() throws {
        guard (1...30).contains(fps) else {
            throw ValidationError(
                "FPS must be between 1 and 30"
            )
        }
        guard (1024...65535).contains(port) else {
            throw ValidationError(
                "Port must be between 1024 and 65535"
            )
        }
        let valid = [
            "auto", "idevicescreenshot", "pymobiledevice3",
        ]
        guard valid.contains(captureTool) else {
            throw ValidationError(
                "capture-tool must be one of: "
                    + valid.joined(separator: ", ")
            )
        }
    }

    func run() async throws {
        let client = try await connectionOptions.client()

        let displayInfo = Self.queryDisplayInfo(
            device: client.device
        )
        let modelDesc = displayInfo.map {
            " (\($0.name))"
        } ?? ""
        print(
            "Starting preview for: \(client.deviceName)"
                + "\(modelDesc) (udid: \(client.udid))"
        )

        let captureSource = createCaptureSource(
            udid: client.udid
        )

        let server = PreviewServer(
            captureSource: captureSource,
            port: port,
            fps: fps,
            deviceName: client.deviceName,
            deviceUDID: client.udid,
            displayInfo: displayInfo
        )

        try await server.start()

        let url = "http://localhost:\(port)"
        print("Preview server running at \(url)")
        print(
            "Open this URL in your Windows browser "
                + "to see the device screen."
        )
        print("Press Ctrl+C to stop.")

        if !noBrowser {
            openBrowser(url: url)
        }

        try await server.waitUntilStopped()
    }

    private func createCaptureSource(
        udid: String
    ) -> any ScreenCaptureSource {
        let tool: ProcessScreenCapture.CaptureTool
        switch captureTool {
        case "idevicescreenshot":
            tool = .idevicescreenshot
        case "pymobiledevice3":
            tool = .pymobiledevice3
        default:
            tool = .auto
        }

        // On Linux, prefer ProcessScreenCapture which now
        // auto-detects the best working tool (idevicescreenshot
        // for iOS ≤16, pymobiledevice3 for iOS 17+).
        // The native DeviceScreenCapture only works with
        // iOS ≤16 via lockdownd.
        if useProcessCapture || tool != .auto {
            return ProcessScreenCapture(
                udid: udid, tool: tool
            )
        }

        #if os(Linux)
        // Use ProcessScreenCapture with auto-detection so
        // it can fall back to pymobiledevice3 on iOS 17+
        return ProcessScreenCapture(
            udid: udid, tool: .auto
        )
        #else
        return ProcessScreenCapture(udid: udid)
        #endif
    }

    static func queryDisplayInfo(
        device: Device
    ) -> DeviceDisplayInfo? {
        guard let lockdown = try? LockdownClient(
            device: device,
            label: "xtool-preview",
            performHandshake: false
        ) else { return nil }
        guard let productType = try? lockdown.value(
            ofType: String.self, forDomain: nil,
            key: "ProductType"
        ) else { return nil }
        return DeviceModelDatabase.displayInfo(
            forProductType: productType
        )
    }

    private func openBrowser(url: String) {
        #if os(macOS)
        let process = Process()
        process.executableURL = URL(
            fileURLWithPath: "/usr/bin/open"
        )
        process.arguments = [url]
        try? process.run()
        #elseif os(Linux)
        let candidates = [
            "/mnt/c/Windows/System32/cmd.exe",
            "/usr/bin/xdg-open",
            "/usr/bin/wslview",
        ]
        for candidate in candidates {
            guard FileManager.default.isExecutableFile(
                atPath: candidate
            ) else {
                continue
            }
            let process = Process()
            process.executableURL = URL(
                fileURLWithPath: candidate
            )
            if candidate.hasSuffix("cmd.exe") {
                process.arguments = ["/c", "start", url]
            } else {
                process.arguments = [url]
            }
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try? process.run()
            return
        }
        #endif
    }
}
