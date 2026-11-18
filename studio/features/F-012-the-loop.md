---
id: F-012
title: The loop — town, tower gate, boss as gate, death returns to town, bare HUD, main scene
status: IN_PROGRESS      # DRAFT | PLAN_REVIEW | PLAN_CHANGES | APPROVED | IN_PROGRESS | CODE_REVIEW | CODE_CHANGES | DONE | PARKED
owner_now: Builder       # who must act next: Planner | Auditor | Builder | Lucas
created: 2026-11-18
updated: 2026-11-18
depends_on: [F-011, D-005, D-006, D-010, D-012, D-013]
pillars: [1]
department: Floors       # studio/design/floors.md
---

# F-012 — The loop

> **How to use this file.** This is the single source of truth for this feature.
> Every agent reads the WHOLE file before acting. Write only in the sections you own
> (see studio/README.md). Never delete another role's text — reply under it.
>
> **This feature runs under D-013:** the lead (Claude Code) wrote §1–§6 and gates the work;
> up to two implementer sub-agents write code; only the lead commits and writes §8.
> The branch is stacked on `feature/F-011-floor-structure`, which is still in code review.

---

## 1. Goal  ·  _Planner_

**Player-facing outcome (one sentence):**
Starting the game puts the player in a town; the tower gate lists the floors they have
unlocked; a floor is walked to its boss; killing the boss opens the way back to town with the
next floor unlocked; dying returns to town, and a boss already reached can be re-entered
directly.

**Why now:** F-011 made floors walkable, but only from debug scenes and with no consequence.
This is slice 2 of the road to a playable loop: floors 1–3 end to end from `scenes/main.tscn`.
It merges three rows of `PHASE1.md`: F-012 (progression), F-013 (minimal town) and the
"health, floor number" part of F-015 (HUD).

**Out of scope (explicitly):**
- Save/load to disk. Progress lives for one run of the game; it only has to be serializable (G7).
- Title screen, pause menu, a designed death screen, settings (slice 3 / F-015).
- Loot, currency, NPCs, shops, anything else in the town (F-014 and phase 2).
- Leaving a floor on purpose in the middle of a run (§10 Q1).
- Fades, transitions, sprites, audio. Everything stays placeholder shapes and plain labels.
- Any change to combat rules, enemy data, room layouts of floors 1–3, or the heal rule.
- Character creation and more than one character (D-005 says progress is per character; there
  is one character).

---

## 2. Context  ·  _Planner_

- **What F-011 left:** `FloorScene` (`src/world/floors/floor_scene.gd`) walks one `FloorData`
  room by room with a `FloorRun` (core). Death restarts the room (placeholder). A cleared boss
  room emits `floor_cleared` and then nothing happens. `scenes/main.tscn` holds only the debug
  overlay.
- **A room is built by `Room`** (`src/world/floors/room.gd`) from a `RoomData`: walls, a door
  over the `E` tiles, the player, the enemies and a new `CombatRunner`. The player has no tick
  of its own: the room's `CombatRunner` steps it. So the town is a `Room` too (no enemies).
- **Nothing lies beyond an open door.** In a floor, standing on an `E` tile swaps the room at
  once. Whatever stands on an `E` tile and is not swapped can walk off the map.
- **D-006 (death):** return to town; cleared floors stay cleared; once a floor's boss room was
  reached the character may re-enter that floor directly at the boss. Per character.
- **Decided by Lucas on 2026-11-18 (chat):** the town is one room with a tower gate; walking
  into the gate opens a plain list of unlocked floors, with "from the start" and, where the
  boss room was reached, "at the boss"; cleared floors can be replayed; when a boss dies a
  door opens that leads back to town with the next floor unlocked.
- **Tooling on Windows:** as in F-011 §2 (`GODOT_BIN`, `.venv/Scripts/gdlint`).
- Design doc: `studio/design/floors.md` (sections "The tower loop" and "Town"; binding).

---

## 3. Options Considered  ·  _Planner_

### ✅ Chosen: a core `TowerSession` decides; one `Game` node shows what it says
- **How it works:** `TowerProgress` (core) holds which floors are cleared and which boss rooms
  were reached. `TowerSession` (core) holds where the character is (town, floor, death pause)
  and is the only thing that changes progress. The glue reports events to it (room entered,
  floor cleared, exit reached, player died) and, on its own next tick, shows the place the
  session says: a `TownScene` or a `FloorScene`. The town is a `RoomData` marked safe, built
  by the same `Room`. The gate is the town's `E` tiles; a core `TownGate` latch decides when
  the list opens.
- **Why chosen:** every rule of the loop is pure logic with tests and can run on a server (G6);
  the whole state is one dictionary (G7); town and floors share one room format (D-012).
- **Costs we're accepting:** scene changes are hard cuts one tick after the event; the town is
  as plain as a combat room; the HUD is three widgets.
- **Would revisit if:** the town needs NPCs or more than one screen, or co-op needs players in
  different places.

### ❌ Rejected: `get_tree().change_scene_to_file()` between town and floor scenes
- **How it would work:** each place is its own main scene; progress sits in an autoload.
- **Why rejected:** the rules would live in an autoload node, the HUD would be rebuilt or
  duplicated per scene, and tests could not drive the loop in one tree.
- **Tempting because:** it is the tutorial way.

### ❌ Rejected: one door per floor in the town; a gate with no choice
- Decided by Lucas 2026-11-18: a floor list at the gate. Doors don't scale to 100 floors; no
  choice means no replay and no way to redo the rooms before a boss.

### ❌ Rejected: the boss room's door leads straight to the next floor; two doors
- Decided by Lucas 2026-11-18: back to town after every boss.

### ❌ Rejected: restart the floor or the room on death in the real game
- D-006. `FloorScene` keeps the room restart only as a debug-scene default.

### ❌ Rejected: physics `Area2D` for the gate; an `interact` prompt
- **Why rejected:** the gate is decided from the player's logic position, like the floor exit
  (F-011/C10, G6). A prompt needs UI that slice 3 owns.
- **Tempting because:** two lines of code.

### ❌ Rejected: freeing the shown scene inside one of its own signals
- **How it would work:** `Game` swaps scenes in the handler of `floor_exited` or `player_died`.
- **Why rejected:** the scene being freed is still running the function that emitted.
- **Tempting because:** no pending state to keep.

---

## 4. Constraints  ·  _Planner_

| ID | Constraint | Reason |
|---|---|---|
| C1 | Everything under `src/core/` extends `RefCounted` or `Resource` and passes `tools/check_core_purity`. | G6 |
| C2 | **Every rule of the loop is decided in core.** Unlocking, boss reached, which entries the gate lists, whether a floor may be entered, when death sends the player to town, when the gate list opens: `TowerProgress`, `TowerSession`, `TownGate`. The glue only reports events and shows results. | G6 |
| C3 | Floor `n` is unlocked when `n == 1` or floor `n − 1` is cleared. A floor's boss room counts as reached the moment that room is entered. Clearing a floor also marks its boss reached. Marks on a locked or unknown floor are refused. Nothing ever un-clears or un-reaches. | Pillar 1, D-006 |
| C4 | `TowerSession.enter_floor(n, at_boss)` succeeds only from the town, only for an unlocked floor, and with `at_boss` only if that boss room was reached. `at_boss` starts in the floor's last room; otherwise room 0. Either way the player starts at full HP. | D-006 |
| C5 | Death: `report_player_died()` moves the session to `DEATH_PAUSE` for `death_return_delay` seconds of ticked time, then to the town. Progress made before the death is kept. If the player and the boss die in the same tick, the death counts and the floor is not cleared. | D-006 |
| C6 | Leaving a floor: only through the exit of its cleared boss room (`report_floor_exited()` is refused otherwise). The session then goes to the town. | Lucas, 2026-11-18 |
| C7 | `TowerProgress` and `TowerSession` have `to_dict()` / `from_dict()`. A snapshot that doesn't fit (wrong floor count, a cleared floor above an uncleared one, a boss reached on a locked floor, a cleared floor whose boss isn't reached, unknown place, floor out of range) is refused and changes nothing. | G7 |
| C8 | The town is a `RoomData` with `is_safe_room = true`: no spawns, no enemies, never a boss room. `FloorData.validate()` refuses a safe room inside a floor. All other room rules (F-011/C16) apply to the town unchanged. Its `E` run is the tower gate. | D-012: one room format |
| C9 | `TowerData` (`data/floors/tower.tres`) lists the town and the floors in order; `floors[i].floor_number == i + 1`; room ids are unique across the tower. Invalid data is refused, never repaired: `Game` and `TownScene` build nothing and log every error. | G9, F-011/C8 |
| C10 | The gate list opens when the player's logic position enters a gate tile (`TownGate.check()`), once per entry: it can't open again until the player has been off the gate tiles. While the list is open the player takes no input and doesn't move. Closing it without a choice puts the player back on the walkable tile just inside the gate. | G6; nothing lies beyond a door |
| C11 | **No behaviour change for F-011's scenes.** `FloorScene`'s new exports default to F-011's behaviour (`death_restarts_room = true`, `debug_keys_enabled = true`, `debug_label_visible = true`). No existing test file is edited, except `tests/test_input_map.gd` if an input action is added (none is planned). All 1135 tests on the F-011 branch stay green. | Regression safety |
| C12 | `Game` never frees or replaces the scene it shows from inside a signal of that scene. Handlers only report to the session; `Game._physics_process` (physics priority 2, after `FloorScene`'s 1) compares what is shown with what the session says and rebuilds then. | Freed-while-running crashes |
| C13 | The HUD decides nothing and nothing reads it. It reads the player's `CombatState` through a provider every frame (the player node is rebuilt every room), so it can't go stale. | G6 |
| C14 | All numbers are data: `data/tunables/tower.tres` (`TowerTunables`: `death_return_delay`, `banner_duration`). Placeholder sizes, positions and colours of HUD and menu are `@export`s. | G2 |
| C15 | New asset/data paths used from code are constants (`Tunables.*_PATH` or a `const` in the script). | G5 |
| C16 | Player-facing strings (banners, menu entries, location text) are constants or built by one static function each, never scattered literals. | Lore/localisation later |
| C17 | Debug keys work in the game only while `Game.debug_keys_enabled` (default on for now): in a floor, `debug_next_room` (N) and `debug_reset` (R) as in F-011; in the town, `debug_next_room` marks the highest unlocked floor's boss reached and the floor cleared. | G3; no save yet, so testing floor 3 needs a shortcut |
| C18 | Sub-agents never run `git` commands that change state, never edit `studio/`, `tools/`, `addons/`, or files outside their task's list, and never use a worktree. | D-013 |
| C19 | Static typing everywhere; `gdlint` and `gdformat --check` clean; one `class_name` per file. | PROJECT.md code style |

**Must not break:** every debug scene `f001`–`f011`, all 1135 existing tests, the heal rule,
the F5 reload in debug scenes, snapshots.

---

## 5. Acceptance Criteria  ·  _Planner_

**Data and gate latch (T1)**
- [ ] AC1: `TowerTunables.validate()` rejects a negative `death_return_delay` and a negative `banner_duration`; the shipped `tower.tres` tunables pass. `Tunables.tower` exists.
- [ ] AC2: A safe room with no spawns and no enemies passes `RoomData.validate()`. A safe room with a spawn, with a non-empty `enemies`, or that is also a boss room is rejected with a message naming the rule. Every F-011 rule still applies to it (one test: a safe room without `P` is rejected). A non-safe room behaves exactly as before.
- [ ] AC3: `FloorData.validate()` rejects a floor containing a safe room, naming the room.
- [ ] AC4: `TowerData.validate()` rejects: no town, a town that isn't a safe room, no floors, a null floor, a `floor_number` that isn't its position + 1, a room id used twice across the tower; and prefixes town errors with `town:` and floor errors with `floor <n>:`. `get_floor()` returns null outside 1…count.
- [ ] AC5: `TownGate.check()` returns true exactly once when the position enters a gate tile, false while it stays there, false off the gate, and true again after the position has left and re-entered. `get_return_position_tiles()` is the centre of the walkable tile inward of the nearest gate tile, for a gate on each of the four borders.

**Progress and session (T2)**
- [ ] AC6: Fresh `TowerProgress` of 3 floors: only floor 1 is unlocked, nothing is cleared or reached, `get_entries()` is one entry (floor 1, from the start). After `mark_boss_reached(1)`: two entries for floor 1. After `mark_floor_cleared(1)`: floor 2 is unlocked, `floor_unlocked(2)` was emitted once, entries are floor 1 start, floor 1 boss, floor 2 start, in that order, and floor 1's entries say cleared.
- [ ] AC7: `mark_boss_reached` and `mark_floor_cleared` return false and change nothing for a locked floor, floor 0 and floor count + 1; a second identical mark returns false and emits nothing; clearing the last floor emits no `floor_unlocked`.
- [ ] AC8: `TowerProgress.to_dict()` → `from_dict()` on a fresh object reproduces every query. Each misfit of C7 is refused and changes nothing (one test each).
- [ ] AC9: `TowerSession` starts in `TOWN` with floor number 0. `enter_floor` follows C4 (one test per refusal, including a call while already on a floor), sets `get_floor_number()`, `get_start_room()` and `get_floor_data()`, and emits `place_changed(FLOOR)` once.
- [ ] AC10: `report_room_entered(index)` marks the boss reached only when that room is the floor's boss room; `report_floor_cleared()` marks the floor cleared and emits `floor_cleared(n, newly_unlocked)` with `newly_unlocked` = n + 1 the first time, 0 on a replay and 0 for the last floor.
- [ ] AC11: `report_floor_exited()` returns false before the floor was cleared in this run and true after, moving to `TOWN`. Reports made in the wrong place (town, death pause) change nothing.
- [ ] AC12: `report_player_died()` → `DEATH_PAUSE`; `tick()` in steps of 1/30, 1/60 and 1/120 s all reach `TOWN` within one step of `death_return_delay`; with a delay of 0 the next `tick()` reaches the town. A boss reached before dying is still reached after. A second `report_player_died()` during the pause doesn't restart the timer.
- [ ] AC13: `TowerSession.to_dict()` → `from_dict()` reproduces place, floor, start room, the time left in a death pause and the progress; a misfit is refused and changes nothing.

**Floor scene (T3)**
- [ ] AC14: With the default exports every F-011 scene test passes unchanged. With `death_restarts_room = false`, a dead player makes `FloorScene` emit `player_died` exactly once; the room is not rebuilt; after it no heal, door opening, room swap or `floor_exited` happens, even if the last enemy dies later.
- [ ] AC15: In the cleared boss room, a player standing on an exit tile makes `FloorScene` emit `floor_exited(floor_number)` exactly once (standing there longer emits nothing more). It is never emitted in an uncleared room or a non-boss room.
- [ ] AC16: With `debug_keys_enabled = false`, N and R do nothing. With `debug_label_visible = false` the debug label is hidden. Player and boss dying in the same tick with `death_restarts_room = false`: `player_died` is emitted, `floor_cleared` is not.

**HUD (T4)**
- [ ] AC17: `HealthBar` shows the provider's player: `get_fill_fraction()` and `get_label_text()` (`HP 70 / 100`) follow a hit on the next frame; a provider that returns null or a freed player gives fraction 0 and an empty label, with no error; after the provider starts returning a new player the bar shows that one.
- [ ] AC18: `Hud.location_text()` gives `Town` for floor 0, `Floor 2 · Room 3 / 5` for a combat room and `Floor 2 · Boss` for a boss room; `set_location()` shows it.
- [ ] AC19: `show_banner(text, duration)` shows the text; it hides after `duration` seconds of `_process` time; a new banner replaces the old one and restarts the time; `duration` 0 hides it on the next frame.

**Town (T5)**
- [ ] AC20: A `TownScene` built from a fixture safe room has the walls, the player at `P` at full HP, no enemies, a `CombatRunner` with no setup errors, and its gate body has no collision. A scripted player can walk around. An invalid town room builds nothing and reports the errors.
- [ ] AC21: Walking the scripted player onto a gate tile opens the gate menu within one tick, listing exactly `TowerProgress.get_entries()` in order plus a last "stay" entry. While it is open the player's position doesn't change over 60 ticks even with move commands held by real input (input is off).
- [ ] AC22: Choosing an entry emits `floor_chosen(floor_number, at_boss)` once and closes the menu. Closing without choosing (the stay entry or `ui_cancel`) emits nothing, puts the player on `TownGate.get_return_position_tiles()`, gives input back, and the menu doesn't reopen until the player has left and re-entered the gate.
- [ ] AC23: `GateMenu`: entry text comes from one static function (`Floor 1 — from the start`, `Floor 1 — at the boss`, with ` (cleared)` appended for a cleared floor); focus starts on the last floor entry; `move_up` / `move_down` and `ui_up` / `ui_down` move the focus; `ui_accept` or `interact` chooses.
- [ ] AC24: In the town, with debug keys on, `debug_next_room` (N) clears the highest unlocked floor in the injected progress; with them off it does nothing.

**Shipped data (T6)**
- [ ] AC25: `data/floors/town.tres` is a safe room that passes validation and matches `floors.md` "Town" (size, gate on the north border, `P` in the lower half). `data/floors/tower.tres` holds that town and floors 1, 2, 3 in order and passes `TowerData.validate()` with the shipped tunables. `Tunables.TOWN_PATH` and `Tunables.TOWER_PATH` exist.

**The game (T7)**
- [ ] AC26: `scenes/main.tscn` starts in the town with the HUD showing `Town` and full HP, no setup errors, and still holds the debug overlay.
- [ ] AC27: Full loop on a fixture tower, scripted, in one test: gate → floor 1 from the start → rooms cleared → entering the boss room marks it reached → the player dies → a "You died" banner, the floor scene still shown during the pause → town at full HP → the list now offers floor 1 at the boss → chosen: the boss room at full HP → the boss dies → banner naming the cleared and the unlocked floor → the exit → town → the list offers floor 2.
- [ ] AC28: Clearing the last floor shows the "no floor above yet" banner, unlocks nothing, and the exit still returns to town.
- [ ] AC29: The HUD location follows every room and place change; the health bar shows the current room's player in every room and in the town (never a freed one).
- [ ] AC30: No scene is freed inside its own signal: the swap happens in `Game._physics_process` on the tick after the report (a test checks the old scene is still valid inside the handler of `floor_exited` and `player_died`, and gone one tick later).
- [ ] AC31: With the shipped tower: every floor can be entered from the start and at the boss (after the debug unlock), with no setup errors, and each boss room's exit returns to town after the boss is killed.
- [ ] AC32: An invalid `TowerData` builds nothing and logs each error; `get_setup_errors()` returns them.

**Gates for every task (the lead runs them before committing):**
1. The task's new tests pass.
2. Full `tools/test`: every test passes, and no test on the F-011 branch was changed or removed.
3. `.venv/Scripts/gdlint src tests` and `.venv/Scripts/gdformat --check src tests` are clean.
4. `tools/check_core_purity` says ok.
5. `git status` shows only files in the task's list.
6. The lead read the diff against §3 Rejected and §4.

**How to verify manually (Lucas, Gate B):** open the project, press F5 (runs `main.tscn`).
You start in the town. Walk up into the gate: the list shows only floor 1. Enter it, fight to
the Warden, die on purpose: you are back in town after a short "You died", and the gate now
offers "Floor 1 — at the boss". Kill the Warden, walk out of the opened door: the town again,
with floor 2 in the list. `N` skips a room in a floor and unlocks the next floor in the town.
Judge: does the loop read without explanation, is the death pause the right length, is going
back to town after each boss right, is the HUD enough to know where you are.

---

## 6. Task Breakdown  ·  _Planner_

Two implementers at most, on disjoint files. A wave starts after the one before is committed.

| # | Wave · who | Task | Files (the task's whole list) |
|---|---|---|---|
| T1 | 1 · A | `TowerTunables`, safe rooms, `TowerData`, `TownGate` + tests | `src/core/tunables/tower_tunables.gd`, `data/tunables/tower.tres`, `src/autoload/tunables.gd` (add `TOWER_TUNABLES_PATH`, `tower`), `src/core/floors/room_data.gd`, `floor_data.gd`, `tower_data.gd`, `town_gate.gd`, `tests/core/floors/tower_fixtures.gd`, `test_tower_tunables.gd`, `test_safe_room.gd`, `test_tower_data.gd`, `test_town_gate.gd` |
| T2 | 1 · A (after T1) | `TowerEntry`, `TowerProgress`, `TowerSession` + tests | `src/core/floors/tower_entry.gd`, `tower_progress.gd`, `tower_session.gd`, `tests/core/floors/test_tower_progress.gd`, `test_tower_session.gd` |
| T3 | 1 · B | `FloorScene`: death and exit signals, debug switches + tests | `src/world/floors/floor_scene.gd`, `tests/scenes/test_f012_floor_scene.gd` |
| T4 | 1 · B (after T3) | HUD: health bar, location, banner + tests | `src/ui/hud/hud.gd`, `hud.tscn`, `health_bar.gd`, `tests/ui/test_hud.gd` |
| T5 | 2 · A | `TownScene`, `GateMenu`, scene test helper + tests | `src/world/town/town_scene.gd`, `town_scene.tscn`, `src/ui/town/gate_menu.gd`, `gate_menu.tscn`, `tests/scenes/f012_scene_test.gd`, `test_f012_town.gd`, `tests/ui/test_gate_menu.gd` |
| T6 | 2 · B | Shipped town and tower, path constants, data tests | `data/floors/town.tres`, `data/floors/tower.tres`, `src/autoload/tunables.gd` (add `TOWN_PATH`, `TOWER_PATH`), `tests/core/floors/test_shipped_tower.gd` |
| T7 | 3 · one | `Game`, `main.tscn`, town debug scene, end-to-end tests, README note | `src/world/game.gd`, `game.tscn`, `scenes/main.tscn`, `scenes/debug/f012_town.tscn`, `tests/scenes/test_f012_game.gd`, `test_f012_main.gd`, `README.md` |

**Contracts (binding — every wave builds against these names):**

```gdscript
# src/core/tunables/tower_tunables.gd  →  data/tunables/tower.tres  →  Tunables.tower
class_name TowerTunables extends Resource
@export var death_return_delay: float = 1.5   # seconds between the death and the town
@export var banner_duration: float = 2.5      # seconds a HUD banner stays
func validate() -> PackedStringArray

# src/core/floors/room_data.gd  (added)
@export var is_safe_room: bool = false        # C8
# src/core/floors/floor_data.gd: validate() refuses a safe room (C8)

# src/core/floors/tower_data.gd
class_name TowerData extends Resource
@export var town: RoomData
@export var floors: Array[FloorData]
func get_floor_count() -> int
func get_floor(floor_number: int) -> FloorData        # null outside 1..count
func validate(rules: FloorTunables) -> PackedStringArray

# src/core/floors/town_gate.gd
class_name TownGate extends RefCounted
func setup(room: RoomData) -> void                     # gate tiles = the room's exit tiles
func check(player_position_tiles: Vector2) -> bool     # true once per entry (C10)
func get_return_position_tiles(player_position_tiles: Vector2) -> Vector2

# src/core/floors/tower_entry.gd
class_name TowerEntry extends RefCounted
var floor_number: int
var at_boss: bool
var is_cleared: bool

# src/core/floors/tower_progress.gd
class_name TowerProgress extends RefCounted
signal floor_unlocked(floor_number: int)
func setup(floor_count: int) -> void
func get_floor_count() -> int
func is_floor_unlocked(floor_number: int) -> bool
func is_floor_cleared(floor_number: int) -> bool
func is_boss_reached(floor_number: int) -> bool
func get_highest_unlocked() -> int
func mark_boss_reached(floor_number: int) -> bool      # true only if it changed something
func mark_floor_cleared(floor_number: int) -> bool     # also marks the boss reached
func get_entries() -> Array[TowerEntry]                # floors ascending; start before boss
func to_dict() -> Dictionary
func from_dict(snapshot: Dictionary) -> bool

# src/core/floors/tower_session.gd
class_name TowerSession extends RefCounted
enum Place { TOWN, FLOOR, DEATH_PAUSE }
signal place_changed(place: Place)
signal floor_cleared(floor_number: int, newly_unlocked: int)   # 0 = nothing new
func setup(tower: TowerData, rules: TowerTunables) -> void     # TOWN, fresh progress
func get_progress() -> TowerProgress
func get_place() -> Place
func get_floor_number() -> int                          # 0 in the town
func get_floor_data() -> FloorData                      # null in the town
func get_start_room() -> int
func enter_floor(floor_number: int, at_boss: bool) -> bool
func report_room_entered(room_index: int) -> void
func report_floor_cleared() -> void
func report_floor_exited() -> bool
func report_player_died() -> void
func tick(delta: float) -> void
func get_death_time_left() -> float
func to_dict() -> Dictionary
func from_dict(snapshot: Dictionary) -> bool

# src/world/floors/floor_scene.gd  (added; defaults keep F-011's behaviour, C11)
signal player_died
signal floor_exited(floor_number: int)
@export var death_restarts_room: bool = true
@export var debug_keys_enabled: bool = true
@export var debug_label_visible: bool = true

# src/ui/hud/health_bar.gd
class_name HealthBar extends Control
var player_provider: Callable                           # () -> Player, may return null
func get_fill_fraction() -> float
func get_label_text() -> String

# src/ui/hud/hud.gd  +  hud.tscn   (root: CanvasLayer)
class_name Hud extends CanvasLayer
var player_provider: Callable                           # passed on to the HealthBar
static func location_text(floor_number: int, room_index: int, room_count: int, is_boss_room: bool) -> String
func set_location(text: String) -> void
func get_location() -> String
func show_banner(text: String, duration: float) -> void
func is_banner_visible() -> bool
func get_banner_text() -> String
func get_health_bar() -> HealthBar

# src/ui/town/gate_menu.gd  +  gate_menu.tscn   (root: Control)
class_name GateMenu extends Control
signal entry_chosen(floor_number: int, at_boss: bool)
signal closed                                           # closed without a choice
static func entry_text(entry: TowerEntry) -> String
func open(entries: Array[TowerEntry]) -> void
func close() -> void                                    # no signal
func is_open() -> bool
func get_entry_count() -> int                           # without the stay entry
func choose(index: int) -> void                         # what a click on entry `index` does
func cancel() -> void                                   # what the stay entry / ui_cancel does

# src/world/town/town_scene.gd  +  town_scene.tscn   (root: Node2D)
class_name TownScene extends Node2D
signal floor_chosen(floor_number: int, at_boss: bool)
@export var town_room: RoomData
@export var class_data: ClassData                       # null takes the Warrior
@export var player_input_enabled: bool = true
@export var debug_keys_enabled: bool = true
@export var floor_count: int = 3                        # used only when no progress was injected
func set_progress(progress: TowerProgress) -> void      # call before the node enters the tree
func get_progress() -> TowerProgress
func get_room() -> Room
func get_gate_menu() -> GateMenu
func get_setup_errors() -> PackedStringArray

# src/world/game.gd  +  game.tscn   (root: Node)
class_name Game extends Node
@export var tower_data: TowerData                       # null loads Tunables.TOWER_PATH
@export var class_data: ClassData
@export var player_input_enabled: bool = true
@export var debug_keys_enabled: bool = true
func get_session() -> TowerSession
func get_town() -> TownScene                            # null while a floor is shown
func get_floor_scene() -> FloorScene                    # null while the town is shown
func get_hud() -> Hud
func get_player() -> Player                             # the shown room's player, or null
func get_setup_errors() -> PackedStringArray
```

---

## 7. Plan Review  ·  _Auditor_

_Skipped for this feature by Lucas's instruction (D-013). The code review (§9) still runs._

---

## 8. Implementation Log  ·  _Builder_

**Started:** 2026-11-18  ·  **Branch:** `feature/F-012-the-loop` (cut from
`feature/F-011-floor-structure` at `a864404`)

### Progress
- [ ] T1
- [ ] T2
- [ ] T3
- [ ] T4
- [ ] T5
- [ ] T6
- [ ] T7

### Deviations from plan
- DEV-1: This file went straight to `IN_PROGRESS`; `APPROVED` was never written and the
  Auditor's plan review didn't run. — **Why:** Lucas gave Gate A in chat on 2026-11-18 ("now
  i need you to begin slice 2", then chose "Stack on F-011 now"), and only Lucas or
  `tools/studio` may write `APPROVED`. — **Impact:** D-013 records the exception.
- DEV-2: The branch is cut from `feature/F-011-floor-structure`, not `main`, while F-011 is
  still at `CODE_REVIEW`. — **Why:** Lucas's choice (D-013). — **Impact:** if F-011's review
  changes its code, this branch is rebased on it; the Auditor should review F-011 first and
  read this branch as the diff from `a864404`.
- DEV-3: Implementer sub-agents write files. — **Why:** D-013. — **Impact:** the lead gates
  and commits every task.

### Assumptions made (small, reversible)
- ASSUMPTION-1: one feature covers `PHASE1.md`'s F-012, F-013 and the health/floor part of
  F-015 — **Why:** Lucas chose "one feature, F-012 'The loop'".
- ASSUMPTION-2: entering a floor always starts at full HP, from the start or at the boss —
  **Why:** the town has no healing to offer yet, and F-011 enters boss rooms at full HP.
- ASSUMPTION-3: the death pause is 1.5 s with a plain "You died" banner — **Why:** a designed
  death screen is slice 3; an instant cut to town reads as a bug.
- ASSUMPTION-4: replaying a cleared floor is allowed and gives nothing — **Why:** Lucas chose
  replay; rewards arrive with loot (F-014).
- ASSUMPTION-5: debug keys stay on in `main.tscn` — **Why:** no save yet; without `N` every
  session would need the Warden and the Hexer killed to reach floor 3.

### Things the Auditor should look at closely

### How to test

---

## 9. Code Review  ·  _Auditor_

---

## 10. Open Questions  ·  _Anyone (append)_

| # | Raised by | Question | Blocking? | Answer (Lucas/Planner) |
|---|---|---|---|---|
| Q1 | Lead | → Lucas: there is no way to leave a floor in the middle of a run except dying. Wanted before the pause menu exists (slice 3), e.g. a "return to town" key? | no | |
| Q2 | Lead | → Lucas (Gate B): values to judge — death pause 1.5 s, banner 2.5 s, town size, back to town after every boss. | no | |
| Q3 | Lead | → Direction: `PHASE1.md` rows F-012, F-013 and part of F-015 are built here as one feature; later rows need renumbering. F-011's row still says "Not started". | no | |
| Q4 | Lead | → Art & Game Feel: look of the health bar, location text, banners and the gate list (all placeholders; FX1, CX8). | no | |

---

## 11. Director Notes  ·  _Lucas_

<Overrides, priorities, gut calls. Everyone obeys these.>
