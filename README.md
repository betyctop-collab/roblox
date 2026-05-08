# Roblox Game

Wave-based combat experience built around the Figma-designed HUD (health, energy,
level, currency, inventory, settings). Players fight off waves of mobs, earn coins,
gems and XP, level up, and persist progress through DataStore.

## Project Layout

```
.
├── aftman.toml              # Toolchain pin (rojo, selene, stylua, lune)
├── default.project.json     # Rojo project definition
├── selene.toml              # Selene linter config
├── stylua.toml              # StyLua formatter config
├── src/
│   ├── client/              # LocalScripts (StarterPlayerScripts.Client)
│   ├── server/              # Server Script + modules (ServerScriptService.Server)
│   └── shared/              # ModuleScripts (ReplicatedStorage.Shared)
├── assets/
│   └── icons/               # Source PNG icons (uploaded as Decals)
├── scripts/                 # Lune scripts (asset upload, place publish)
└── build/                   # Output of `rojo build` (gitignored)
```

## Local development

Install [Aftman](https://github.com/LPGhatguy/aftman), then run:

```bash
aftman install
rojo build -o build/game.rbxlx
```

Open `build/game.rbxlx` in Roblox Studio, or use `rojo serve` and the Rojo Studio
plugin to live-sync changes.

## Linting / formatting

```bash
selene src/
stylua --check src/
```

## Tooling

| Tool   | Purpose                                                      |
| ------ | ------------------------------------------------------------ |
| Rojo   | Sync filesystem ⇄ Roblox Studio + build `.rbxlx`             |
| Selene | Lua linter (Roblox std)                                      |
| StyLua | Lua formatter                                                |
| Lune   | Standalone Luau runtime (used by the asset / publish scripts) |

## Open Cloud scripts

Both scripts read `ROBLOX_OPEN_CLOUD_API_KEY` from the environment.

* `lune run scripts/upload_assets.luau` — uploads every PNG in `assets/icons/`
  as a Decal, prints back the Asset IDs and patches `src/shared/IconIds.luau`.
* `lune run scripts/publish_place.luau` — uploads `build/game.rbxlx` to the
  configured `UNIVERSE_ID` / `PLACE_ID` as a saved version.

## Game design (default)

* Genre: wave-based PvE with light combat
* Multiplayer: shared server, every player fights the same wave
* Loop: kill mobs → gain XP / coins / gems → level up → bigger waves
* Currency: `Coins` (common reward), `Gems` (rare reward / boss drops)
* Persisted: `Level`, `XP`, `Coins`, `Gems`, owned inventory items
