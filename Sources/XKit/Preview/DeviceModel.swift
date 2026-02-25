import Foundation

/// Represents an iOS device's display characteristics for preview rendering.
public struct DeviceDisplayInfo: Sendable, Codable {
    /// Marketing name (e.g., "iPhone 15 Pro")
    public let name: String
    /// Native screen width in pixels
    public let screenWidth: Int
    /// Native screen height in pixels
    public let screenHeight: Int
    /// Display style for frame rendering
    public let displayStyle: DisplayStyle
    /// Screen corner radius in CSS px (scaled to preview)
    public let cornerRadius: Int

    public enum DisplayStyle: String, Sendable, Codable {
        /// Home button device (iPhone SE, iPhone 8)
        case homeButton
        /// Notch display (iPhone X through 13)
        case notch
        /// Dynamic Island (iPhone 14 Pro+, iPhone 15+)
        case dynamicIsland
    }

    /// Aspect ratio as height/width
    public var aspectRatio: Double {
        Double(screenHeight) / Double(screenWidth)
    }
}

/// Maps iOS device ProductType identifiers to display characteristics.
public enum DeviceModelDatabase {
    // swiftlint:disable function_body_length
    public static func displayInfo(
        forProductType productType: String
    ) -> DeviceDisplayInfo {
        switch productType {
        // iPhone SE (2nd gen)
        case "iPhone12,8":
            return .init(
                name: "iPhone SE (2nd gen)", screenWidth: 750,
                screenHeight: 1334, displayStyle: .homeButton,
                cornerRadius: 0
            )
        // iPhone SE (3rd gen)
        case "iPhone14,6":
            return .init(
                name: "iPhone SE (3rd gen)", screenWidth: 750,
                screenHeight: 1334, displayStyle: .homeButton,
                cornerRadius: 0
            )
        // iPhone 12 mini
        case "iPhone13,1":
            return .init(
                name: "iPhone 12 mini", screenWidth: 1080,
                screenHeight: 2340, displayStyle: .notch,
                cornerRadius: 44
            )
        // iPhone 12 / 12 Pro
        case "iPhone13,2", "iPhone13,3":
            return .init(
                name: "iPhone 12", screenWidth: 1170,
                screenHeight: 2532, displayStyle: .notch,
                cornerRadius: 47
            )
        // iPhone 12 Pro Max
        case "iPhone13,4":
            return .init(
                name: "iPhone 12 Pro Max", screenWidth: 1284,
                screenHeight: 2778, displayStyle: .notch,
                cornerRadius: 53
            )
        // iPhone 13 mini
        case "iPhone14,4":
            return .init(
                name: "iPhone 13 mini", screenWidth: 1080,
                screenHeight: 2340, displayStyle: .notch,
                cornerRadius: 44
            )
        // iPhone 13 / 13 Pro
        case "iPhone14,5", "iPhone14,2":
            return .init(
                name: "iPhone 13", screenWidth: 1170,
                screenHeight: 2532, displayStyle: .notch,
                cornerRadius: 47
            )
        // iPhone 13 Pro Max
        case "iPhone14,3":
            return .init(
                name: "iPhone 13 Pro Max", screenWidth: 1284,
                screenHeight: 2778, displayStyle: .notch,
                cornerRadius: 53
            )
        // iPhone 14 / 14 Plus
        case "iPhone14,7":
            return .init(
                name: "iPhone 14", screenWidth: 1170,
                screenHeight: 2532, displayStyle: .notch,
                cornerRadius: 47
            )
        case "iPhone14,8":
            return .init(
                name: "iPhone 14 Plus", screenWidth: 1284,
                screenHeight: 2778, displayStyle: .notch,
                cornerRadius: 53
            )
        // iPhone 14 Pro
        case "iPhone15,2":
            return .init(
                name: "iPhone 14 Pro", screenWidth: 1179,
                screenHeight: 2556, displayStyle: .dynamicIsland,
                cornerRadius: 55
            )
        // iPhone 14 Pro Max
        case "iPhone15,3":
            return .init(
                name: "iPhone 14 Pro Max", screenWidth: 1290,
                screenHeight: 2796, displayStyle: .dynamicIsland,
                cornerRadius: 55
            )
        // iPhone 15 / 15 Plus
        case "iPhone15,4":
            return .init(
                name: "iPhone 15", screenWidth: 1179,
                screenHeight: 2556, displayStyle: .dynamicIsland,
                cornerRadius: 55
            )
        case "iPhone15,5":
            return .init(
                name: "iPhone 15 Plus", screenWidth: 1290,
                screenHeight: 2796, displayStyle: .dynamicIsland,
                cornerRadius: 55
            )
        // iPhone 15 Pro / Pro Max
        case "iPhone16,1":
            return .init(
                name: "iPhone 15 Pro", screenWidth: 1179,
                screenHeight: 2556, displayStyle: .dynamicIsland,
                cornerRadius: 55
            )
        case "iPhone16,2":
            return .init(
                name: "iPhone 15 Pro Max", screenWidth: 1290,
                screenHeight: 2796, displayStyle: .dynamicIsland,
                cornerRadius: 55
            )
        // iPhone 16 / 16 Plus
        case "iPhone17,3":
            return .init(
                name: "iPhone 16", screenWidth: 1179,
                screenHeight: 2556, displayStyle: .dynamicIsland,
                cornerRadius: 55
            )
        case "iPhone17,4":
            return .init(
                name: "iPhone 16 Plus", screenWidth: 1290,
                screenHeight: 2796, displayStyle: .dynamicIsland,
                cornerRadius: 55
            )
        // iPhone 16 Pro
        case "iPhone17,1":
            return .init(
                name: "iPhone 16 Pro", screenWidth: 1206,
                screenHeight: 2622, displayStyle: .dynamicIsland,
                cornerRadius: 55
            )
        // iPhone 16 Pro Max
        case "iPhone17,2":
            return .init(
                name: "iPhone 16 Pro Max", screenWidth: 1320,
                screenHeight: 2868, displayStyle: .dynamicIsland,
                cornerRadius: 55
            )
        default:
            return defaultDisplay(for: productType)
        }
    }
    // swiftlint:enable function_body_length

    private static func defaultDisplay(
        for productType: String
    ) -> DeviceDisplayInfo {
        if productType.hasPrefix("iPad") {
            return .init(
                name: "iPad", screenWidth: 1620,
                screenHeight: 2160, displayStyle: .homeButton,
                cornerRadius: 18
            )
        }
        // Default to iPhone 15-style for unknown iPhones
        return .init(
            name: "iPhone", screenWidth: 1179,
            screenHeight: 2556, displayStyle: .dynamicIsland,
            cornerRadius: 55
        )
    }
}
