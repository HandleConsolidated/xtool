import Foundation

/// The trainer's inventory: a mapping from item id to quantity. Items not
/// present in the bag are implicitly quantity zero.
public struct Bag: Codable, Sendable {
    /// itemID -> quantity. Quantities are always positive; entries hit
    /// zero are removed on `remove`.
    public private(set) var contents: [String: Int]

    public init(contents: [String: Int] = [:]) {
        // Filter any caller-supplied zero/negative entries on the way in.
        self.contents = contents.filter { $0.value > 0 }
    }

    /// Quantity of `itemID` in the bag; zero if the item is not held.
    public func quantity(of itemID: String) -> Int {
        contents[itemID] ?? 0
    }

    /// Add `count` copies of `itemID` to the bag. Negative / zero counts
    /// are ignored.
    public mutating func add(_ itemID: String, count: Int = 1) {
        guard count > 0 else { return }
        contents[itemID, default: 0] += count
    }

    /// Remove `count` copies of `itemID`. Returns `true` iff the bag had
    /// at least that many; otherwise the bag is unchanged.
    @discardableResult
    public mutating func remove(_ itemID: String, count: Int = 1) -> Bool {
        guard count > 0 else { return true }
        let current = contents[itemID] ?? 0
        guard current >= count else { return false }
        let remaining = current - count
        if remaining == 0 {
            contents.removeValue(forKey: itemID)
        } else {
            contents[itemID] = remaining
        }
        return true
    }

    /// All held items and their quantities, sorted by category (using the
    /// natural order of `ItemCategory`) then by item id. Items whose id
    /// is not present in `ItemDex` are silently skipped — this keeps a
    /// forward-compatible save from crashing the UI.
    public func listed() -> [(item: Item, quantity: Int)] {
        contents
            .compactMap { (id, qty) -> (Item, Int)? in
                guard let item = ItemDex.byID[id] else { return nil }
                return (item, qty)
            }
            .sorted(by: Self.sortOrder)
            .map { (item: $0.0, quantity: $0.1) }
    }

    /// Same as `listed()` but restricted to a single category.
    public func listed(category: ItemCategory) -> [(item: Item, quantity: Int)] {
        listed().filter { $0.item.category == category }
    }

    // MARK: - Private

    /// Stable sort by (category-rank, id) so the UI can render a
    /// tabbed listing without re-sorting every frame.
    private static func sortOrder(_ lhs: (Item, Int), _ rhs: (Item, Int)) -> Bool {
        let lRank = categoryRank(lhs.0.category)
        let rRank = categoryRank(rhs.0.category)
        if lRank != rRank { return lRank < rRank }
        return lhs.0.id < rhs.0.id
    }

    private static func categoryRank(_ category: ItemCategory) -> Int {
        switch category {
        case .heal:    return 0
        case .orb:     return 1
        case .battle:  return 2
        case .keyItem: return 3
        }
    }
}
