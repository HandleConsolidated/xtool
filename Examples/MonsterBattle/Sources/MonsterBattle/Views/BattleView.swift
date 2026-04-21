#if canImport(SwiftUI)
import SwiftUI
import MonsterBattleCore

/// Main battle UI. Renders the opponent and player combatants with HP
/// bars, a scrolling message log of formatted `BattleEvent`s, and a
/// context-sensitive action panel (root / fight / bag).
struct BattleView: View {
    @ObservedObject var controller: BattleController
    @EnvironmentObject var game: GameController

    @State private var mode: PanelMode = .root
    @State private var showingPartySheet: Bool = false

    enum PanelMode: Equatable {
        case root
        case fight
        case bag
    }

    var body: some View {
        ZStack {
            background
                .ignoresSafeArea()
            VStack(spacing: 12) {
                opponentHeader
                CreatureSprite(species: species(for: controller.state.opponent), size: 110)
                    .frame(maxWidth: .infinity, alignment: .center)

                messageLog

                CreatureSprite(species: species(for: controller.state.player), size: 110)
                    .frame(maxWidth: .infinity, alignment: .center)
                playerHeader

                actionPanel
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        // When the engine asks for a forced switch after a faint, pop the
        // party picker so the player can choose who comes in.
        .onChange(of: controller.state.awaitingPlayerSwitch) { awaiting in
            if awaiting {
                mode = .root
                showingPartySheet = true
            }
        }
        .sheet(isPresented: $showingPartySheet) {
            BattlePartySheet(
                controller: controller,
                forcedSwitch: controller.state.awaitingPlayerSwitch,
                onPick: { partyIndex in
                    showingPartySheet = false
                    controller.submit(playerAction: .switchMonster(partyIndex: partyIndex))
                },
                onCancel: {
                    // Only allow cancel for a non-forced switch.
                    if !controller.state.awaitingPlayerSwitch {
                        showingPartySheet = false
                    }
                }
            )
            .interactiveDismissDisabled(controller.state.awaitingPlayerSwitch)
        }
    }

    // MARK: - Header tiles

    private var opponentHeader: some View {
        combatantPlate(
            side: controller.state.opponent,
            label: modeLabel,
            showNumericHP: false
        )
    }

    private var playerHeader: some View {
        combatantPlate(
            side: controller.state.player,
            label: "YOU",
            showNumericHP: true
        )
    }

    private var modeLabel: String {
        switch controller.state.mode {
        case .wild: return "WILD"
        case .trainer(let name): return name.uppercased()
        }
    }

    private func combatantPlate(
        side: BattleSide,
        label: String,
        showNumericHP: Bool
    ) -> some View {
        let species = species(for: side)
        let monster = side.combatant.monster
        let maxHP = side.combatant.maxHP
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
            }
            HStack {
                Text(monster.displayName(using: species)).font(.headline)
                Text("Lv\(monster.level)").font(.subheadline).foregroundStyle(.secondary)
                StatusChip(status: monster.status)
                Spacer()
            }
            HStack(spacing: 4) {
                ForEach(species.types, id: \.self) { TypeBadge(element: $0, compact: true) }
            }
            HPBar(current: monster.currentHP, max: maxHP)
            if showNumericHP {
                HStack {
                    Spacer()
                    Text("\(max(monster.currentHP, 0)) / \(max(maxHP, 0))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: Theme.cardCorner).fill(Theme.panelBackground))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardCorner).stroke(Theme.panelStroke, lineWidth: 1)
        )
    }

    // MARK: - Message log

    private var messageLog: some View {
        let lines = recentMessages(limit: 6)
        return ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { idx, line in
                        Text(line)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(idx)
                    }
                }
                .padding(10)
            }
            .frame(height: 120)
            .background(RoundedRectangle(cornerRadius: Theme.cardCorner).fill(Theme.panelBackground))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardCorner).stroke(Theme.panelStroke, lineWidth: 1)
            )
            .onChange(of: controller.state.log.count) { _ in
                if !lines.isEmpty {
                    withAnimation {
                        proxy.scrollTo(lines.count - 1, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func recentMessages(limit: Int) -> [String] {
        let state = controller.state
        let formatted = state.log.map { BattleEventFormatter.format($0, state: state) }
        return Array(formatted.suffix(limit))
    }

    // MARK: - Action panel

    @ViewBuilder
    private var actionPanel: some View {
        if controller.state.outcome != .ongoing {
            Button {
                // BattleScreenHost handles routing; this is here for keypad.
            } label: {
                Text(outcomeTitle)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.15))
                    )
            }
            .disabled(true)
        } else {
            switch mode {
            case .root, .partySwitch:     rootActions
            case .fight:                  fightGrid
            case .bag:                    bagPanel
            }
        }
    }

    private var outcomeTitle: String {
        switch controller.state.outcome {
        case .ongoing:    return ""
        case .playerWon:  return "Victory!"
        case .playerLost: return "Defeated..."
        case .fled:       return "Got away safely"
        case .caught:     return "Monster caught!"
        }
    }

    private var rootActions: some View {
        let grid = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: grid, spacing: 10) {
            actionButton(title: "Fight",  icon: "flame") { mode = .fight }
            actionButton(title: "Bag",    icon: "bag")   { mode = .bag }
            actionButton(title: "Party",  icon: "person.3") { showingPartySheet = true }
            actionButton(title: "Run",    icon: "figure.run") {
                controller.submit(playerAction: .run)
            }
        }
    }

    private func actionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title).font(.headline)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
    }

    // MARK: - Fight

    private var fightGrid: some View {
        let slots = controller.state.player.combatant.monster.moves
        let grid = [GridItem(.flexible()), GridItem(.flexible())]
        return VStack(spacing: 8) {
            LazyVGrid(columns: grid, spacing: 10) {
                ForEach(Array(slots.enumerated()), id: \.offset) { index, slot in
                    moveButton(index: index, slot: slot)
                }
            }
            Button("Back") { mode = .root }
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func moveButton(index: Int, slot: MoveSlot) -> some View {
        if let move = MoveDex.byID[slot.moveID] {
            Button {
                controller.submit(playerAction: .fight(moveSlotIndex: index))
                mode = .root
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(move.name).font(.headline)
                        Spacer()
                        TypeBadge(element: move.element, compact: true)
                    }
                    HStack {
                        Text(move.category.rawValue.capitalized)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("PP \(slot.currentPP)/\(slot.maxPP)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(slot.currentPP == 0 ? .red : .secondary)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(move.element.color).opacity(0.25))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(move.element.color).opacity(0.75), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .disabled(slot.currentPP == 0)
            .opacity(slot.currentPP == 0 ? 0.5 : 1)
        } else {
            Text("—")
                .padding()
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Bag

    private var bagPanel: some View {
        let items = game.trainer.bag.listed()
            .filter { item in
                // In-battle, orbs and healing items are meaningful.
                item.item.category == .orb || item.item.category == .heal
            }
        return VStack(spacing: 8) {
            if items.isEmpty {
                Text("Your bag has nothing usable here.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(items, id: \.item.id) { entry in
                            Button {
                                submitItem(entry.item)
                            } label: {
                                itemRow(item: entry.item, quantity: entry.quantity)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.white)
                        }
                    }
                }
                .frame(maxHeight: 160)
            }
            Button("Back") { mode = .root }
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func itemRow(item: Item, quantity: Int) -> some View {
        HStack {
            Text(item.emoji)
            Text(item.name).font(.subheadline.weight(.medium))
            Spacer()
            Text("x\(quantity)").font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.1))
        )
    }

    private func submitItem(_ item: Item) {
        switch item.category {
        case .orb:
            controller.submit(playerAction: .useItem(itemID: item.id, targetPartyIndex: nil))
        case .heal:
            let target = controller.state.player.activeIndex
            controller.submit(playerAction: .useItem(itemID: item.id, targetPartyIndex: target))
        default:
            break
        }
        mode = .root
    }

    // MARK: - Helpers

    private func species(for side: BattleSide) -> CreatureSpecies {
        CreatureDex.species(side.combatant.monster.speciesID)
    }

    private var background: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.10, green: 0.10, blue: 0.18),
                Color(red: 0.18, green: 0.08, blue: 0.22)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Event formatter

/// Utility that turns a `BattleEvent` + live state into a human line.
/// Kept private to `BattleView`; other screens don't need to format logs.
enum BattleEventFormatter {
    static func format(_ event: BattleEvent, state: BattleState) -> String {
        switch event {
        case .turnStart(let number):
            return "— Turn \(number) —"
        case .message(let text):
            return text
        case .moveUsed(let attackerID, let move):
            return "\(name(for: attackerID, in: state)) used \(move)!"
        case .moveMissed(let attackerID):
            return "\(name(for: attackerID, in: state))'s attack missed!"
        case .damageDealt(let defenderID, let amount, let effectiveness, let critical):
            var line = "\(name(for: defenderID, in: state)) took \(amount) damage"
            if critical { line += " (Critical hit!)" }
            switch effectiveness {
            case .superEffective:    line += " — Super effective!"
            case .notVeryEffective:  line += " — Not very effective."
            case .noEffect:          line = "It had no effect on \(name(for: defenderID, in: state))."
            case .neutral:           break
            }
            return line
        case .healed(let monsterID, let amount):
            return "\(name(for: monsterID, in: state)) recovered \(amount) HP."
        case .statChanged(let monsterID, let stat, let delta):
            let dir = delta > 0 ? "rose" : "fell"
            let mag = abs(delta) >= 2 ? " sharply" : ""
            return "\(name(for: monsterID, in: state))'s \(stat.rawValue) \(dir)\(mag)!"
        case .statusApplied(let monsterID, let status):
            return "\(name(for: monsterID, in: state)) is now \(status.displayName)."
        case .statusCured(let monsterID, let status):
            return "\(name(for: monsterID, in: state)) is no longer \(status.displayName)."
        case .statusDamage(let monsterID, let status, let amount):
            return "\(name(for: monsterID, in: state)) took \(amount) from \(status.displayName)."
        case .skippedTurn(let monsterID, let reason):
            switch reason {
            case .paralyzed:               return "\(name(for: monsterID, in: state)) is paralyzed and can't move!"
            case .asleep:                  return "\(name(for: monsterID, in: state)) is fast asleep."
            case .frozen:                  return "\(name(for: monsterID, in: state)) is frozen solid!"
            }
        case .fainted(let monsterID):
            return "\(name(for: monsterID, in: state)) fainted!"
        case .caughtCreature(let speciesID):
            let name = CreatureDex.byID[speciesID]?.name ?? speciesID
            return "Gotcha! \(name) was caught!"
        case .captureFailed(let shakes):
            return "The orb shook \(shakes) time(s)... but broke free!"
        case .ran(let successful):
            return successful ? "Got away safely!" : "Couldn't escape!"
        case .experienceGained(let monsterID, let amount):
            return "\(name(for: monsterID, in: state)) gained \(amount) XP."
        case .leveledUp(let monsterID, let newLevel):
            return "\(name(for: monsterID, in: state)) grew to Lv\(newLevel)!"
        case .learnedMove(let monsterID, let moveID):
            let moveName = MoveDex.byID[moveID]?.name ?? moveID
            return "\(name(for: monsterID, in: state)) learned \(moveName)!"
        case .evolved(let fromSpeciesID, let toSpeciesID, _):
            let from = CreatureDex.byID[fromSpeciesID]?.name ?? fromSpeciesID
            let to = CreatureDex.byID[toSpeciesID]?.name ?? toSpeciesID
            return "\(from) evolved into \(to)!"
        case .battleEnded(let outcome):
            switch outcome {
            case .playerWon:  return "You won the battle!"
            case .playerLost: return "You have no monsters left..."
            case .fled:       return "You escaped."
            case .caught:     return "Caught!"
            case .ongoing:    return ""
            }
        }
    }

    private static func name(for id: UUID, in state: BattleState) -> String {
        if let match = state.player.party.first(where: { $0.id == id }) {
            return match.displayName(using: CreatureDex.species(match.speciesID))
        }
        if let match = state.opponent.party.first(where: { $0.id == id }) {
            let label = match.displayName(using: CreatureDex.species(match.speciesID))
            // Mark opposing creatures with "Foe" for clarity.
            if case .wild = state.mode { return "Wild \(label)" }
            return "Foe's \(label)"
        }
        return "Creature"
    }
}

/// Sheet presented when the player taps "Party" in battle, or when the
/// engine demands a forced switch after a faint. The forced variant
/// hides the "Cancel" button and blocks interactive dismissal.
private struct BattlePartySheet: View {
    @ObservedObject var controller: BattleController
    let forcedSwitch: Bool
    let onPick: (Int) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationView {
            List {
                ForEach(Array(controller.state.player.party.enumerated()), id: \.element.id) { index, monster in
                    let species = CreatureDex.species(monster.speciesID)
                    let isActive = index == controller.state.player.activeIndex
                    let isFainted = monster.isFainted
                    let disabled = isActive || isFainted
                    Button {
                        guard !disabled else { return }
                        onPick(index)
                    } label: {
                        row(monster: monster, species: species, isActive: isActive, isFainted: isFainted)
                    }
                    .buttonStyle(.plain)
                    .disabled(disabled)
                    .opacity(disabled ? 0.5 : 1.0)
                }
            }
            .navigationTitle(forcedSwitch ? "Pick next monster" : "Switch monster")
            .toolbar {
                if !forcedSwitch {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: onCancel)
                    }
                }
            }
        }
    }

    private func row(monster: MonsterInstance, species: CreatureSpecies, isActive: Bool, isFainted: Bool) -> some View {
        HStack(spacing: 12) {
            Text(species.emoji).font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(monster.displayName(using: species)).font(.headline)
                    Text("Lv\(monster.level)").font(.caption).foregroundStyle(.secondary)
                    StatusChip(status: monster.status)
                    if isActive { Text("In play").font(.caption2).foregroundStyle(.secondary) }
                    if isFainted { Text("Fainted").font(.caption2).foregroundStyle(.red) }
                }
                HPBar(current: monster.currentHP, max: monster.maxHP(using: species))
                    .frame(height: 8)
            }
        }
        .padding(.vertical, 6)
    }
}
#endif
