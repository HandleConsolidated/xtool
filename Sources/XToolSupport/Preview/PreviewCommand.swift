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
              - libimobiledevice installed (apt install libimobiledevice-utils)

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

    @Flag(
        name: .long,
        help: "Use idevicescreenshot CLI tool instead of native capture"
    ) var useProcessCapture = false

    @Flag(
        name: .long,
        help: "Don't auto-open browser"
    ) var noBrowser = false

    func validate() throws {
        guard (1...30).contains(fps) else {
            throw ValidationError("FPS must be between 1 and 30")
        }
        guard (1024...65535).contains(port) else {
            throw ValidationError("Port must be between 1024 and 65535")
        }
    }

    func run() async throws {
        let client = try await connectionOptions.client()

        let displayInfo = Self.queryDisplayInfo(device: client.device)
        let modelDesc = displayInfo.map { " (\($0.name))" } ?? ""
        print(
            "Starting preview for: \(client.deviceName)"
                + "\(modelDesc) (udid: \(client.udid))"
        )

        let captureSource = try createCaptureSource(udid: client.udid)

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
        print("Open this URL in your Windows browser to see the device screen.")
        print("Press Ctrl+C to stop.")

        if !noBrowser {
            openBrowser(url: url)
        }

        try await server.waitUntilStopped()
    }

    private func createCaptureSource(udid: String) throws -> any ScreenCaptureSource {
        if useProcessCapture {
            return ProcessScreenCapture(udid: udid)
        }

        #if os(Linux)
        return DeviceScreenCapture(udid: udid)
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
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [url]
        try? process.run()
        #elseif os(Linux)
        // On WSL, try to open in Windows browser
        let candidates = [
            "/mnt/c/Windows/System32/cmd.exe",
            "/usr/bin/xdg-open",
            "/usr/bin/wslview",
        ]
        for candidate in candidates {
            guard FileManager.default.isExecutableFile(atPath: candidate) else {
                continue
            }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: candidate)
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
