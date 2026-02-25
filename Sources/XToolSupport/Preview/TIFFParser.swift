import Foundation

/// Minimal TIFF parser for iOS screenshotr output.
///
/// iOS screenshotr produces uncompressed RGB TIFF images with a
/// standard header. This parser extracts the raw pixel data
/// needed for JPEG recompression.
enum TIFFParser {
    struct RawImage {
        let width: Int
        let height: Int
        let bytesPerPixel: Int
        let pixels: Data
    }

    enum ParseError: Error {
        case invalidHeader
        case unsupportedFormat(String)
        case missingRequiredTag(UInt16)
        case dataOutOfBounds
    }

    /// Parse a TIFF image and extract raw pixel data.
    static func parse(_ data: Data) throws -> RawImage {
        guard data.count >= 8 else {
            throw ParseError.invalidHeader
        }

        let bytes = [UInt8](data)

        // Check byte order
        let isLittleEndian: Bool
        if bytes[0] == 0x49 && bytes[1] == 0x49 {
            isLittleEndian = true
        } else if bytes[0] == 0x4D && bytes[1] == 0x4D {
            isLittleEndian = false
        } else {
            throw ParseError.invalidHeader
        }

        // Check magic number (42)
        let magic = readUInt16(bytes, offset: 2, le: isLittleEndian)
        guard magic == 42 else {
            throw ParseError.invalidHeader
        }

        // Read IFD offset
        let ifdOffset = readUInt32(
            bytes, offset: 4, le: isLittleEndian
        )

        // Parse IFD entries
        let ifd = try parseIFD(
            bytes, offset: Int(ifdOffset), le: isLittleEndian
        )

        // Extract required tags
        guard let width = ifd[256] else {
            throw ParseError.missingRequiredTag(256)
        }
        guard let height = ifd[257] else {
            throw ParseError.missingRequiredTag(257)
        }

        let samplesPerPixel = ifd[277] ?? 3
        let compression = ifd[259] ?? 1
        guard compression == 1 else {
            throw ParseError.unsupportedFormat(
                "compressed TIFF (compression=\(compression))"
            )
        }

        // Get strip offsets and byte counts
        let stripOffsets = try readTagArray(
            bytes, ifd: ifd, tag: 273, le: isLittleEndian
        )
        let stripByteCounts = try readTagArray(
            bytes, ifd: ifd, tag: 279, le: isLittleEndian
        )

        guard !stripOffsets.isEmpty else {
            throw ParseError.missingRequiredTag(273)
        }

        // Concatenate all strips into raw pixel data
        var pixels = Data()
        pixels.reserveCapacity(
            Int(width) * Int(height) * Int(samplesPerPixel)
        )

        for i in 0..<stripOffsets.count {
            let offset = Int(stripOffsets[i])
            let count: Int
            if i < stripByteCounts.count {
                count = Int(stripByteCounts[i])
            } else {
                count = data.count - offset
            }

            guard offset >= 0, offset + count <= data.count else {
                throw ParseError.dataOutOfBounds
            }
            pixels.append(data[offset..<(offset + count)])
        }

        return RawImage(
            width: Int(width),
            height: Int(height),
            bytesPerPixel: Int(samplesPerPixel),
            pixels: pixels
        )
    }

    // MARK: - IFD Parsing

    private typealias IFDEntries = [UInt16: UInt32]

    private struct IFDEntry {
        let tag: UInt16
        let type: UInt16
        let count: UInt32
        let valueOffset: UInt32
    }

    private static func parseIFD(
        _ bytes: [UInt8],
        offset: Int,
        le: Bool
    ) throws -> IFDEntries {
        guard offset + 2 <= bytes.count else {
            throw ParseError.invalidHeader
        }

        let entryCount = readUInt16(bytes, offset: offset, le: le)
        var entries: IFDEntries = [:]

        for i in 0..<Int(entryCount) {
            let entryOffset = offset + 2 + i * 12
            guard entryOffset + 12 <= bytes.count else { break }

            let tag = readUInt16(bytes, offset: entryOffset, le: le)
            let type = readUInt16(
                bytes, offset: entryOffset + 2, le: le
            )
            let count = readUInt32(
                bytes, offset: entryOffset + 4, le: le
            )
            let value = readUInt32(
                bytes, offset: entryOffset + 8, le: le
            )

            // For single-value entries, store the value directly
            if count == 1 {
                let resolved: UInt32
                switch type {
                case 3: // SHORT
                    resolved = UInt32(
                        readUInt16(bytes, offset: entryOffset + 8, le: le)
                    )
                default:
                    resolved = value
                }
                entries[tag] = resolved
            } else {
                // Multi-value: store the offset to the values
                entries[tag] = value
            }
        }

        return entries
    }

    /// Read array values from a tag (for StripOffsets, StripByteCounts).
    private static func readTagArray(
        _ bytes: [UInt8],
        ifd: IFDEntries,
        tag: UInt16,
        le: Bool
    ) throws -> [UInt32] {
        guard let value = ifd[tag] else { return [] }

        // Re-parse IFD to get the full entry for this tag
        // We need count and type info
        let ifdOffset = readUInt32(bytes, offset: 4, le: le)
        let entryCount = readUInt16(
            bytes, offset: Int(ifdOffset), le: le
        )

        for i in 0..<Int(entryCount) {
            let entryOffset = Int(ifdOffset) + 2 + i * 12
            guard entryOffset + 12 <= bytes.count else { break }

            let entryTag = readUInt16(
                bytes, offset: entryOffset, le: le
            )
            guard entryTag == tag else { continue }

            let type = readUInt16(
                bytes, offset: entryOffset + 2, le: le
            )
            let count = readUInt32(
                bytes, offset: entryOffset + 4, le: le
            )

            if count == 1 {
                return [value]
            }

            // Values are at the offset stored in value
            let dataOffset = Int(
                readUInt32(bytes, offset: entryOffset + 8, le: le)
            )
            var result: [UInt32] = []
            result.reserveCapacity(Int(count))

            for j in 0..<Int(count) {
                let itemOffset: Int
                let itemValue: UInt32
                switch type {
                case 3: // SHORT (2 bytes)
                    itemOffset = dataOffset + j * 2
                    guard itemOffset + 2 <= bytes.count else { break }
                    itemValue = UInt32(
                        readUInt16(bytes, offset: itemOffset, le: le)
                    )
                default: // LONG (4 bytes)
                    itemOffset = dataOffset + j * 4
                    guard itemOffset + 4 <= bytes.count else { break }
                    itemValue = readUInt32(
                        bytes, offset: itemOffset, le: le
                    )
                }
                result.append(itemValue)
            }
            return result
        }

        return [value]
    }

    // MARK: - Binary Readers

    private static func readUInt16(
        _ bytes: [UInt8], offset: Int, le: Bool
    ) -> UInt16 {
        if le {
            return UInt16(bytes[offset])
                | (UInt16(bytes[offset + 1]) << 8)
        } else {
            return (UInt16(bytes[offset]) << 8)
                | UInt16(bytes[offset + 1])
        }
    }

    private static func readUInt32(
        _ bytes: [UInt8], offset: Int, le: Bool
    ) -> UInt32 {
        if le {
            return UInt32(bytes[offset])
                | (UInt32(bytes[offset + 1]) << 8)
                | (UInt32(bytes[offset + 2]) << 16)
                | (UInt32(bytes[offset + 3]) << 24)
        } else {
            return (UInt32(bytes[offset]) << 24)
                | (UInt32(bytes[offset + 1]) << 16)
                | (UInt32(bytes[offset + 2]) << 8)
                | UInt32(bytes[offset + 3])
        }
    }
}
