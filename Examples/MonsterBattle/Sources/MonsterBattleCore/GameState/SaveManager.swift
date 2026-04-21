import Foundation

/// Something went wrong reading or writing a save file.
public enum SaveError: Error, Sendable, Equatable {
    case fileNotFound
    case decodeFailed(String)
    case encodeFailed(String)
    case ioFailed(String)
    case incompatibleVersion(Int)
}

/// Persists `SaveFile`s to JSON on disk. Actor-isolated so save/load
/// operations happen serially per manager instance and don't race with
/// each other from concurrent callers.
public actor SaveManager {
    /// Directory the manager reads from / writes to. Created on demand by
    /// `default()`; caller-supplied directories must already exist.
    public let directoryURL: URL

    public init(directoryURL: URL) {
        self.directoryURL = directoryURL
    }

    /// Manager rooted under the platform's Application Support directory
    /// (`~/Library/Application Support/MonsterBattle` on Apple platforms).
    /// Creates the directory if it's missing.
    public static func `default`() throws -> SaveManager {
        let base: URL
        do {
            base = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        } catch {
            throw SaveError.ioFailed("couldn't locate application support directory: \(error)")
        }
        let dir = base.appendingPathComponent("MonsterBattle", isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: dir,
                withIntermediateDirectories: true
            )
        } catch {
            throw SaveError.ioFailed("couldn't create save directory \(dir.path): \(error)")
        }
        return SaveManager(directoryURL: dir)
    }

    /// Write `file` to the slot's JSON blob atomically.
    public func save(_ file: SaveFile, slot: Int = 0) throws {
        let encoder = Self.makeEncoder()
        let data: Data
        do {
            data = try encoder.encode(file)
        } catch {
            throw SaveError.encodeFailed("\(error)")
        }
        let url = fileURL(for: slot)
        do {
            try data.write(to: url, options: [.atomic])
        } catch {
            throw SaveError.ioFailed("couldn't write \(url.path): \(error)")
        }
    }

    /// Read the slot's JSON blob back into a `SaveFile`. Throws
    /// `.fileNotFound` for a missing slot, `.decodeFailed` for a corrupt
    /// file, and `.incompatibleVersion` when the save was written by a
    /// newer schema than this binary knows about.
    public func load(slot: Int = 0) throws -> SaveFile {
        let url = fileURL(for: slot)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw SaveError.fileNotFound
        }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw SaveError.ioFailed("couldn't read \(url.path): \(error)")
        }
        let decoder = Self.makeDecoder()
        let file: SaveFile
        do {
            file = try decoder.decode(SaveFile.self, from: data)
        } catch {
            throw SaveError.decodeFailed("\(error)")
        }
        guard file.version <= SaveFile.currentVersion else {
            throw SaveError.incompatibleVersion(file.version)
        }
        return file
    }

    /// True iff a save file exists at the given slot.
    public func slotExists(slot: Int = 0) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(for: slot).path)
    }

    /// Delete the save at `slot`. A missing slot is treated as success
    /// (idempotent) so the caller doesn't need to pre-check.
    public func delete(slot: Int = 0) throws {
        let url = fileURL(for: slot)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            throw SaveError.ioFailed("couldn't delete \(url.path): \(error)")
        }
    }

    /// Enumerate every slot number currently present on disk, sorted.
    public func listSlots() -> [Int] {
        let entries: [URL]
        do {
            entries = try FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
        } catch {
            return []
        }
        var slots: [Int] = []
        for url in entries {
            let name = url.lastPathComponent
            guard name.hasPrefix("save_"), name.hasSuffix(".json") else { continue }
            let startIndex = name.index(name.startIndex, offsetBy: "save_".count)
            let endIndex = name.index(name.endIndex, offsetBy: -".json".count)
            let numberPart = String(name[startIndex..<endIndex])
            if let slot = Int(numberPart) {
                slots.append(slot)
            }
        }
        return slots.sorted()
    }

    // MARK: - Private

    private func fileURL(for slot: Int) -> URL {
        directoryURL.appendingPathComponent(Self.filename(for: slot), isDirectory: false)
    }

    /// `save_00.json`, `save_01.json`, ... Two-digit, zero-padded.
    static func filename(for slot: Int) -> String {
        String(format: "save_%02d.json", slot)
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
