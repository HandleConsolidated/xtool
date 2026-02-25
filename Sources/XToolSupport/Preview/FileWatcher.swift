import Foundation

/// Watches a directory tree for Swift source file changes
/// using a cross-platform polling strategy.
actor FileWatcher {
    private let directory: URL
    private let debounceSeconds: TimeInterval
    private var modTimes: [String: Date] = [:]
    private var watchTask: Task<Void, Never>?

    init(
        directory: URL,
        debounceSeconds: TimeInterval = 0.5
    ) {
        self.directory = directory
        self.debounceSeconds = debounceSeconds
    }

    /// Begin watching for changes. Calls `onChange` when Swift
    /// source files are created, modified, or deleted.
    func watch(
        onChange: @escaping @Sendable () async -> Void
    ) {
        modTimes = scanSwiftFiles()

        watchTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { break }

                let current = scanSwiftFiles()
                guard hasChanges(current: current) else {
                    continue
                }

                // Debounce: wait for rapid edits to settle
                try? await Task.sleep(
                    nanoseconds: UInt64(
                        debounceSeconds * 1_000_000_000
                    )
                )
                guard !Task.isCancelled else { break }

                // Re-scan after debounce to get final state
                modTimes = scanSwiftFiles()
                await onChange()
            }
        }
    }

    func stop() {
        watchTask?.cancel()
        watchTask = nil
    }

    // MARK: - File Scanning

    private nonisolated func scanSwiftFiles() -> [String: Date] {
        var result: [String: Date] = [:]
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: directory,
            includingPropertiesForKeys: [
                .contentModificationDateKey,
            ],
            options: [.skipsHiddenFiles]
        ) else { return result }

        for case let url as URL in enumerator {
            let path = url.path
            // Skip build artifacts and package caches
            if path.contains("/.build/") { continue }
            if path.contains("/Packages/") { continue }
            guard url.pathExtension == "swift" else { continue }

            if let mtime = try? url.resourceValues(
                forKeys: [.contentModificationDateKey]
            ).contentModificationDate {
                result[path] = mtime
            }
        }
        return result
    }

    private func hasChanges(
        current: [String: Date]
    ) -> Bool {
        if modTimes.count != current.count { return true }
        for (path, mtime) in current {
            guard let prev = modTimes[path],
                  prev >= mtime
            else {
                return true
            }
        }
        return false
    }
}
