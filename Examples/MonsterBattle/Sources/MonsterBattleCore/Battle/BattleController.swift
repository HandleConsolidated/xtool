import Foundation
#if canImport(Combine)
import Combine
#endif

#if canImport(Combine)

/// Observable reference wrapper around the value-type `BattleState`.
/// Intended for SwiftUI use: views bind to `state` and `pendingEvents`
/// to drive animation, while the underlying engine remains a pure value
/// type so tests stay deterministic.
@MainActor
public final class BattleController: ObservableObject {

    /// The live battle state. Mutated via `submit(playerAction:)`.
    @Published public private(set) var state: BattleState

    /// Events produced since the UI last called `consumeEvents()`. The UI
    /// should drain this queue to animate each event in order, then call
    /// `consumeEvents()` to clear it.
    @Published public private(set) var pendingEvents: [BattleEvent] = []

    public init(state: BattleState) {
        self.state = state
    }

    /// Submit the player's action. The opponent's action is chosen by
    /// `BattleAI` inside `BattleState.submit` to keep the engine pure.
    public func submit(playerAction: BattleAction) {
        let newEvents = state.submit(playerAction: playerAction)
        pendingEvents.append(contentsOf: newEvents)
    }

    /// Drain the pending event queue. Returns the events the UI has not
    /// yet processed and clears the buffer.
    @discardableResult
    public func consumeEvents() -> [BattleEvent] {
        let events = pendingEvents
        pendingEvents.removeAll(keepingCapacity: true)
        return events
    }
}

#else

/// Plain reference wrapper for platforms without Combine (pure Linux).
/// SwiftUI isn't available there so we don't need ObservableObject.
@MainActor
public final class BattleController {
    public private(set) var state: BattleState
    public private(set) var pendingEvents: [BattleEvent] = []

    public init(state: BattleState) {
        self.state = state
    }

    public func submit(playerAction: BattleAction) {
        let newEvents = state.submit(playerAction: playerAction)
        pendingEvents.append(contentsOf: newEvents)
    }

    @discardableResult
    public func consumeEvents() -> [BattleEvent] {
        let events = pendingEvents
        pendingEvents.removeAll(keepingCapacity: true)
        return events
    }
}

#endif
