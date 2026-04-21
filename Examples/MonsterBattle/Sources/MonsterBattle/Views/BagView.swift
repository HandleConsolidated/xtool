#if canImport(SwiftUI)
import SwiftUI
import MonsterBattleCore

/// Tabbed inventory viewer. Outside battle, healing items target a party
/// member (via a picker sheet) and orbs / battle items show an inline
/// "can't use here" toast. Key items are read-only for now.
struct BagView: View {
    @EnvironmentObject var game: GameController

    @State private var selectedCategory: ItemCategory = .heal
    @State private var inlineToast: String?
    @State private var applyingItem: Item?

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                tabBar
                Divider().opacity(0.3)
                itemList
                if let toast = inlineToast {
                    Text(toast)
                        .font(.footnote)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.red.opacity(0.25))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.red.opacity(0.6), lineWidth: 1)
                        )
                        .transition(.opacity)
                }
                HStack {
                    Text("Money: $\(game.trainer.money)")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Done") {
                        game.present(scene: .overworld)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
            }
            .navigationTitle("Bag")
            .sheet(item: $applyingItem) { item in
                PartyPickerSheet(item: item) { chosenIndex in
                    applyHeal(item: item, toPartyIndex: chosenIndex)
                    applyingItem = nil
                } cancel: {
                    applyingItem = nil
                }
            }
        }
    }

    // MARK: - Tabs

    private var tabBar: some View {
        let tabs: [(ItemCategory, String, String)] = [
            (.heal,    "Heal",   "cross.case.fill"),
            (.orb,     "Orb",    "circle.fill"),
            (.battle,  "Battle", "bolt.fill"),
            (.keyItem, "Key",    "key.fill")
        ]
        return HStack(spacing: 0) {
            ForEach(tabs, id: \.0) { cat, title, icon in
                Button {
                    withAnimation { selectedCategory = cat }
                    inlineToast = nil
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: icon)
                        Text(title).font(.caption.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        Rectangle()
                            .fill(selectedCategory == cat
                                  ? Color.white.opacity(0.15)
                                  : Color.clear)
                    )
                }
                .buttonStyle(.plain)
                .foregroundStyle(selectedCategory == cat ? .white : .secondary)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Item list

    private var itemList: some View {
        let entries = game.trainer.bag.listed(category: selectedCategory)
        return Group {
            if entries.isEmpty {
                VStack {
                    Spacer()
                    Text("No items in this pocket.")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(entries, id: \.item.id) { entry in
                        Button {
                            handleTap(item: entry.item)
                        } label: {
                            row(item: entry.item, quantity: entry.quantity)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func row(item: Item, quantity: Int) -> some View {
        HStack(spacing: 12) {
            Text(item.emoji).font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.headline)
                Text(item.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Text("x\(quantity)")
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Use item

    private func handleTap(item: Item) {
        inlineToast = nil
        switch item.category {
        case .heal:
            applyingItem = item
        case .orb, .battle:
            flashToast("Can't use here.")
        case .keyItem:
            flashToast(item.description)
        }
    }

    private func flashToast(_ text: String) {
        withAnimation { inlineToast = text }
        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            await MainActor.run {
                withAnimation { inlineToast = nil }
            }
        }
    }

    /// Apply a healing item outside battle. We perform the effect locally
    /// since Core's `ItemResolution` is wired to `BattleState`.
    private func applyHeal(item: Item, toPartyIndex index: Int) {
        var trainer = game.trainer
        guard trainer.party.monsters.indices.contains(index) else { return }
        var monster = trainer.party.monsters[index]
        let species = CreatureDex.species(monster.speciesID)
        let maxHP = monster.maxHP(using: species)

        var consumed = true
        switch item.effect {
        case .heal(let amount):
            guard !monster.isFainted else {
                flashToast("Can't use on a fainted monster.")
                return
            }
            if monster.currentHP >= maxHP {
                flashToast("Already at full HP.")
                return
            }
            monster.currentHP = min(maxHP, monster.currentHP + amount)
        case .healFull:
            if monster.currentHP >= maxHP && monster.status == .none {
                flashToast("Nothing to restore.")
                return
            }
            monster.currentHP = maxHP
            monster.status = .none
        case .curStatus(let target):
            if let target, monster.status != target {
                flashToast("That won't work on \(monster.status.displayName).")
                return
            }
            if monster.status == .none {
                flashToast("No status to cure.")
                return
            }
            monster.status = .none
        case .revive(let fraction):
            guard monster.isFainted else {
                flashToast("That's only for fainted monsters.")
                return
            }
            monster.currentHP = max(1, Int(Double(maxHP) * fraction))
        case .captureBall:
            // Orbs are handled in battle; treated as consumed = false here.
            consumed = false
        }

        trainer.party.replace(at: index, with: monster)
        if consumed {
            _ = trainer.bag.remove(item.id, count: 1)
        }
        game.trainer = trainer
    }
}

/// Small sheet listing party members; the user taps one to apply a
/// consumable item to it.
private struct PartyPickerSheet: View {
    let item: Item
    var onSelect: (Int) -> Void
    var cancel: () -> Void

    @EnvironmentObject var game: GameController

    var body: some View {
        NavigationView {
            List {
                ForEach(Array(game.trainer.party.monsters.enumerated()), id: \.element.id) { index, monster in
                    Button {
                        onSelect(index)
                    } label: {
                        row(monster: monster)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Use \(item.name) on...")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: cancel)
                }
            }
        }
    }

    private func row(monster: MonsterInstance) -> some View {
        let species = CreatureDex.species(monster.speciesID)
        return HStack(spacing: 12) {
            Text(species.emoji).font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(monster.displayName(using: species)).font(.headline)
                    Text("Lv\(monster.level)").font(.caption).foregroundStyle(.secondary)
                    StatusChip(status: monster.status)
                }
                HPBar(current: monster.currentHP, max: monster.maxHP(using: species))
                    .frame(height: 8)
            }
        }
        .padding(.vertical, 6)
    }
}
#endif
