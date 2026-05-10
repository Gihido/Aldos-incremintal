# Aldos Incremental

Roblox/Rojo project scaffold for a small incremental coin-collection loop.

## Hierarchy

```text
Workspace
├── CoinPart
├── ZonePart
└── LeaderstatsBoard

ServerScriptService
├── MainServer
├── DataService
├── CoinService
└── LeaderboardService

StarterPlayer
└── StarterPlayerScripts
    └── CoinVisualClient

ReplicatedStorage
└── Remotes
    └── CoinCollectedEffect
```

## Behavior

- Touching `CoinPart` awards one coin.
- `leaderstats.Coins` is created for every player and updated after each collection.
- `LeaderstatsBoard` renders the top five in-session coin totals.
- `CoinCollectedEffect` notifies the collecting client so `CoinVisualClient` can show a floating UI message and a short world burst.
- Player coin totals are saved with `DataStoreService` outside Studio.
