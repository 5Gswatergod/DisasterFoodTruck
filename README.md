# Disaster Food Truck Tycoon — Roblox Project Skeleton (v2)

## Use with or without Rojo
- **With Rojo**: `default.project.json` maps `src/*` to Studio services.
- **Without Rojo**: Server module `ServerScriptService/InitRemotes.lua` auto-creates all Remotes at runtime.

## Structure
- ReplicatedStorage
  - Shared/Configs (Recipes/Disasters/Items/Missions)
  - Remotes (empty in repo; created by server on startup)
- ServerScriptService
  - InitRemotes.lua (creates Remotes)
  - Systems (PlayerData / OrderSystem / CookSystem / DisasterController / Economy / Matchmaking / AntiExploit)
  - Bootstrap.server.lua (starts systems; spawns first order)
- StarterPlayer/StarterPlayerScripts (UI, Input, CameraFX placeholders)

## Quickstart
1) Optional: Install Rojo → `rojo serve` and connect from Studio.
2) Play: on server start, `InitRemotes` ensures required remotes exist.
3) Join: after ~5s, a first order is sent to the joining player.

## Notes
- Economy uses a one-time token flow (Preauth → Purchase) to mitigate replay.
- Replace placeholder TODOs with real map/disaster logic and UI.
