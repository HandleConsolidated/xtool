import Foundation

/// An action a side can submit for the current turn.
///
/// The engine picks the opponent's action internally (via `BattleAI`), so
/// the public `BattleState.submit(playerAction:)` only takes one of these.
public enum BattleAction: Sendable {
    /// Use the move at `moveSlotIndex` of the active monster's move list.
    case fight(moveSlotIndex: Int)

    /// Use an item from the player's bag. `targetPartyIndex` picks which
    /// of the player's party the item is applied to; pass `nil` for
    /// capture orbs (which target the opponent) or items that don't need
    /// a specific target.
    case useItem(itemID: String, targetPartyIndex: Int?)

    /// Swap the active monster with the party member at `partyIndex`.
    case switchMonster(partyIndex: Int)

    /// Attempt to flee the battle. Only works against wild encounters.
    case run
}
