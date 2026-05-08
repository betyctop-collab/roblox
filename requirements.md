# Requirements

Source design: `Untitled.make` (Figma Make → React/Tailwind), translated 1-to-1
into Roblox `ScreenGui` instances built in Luau.

## HUD layout (always visible)

### Top-left column (`AnchorPoint = 0,0`, padding 16px)

1. **Health panel** — black/60 backdrop, white border 2px, rounded 12px corners
   * Red `Heart` icon in a red rounded square
   * Label `HEALTH` (bold, white)
   * Value `<current>/100` right-aligned
   * Red progress bar
2. **Energy panel** — same shape, yellow icon (`Zap`), yellow bar, `ENERGY <v>/100`
3. **Level panel** — same shape, purple `Award` icon, label `LEVEL <n>` and `XP%`

### Top-right column (`AnchorPoint = 1,0`, padding 16px)

1. **Coins panel** — black/60, yellow `Coins` icon left, `Coins` label and big value right
2. **Gems panel** — same shape, cyan `Star` icon, `Gems` label

### Right side, vertically centred (`AnchorPoint = 1,0.5`, padding 16px)

Stack of four square buttons (border 4px, hover scale 1.1):

| # | Color  | Icon       | Action               |
| - | ------ | ---------- | -------------------- |
| 1 | orange | `Backpack` | Toggle Inventory     |
| 2 | green  | `Map`      | (placeholder)        |
| 3 | purple | `Users`    | (placeholder)        |
| 4 | gray   | `Settings` | Toggle Settings      |

### Bottom-centre (`AnchorPoint = 0.5,1`, padding 32px)

* `ATTACK` button — red gradient, `Swords` icon, hover scale 1.05
* `DEFEND` button — blue gradient, `Shield` icon, hover scale 1.05

### Centre overlay

Faint, 60px white text "GAME WORLD" at 20% opacity (decorative).

## Modals

### Inventory modal

* 600px wide gray-800/900 gradient panel, 4px gray-700 border, rounded 16px
* Header: orange `Backpack` icon, `INVENTORY` 30px bold, red close button (X)
* 3-column grid of items
* Each cell: icon (5xl), name, rarity color border + tinted background, quantity badge
* Default items:
  | id | name           | icon  | qty | rarity     |
  | -- | -------------- | ----- | --- | ---------- |
  | 1  | Health Potion  | 🧪    | 5   | common     |
  | 2  | Diamond Sword  | ⚔️    | 1   | legendary  |
  | 3  | Shield         | 🛡️   | 2   | rare       |
  | 4  | Speed Boost    | ⚡    | 3   | epic       |
  | 5  | Armor          | 🥋    | 1   | epic       |
  | 6  | Magic Staff    | 🪄    | 1   | legendary  |
* Rarity colors: common=gray-400, rare=blue-400, epic=purple-400, legendary=yellow-400

### Settings modal

* 500px wide same gradient/style
* Header: gray `Settings` icon, `SETTINGS` 30px bold, red X close
* Three rows in gray-700/50 cards:
  * "Sound Effects" + progress bar (80)
  * "Music Volume" + progress bar (60)
  * "Graphics Quality" + three buttons (High/Medium/Low; first one green)

## Background

Sky-blue → emerald gradient (top → bottom), faint white grid overlay (60×60 cells, 0.5px
strokes, 10% opacity).

## Server systems

### Player data

Persist per-`UserId` in a DataStore named `PlayerProfileV1`:

```luau
{
    Level = number,
    XP = number,
    Coins = number,
    Gems = number,
    Inventory = { [itemId] = quantity },
}
```

Mirrored to `Player.leaderstats.{Coins, Gems, Level}` so they show up in the
default Roblox player list.

### RemoteEvents

In `ReplicatedStorage.Shared.RemoteEvents`:

* `StateChanged` (server → client) — pushes the full player profile after every
  update so the HUD can refresh.
* `Action` (client → server) — `(actionName: string, ...)` for `Attack`,
  `Defend`, `OpenInventory` (server-side analytics only).

### Wave-based combat

* Single server instance, all online players fight the same wave.
* `Wave 1` spawns 3 mobs near origin; each subsequent wave grows by 2.
* Mobs are simple `Part` cubes with humanoid health (no animation work).
* Hit detection: `ATTACK` button → server raycast in front of the player, mob
  takes damage.
* `DEFEND` → +50 % damage reduction for 1 s.
* Killing a mob awards 25 XP, 10 Coins, 1 Gem (5 % chance).
* Level-up at `XP >= 100 * Level`.

## Out of scope (for now)

* Real attack animations (placeholder mobs and damage numbers)
* Tower defence, boss fights, parties — possible follow-up
* Microtransactions / DevProducts
* Mobile-specific layout
