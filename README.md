# Aldos Incremental

Roblox/Rojo project scaffold for a small incremental coin-collection loop.

## Hierarchy

```text
ServerStorage
└── CoinPart

Workspace
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

- `ServerStorage.CoinPart` is the coin template; it is cloned into `Workspace` and is never moved or destroyed directly.
- `CoinService` keeps up to 10 active coin clones randomly spawned inside `Workspace.ZonePart`.
- Touching a spawned coin awards one coin, destroys only that clone, and spawns a replacement after one second.
- Spawned coins receive `IsCoin = true` and `Collected = false` attributes so the client can animate only live coins.
- `leaderstats.Coins` is created for every player and updated after each collection.
- `LeaderstatsBoard` renders a styled in-world SurfaceGui for the top 100 players on the current server.
- Change the leaderboard background image in `src/ServerScriptService/LeaderboardService.lua` by editing `BOARD_BACKGROUND_IMAGE_ID`.
- `CoinCollectedEffect` notifies the collecting client so `CoinVisualClient` can show a floating UI message and a short world burst.
- Player coin totals are saved with `DataStoreService` outside Studio.
