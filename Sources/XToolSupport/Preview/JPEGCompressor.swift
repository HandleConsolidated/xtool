import Foundation

#if canImport(CTurboJPEG)
import CTurboJPEG
#endif

#if canImport(CoreGraphics) && canImport(ImageIO)
import CoreGraphics
import ImageIO
#endif

/// Compresses raw image data to JPEG for efficient streaming.
enum JPEGCompressor {
    struct CompressedFrame {
        let data: Data
        let contentType: String
    }

    /// Compress a raw screenshot frame for streaming.
    ///
    /// On macOS, uses CoreGraphics/ImageIO to convert any image
    /// format to JPEG. On Linux with turbojpeg, parses TIFF and
    /// compresses the raw pixels. Falls back to passing through
    /// the original data if compression isn't available.
    static func compress(
        _ rawData: Data,
        quality: Int = 70
    ) -> CompressedFrame {
        #if canImport(CoreGraphics) && canImport(ImageIO)
        if let jpeg = compressWithCoreGraphics(rawData, quality: quality) {
            return CompressedFrame(
                data: jpeg, contentType: "image/jpeg"
            )
        }
        #endif

        #if canImport(CTurboJPEG)
        if let jpeg = compressWithTurboJPEG(rawData, quality: quality) {
            return CompressedFrame(
                data: jpeg, contentType: "image/jpeg"
            )
        }
        #endif

        let contentType = detectContentType(rawData)
        return CompressedFrame(
            data: rawData, contentType: contentType
        )
    }

    // MARK: - CoreGraphics (macOS)

    #if canImport(CoreGraphics) && canImport(ImageIO)
    private static func compressWithCoreGraphics(
        _ imageData: Data,
        quality: Int
    ) -> Data? {
        guard let source = CGImageSourceCreateWithData(
            imageData as CFData, nil
        ) else { return nil }
        guard let cgImage = CGImageSourceCreateImageAtIndex(
            source, 0, nil
        ) else { return nil }

        let mutableData = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            mutableData, "public.jpeg" as CFString, 1, nil
        ) else { return nil }

        let q = Double(quality) / 100.0
        let options: NSDictionary = [
            kCGImageDestinationLossyCompressionQuality: q
        ]
        CGImageDestinationAddImage(dest, cgImage, options)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return mutableData as Data
    }
    #endif

    // MARK: - TurboJPEG (Linux)

    #if canImport(CTurboJPEG)
    private static func compressWithTurboJPEG(
        _ rawData: Data,
        quality: Int
    ) -> Data? {
        // If already JPEG, skip
        if isJPEG(rawData) { return rawData }

        // If TIFF, parse and compress raw pixels
        if isTIFF(rawData) {
            return compressTIFFWithTurboJPEG(rawData, quality: quality)
        }

        // PNG or other: can't compress without a decoder
        return nil
    }

    private static func compressTIFFWithTurboJPEG(
        _ tiffData: Data,
        quality: Int
    ) -> Data? {
        guard let raw = try? TIFFParser.parse(tiffData) else {
            return nil
        }

        guard let handle = tjInitCompress() else { return nil }
        defer { tjDestroy(handle) }

        let pixelFormat: TJPF
        switch raw.bytesPerPixel {
        case 3:
            pixelFormat = TJPF_RGB
        case 4:
            pixelFormat = TJPF_RGBA
        default:
            return nil
        }

        var jpegBuf: UnsafeMutablePointer<UInt8>?
        var jpegSize: UInt = 0
        let pitch = raw.width * raw.bytesPerPixel

        let result = raw.pixels.withUnsafeBytes { rawPtr -> Int32 in
            guard let baseAddr = rawPtr.baseAddress else {
                return -1
            }
            return tjCompress2(
                handle,
                baseAddr.assumingMemoryBound(to: UInt8.self),
                Int32(raw.width),
                Int32(pitch),
                Int32(raw.height),
                pixelFormat.rawValue,
                &jpegBuf,
                &jpegSize,
                Int32(TJSAMP_420.rawValue),
                Int32(quality),
                Int32(TJFLAG_FASTDCT)
            )
        }

        guard result == 0, let jpegBuf, jpegSize > 0 else {
            return nil
        }

        let data = Data(bytes: jpegBuf, count: Int(jpegSize))
        tjFree(jpegBuf)
        return data
    }
    #endif

    // MARK: - Format Detection

    static func detectContentType(_ data: Data) -> String {
        guard data.count >= 4 else { return "application/octet-stream" }
        if isJPEG(data) { return "image/jpeg" }
        if isPNG(data) { return "image/png" }
        if isTIFF(data) { return "image/tiff" }
        return "image/png"
    }

    private static func isJPEG(_ data: Data) -> Bool {
        data.count >= 2 && data[data.startIndex] == 0xFF
            && data[data.startIndex + 1] == 0xD8
    }

    private static func isPNG(_ data: Data) -> Bool {
        data.count >= 2 && data[data.startIndex] == 0x89
            && data[data.startIndex + 1] == 0x50
    }

    private static func isTIFF(_ data: Data) -> Bool {
        guard data.count >= 2 else { return false }
        let b0 = data[data.startIndex]
        let b1 = data[data.startIndex + 1]
        return (b0 == 0x49 && b1 == 0x49)
            || (b0 == 0x4D && b1 == 0x4D)
    }
}
