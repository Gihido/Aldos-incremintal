# Aldos Incremental

Roblox/Rojo project scaffold for an incremental coin-collection loop with upgrades, persistence, compact client effects, and in-world boards.

## Hierarchy

```text
ServerStorage
└── CoinPart

Workspace
├── ZonePart
├── LeaderstatsBoard
└── UpgCoin

ServerScriptService
├── MainServer
├── DataService
├── CoinService
├── UpgradeService
└── LeaderboardService

StarterPlayer
└── StarterPlayerScripts
    └── ClientEffects

ReplicatedStorage
├── Remotes
│   ├── CoinCollectedEffect
│   ├── BuyUpgrade
│   ├── UpgradeResult
│   └── SyncPlayerData
└── Shared
    └── FormatNumber
```

## Behavior

- `ServerStorage.CoinPart` is the coin template; `CoinService` clones it into `Workspace` and never moves or destroys the template directly.
- Coins spawn randomly inside `Workspace.ZonePart`, respawn one second after collection, and use `IsCoin` / `Collected` attributes.
- Server-side upgrades control coin rewards and the shared server coin spawn limit:
  - `Coin Gain`: +1 coin per pickup per level, first price 2, x2 scaling, 15 max levels.
  - `Multi Coins`: +0.1 multiplier per level, first price 5, x1.5 scaling, 20 max levels.
  - `Max Spawn Coins`: +1 shared max spawned coin per level, first price 2.5, x1.5 scaling, 15 max levels.
- The client sends only upgrade purchase requests; the server validates price, max level, mode, affordability, and buy-max totals.
- `DataService` saves Coins, position, and upgrade levels, then autosaves about every 60 seconds.
- `ClientEffects` animates coins, shows compact pickup popups, builds the `UpgCoin` upgrade board, and shows right-side purchase notifications.
- `LeaderboardService` renders a styled top-100 current-server leaderboard and uses shared number formatting.

## Asset IDs to replace

- Pickup popup icon: `COIN_POPUP_ICON_ID` in `src/StarterPlayer/StarterPlayerScripts/ClientEffects.client.lua`.
- Pickup popup background image: `COIN_POPUP_BACKGROUND_IMAGE_ID` in `src/StarterPlayer/StarterPlayerScripts/ClientEffects.client.lua` (leave `rbxassetid://0` for the default grey frame).
- Upgrade icons: `UPGRADE_ICONS` in `src/StarterPlayer/StarterPlayerScripts/ClientEffects.client.lua`.
- Notification icons/colors: `NOTIFICATION_CONFIG` in `src/StarterPlayer/StarterPlayerScripts/ClientEffects.client.lua`.
- Leaderboard background image: `BOARD_BACKGROUND_IMAGE_ID` in `src/ServerScriptService/LeaderboardService.module.lua`.

## Workspace notes

The upgrade board part must be named exactly `UpgCoin` in `Workspace`. The client also checks `UPGCoin` and `UpgradeCoin` as fallbacks, but the intended name is `UpgCoin`.

## Studio DataStore note

For DataStore testing in Studio, enable **Game Settings → Security → Enable Studio Access to API Services**.
