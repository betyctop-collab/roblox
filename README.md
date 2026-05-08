# Roblox RNG Katana

An RNG roll game for Roblox built with [Rojo](https://rojo.space/). Players
auto-roll every 5 seconds (or click ROLL to skip the wait) for a chance at one
of 24 anime-themed katanas spread across 8 rarity tiers (Common 1/2 →
Celestial 1/1,000,000). Mythic-and-rarer drops trigger a server-wide
announcement.

## Layout

```
src/shared/        Theme, Constants, Rarities, Items, IconIds, RemoteEvents
src/server/        PlayerData (DataStore + leaderstats), RollService, init.server
src/client/        HUD (ScreenGui + modals), init.client
scripts/           generate_icons.py, upload_assets.luau, publish_place.luau
assets/icons/      placeholder PNGs (256×256, white-on-transparent)
```

## Tooling

Pinned via `aftman.toml`. Run `aftman install` once to fetch them into
`~/.aftman/bin`.

| Tool   | Version | Purpose                                  |
| ------ | ------- | ---------------------------------------- |
| rojo   | 7.4.4   | filesystem ↔ Roblox sync / build         |
| selene | 0.27.1  | Luau static analysis                     |
| stylua | 0.20.0  | Luau formatter                           |
| lune   | 0.8.9   | runs the asset / publish CLI scripts     |

## Common commands

```bash
# Generate placeholder PNG icons
pip install Pillow
python3 scripts/generate_icons.py

# Lint + format
selene src/
stylua --check src/

# Build a place file
rojo build -o build/game.rbxlx

# Upload icons via Open Cloud (patches src/shared/IconIds.luau)
ROBLOX_OPEN_CLOUD_API_KEY=... ROBLOX_USER_ID=... \
  lune run scripts/upload_assets.luau

# Publish to a place
ROBLOX_OPEN_CLOUD_API_KEY=... \
  ROBLOX_UNIVERSE_ID=... \
  ROBLOX_PLACE_ID=... \
  ROBLOX_PUBLISH_VERSION_TYPE=Published \
  lune run scripts/publish_place.luau
```

## Tunables

All design knobs live in [`src/shared/Constants.luau`](src/shared/Constants.luau)
and the rarity ladder is in [`src/shared/Rarities.luau`](src/shared/Rarities.luau).

| Setting                       | Default                  |
| ----------------------------- | ------------------------ |
| Auto-roll interval            | 5 seconds                |
| Manual roll cooldown          | 0.25 seconds             |
| Boost shop                    | x2/60s, x5/30s, x10/15s  |
| Server-wide announce floor    | Mythic (1/10,000)        |
| DataStore name                | `RngKatanaProfileV1`     |

## Notes

- The HUD applies its own `ImageColor3` tint, so the placeholder PNGs are
  white-on-transparent silhouettes that pick up the panel colour at runtime.
- DataStore APIs only run in published Studio sessions, so persistence won't
  work in plain "Play" mode.
- Branch base is `init` (a one-commit orphan branch — the repo was empty when
  the first PR was opened). Rename to `main` after merging if you want.
