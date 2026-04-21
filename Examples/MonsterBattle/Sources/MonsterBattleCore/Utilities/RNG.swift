import Foundation

/// Deterministic pseudo-random number generator based on the xorshift64*
/// algorithm. Seed with any non-zero UInt64 to reproduce a sequence.
///
/// This is `Sendable` because it is a value type holding only a single
/// `UInt64`. Mutation happens through the `inout` `next()` method as
/// required by `RandomNumberGenerator`.
public struct SeededRandomNumberGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    /// Create a generator seeded with the given value. The seed is
    /// coerced away from zero (xorshift collapses to 0 on zero state).
    public init(seed: UInt64) {
        self.state = seed == 0 ? 0xDEAD_BEEF_CAFE_F00D : seed
    }

    public mutating func next() -> UInt64 {
        // xorshift64*
        var x = state
        x ^= x >> 12
        x ^= x << 25
        x ^= x >> 27
        state = x
        return x &* 0x2545_F491_4F6C_DD1D
    }
}

/// Generate a non-negative `Int` in `0..<bound` from an existential RNG,
/// avoiding the need to pass `any RandomNumberGenerator` as `inout` into
/// generic stdlib functions (which historically does not implicitly open
/// existentials for `inout` parameters).
public func randomInt(below bound: Int, using rng: inout any RandomNumberGenerator) -> Int {
    precondition(bound > 0, "bound must be positive")
    let raw = rng.next()
    return Int(raw % UInt64(bound))
}

/// Generate an `Int` in the closed range `a...b` from an existential RNG.
public func randomInt(in range: ClosedRange<Int>, using rng: inout any RandomNumberGenerator) -> Int {
    let width = range.upperBound - range.lowerBound + 1
    return range.lowerBound + randomInt(below: width, using: &rng)
}

/// Generate an `Int` in the half-open range `a..<b` from an existential RNG.
public func randomInt(in range: Range<Int>, using rng: inout any RandomNumberGenerator) -> Int {
    let width = range.upperBound - range.lowerBound
    return range.lowerBound + randomInt(below: width, using: &rng)
}

/// Pick one element at random, weighted by an associated integer weight.
/// Returns nil for an empty list. Non-positive weights are skipped.
public func weightedRandom<T>(
    _ items: [(T, Int)],
    using rng: inout any RandomNumberGenerator
) -> T? {
    let total = items.reduce(0) { $0 + max(0, $1.1) }
    guard total > 0 else { return nil }
    let pick = randomInt(below: total, using: &rng)
    var running = 0
    for (item, weight) in items where weight > 0 {
        running += weight
        if pick < running { return item }
    }
    return items.last?.0
}

extension Array {
    /// Convenience wrapper that accepts an existential `any RandomNumberGenerator`.
    /// Named distinctly (`usingAny:`) to avoid overlapping the stdlib's generic
    /// `randomElement(using:)`.
    public func randomElement(usingAny rng: inout any RandomNumberGenerator) -> Element? {
        guard !isEmpty else { return nil }
        let index = randomInt(below: count, using: &rng)
        return self[index]
    }
}
