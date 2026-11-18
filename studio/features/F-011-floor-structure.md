---
id: F-011
title: Floor structure — rooms as data, navigation, room-clear healing, floors 1–3 in greybox
status: IN_PROGRESS      # DRAFT | PLAN_REVIEW | PLAN_CHANGES | APPROVED | IN_PROGRESS | CODE_REVIEW | CODE_CHANGES | DONE | PARKED
owner_now: Builder       # who must act next: Planner | Auditor | Builder | Lucas
created: 2026-11-18
updated: 2026-11-18
depends_on: [F-004, F-005, F-006, F-007, F-008, F-009, D-006, D-007, D-008, D-011, D-012]
pillars: [1, 2]
department: Floors       # studio/design/floors.md
---

# F-011 — Floor structure

> **How to use this file.** This is the single source of truth for this feature.
> Every agent reads the WHOLE file before acting. Write only in the sections you own
> (see studio/README.md). Never delete another role's text — reply under it.
>
> **This feature runs under D-011:** the lead (Claude Code) wrote §1–§6 and gates the work;
> up to two implementer sub-agents write code; only the lead commits and writes §8.

---

## 1. Goal  ·  _Planner_

**Player-facing outcome (one sentence):**
The player walks floors 1, 2 and 3 room by room — each room locks until its enemies are
dead, clearing it heals a little, and the last room holds that floor's boss.

**Why now:** Ten features built the fight; nothing yet strings fights into a floor. This is
slice 1 of the road to a playable loop, and everything after it (progression, town, HUD,
loot) needs rooms to exist.

**Out of scope (explicitly):**
- Floor-to-floor progression, the boss as a gate to the next floor, the town, death returning
  to town and re-entry at the boss (D-006) → F-012 / F-013. Here, death restarts the room.
- A real HUD, menus, sprites, tiles art, audio. Everything is placeholder shapes and a debug label.
- Procedural generation. Rooms are hand-authored data.
- Save/load to disk. `FloorRun` only has to be serializable (G7).
- Wiring `scenes/main.tscn`. Floors run from `scenes/debug/f011_floor_*.tscn`.
- Any change to enemy attack rules, attack choice, or combat tunables.

---

## 2. Context  ·  _Planner_

- **How a fight is wired today:** a debug scene holds wall `StaticBody2D`s (layer 1 `world`),
  a `Player`, `Enemy` instances and, last, a `CombatRunner` whose `combatant_paths` fixes the
  registration order at `_ready()`. Combatants never join or leave a running sim (F-003/C19;
  "summoned adds" is rejected in `design/combat.md`). So **one room = one fresh sim**.
- **Enemy movement today:** brains (`src/core/enemies/*_brain.gd`) return a straight direction
  to the target; the body slides along walls. No path finding.
- **Walls today:** only Godot physics knows them. Core learns of wall stops through glue
  reports (D-008). That stays for projectiles and charges.
- **Player HP:** `PlayerMotor.setup()` fills HP. `CombatState` has `refill()` but no heal.
- **Tooling on Windows:** `tools/lint` expects `.venv/bin`; on this machine use
  `.venv/Scripts/gdlint` and `.venv/Scripts/gdformat` directly. `tools/test` and
  `tools/check_core_purity` work with `GODOT_BIN` set.
- Decisions: D-006 (death), D-007 (step grid), D-008 (wall reports), D-011 (how this feature
  is built), D-012 (rooms as data, navigation grid in core).
- Design doc: `studio/design/floors.md` (encounter tables and room rules; binding).

---

## 3. Options Considered  ·  _Planner_

### ✅ Chosen: rooms as data, one sim per room, flow-field navigation in core
- **How it works:** a `RoomData` resource holds an ASCII tile grid. The glue builds the walls,
  the door, the player and the enemies from it, with a new `CombatRunner` per room. Core builds
  a `NavGrid` from the same rows; brains use it only when the straight line to the target is
  blocked. A `FloorRun` (core) carries room index and HP between rooms and applies the heal rule.
- **Why chosen:** walls are written once (G9); routing is pure logic the server can run (G6);
  fixed registration per sim is kept; behaviour without a `NavGrid` is exactly today's.
- **Costs we're accepting:** room transitions are hard cuts; the grid is coarse (1 tile);
  no diagonal squeezing; enemies in another room don't exist.
- **Would revisit if:** floors need rooms larger than one sim can hold, or streaming.

### ❌ Rejected: open rooms without path finding
- **How it would work:** keep straight-line movement, forbid walls between enemy and player.
- **Why rejected:** no cover for the Hexer floor, no pillars, and every layout is a rectangle.
- **Tempting because:** zero core changes.

### ❌ Rejected: Godot `NavigationServer2D` / `NavigationAgent2D`
- **How it would work:** bake a nav mesh, let agents path in the scene tree.
- **Why rejected:** decisions would come from an engine server outside core (G6), asynchronous
  and not snapshot-safe; core tests couldn't cover it.
- **Tempting because:** it's the built-in, tutorial way.

### ❌ Rejected: one big scene per floor with every room's enemies registered at once
- **How it would work:** a single sim for the floor, dormant enemies in far rooms.
- **Why rejected:** 20+ combatants stepped at 120 Hz while idle, aggro across walls, and one
  huge snapshot. Nothing in phase 1 needs it.
- **Tempting because:** seamless walking between rooms.

### ❌ Rejected: physics `Area2D` as the exit trigger
- **How it would work:** an overlap signal changes the room.
- **Why rejected:** physics would decide an outcome (G6). The exit is decided from the
  player's logic position against the room's exit tiles.
- **Tempting because:** two lines of code.

### ❌ Rejected: healing flasks, and no healing between rooms
- Decided by Lucas 2026-11-18: heal on room clear, full heal entering the boss room.
- **Tempting because:** flasks are the genre standard.

### ❌ Rejected: branching floor maps, doors that are open during the fight
- Decided by Lucas 2026-11-18: a linear chain, the exit opens when the room is cleared.

---

## 4. Constraints  ·  _Planner_

| ID | Constraint | Reason |
|---|---|---|
| C1 | Everything under `src/core/floors/` and `src/core/tunables/floor_tunables.gd` extends `RefCounted` or `Resource` and passes `tools/check_core_purity`. | G6 |
| C2 | **No behaviour change without a `NavGrid`.** With `CombatView.nav == null` every brain returns exactly what it returns on `main`. No existing test file is edited, except to add new tests. All 916 tests on `main` stay green. | Regression safety |
| C3 | A brain routes only when `NavGrid.has_clear_line(from, to, own radius)` is false; otherwise it uses the straight direction. Attack choice (trigger bands, cooldown, target pick) never reads the `NavGrid`. | Keeps combat design intact |
| C4 | `NavGrid` is deterministic: same rows + same positions → same answer, whatever the call order or the number of callers. Neighbour order is fixed. No randomness, no time. | G1, co-op later |
| C5 | Path search is 8-way; a diagonal step is allowed only when both orthogonal neighbours are walkable. The distance field is cached per target tile and rebuilt only when the target's tile changes. The cache is never serialized. | No corner cutting; cost at 120 steps/s |
| C6 | `RoomData` legend, exactly: `#` wall · `.` floor · `P` player start · `E` exit · `1`–`9` spawn of `enemies[digit − 1]`. Tile `(x, y)` has its centre at `(x + 0.5, y + 0.5)` tiles; the grid's top-left corner is the room's origin `(0, 0)`. | One format for data, glue and nav |
| C7 | Spawn combat ids are `"<EnemyData.id>_<n>"`, `n` = 1-based index of the spawn in row-major order (top row first, left to right). That order is the registration order, after the player. | F-003/C19 fixed ids and order |
| C8 | Invalid data is refused, never repaired: `RoomData.validate()` / `FloorData.validate()` return every error; the floor scene builds nothing and logs them when the list isn't empty. | Same rule as enemy data (F-004/C12) |
| C9 | All numbers are in `data/tunables/floors.tres` (`FloorTunables`): heal fraction, boss full heal, min spawn distance, max enemies per room, room size limits, exit min width. | G2 |
| C10 | The exit is decided in core: `FloorRun.is_exit_reached(player_position_tiles)`. No `Area2D`. The door is a wall body (layer 1) over the `E` tiles that the glue disables when the room is cleared. | G6 |
| C11 | "Cleared" is read from logic: every enemy combatant in the room's sim is dead. Never stored in the glue. | Can't go stale |
| C12 | The heal is `roundi(max_hp × room_clear_heal_fraction)`, applied once per room, capped at max HP, never to a dead player. A boss room clear heals nothing. Entering the boss room sets HP to max when `boss_room_full_heal`. | Lucas's decision, 2026-11-18 |
| C13 | `FloorRun` has `to_dict()` / `from_dict()`; a restore that doesn't fit the floor (room index out of range) is refused and changes nothing. | G7 |
| C14 | The glue builds each room with a **new** `CombatRunner`, added last, with `combatant_paths` = player, then spawns in C7 order. Nothing is added to or removed from a running sim. | F-003/C19 |
| C15 | New asset/data paths used from code are constants (`Tunables.*_PATH` or a `const` in the script). | G5 |
| C16 | Layout rules enforced by `RoomData.validate()`: rectangular; within size limits; border is all `#`/`E`; exactly one `P`; `E` tiles form one straight run on the border, not on a corner, at least `exit_min_width_tiles` long, touching walkable tiles; every walkable tile reachable from `P`; every walkable tile is part of a fully walkable 2×2 block (no 1-tile corridors); every interior wall tile is part of a fully wall 2×2 block (no thin walls); every spawn at least `min_spawn_distance_tiles` from `P`; non-boss rooms have 1 to `max_enemies_per_room` spawns; a boss room has exactly one. | Bodies up to 0.8 tiles; no melee through walls |
| C17 | Sub-agents never run `git` commands that change state, never edit `studio/`, `tools/`, `addons/`, or files outside their task's list, and never use a worktree. | D-011 |
| C18 | Static typing everywhere; `gdlint` and `gdformat --check` clean; one `class_name` per file. | PROJECT.md code style |

**Must not break:** every debug scene `f001`–`f009`, all 916 existing tests, the F5 reload,
snapshots, and the rule that enemies are slower than the player on foot.

---

## 5. Acceptance Criteria  ·  _Planner_

**Data (T1)**
- [ ] AC1: A valid room passes `validate()`. One test per C16 rule shows a room breaking only that rule is rejected with a message naming the rule and the tile.
- [ ] AC2: `get_spawns()` returns spawns in row-major order with C7 ids and C6 centre positions; `get_player_start_tiles()` and `get_exit_tiles()` match the grid.
- [ ] AC3: `FloorData.validate()` rejects: fewer than 2 rooms, a null room, a boss room that isn't last, a last room that isn't a boss room, duplicate room ids; and prefixes room errors with the room id.
- [ ] AC4: `FloorTunables.validate()` rejects a heal fraction outside 0–1, non-positive sizes, min size above max size, `max_enemies_per_room` < 1.

**Navigation (T2, T3)**
- [ ] AC5: `has_clear_line` is true across open floor and false when a wall tile is within `radius` of the segment, including a segment that only grazes a wall corner.
- [ ] AC6: In a room with a wall between A and B, repeatedly moving 0.05 tiles along `direction_toward` from A reaches B's tile without ever entering a wall tile, in no more than 1.5× the shortest tile-path length.
- [ ] AC7: No corner cutting: with walls at `(1,0)` and `(0,1)`, a path from `(0,0)` to `(1,1)` doesn't exist as a diagonal step.
- [ ] AC8: The field is rebuilt only when the target tile changes (a build counter proves it), and two enemies asking in either order get the same directions (C4).
- [ ] AC9: No path (target sealed off) → `Vector2.ZERO`, and the brain then falls back to the straight direction.
- [ ] AC10: With `nav == null` each of the three brains returns the same intent as before for a recorded set of positions (C2). With a `NavGrid` and a wall between, chaser and brute return a move whose direction is `direction_toward`'s; with a clear line they return the straight direction. The caster walks in the same way and still retreats straight.
- [ ] AC11: `CombatSim.set_nav()` reaches every combatant's `sense()` through `CombatView.nav`; `to_dict()` is unchanged by it.

**Run state and healing (T4)**
- [ ] AC12: `CombatState.heal(30)` at 50/100 gives 80 and returns 30; at 90/100 gives 100 and returns 10; at 0 HP returns 0 and stays 0; a negative amount does nothing.
- [ ] AC13: `FloorRun`: clearing a non-boss room returns `roundi(max_hp × fraction)` once and 0 on a second report; `advance()` is refused before the clear and on the last room; entering the boss room gives max HP as entry HP; clearing the boss room marks the floor cleared and emits `floor_cleared` once.
- [ ] AC14: `is_exit_reached()` is false before the clear whatever the position, and true after it only on an `E` tile.
- [ ] AC15: `to_dict()` → `from_dict()` on a fresh `FloorRun` reproduces room index, HP and cleared flags; an out-of-range room index is refused and changes nothing.

**Glue (T5)**
- [ ] AC16: A room built from a fixture `RoomData` has one wall body per horizontal run of `#`, a door body over the `E` tiles, the player at `P`, one `Enemy` per spawn with the right data, id and position, and a `CombatRunner` as its last child with no setup errors.
- [ ] AC17: A scripted player can't leave through the door while an enemy lives; when the last enemy dies the door's collision is off within one tick and HP rose by the C12 amount exactly once.
- [ ] AC18: Standing on an `E` tile after the clear replaces the room with the next one: the old room is freed, the new sim's ids are the new room's, and the player's HP is the carried HP.
- [ ] AC19: In the fixture floor's boss room the player enters at full HP, and killing the boss shows "floor cleared" and emits `floor_cleared` once.
- [ ] AC20: Player death restarts the current room at full HP (placeholder until F-012), with a fresh sim.
- [ ] AC21: A floor whose data fails validation builds no room and logs each error.
- [ ] AC22: An enemy with a wall between it and the player reaches the player in the real scene (physics on), at 30, 60 and 120 ticks/s.
- [ ] AC23: The debug label shows floor number, room index / count, player HP and living enemies; `debug_next_room` (N) jumps to the next room; `debug_reset` (R) restarts the room.

**Content (T6, T7)**
- [ ] AC24: `floor_1.tres`, `floor_2.tres`, `floor_3.tres` pass validation with the shipped tunables and match the encounter tables in `studio/design/floors.md` (room count, enemy types and counts per room, boss).
- [ ] AC25: In every shipped room, every spawn has a tile path to `P`.
- [ ] AC26: Every shipped room loads in the real floor scene with no setup errors, and stepping it 2 s with the AI on raises no error.
- [ ] AC27: The Hexer room has at least four cover blocks that break the line between the boss spawn and `P`; the Juggernaut room has no interior walls and is at least 20 × 12 tiles of open floor.

**Gates for every task (the lead runs them before committing):**
1. The task's new tests pass.
2. Full `tools/test`: every test passes, and no test on `main` was changed or removed.
3. `.venv/Scripts/gdlint src tests` and `.venv/Scripts/gdformat --check src tests` are clean.
4. `tools/check_core_purity` says ok.
5. `git status` shows only files in the task's list.
6. The lead read the diff against §3 Rejected and §4.

**How to verify manually (Lucas, Gate B):** open `scenes/debug/f011_floor_1.tscn`, press F6.
Clear room 1 and watch the door open and HP rise; walk through; reach the Warden with full HP.
Repeat for `f011_floor_2.tscn` and `f011_floor_3.tscn`. In a room with pillars, stand behind
one: chasers must walk around it, not push into it. Judge: room sizes, enemy counts, whether
30 % feels right, whether the Hexer's cover and the Juggernaut's open room play as intended.

---

## 6. Task Breakdown  ·  _Planner_

Two implementers at most, on disjoint files. Wave 2 starts after wave 1 is committed.

| # | Wave · who | Task | Files (the task's whole list) |
|---|---|---|---|
| T1 | 1 · A | `FloorTunables`, `RoomData`, `RoomSpawn`, `FloorData` + validation + tests | `src/core/tunables/floor_tunables.gd`, `src/core/floors/room_data.gd`, `room_spawn.gd`, `floor_data.gd`, `data/tunables/floors.tres`, `src/autoload/tunables.gd` (add `FLOORS_PATH`, `floors`), `tests/core/floors/test_room_data.gd`, `test_floor_data.gd`, `test_floor_tunables.gd`, `tests/core/floors/room_fixtures.gd` |
| T4 | 1 · A | `CombatState.heal()` / `set_hp()`, `FloorRun` + tests | `src/core/combat/combat_state.gd`, `src/core/floors/floor_run.gd`, `tests/core/combat/test_combat_state_heal.gd`, `tests/core/floors/test_floor_run.gd` |
| T2 | 1 · B | `NavGrid` + tests | `src/core/floors/nav_grid.gd`, `tests/core/floors/test_nav_grid.gd` |
| T3 | 1 · B | `CombatView.nav`, `CombatSim.set_nav()`, `EnemyBrain.steer()`, the three brains + tests | `src/core/combat/combat_view.gd`, `combat_sim.gd`, `src/core/enemies/enemy_brain.gd`, `chaser_brain.gd`, `caster_brain.gd`, `brute_brain.gd`, `tests/core/enemies/test_brain_nav.gd`, `tests/core/combat/test_combat_sim_nav.gd` |
| T5 | 2 · A | `Room` and `FloorScene` glue, debug label, `debug_next_room` action, fixture floor, scene tests | `src/world/floors/room.gd`, `floor_scene.gd`, `floor_scene.tscn`, `src/ui/debug/floor_debug_label.gd`, `project.godot` (one input action), `tests/fixtures/floors/*.tres`, `tests/scenes/test_f011_*.gd`, `tests/scenes/f011_scene_test.gd` |
| T6 | 2 · B | Floors 1–3 content: 12 combat rooms, 3 boss rooms, 3 floors, path constants, data tests | `data/floors/**`, `src/autoload/tunables.gd` (floor path constants), `tests/core/floors/test_shipped_floors.gd` |
| T7 | 3 · one | Debug scenes per floor + shipped-floor scene tests (AC26) | `scenes/debug/f011_floor_1.tscn`, `_2`, `_3`, `tests/scenes/test_f011_shipped_floors.gd` |

**Contracts (binding — both waves build against these names):**

```gdscript
# src/core/floors/room_data.gd
class_name RoomData extends Resource
@export var id: StringName
@export var rows: PackedStringArray
@export var enemies: Array[EnemyData]
@export var is_boss_room: bool
func get_size() -> Vector2i
func is_walkable(tile: Vector2i) -> bool            # '.', 'P', digits. '#', 'E', outside → false
func get_player_start_tiles() -> Vector2            # tile centre
func get_exit_tiles() -> Array[Vector2i]
func get_spawns() -> Array[RoomSpawn]               # C7 order
func validate(rules: FloorTunables) -> PackedStringArray

# src/core/floors/room_spawn.gd
class_name RoomSpawn extends RefCounted
var enemy: EnemyData
var position_tiles: Vector2
var combat_id: StringName

# src/core/floors/floor_data.gd
class_name FloorData extends Resource
@export var floor_number: int
@export var rooms: Array[RoomData]
func get_room_count() -> int
func validate(rules: FloorTunables) -> PackedStringArray

# src/core/tunables/floor_tunables.gd  →  data/tunables/floors.tres  →  Tunables.floors
class_name FloorTunables extends Resource
@export var room_clear_heal_fraction: float = 0.30
@export var boss_room_full_heal: bool = true
@export var min_spawn_distance_tiles: float = 4.0
@export var max_enemies_per_room: int = 6
@export var min_room_size: Vector2i = Vector2i(8, 6)
@export var max_room_size: Vector2i = Vector2i(40, 22)
@export var exit_min_width_tiles: int = 2
func validate() -> PackedStringArray

# src/core/floors/nav_grid.gd
class_name NavGrid extends RefCounted
static func from_rows(rows: PackedStringArray) -> NavGrid   # walkable = anything but '#' and 'E'
func get_size() -> Vector2i
func is_walkable(tile: Vector2i) -> bool
func tile_of(position_tiles: Vector2) -> Vector2i
func has_clear_line(from: Vector2, to: Vector2, radius_tiles: float) -> bool
func direction_toward(from: Vector2, to: Vector2) -> Vector2  # unit, or ZERO (no path / same tile)
func get_field_builds() -> int                                # AC8

# src/core/combat/combat_view.gd / combat_sim.gd
var nav: NavGrid = null                                       # CombatView
static func capture(combatants: Array[Combatant], nav_grid: NavGrid = null) -> CombatView
func set_nav(nav_grid: NavGrid) -> void                       # CombatSim
func get_nav() -> NavGrid

# src/core/enemies/enemy_brain.gd
static func steer(view: CombatView, enemy: EnemyLogic, target_position: Vector2) -> Vector2

# src/core/combat/combat_state.gd
func heal(amount: int) -> int        # returns what was healed
func set_hp(hp: int) -> void         # clamped to 0..max

# src/core/floors/floor_run.gd
class_name FloorRun extends RefCounted
signal room_cleared(room_index: int)
signal floor_cleared(floor_number: int)
func setup(floor: FloorData, rules: FloorTunables, max_hp: int, start_room: int = 0) -> void
func get_room() -> RoomData
func get_room_index() -> int
func get_entry_hp() -> int
func is_room_cleared() -> bool
func is_floor_cleared() -> bool
func report_room_cleared(current_hp: int) -> int   # heal to apply; 0 the second time
func is_exit_reached(player_position_tiles: Vector2) -> bool
func advance(current_hp: int) -> bool
func restart_room() -> void                        # placeholder death rule: entry HP = max
func to_dict() -> Dictionary
func from_dict(snapshot: Dictionary) -> bool
```

---

## 7. Plan Review  ·  _Auditor_

_Skipped for this feature by Lucas's instruction (D-011). The code review (§9) still runs._

---

## 8. Implementation Log  ·  _Builder_

**Started:** 2026-11-18  ·  **Branch:** `feature/F-011-floor-structure`

### Progress
- [x] T1 — 9962aa5
- [x] T2 — 1057aeb
- [x] T3 — f724409
- [x] T4 — 6112eeb
- [ ] T5
- [ ] T6
- [ ] T7

### Deviations from plan
- DEV-1: This file went straight to `IN_PROGRESS`; `APPROVED` was never written and the
  Auditor's plan review didn't run. — **Why:** Lucas gave Gate A in chat on 2026-11-18
  ("begin slice 1 … you are the orchestrator and engineer (lead) … spawn sonnet 5.5 high
  subagents"; then chose "Your message is Gate A"), and only Lucas or `tools/studio` may
  write `APPROVED`. — **Impact:** `tools/studio` sees a feature that skipped a state; D-011
  records the exception.
- DEV-2: Implementer sub-agents write files (D-010 allowed read-only ones). — **Why:** D-011.
  — **Impact:** the lead gates and commits every task; the Auditor's §9 is unchanged.

- DEV-3: `# gdlint:disable=max-public-methods` on `combat_state.gd` (22 public methods after
  `heal`/`set_hp`) and on three long test files. — **Why:** gdlint's cap is 20; `combatant.gd`
  and `enemy_logic.gd` already do the same. — **Impact:** none at runtime.
- DEV-4: `RoomData.validate()` has one rule C16 doesn't list, `legend`: unknown characters, a
  digit with no `enemies` entry, a null entry. — **Why:** such a room can't be built (C8).
  — **Impact:** stricter data only.

### Assumptions made (small, reversible)
- ASSUMPTION-1: tile size stays 16 px and rooms are at most 40 × 22 tiles (one 640 × 360
  screen) — **Why:** the art/pixel-scale decision is still open (CX1); all values are in tiles.
- ASSUMPTION-2: "floor 1 = 3 rooms, floor 2 = 4, floor 3 = 5" counts combat rooms; the boss
  room comes after them — **Why:** the chain "ends in the boss room".
- ASSUMPTION-3: death restarts the current room at full HP — **Why:** D-006's return to town
  needs F-012/F-013; this is the smallest placeholder that isn't a rejected option.

- ASSUMPTION-4: reachability is a 4-way flood from `P`; spawn distance is centre to centre and
  exactly the minimum passes; "touching walkable" means the tile inward of each `E` is walkable.
- ASSUMPTION-5: `FloorRun.setup()` clamps an out-of-range start room; a clear with a dead
  player still clears (heal 0); a boss clear emits `room_cleared` and `floor_cleared`;
  `restart_room()` keeps the floor-cleared flag; `set_hp()` emits no signal.
- ASSUMPTION-6: `NavGrid` neighbour order is N, E, S, W, NE, SE, SW, NW; touching a wall counts
  as blocked (distance ≤ radius + `DISTANCE_EPSILON`); a position inside a wall or outside the
  grid snaps to the nearest walkable tile.

### Things the Auditor should look at closely
- _filled at the end_

### How to test
- _filled at the end_

---

## 9. Code Review  ·  _Auditor_

---

## 10. Open Questions  ·  _Anyone (append)_

| # | Raised by | Question | Blocking? | Answer (Lucas/Planner) |
|---|---|---|---|---|
| Q1 | Lead | → Combat: hits ignore walls (circle–sector in core). C16's "no thin walls" keeps 1-tile walls out of rooms, but a 2-tile pillar corner can still be clipped by a long sector (Warden overhead 2.0 tiles). Accept for phase 1, or make hits respect line of sight? | no | |
| Q2 | Lead | → Combat: a caster with no clear line still shoots (its bolt hits the wall). Kept on purpose: walls are cover. Should it reposition instead? | no | |
| Q3 | Lead | → Lucas: starting values to judge at Gate B — heal 30 %, room sizes, enemy counts per room (`studio/design/floors.md`). | no | |

---

## 11. Director Notes  ·  _Lucas_

<Overrides, priorities, gut calls. Everyone obeys these.>
