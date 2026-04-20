#if canImport(SwiftUI)
import SwiftUI
import MonsterBattleCore

@main
struct MonsterBattleApp: App {
    @StateObject private var game = GameController()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(game)
                .preferredColorScheme(.dark)
        }
    }
}
#endif
