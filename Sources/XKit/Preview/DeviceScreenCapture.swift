#if os(Linux)
import Foundation
import CScreenCapture

// lockdownd_error_t enum constants may not be imported by
// Swift's Clang importer on all platforms; use raw value.
private let LOCKDOWN_OK = lockdownd_error_t(0)

/// Captures screenshots from a connected iOS device using
/// libimobiledevice's screenshotr service.
///
/// This requires a mounted Developer Disk Image on all iOS
/// versions. On iOS 17+, a Personalized DDI is needed (handled
/// automatically by `ideviceimagemounter auto`). Developer Mode
/// must also be enabled on the device.
public actor DeviceScreenCapture: ScreenCaptureSource {
    public enum CaptureError: LocalizedError {
        case deviceNotFound(udid: String)
        case lockdownFailed(String)
        case serviceStartFailed(String)
        case screenshotFailed(String)
        case notStarted

        public var errorDescription: String? {
            switch self {
            case .deviceNotFound(let udid):
                return "Device not found: \(udid)"
            case .lockdownFailed(let detail):
                return "Lockdown connection failed: \(detail)"
            case .serviceStartFailed(let detail):
                return """
                    Failed to start screenshot service: \
                    \(detail). Ensure Developer Disk Image is \
                    mounted (run: ideviceimagemounter auto) \
                    and Developer Mode is enabled on the device.
                    """
            case .screenshotFailed(let detail):
                return "Screenshot capture failed: \(detail)"
            case .notStarted:
                return "Screen capture not started. Call start() first."
            }
        }
    }

    private let udid: String
    private var device: idevice_t?
    private var client: screenshotr_client_t?
    private var isStarted = false

    public init(udid: String) {
        self.udid = udid
    }

    public func start() async throws {
        // Attempt to auto-mount DDI before connecting
        try await mountDDIIfNeeded()

        var dev: idevice_t?
        let devErr = idevice_new_with_options(
            &dev, udid, IDEVICE_LOOKUP_USBMUX
        )
        guard devErr == IDEVICE_E_SUCCESS, let dev else {
            throw CaptureError.deviceNotFound(udid: udid)
        }
        self.device = dev

        var lockdownClient: lockdownd_client_t?
        let ldErr = lockdownd_client_new_with_handshake(
            dev, &lockdownClient, "xtool-preview"
        )
        guard ldErr == LOCKDOWN_OK,
              let lockdownClient
        else {
            throw CaptureError.lockdownFailed(
                "error code \(ldErr.rawValue)"
            )
        }

        var service: lockdownd_service_descriptor_t?
        let svcErr = lockdownd_start_service(
            lockdownClient,
            "com.apple.mobile.screenshotr",
            &service
        )
        lockdownd_client_free(lockdownClient)

        guard svcErr == LOCKDOWN_OK, let service else {
            throw CaptureError.serviceStartFailed(
                "error code \(svcErr.rawValue)"
            )
        }

        var screenshotrClient: screenshotr_client_t?
        let ssErr = screenshotr_client_new(
            dev, service, &screenshotrClient
        )
        lockdownd_service_descriptor_free(service)

        guard ssErr == SCREENSHOTR_E_SUCCESS,
              let screenshotrClient
        else {
            throw CaptureError.serviceStartFailed(
                "screenshotr_client_new failed: "
                    + "\(ssErr.rawValue)"
            )
        }

        self.client = screenshotrClient
        self.isStarted = true
    }

    private func mountDDIIfNeeded() async throws {
        do {
            try await DDIAutoMounter.autoMount(udid: udid)
        } catch is DDIAutoMounter.MountError {
            // DDI mount failed — continue anyway; the
            // screenshotr service start will give a clearer
            // error if the DDI is truly not mounted.
        }
    }

    public func captureFrame() async throws -> Data {
        guard isStarted, let client else {
            throw CaptureError.notStarted
        }

        var imgdata: UnsafeMutablePointer<CChar>?
        var imgsize: UInt64 = 0

        let err = screenshotr_take_screenshot(client, &imgdata, &imgsize)
        guard err == SCREENSHOTR_E_SUCCESS, let imgdata, imgsize > 0 else {
            throw CaptureError.screenshotFailed("error code \(err.rawValue)")
        }

        let data = Data(bytes: imgdata, count: Int(imgsize))
        free(imgdata)
        return data
    }

    public func stop() async throws {
        if let client {
            screenshotr_client_free(client)
            self.client = nil
        }
        if let device {
            idevice_free(device)
            self.device = nil
        }
        isStarted = false
    }

    deinit {
        if let client {
            screenshotr_client_free(client)
        }
        if let device {
            idevice_free(device)
        }
    }
}
#endif
