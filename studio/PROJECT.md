# PROJECT — Hundred Gates

> Slow-changing. Every agent reads this before every task.
> Only Lucas (or the Planner, with Lucas's OK) edits it.

## One-line pitch
A top-down 2D action RPG where you climb a 100-floor tower: every floor is a dungeon
ending in a boss, and the final floor holds a boss built to be nearly impossible —
climbed solo or, eventually, with a guild.

## The full vision (north star — NOT the current scope)
- 100 floors, each a dungeon + boss; floor 100 boss is the hardest thing in the game
- Online: guilds raid floors together, or players climb solo
- Gear progression, crafting/upgrading
- Online player market + NPC vendors
- A town hub between floors

Everything below is about getting there in phases where **each phase is a finished,
playable game on its own**. See D-002.

## Pillars (max 3)
1. **The tower is the progression** — Each floor cleared is a visible, earned step.
   Boss = gate. Players should always know which floor they're on and want the next.
2. **Skill beats stats in a fight** — Combat is real-time and readable: telegraphed
   attacks, dodging, positioning. A skilled player with weaker gear can win.
   Bosses are pattern fights, not damage sponges.
3. **Gear makes you stronger; you make you survive** — Loot and upgrades matter and
   feel good, but never replace pillar 2.

## Anti-goals (for phases 1–2)
- No online, no accounts, no servers.
- No guilds, no player market, no PvP.
- No open world — the tower and the town hub only.
- No original IP from Sword Art Online (names like Aincrad, characters, UI copies).
  Inspired by the concept, not a copy of it.

## Roadmap (phases)
| Phase | Name | Contains | Done when |
|---|---|---|---|
| 1 | **Vertical slice** | Floors 1–3, solo, offline. Town hub (minimal), 1 weapon type, dodge, 3 enemy types, 3 bosses, basic loot | A stranger plays floor 1–3 and wants floor 4 |
| 2 | **Tower v0.1** | Floors 1–10, gear system + upgrades, NPC shop, save/load, 2–3 weapon types | 10 floors complete, beatable, saved progress |
| 3 | **Co-op** | Party of up to 4 online (host-based or relay), shared dungeon runs. No persistent world | 4 friends clear a floor together without desync |
| 4 | **Online world** | Accounts, backend server, persistent characters, guilds, player market | Guild can form, raid, trade |
| 5 | **The 100** | Floors 11–100, floor 100 super-boss, endgame | — |

Current phase: **1**.

## Scope target (phase 1)
- **Platform:** PC (Windows, macOS)
- **Camera:** top-down
- **Target resolution / pixel scale:** <TBD with engine choice>

## Tech stack
| Thing | Choice | Decision |
|---|---|---|
| Engine | Godot 4.7.2-stable | D-001 |
| Language | GDScript, static typing everywhere | D-001 |
| Tests | GUT (Godot Unit Test), run headless | F-000 |
| Lint/format | gdtoolkit (`gdlint`, `gdformat`) | F-000 |
| Version control | Git + GitHub (`KSKluc4/Hundred-Gates`) | — |
| Backend (phase 4) | <TBD — later> | — |
| Art pipeline | <Aseprite / Krita / …> | |
| Audio | | |

## Global constraints (apply to every feature)
| ID | Constraint | Reason |
|---|---|---|
| G1 | Game logic must be frame-rate independent | Consistent feel; required for online later |
| G2 | No magic numbers for tunables — use config/resource files | Lucas tunes feel without touching code |
| G3 | Every feature testable in isolation (test scene or debug toggle) | Fast review loop |
| G4 | No new third-party dependency without a D-### entry | Avoid lock-in and bloat |
| G5 | Assets referenced by path constants, never scattered strings | Safe renames |
| G6 | **Game logic separated from presentation** (logic doesn't read sprites/animations to decide outcomes) | Server must be able to run logic in phase 3–4 (D-002) |
| G7 | **All game state serializable** (player, inventory, floor progress) | Save/load in phase 2, network sync later (D-002) |
| G8 | **Player actions go through an input → command layer**, not direct calls from input handlers | Commands can later be sent over the network (D-002) |
| G9 | **Content is data-driven**: items, enemies, floors, bosses defined in data files, not code | 100 floors is impossible to hand-code (D-002) |

## Folder conventions
```
project.godot
src/
  core/        # pure game logic — RefCounted/Resource only, no visuals (G6)
  commands/    # player/AI action commands (G8)
  entities/    # scenes + glue: player/, enemies/, bosses/ (presentation)
  world/       # floors, rooms, town hub scenes
  ui/          # HUD, menus, debug overlay
  autoload/    # singletons (Tunables, etc.) — keep this list short
data/          # content as .tres files (G9)
  tunables/  items/  enemies/  floors/
assets/
  sprites/  audio/  fonts/
scenes/
  main.tscn
  debug/       # isolated test scenes (G3)
tests/         # GUT tests, mirror src/ layout
tools/         # scripts: run tests, lint, core purity check
addons/        # third-party Godot addons (each needs a D-###/F-### entry, G4)
```

## Code style
- Static typing on every variable, parameter and return (`var hp: int`, `-> void`).
- `snake_case` files, functions, variables · `PascalCase` classes (`class_name`) and nodes ·
  `UPPER_SNAKE` constants.
- One `class_name` per script file; file name = snake_case of class name.
- `gdformat` before commit; `gdlint` must pass.
- Signals named in past tense (`died`, `floor_cleared`).
- `src/core/` never extends `Node2D`, `CanvasItem` or touches sprites/animation (G6).
- Non-obvious code that exists because of a decision gets `# D-###` comment.
