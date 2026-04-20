# Monster Battle

A monster-catching & turn-based battle game for iOS, built with SwiftUI.
This is a sample app that ships inside the xtool repo and can be built with
`xtool` on Linux / macOS.

> ⚠️ Monster Battle is an original game. The creatures, moves, types, and
> stories are not Pokémon — they are inspired by classic monster-battle games
> but use original names and lore to avoid infringing on any trademark or
> copyright.

## Features

- **12+ original creatures**, each with its own base stats and elemental types.
- **6 elemental types** with a rock-paper-scissors style effectiveness chart.
- **Turn-based battles** with type effectiveness, STAB, critical hits, status
  conditions (poison, burn, paralyze, sleep), and multi-turn effects.
- **Capture mechanic** — throw Monster Orbs to catch wild creatures.
- **Overworld exploration** on a tiled grid with tall-grass encounters.
- **NPCs & trainer battles** with scripted dialogue.
- **Party, bag, and save/load** — the game persists to disk between sessions.
- **Cross-platform Core library** — the game logic builds on Linux so battle
  mechanics can be unit-tested without iOS.

## Architecture

```
Examples/MonsterBattle/
├── Package.swift                 – SPM manifest (Core + App targets)
├── xtool.yml                     – xtool build config
├── App/Info.plist                – iOS Info.plist overrides
├── Sources/
│   ├── MonsterBattleCore/        – Platform-agnostic game logic
│   │   ├── Models/               – Creature, Move, Element, Stats, …
│   │   ├── Battle/               – Battle engine, damage, AI, capture
│   │   ├── World/                – Tiles, maps, encounters, NPCs
│   │   ├── GameState/            – Trainer, party, bag, save manager
│   │   ├── Data/                 – Monster/Move/Item/Map databases
│   │   └── Utilities/            – RNG, helpers
│   └── MonsterBattle/            – iOS SwiftUI app shell
│       ├── App.swift             – @main entry point
│       └── Views/                – Main menu, overworld, battle, party, …
└── Tests/MonsterBattleCoreTests/ – XCTest / Swift Testing specs
```

## Building

### On a Mac with Xcode

```bash
cd Examples/MonsterBattle
xtool dev
```

### Using xtool from source

```bash
# From the repo root:
swift run xtool dev build --project Examples/MonsterBattle
```

### Verifying the Core library on Linux

The Core library is pure Swift with no UI dependencies, so you can syntax-check
the game logic and run the unit tests anywhere Swift runs:

```bash
cd Examples/MonsterBattle
swift build --target MonsterBattleCore
swift test --filter MonsterBattleCoreTests
```

## Controls

- **Overworld:** Tap a D-pad arrow to move one tile. Tap an NPC to talk.
- **Battle:** Choose Fight / Bag / Party / Run. In Fight, tap one of four
  moves. Use Monster Orbs from the Bag to capture wild creatures.
- **Menu:** Tap the ☰ icon to open Party / Bag / Save / Quit.

## Credits

Built as a technical demonstration for
[xtool](https://github.com/xtool-org/xtool). All creature art is generated
procedurally from emoji + SwiftUI shapes, so the app ships with zero bundled
image assets.
