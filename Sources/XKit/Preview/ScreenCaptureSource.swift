import Foundation

/// A source that captures screen frames from an iOS device.
///
/// Conforming types provide a mechanism to capture screenshot data
/// from a connected device, returning image data suitable for
/// streaming to a preview viewer.
public protocol ScreenCaptureSource: Sendable {
    /// Prepare the capture source for use (e.g., connect to device services).
    func start() async throws

    /// Capture a single frame from the device screen.
    /// - Returns: Image data (PNG or TIFF) of the current screen content.
    func captureFrame() async throws -> Data

    /// Release resources associated with this capture source.
    func stop() async throws
}
