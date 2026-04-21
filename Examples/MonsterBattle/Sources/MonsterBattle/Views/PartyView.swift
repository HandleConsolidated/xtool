#if canImport(SwiftUI)
import SwiftUI
import MonsterBattleCore

/// Lists the trainer's active party with quick-glance HP and status, and
/// lets the player drill into a single monster for full stats / moves.
///
/// Also exposes a dev-only "Heal All" button since there's no recovery
/// facility in the demo content.
struct PartyView: View {
    @EnvironmentObject var game: GameController

    @State private var selectedMonsterID: UUID?

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                List {
                    ForEach(Array(game.trainer.party.monsters.enumerated()), id: \.element.id) { _, monster in
                        Button {
                            selectedMonsterID = monster.id
                        } label: {
                            row(for: monster)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)

                HStack {
                    Button {
                        healAll()
                    } label: {
                        Label("Heal All (Dev)", systemImage: "cross.case")
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("Done") {
                        game.present(scene: .overworld)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
            }
            .navigationTitle("Party")
            .sheet(item: Binding(
                get: { selectedMonsterID.flatMap { id in
                    game.trainer.party.monsters.first(where: { $0.id == id }).map(IDBox.init)
                } },
                set: { box in selectedMonsterID = box?.monster.id }
            )) { box in
                MonsterDetailView(monster: box.monster)
            }
        }
    }

    private func row(for monster: MonsterInstance) -> some View {
        let species = CreatureDex.species(monster.speciesID)
        return HStack(spacing: 12) {
            CreatureSprite(species: species, size: 48)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(monster.displayName(using: species)).font(.headline)
                    Text("Lv\(monster.level)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    StatusChip(status: monster.status)
                }
                HPBar(current: monster.currentHP, max: monster.maxHP(using: species))
                    .frame(height: 8)
                Text("\(max(monster.currentHP, 0)) / \(monster.maxHP(using: species)) HP")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }

    /// Heal everyone. Mutates the `Party` value type via the `trainer`
    /// setter so SwiftUI picks up the change.
    private func healAll() {
        var trainer = game.trainer
        trainer.healAllMonsters()
        game.trainer = trainer
    }

    /// Tiny wrapper so `.sheet(item:)` can bind to a monster value.
    private struct IDBox: Identifiable {
        let monster: MonsterInstance
        var id: UUID { monster.id }
    }
}

/// Full-detail view for a single party member: stats, moves, status.
private struct MonsterDetailView: View {
    let monster: MonsterInstance

    var body: some View {
        let species = CreatureDex.species(monster.speciesID)
        let stats = monster.stats(using: species)
        let maxHP = monster.maxHP(using: species)

        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 6) {
                        CreatureSprite(species: species, size: 100)
                        Text(monster.displayName(using: species)).font(.title2.weight(.bold))
                        Text("Lv\(monster.level) • \(species.name) #\(species.dexNumber)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            ForEach(species.types, id: \.self) { TypeBadge(element: $0) }
                        }
                        StatusChip(status: monster.status)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("HP").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        HPBar(current: monster.currentHP, max: maxHP)
                            .frame(height: 12)
                        Text("\(max(monster.currentHP, 0)) / \(maxHP)")
                            .font(.caption.monospacedDigit())
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: Theme.cardCorner)
                            .fill(Color.white.opacity(0.08))
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Stats").font(.headline)
                        statLine("Attack", stats.attack)
                        statLine("Defense", stats.defense)
                        statLine("Sp. Atk", stats.specialAttack)
                        statLine("Sp. Def", stats.specialDefense)
                        statLine("Speed",   stats.speed)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: Theme.cardCorner)
                            .fill(Color.white.opacity(0.08))
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Moves").font(.headline)
                        ForEach(Array(monster.moves.enumerated()), id: \.offset) { _, slot in
                            moveRow(slot: slot)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: Theme.cardCorner)
                            .fill(Color.white.opacity(0.08))
                    )
                }
                .padding()
            }
            .navigationTitle("Inspect")
        }
    }

    private func statLine(_ label: String, _ value: Int) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text("\(value)").font(.body.monospacedDigit().weight(.semibold))
        }
    }

    @ViewBuilder
    private func moveRow(slot: MoveSlot) -> some View {
        if let move = MoveDex.byID[slot.moveID] {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(move.name).font(.subheadline.weight(.semibold))
                        TypeBadge(element: move.element, compact: true)
                    }
                    Text(move.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Text("PP \(slot.currentPP)/\(slot.maxPP)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
        } else {
            Text("Unknown move: \(slot.moveID)")
                .font(.caption)
                .foregroundStyle(.red.opacity(0.8))
        }
    }
}
#endif
