// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MonsterBattle",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MonsterBattle", targets: ["MonsterBattle"]),
        .library(name: "MonsterBattleCore", targets: ["MonsterBattleCore"])
    ],
    targets: [
        .executableTarget(
            name: "MonsterBattle",
            dependencies: ["MonsterBattleCore"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .target(
            name: "MonsterBattleCore",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "MonsterBattleCoreTests",
            dependencies: ["MonsterBattleCore"]
        )
    ]
)
