#if canImport(SwiftUI)
import SwiftUI
import MonsterBattleCore

/// Overworld scene: tile grid + header + on-screen D-pad.
///
/// The grid viewport is fixed at 9 columns x 7 rows and scrolls to centre
/// on the player. Tiles outside the map render as transparent space.
struct OverworldView: View {
    @EnvironmentObject var game: GameController

    private static let viewportWidth = 9
    private static let viewportHeight = 7

    var body: some View {
        VStack(spacing: 12) {
            header
            GeometryReader { geo in
                tileGrid(in: geo.size)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color.black.opacity(0.4))
            dpad
        }
        .padding(.bottom, 10)
    }

    // MARK: - Header

    private var mapName: String {
        MapData.byID[game.world.currentMapID]?.name ?? game.world.currentMapID
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(mapName).font(.headline)
                Text(game.trainer.name.isEmpty ? "Trainer" : game.trainer.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                game.present(scene: .party)
            } label: {
                Label("Party", systemImage: "person.3")
            }
            .buttonStyle(.bordered)

            Button {
                game.present(scene: .bag)
            } label: {
                Label("Bag", systemImage: "bag")
            }
            .buttonStyle(.bordered)

            Menu {
                Button("Save") { game.save() }
                Button("Return to Main Menu") {
                    game.present(scene: .mainMenu)
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.title2)
                    .padding(8)
                    .background(Circle().fill(Color.white.opacity(0.12)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }

    // MARK: - Tile grid

    private func tileGrid(in size: CGSize) -> some View {
        let cellSize = min(size.width / CGFloat(Self.viewportWidth),
                           size.height / CGFloat(Self.viewportHeight))
        let player = game.world.playerPosition

        // Top-left tile in world coords for centering on the player.
        let originX = player.x - Self.viewportWidth / 2
        let originY = player.y - Self.viewportHeight / 2
        let map = MapData.byID[game.world.currentMapID]
        let defeated = game.world.mapState[game.world.currentMapID]?.defeatedNPCs ?? []

        return VStack(spacing: 0) {
            ForEach(0..<Self.viewportHeight, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<Self.viewportWidth, id: \.self) { col in
                        let worldPos = GridPosition(x: originX + col, y: originY + row)
                        cell(
                            at: worldPos,
                            player: player,
                            map: map,
                            defeated: defeated,
                            size: cellSize
                        )
                    }
                }
            }
        }
        .frame(width: cellSize * CGFloat(Self.viewportWidth),
               height: cellSize * CGFloat(Self.viewportHeight))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func cell(
        at worldPos: GridPosition,
        player: GridPosition,
        map: GameMap?,
        defeated: Set<String>,
        size: CGFloat
    ) -> some View {
        let tile = map?.tile(at: worldPos)
        ZStack {
            if let tile {
                Rectangle().fill(Color(tile.color))
                Text(tile.emoji)
                    .font(.system(size: size * 0.7))
            } else {
                Rectangle().fill(Color.black)
            }

            if let map,
               let npc = map.npc(at: worldPos),
               !defeated.contains(npc.id) {
                Text(npc.emoji)
                    .font(.system(size: size * 0.7))
            }

            if worldPos == player {
                Text("\u{1F9D1}") // neutral "person"
                    .font(.system(size: size * 0.6))
                    .shadow(color: .black.opacity(0.6), radius: 2)
                // Show a facing indicator on the bottom-right of the cell.
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(game.world.playerFacing.arrow)
                            .font(.system(size: size * 0.3))
                    }
                }
                .padding(2)
            }
        }
        .frame(width: size, height: size)
    }

    // MARK: - D-Pad

    private var dpad: some View {
        VStack(spacing: 4) {
            dpadButton(direction: .north, glyph: "\u{2B06}")
            HStack(spacing: 4) {
                dpadButton(direction: .west, glyph: "\u{2B05}")
                dpadButton(direction: .south, glyph: "\u{2B07}")
                dpadButton(direction: .east, glyph: "\u{27A1}")
            }
        }
        .padding(.horizontal)
    }

    private func dpadButton(direction: Direction, glyph: String) -> some View {
        Button {
            game.tryMove(direction: direction)
        } label: {
            Text(glyph)
                .font(.system(size: 38))
                .frame(width: 72, height: 60)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.15))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
#endif
