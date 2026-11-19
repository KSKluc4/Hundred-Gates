---
id: F-011
title: Floor structure — rooms as data, navigation, room-clear healing, floors 1–3 in greybox
status: CODE_REVIEW      # DRAFT | PLAN_REVIEW | PLAN_CHANGES | APPROVED | IN_PROGRESS | CODE_REVIEW | CODE_CHANGES | DONE | PARKED
owner_now: Auditor        # who must act next: Planner | Auditor | Builder | Lucas
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
| C6 | `RoomData` legend, exactly: `#` wall · `.` floor · `P` player start · `E` exit · `1`–`9` spawn of `enemies[digit − 1]`. Tile `(x, y)` has its centre at `(x + 0.5, y + 0.5)` tiles; the grid's top-left corner is the room's origin `(0, 0)`. The floor scene must sit at the world origin: tile positions are read from global positions, and any other origin is refused as a setup error (review round 1, CR-4). | One format for data, glue and nav |
| C7 | Spawn combat ids are `"<EnemyData.id>_<n>"`, `n` = 1-based index of the spawn in row-major order (top row first, left to right). That order is the registration order, after the player. | F-003/C19 fixed ids and order |
| C8 | Invalid data is refused, never repaired: `RoomData.validate()` / `FloorData.validate()` return every error; the floor scene builds nothing and logs them when the list isn't empty. | Same rule as enemy data (F-004/C12) |
| C9 | All numbers are in `data/tunables/floors.tres` (`FloorTunables`): heal fraction, boss full heal, min spawn distance, max enemies per room, room size limits, exit min width. | G2 |
| C10 | The exit is decided in core: `FloorRun.is_exit_reached(player_position_tiles)`. No `Area2D`. The door is a wall body (layer 1) over the `E` tiles that the glue disables when the room is cleared. | G6 |
| C11 | "Cleared" is read from logic: every enemy combatant in the room's sim is dead. Never stored in the glue. | Can't go stale |
| C12 | The heal is `roundi(max_hp × room_clear_heal_fraction)`, applied once per room, capped at max HP, never to a dead player. A boss room clear heals nothing. Entering the boss room sets HP to max when `boss_room_full_heal`. | Lucas's decision, 2026-11-18 |
| C13 | `FloorRun` has `to_dict()` / `from_dict()`; a restore that doesn't fit the floor (room index out of range) is refused and changes nothing. The snapshot carries the floor number, and one from another floor is refused (review round 1, CR-8). | G7 |
| C14 | The glue builds each room with a **new** `CombatRunner`, added last, with `combatant_paths` = player, then spawns in C7 order. Nothing is added to or removed from a running sim. | F-003/C19 |
| C15 | New asset/data paths used from code are constants (`Tunables.*_PATH` or a `const` in the script). | G5 |
| C16 | Layout rules enforced by `RoomData.validate()`: rectangular; within size limits; border is all `#`/`E`; exactly one `P`; `E` tiles form one straight run on the border, not on a corner, at least `exit_min_width_tiles` long, touching walkable tiles; every walkable tile reachable from `P`; every walkable tile is part of a fully walkable 2×2 block (no 1-tile corridors); every two orthogonally adjacent walkable tiles share a fully walkable 2×2 block (no 1-tile pinch between wall corners; review round 1, CR-2); every interior wall tile is part of a fully wall 2×2 block (no thin walls); every spawn at least `min_spawn_distance_tiles` from `P`; non-boss rooms have 1 to `max_enemies_per_room` spawns; a boss room has exactly one. | Bodies up to 0.8 tiles; no melee through walls |
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
- [x] T5 — bbb765f
- [x] T6 — 3975aa6
- [x] T7 — f5837b4
- [x] Review round 1 fixes — CR-2 fefa482, CR-8 85d7646, CR-4 eb2b7fe, CR-3 6165d01 (replies in §9)

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
- DEV-5: one line added to `tests/test_input_map.gd` (`debug_next_room`). — **Why:** that test
  pins the exact action list, so any new input action changes it; C2's "no existing test
  edited" can't hold for it. — **Impact:** none beyond the new action.
- DEV-6: `FloorScene` and `Room` have `player_input_enabled` (not in the contracts), and
  `FloorScene` runs at `process_physics_priority = 1`. — **Why:** scripted runs need input
  off on rebuilt rooms; running after the room's `CombatRunner` puts the heal and the door
  opening in the same tick as the kill. — **Impact:** the old room is freed inside
  `_physics_process`, which is safe only while the floor runs after the runner.
- DEV-7: test fixtures for the glue are built in code (`tests/fixtures/floors/floor_fixtures.gd`),
  not `.tres` files. — **Why:** easier to vary per test. — **Impact:** none.

- DEV-8: in `studio/design/floors.md` the line "`P` and `E` sit on opposite sides, so the
  room is crossed" was moved from the rules `RoomData.validate()` enforces to a new
  "Guidelines (not enforced)" list, in the log commit `c6f0eb6`, and was not logged here until
  review round 1 (CR-1). — **Why:** C16 never listed it, and "opposite sides" has no exact
  meaning for an exit on a side wall or a start in a corner (the Hexer room's `P` is in a
  corner on purpose, ASSUMPTION-8). — **Impact:** the design doc Lucas approved at Gate A said
  the rule was enforced; it isn't. The shipped rooms all have `P` and `E` on opposite walls
  (`test_shipped_floors.gd`). §10 Q5 asks Lucas whether it should be enforced.
- DEV-9: `FloorData.validate()` also rejects `floor_number < 1`, and `FloorTunables.validate()`
  also rejects a negative `min_spawn_distance_tiles` and `exit_min_width_tiles < 1` (not in
  AC3/AC4). — **Why:** such data can't be built or makes a rule meaningless. — **Impact:**
  stricter data only (logged in review round 1, CR-1).
- DEV-10: `Room` adds, beyond the contracts and AC16, a `PlaceholderShake` camera on the
  player, a `CombatDebugDraw`, and a `BossBar` in boss rooms. — **Why:** the debug scenes of
  F-003 to F-009 have them and a floor without them can't be judged at Gate B. — **Impact:**
  none on logic; all three are existing presentation nodes (logged in review round 1, CR-1).
- DEV-11: `README.md` got a paragraph in T7's commit, outside T7's file list. — **Why:** the
  lead added it to T7's brief and not to §6. — **Impact:** none (logged in review round 1, CR-1).
- DEV-12: after code review round 1 the lead amended C6, C13 and C16 (each marked "review
  round 1"). — **Why:** CR-2, CR-4 and CR-8. — **Impact:** one more validation rule, one more
  setup error, one more snapshot key.

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
- ASSUMPTION-7: `room_entered` is emitted on every build (first room, next room, restart,
  skip). `skip_room()` (debug N) marks the room cleared without healing. A dead player
  restarts the room even if it was already cleared.
- ASSUMPTION-8: every shipped spawn, bosses included, starts outside its own aggro radius
  from `P`, so the player starts each fight. The Hexer room's `P` is in a corner so a cover
  block breaks the first line of fire (AC27).

### Things the Auditor should look at closely
- **C2 (no behaviour change without a NavGrid).** `chaser_brain.gd`, `brute_brain.gd` and
  `caster_brain.gd` now call `EnemyBrain.steer()`. With `view.nav == null` it must be exactly
  `direction_to`. `tests/core/enemies/test_brain_nav.gd` re-derives the old formulas; the 916
  tests from `main` are untouched except one line in `tests/test_input_map.gd` (DEV-5).
- **Room swap inside `_physics_process`.** `FloorScene._build_room()` removes and `free()`s
  the old room mid-frame. It is safe only because the floor runs at physics priority 1, after
  the room's `CombatRunner` (DEV-6). `restart_room()` and `skip_room()` also run from
  `_unhandled_input`.
- **`NavGrid` keeps one cached field** (the last target tile). With two players in different
  tiles (phase 3) it would rebuild on every query. Fine for one player; flagged for co-op.
- **`has_clear_line` uses the enemy's own radius at both ends**, so a player hugging a wall
  is "not clear" for a brute (0.6) and it routes by tile centres until it shares the player's
  tile, then falls back to the straight line.
- **Wide bodies at corners.** A brute is 1.2 tiles wide and the route aims at tile centres; it
  leans on `move_and_slide()` at pillar corners. Covered at 30 and 120 ticks/s for a pillar and
  for a 2-tile gap (`test_f011_navigation.gd`), with a standing player only.
- **§10 Q4:** the caster's hold-and-shoot behind a wall, and the brute charging a pillar. The
  caster test asserts only that it walks to the gap, not that it gets a clear line.
- **`F011SceneTest.hit()`** writes to `CombatState.apply_hit` directly (kills only); it does not
  set aggro. `test_f011_shipped_floors.gd` wakes enemies through `EnemyLogic.apply_hit`.
- **Not done by anyone:** nobody has played the floors with a keyboard or a gamepad. The lead
  rendered `f011_floor_1.tscn` to an image once (walls, door, player, two chasers and the label
  draw as expected); everything else is headless.
- `tools/lint` expects `.venv/bin` and doesn't run on Windows; the gates called
  `.venv/Scripts/gdlint` and `gdformat` directly. Not changed here (out of scope).

### How to test
```sh
export GODOT_BIN=/path/to/Godot_v4.7.2-stable
tools/test                      # 109 scripts, 1135 tests, all passing (about 5.5 min)
tools/lint                      # on Windows: .venv/Scripts/gdlint src tests && .venv/Scripts/gdformat --check src tests
tools/check_core_purity
```
`tools/test` ignores `-gtest`; for one script run
`"$GODOT_BIN" --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/scenes/test_f011_flow.gd -gexit`.

By hand (Gate B): open `scenes/debug/f011_floor_1.tscn`, `f011_floor_2.tscn` or
`f011_floor_3.tscn` and press F6. `N` skips to the next room, `R` restarts the room. See §5
"How to verify manually" for what to judge.

Final gate run by the lead on `f5837b4`: 1135/1135 tests, gdlint clean, gdformat 220 files
unchanged, core purity ok (self-test: 19 rules).

After the review round 1 fixes (`6165d01`): 1150/1150 tests (15 new), gdlint clean, gdformat 220
files unchanged, core purity ok.

---

## 9. Code Review  ·  _Auditor_

<!-- review-round: 1 verdict: CHANGES_REQUESTED -->

**Reviewed commit:** a864404

**Date:** 2026-11-18 · **Verdict:** CHANGES_REQUESTED · **By:** Auditor (lead, D-014)

How this round was done (D-014): a fresh reviewer sub-agent that wrote neither the spec nor
the code read `AGENTS.md`, this file and the whole diff against `main`. It extracted `a864404`
into a scratch folder and ran its probes against that copy, so every run below is on the
reviewed commit. The lead then checked each finding against the code and the git history
before recording it here. `tools/test` (1135 tests), lint and `tools/check_core_purity` had
passed on this commit and were not rerun.

No functional bug was found in the shipped floors, the navigation, the brains or the room
flow. The blocking finding is a rule matter: differences from the plan that §8 doesn't log,
one of them a design-doc rule demoted inside a log commit. Four findings should be fixed: a
validation hole that lets a room trap a wide enemy, a content test that proves less than it
reads, a silent dependence on the world origin, and a design doc that now contradicts the code.

Independent checks the reviewer ran, all clean: 3,600 random segments of `has_clear_line`
against brute-force sampling; 550 random-grid walks along `direction_toward`; the three brains
of `main` against this commit's with no nav grid over 6,000 random states (C2: 0 differences);
all 15 shipped rooms with every enemy awake and attacking for 25 s at 30 and 60 ticks/s; 641
player positions across the rooms with every enemy walking to its stop distance.

### AC evidence

| AC | Result | Evidence |
|---|---|---|
| AC1 | ✅ | `room_data.gd:67`; one test per rule in `test_room_data.gd:15` |
| AC2 | ✅ | `room_data.gd:36`, `:44`, `:50`; `test_room_data.gd:235` |
| AC3 | ✅ | `floor_data.gd:14`; `test_floor_data.gd:22` |
| AC4 | ✅ | `floor_tunables.gd:20`; `test_floor_tunables.gd:27` |
| AC5 | ✅ | `nav_grid.gd:70`; `test_nav_grid.gd:97`; fuzz clean |
| AC6 | ✅ | `nav_grid.gd:87`; `test_nav_grid.gd:182`, `:368`; fuzz clean |
| AC7 | ✅ | `nav_grid.gd:125`; `test_nav_grid.gd:246` |
| AC8 | ✅ | `nav_grid.gd:156`; `test_nav_grid.gd:288` |
| AC9 | ✅ | `nav_grid.gd:90`, `enemy_brain.gd:65`; `test_nav_grid.gd:348`, `test_brain_nav.gd:222` |
| AC10 | ✅ | `enemy_brain.gd:55`, the three brains; `test_brain_nav.gd:50`; differential run against `main` clean |
| AC11 | ✅ | `combat_sim.gd:51`, `:65`; `test_combat_sim_nav.gd:30` |
| AC12 | ✅ | `combat_state.gd:103`, `:112`; `test_combat_state_heal.gd:14` |
| AC13 | ✅ | `floor_run.gd:61`, `:87`; `test_floor_run.gd:39` |
| AC14 | ✅ | `floor_run.gd:78`; `test_floor_run.gd:143` |
| AC15 | ✅ | `floor_run.gd:108`; `test_floor_run.gd:178` (see CR-8) |
| AC16 | ✅ | `room.gd:113`–`:202`; `test_f011_room.gd:12` |
| AC17 | ✅ | `floor_scene.gd:53`, `room.gd:100`; `test_f011_flow.gd:10`, `:25` (a real sword kill) |
| AC18 | ✅ | `floor_scene.gd:57`, `:114`; `test_f011_flow.gd:60`, `:85` |
| AC19 | ✅ | `floor_run.gd:66`, `:92`; `test_f011_flow.gd:95`, `:122` |
| AC20 | ✅ | `floor_scene.gd:50`, `:83`; `test_f011_flow.gd:133`, `:157` |
| AC21 | ✅ | `floor_scene.gd:32`, `:101`; `test_f011_debug.gd:8` |
| AC22 | ✅ | `test_f011_navigation.gd:16` (chaser at 30/60/120; brute and caster at 30 and 120, and the brute "reaches" by starting a charge with a clear line, as §8 says) |
| AC23 | ✅ | `floor_debug_label.gd:13`, `floor_scene.gd:62`; `test_f011_debug.gd:65` |
| AC24 | ✅ | `data/floors/**`; `test_shipped_floors.gd:81`; the 15 rooms were also checked by hand against `floors.md` |
| AC25 | ✅ | `test_shipped_floors.gd:165` |
| AC26 | ✅ | By its words only: `test_f011_shipped_floors.gd:42`, `:116`. The test proves much less than it reads (CR-3). |
| AC27 | ✅ | `test_shipped_floors.gd:181` |

### Checks

- **Rejected options (§3):** none implemented. No `Navigation*` or `Area2D` in the new code or
  scenes; the exit is decided in `FloorRun.is_exit_reached`; one sim per room; no flasks; a
  linear chain; the door stays locked until the clear.
- **Constraints C1–C18:** met by their wording. C2 verified by the differential run; only
  `tests/test_input_map.gd` changed among existing tests (DEV-5). C16 is implemented as
  written, and as written it lets a broken room through (CR-2). C11 holds for
  `Room.is_cleared()`, but the door and `FloorRun`'s flag are latches (CR-6).
- **G1–G9:** no violation found. Nothing in the navigation or the room flow reads time or a
  frame count. G7: see CR-8.
- **Deviations:** DEV-1 to DEV-7 are justified (DEV-6 checked by about 700 scene runs with no
  engine error on a swap or a restart). Unlogged ones: CR-1.
- **Assumptions:** 1–8 reasonable and reversible. ASSUMPTION-4 is what opens CR-2, and
  ASSUMPTION-8 is what empties AC26's test (CR-3).
- **Tick rates:** first-hit times agree at 30/60/120. Long fights with several enemies drift
  slightly between rates, and by the same amount with the nav grid removed: it comes from the
  existing physics glue, not from this feature.

### Findings

**CR-1 🔴 Differences from the plan that §8 doesn't log.** Verified in the git history.
- (a) `studio/design/floors.md`, commit `c6f0eb6` (a log commit): the line "`P` and `E` sit on
  opposite sides, so the room is crossed" moved from "Rules (enforced by
  `RoomData.validate()`)" to a new "Guidelines (not enforced)" list. At the spec commit
  `82a82a5` the binding design doc said the rule was enforced; C16 never listed it. The
  contradiction was settled by editing the design doc, with nothing in §8.
- (b) `floor_data.gd:16` rejects `floor_number < 1`: not in AC3.
- (c) `floor_tunables.gd:24`, `:34` reject a negative `min_spawn_distance_tiles` and
  `exit_min_width_tiles < 1`: not in AC4.
- (d) `room.gd:155`, `:173` give every room a `PlaceholderShake` camera and a
  `CombatDebugDraw`, and boss rooms a `BossBar`: not in the contracts or AC16.
- (e) `README.md` changed in T7's commit `f5837b4`, outside T7's file list.
- **Why it matters:** (b)–(e) are harmless. (a) is the real one: Gate A was given on a design
  doc that said the rule was enforced. The shipped rooms do comply
  (`test_shipped_floors.gd:279`).
- **Suggested fix:** log each in §8; for (a), enforce the rule or ask Lucas to confirm it is a
  guideline. No code change needed for the others.

> **Builder reply (lead):** logged in `616b3d9` as DEV-8 (the design-doc rule), DEV-9, DEV-10 and DEV-11. For (a) the rule stays a guideline for now: "opposite sides" has no exact meaning for a side exit or a corner start, and §10 Q5 asks Lucas whether to enforce it. No code change.

**CR-2 🟡 A room that passes validation can trap a wide enemy for good.** Verified by running.
- **Where:** `src/core/floors/room_data.gd:226` (`_check_corridors`) and C16's wording.
- **Problem:** "every walkable tile is part of a walkable 2×2 block" does not make every
  passage 2 tiles wide: two wall corners one tile apart pass. A 16 × 12 room with a wall from
  the west at rows 4–5 (x ≤ 7) and a wall from the east at rows 6–7 (x ≥ 9) validates with no
  error, leaving a 1-tile opening at (8, 5)–(8, 6). A chaser gets through; a brute (1.2 tiles
  wide) routes into the opening and stays there, 8.1 tiles from the player, for the whole 40 s.
- **Why it matters:** the exit is locked until every enemy is dead, and validation is the only
  guard for rooms authored later. No shipped room has this.
- **Suggested fix:** also require that every two orthogonally adjacent walkable tiles share a
  fully walkable 2×2 block; add the test; state the rule in `floors.md`.

> **Builder reply (lead):** fixed in `fefa482`. New rule `pinch` in `RoomData.validate()`: two walkable tiles side by side must share a walkable 2×2 block; each pair is reported once, and a tile the `corridor` rule already refuses is not reported twice. All 15 shipped rooms and every fixture pass it unchanged. C16 and `floors.md` state the rule (`616b3d9`).

**CR-3 🟡 AC26's test runs almost every room with sleeping enemies.** Verified by reading; the
rooms themselves verified by running.
- **Where:** `tests/scenes/test_f011_shipped_floors.gd:116` (`_walk_floor`), `:150`, `:205`.
- **Problem:** the player idles at `P`, and `test_shipped_floors.gd:271` pins every spawn
  outside its own aggro radius from `P`. For the 2 s no enemy decides, routes or attacks; "AI
  on" only checks the toggle. `_wake_room` wakes one non-boss room per floor. No boss room and
  9 of the 12 combat rooms are ever awake in the floor scene in any test.
- **Why it matters:** a broken interaction between a room's walls and its enemies (Hexer bolts
  and cover, Juggernaut charges, casters in alcoves) would pass the suite. The reviewer's own
  run of all 15 rooms awake was clean, so the content is fine; the test is the gap.
- **Suggested fix:** wake every room, boss rooms included, in `_walk_floor`, with the same
  no-error and no-stray-body asserts.

> **Builder reply (lead):** fixed in `6165d01`. `_walk_floor` now wakes every enemy of every room, boss rooms included, and asserts that each one was aggroed, left its idle state and left its spawn tile, with the old asserts kept. All 15 rooms were clean. Limit: in 2 s from `P` no hit lands, so the test proves that every enemy decides and moves, not that a full fight is error-free.

**CR-4 🟡 The floor only works at the world origin, and nothing says or checks it.** Verified
by running.
- **Where:** `src/world/floors/room.gd:154`, `:168`, `:211`; `floor_scene.gd:57`; C6.
- **Problem:** bodies take their logic position from `global_position`, while the `NavGrid` and
  `FloorRun.is_exit_reached` use room-local tiles. With `FloorScene.position = (160, 64)`, `P`
  at (1.5, 4.5) became logic position (11.5, 8.5): the door opened after the clear, the player
  walked through it, the room never swapped.
- **Why it matters:** the debug scenes sit at the origin, so nothing breaks today. It is a
  silent soft lock for whoever places the scene elsewhere.
- **Suggested fix:** refuse a non-zero origin as a setup error, or subtract the room's origin
  where positions are read; say which in C6.

> **Builder reply (lead):** fixed in `eb2b7fe`. A floor scene whose global transform is not the identity is a setup error and builds nothing; C6 says so (`616b3d9`).

**CR-5 🟡 `studio/design/combat.md` now contradicts the code.** Verified by reading.
- **Where:** `combat.md:160` ("Slides along walls, no pathfinding"), `:172` (caster movement).
- **Problem:** D-012 changed how every enemy walks; the binding Combat doc still describes the
  old behaviour. `PHASE1.md` still lists F-011 as "Not started".
- **Suggested fix:** update the movement lines to point at D-012. §10 Q4(b) (a brute that
  charges a pillar and stuns itself is a free punish) deserves an explicit answer at Gate B.

> **Builder reply (lead):** fixed in `616b3d9`: the chaser and caster movement lines in `combat.md` now point at D-012 and F-011 §10 Q4. `PHASE1.md` is Direction's and was not touched; Lucas has been told its rows are stale.

**CR-6 🔵 "Cleared" can go stale after a sim restore.** Verified by running.
`floor_scene.gd:53`, `room.gd:100`: the door and `FloorRun._room_cleared` latch on the first
clear. A snapshot taken with the enemy alive and restored after the clear leaves the enemy
alive and the door open. No key reaches this in the floor scene.

> **Builder reply (lead):** not changed. Nothing restores a sim snapshot in a floor room (the debug scenes with restore keys are F-003 to F-009's, not the floor scene), so the latch can't go stale today. It is noted here for whoever adds restore to a room.

**CR-7 🔵 The boss room's door opens onto nothing.** Verified by running. After the boss dies
the door opens, `advance()` is refused, and the player can walk out of the grid.

> **Builder reply (lead):** not changed here. F-012 uses the opened boss door as the way back to town (`floor_exited`); in F-011's own debug scenes the player can still walk out, which harms nothing.

**CR-8 🔵 A `FloorRun` snapshot doesn't say which floor it is.** From reading.
`floor_run.gd:108`, `:129`: a floor 3 snapshot is accepted by a floor 2 run when the room
index fits (G7).

> **Builder reply (lead):** fixed in `85d7646`. The snapshot has `floor_number`; a missing, non-int or different one is refused and changes nothing. C13 says so (`616b3d9`).

**CR-9 🔵 `GLOSSARY.md` has no entry for room, exit, room clear, floor run or nav grid.**

> **Builder reply (lead):** fixed on the F-012 branch, where the glossary already gained Floor, Room, Safe room and Town: exit, room clear, floor run and nav grid are added there, to avoid two branches appending to the same lines.

**CR-10 🔵 A bad enemy file is found only when its room is built.** Suspected, from reading.
`FloorScene._collect_setup_errors()` validates rooms, not their `EnemyData`. The room's
`CombatRunner` then stops itself and logs, but the floor keeps ticking: a frozen room with a
locked door and nothing on the label.

> **Builder reply (lead):** not changed (🔵). Shipped enemy files are validated by their own data tests, and in the game the debug label is hidden; a floor-setup check belongs with content tooling.

**Not checked in this round:** anything by hand (keyboard, gamepad, a rendered frame; feel,
room sizes, the heal, the camera); a moving player in the soak runs; debug scenes `f001`–`f009`
(untouched by the diff, not run).

---

## 10. Open Questions  ·  _Anyone (append)_

| # | Raised by | Question | Blocking? | Answer (Lucas/Planner) |
|---|---|---|---|---|
| Q1 | Lead | → Combat: hits ignore walls (circle–sector in core). C16's "no thin walls" keeps 1-tile walls out of rooms, but a 2-tile pillar corner can still be clipped by a long sector (Warden overhead 2.0 tiles). Accept for phase 1, or make hits respect line of sight? | no | |
| Q2 | Lead | → Combat: a caster with no clear line still shoots (its bolt hits the wall). Kept on purpose: walls are cover. Should it reposition instead? | no | |
| Q4 | Lead | → Combat: found in T5's scene tests. (a) A caster inside its stop distance (6 tiles) never routes: behind a wall it holds and shoots the wall for as long as the player stays put. Not a softlock (the player can walk to it), but it never repositions for a clear line. (b) A brute whose target is 3–7 tiles away behind a pillar charges the pillar and stuns itself, then walks round. Both follow from C3 (attack choice ignores walls). Keep as cover play, or teach attack choice about line of sight? | no | |
| Q3 | Lead | → Lucas: starting values to judge at Gate B — heal 30 %, room sizes, enemy counts per room (`studio/design/floors.md`). | no | |
| Q5 | Lead | → Lucas: should "`P` and `E` sit on opposite sides of the room" be enforced by validation? It was listed as enforced when you gave Gate A and is a guideline now (DEV-8, review CR-1). All 15 shipped rooms comply. Enforcing it means defining "opposite" (opposite walls only?) and limits rooms like a loop or an L. | no | |

---

## 11. Director Notes  ·  _Lucas_

<Overrides, priorities, gut calls. Everyone obeys these.>
