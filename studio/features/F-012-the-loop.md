---
id: F-012
title: The loop — town, tower gate, boss as gate, death returns to town, bare HUD, main scene
status: CODE_REVIEW      # DRAFT | PLAN_REVIEW | PLAN_CHANGES | APPROVED | IN_PROGRESS | CODE_REVIEW | CODE_CHANGES | DONE | PARKED
owner_now: Lucas         # who must act next: Planner | Auditor | Builder | Lucas
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
| C5 | Death: `report_player_died()` moves the session to `DEATH_PAUSE` for `death_return_delay` seconds of ticked time, then to the town. Progress made before the death is kept. If the player and the boss die in the same tick, the death counts and the floor is not cleared. From the reported death until the town, the player takes no input and the floor's debug keys do nothing (review round 1, CR-4). | D-006 |
| C6 | Leaving a floor: only through the exit of its cleared boss room (`report_floor_exited()` is refused otherwise). The session then goes to the town. | Lucas, 2026-11-18 |
| C7 | `TowerProgress` and `TowerSession` have `to_dict()` / `from_dict()`. A snapshot that doesn't fit (wrong floor count, a cleared floor above an uncleared one, a boss reached on a locked floor, a cleared floor whose boss isn't reached, unknown place, floor out of range) is refused and changes nothing. The session's snapshot includes whether the floor was cleared during this visit; that flag may be true only on a floor (review round 1, CR-5). | G7 |
| C8 | The town is a `RoomData` with `is_safe_room = true`: no spawns, no enemies, never a boss room. `FloorData.validate()` refuses a safe room inside a floor. All other room rules (F-011/C16) apply to the town unchanged. Its `E` run is the tower gate. | D-012: one room format |
| C9 | `TowerData` (`data/floors/tower.tres`) lists the town and the floors in order; `floors[i].floor_number == i + 1`; room ids are unique across the tower. Invalid data is refused, never repaired: `Game` and `TownScene` build nothing and log every error. The town scene, like the floor scene (F-011/C6), must sit at the world origin with no rotation or scale: positions are read from global positions against the room's own tiles, and any other placement is a setup error (review rounds 1 and 2, CR-13). | G9, F-011/C8 |
| C10 | The gate list opens when the player's logic position enters a gate tile (`TownGate.check()`), once per entry: it can't open again until the player has been off the gate tiles. Opening the list **engages** the gate (state in `TownGate`): while it is engaged the player takes no input and is held on the position they had when it engaged, every tick, also through a dash. Closing the list without a choice releases the gate, puts the player back on the walkable tile just inside it, and gives input back on the next physics tick, after the room's runner has run, or later if a dash was running or buffered when the list closed: the player is kept on that tile until it has ended. So the key that closed the list can't also act in the room (review round 1, CR-1, CR-2, CR-9; round 2, CR-14). | G6; nothing lies beyond a door |
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
- [ ] AC21: Walking the scripted player onto a gate tile opens the gate menu within one tick, listing exactly `TowerProgress.get_entries()` in order plus a last "stay" entry. While the gate is engaged the player takes no input and stays exactly on the position they had when the list opened, checked over 60 ticks for a player who walked in and for one who dashed in (review round 1, CR-1).
- [ ] AC22: Choosing an entry emits `floor_chosen(floor_number, at_boss)` once and closes the menu. Closing without choosing (the stay entry or `ui_cancel`) emits nothing, puts the player on `TownGate.get_return_position_tiles()`, gives input back on the next tick (later if a dash is still running or buffered), and the menu doesn't reopen until the player has left and re-entered the gate. Closing it with a real Space key press (`ui_accept` and `dodge` at once) or a click doesn't make the player dodge or attack (review round 1, CR-2).
- [ ] AC23: `GateMenu`: entry text comes from one static function (`Floor 1 — from the start`, `Floor 1 — at the boss`, with ` (cleared)` appended for a cleared floor); focus starts on the last floor entry; `move_up` / `move_down` and `ui_up` / `ui_down` move the focus; `ui_accept` or `interact` chooses. A held stick moves the focus one step per push, not one per motion event (review round 1, CR-3): a push starts past the larger deadzone of its direction and ends inside the smaller one, and only the stick sets the stick's state (round 3, CR-15, CR-16). When the list opens the stick is read as it is: a direction it is already past the smaller deadzone in counts as pushed, so letting go of a stick that was held on arrival moves nothing (round 4, CR-18). On a gamepad A chooses and B cancels (round 3, CR-17).
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
func check(player_position_tiles: Vector2) -> bool     # true once per entry (C10); engages the gate
func is_engaged() -> bool                              # review round 1 (CR-1, CR-9)
func get_hold_position_tiles() -> Vector2              # where the player was when it engaged
func release() -> void                                 # not armed again until the player is off the gate
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
- [x] T1 — e54c02e
- [x] T2 — b586abd
- [x] T3 — b66cb36
- [x] T4 — 4381170, placement fix 5a280b0
- [x] T5 — 641fc54
- [x] T6 — d768146
- [x] T7 — 9216679
- [x] Review round 1 fixes — CR-1/CR-2/CR-9 add2f1b, CR-3/CR-10 6472012, CR-5 8de6c4c, CR-4 996fc6e, town origin ec5b964; F-011's round 1 fixes merged in 7f71ab5 (replies in §9)
- [x] Review round 2 fix — CR-3 a772a52; spec and log edits 19a57bf; F-011's round 2 merged in 8905f83
- [x] Review round 3 notes — CR-15, CR-16, CR-17 2f5cb54
- [x] Review round 4 fix — CR-18 983846b
- [x] Review round 5 note — CR-19 41760e4. Rounds: 1 changes requested, 2 changes requested, 3 approved with notes, 4 changes requested, 5 approved with notes.

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
- DEV-4 (superseded by DEV-12: AC21 was replaced again in review round 1 and now asks for an
  exact hold): AC21 was reworded by the lead before T5 started: "position doesn't change over 60
  ticks" became "after the motor's own deceleration the position doesn't change, and it ends
  at most 1 tile from where the menu opened". — **Why:** with input off the motor still
  decelerates; the first wording could not be met without a new stop rule in core. —
  **Impact:** none on the design (C10 is unchanged).
- DEV-6: `scenes/debug/f012_town.tscn` (in T7's file list) is not built. — **Why:** a town on
  its own has nothing to do after a floor is chosen (its input stays off for the owner to
  replace it, C12); `scenes/main.tscn` with the debug keys is the isolated scene for this
  feature (G3). — **Impact:** one file fewer; the town is covered by `test_f012_town.gd`.
- DEV-7: `GateMenu` has one public method the contract doesn't list, `get_focus_index()`, and
  `Game` has one, the static `cleared_banner_text()`. — **Why:** tests read the focus; the
  banner text is built in one place (C16). — **Impact:** none.
- DEV-8: the health bar moved from the top left (T4 as first built) to the bottom left, and its
  text was re-centred on the bar (`5a280b0`). — **Why:** the lead rendered `main.tscn`: the bar was
  drawn on top of the debug overlay's first line, and its label was 23 px tall on a 10 px bar.
  Headless tests could not see either. — **Impact:** tests now assert the bar and its text are
  on screen and overlap neither the overlay nor the boss bar.
- DEV-9: AC30 says the swap happens "on the tick after the report". It happens later in the
  **same** physics tick: `Game` (priority 2) runs after `FloorScene` (priority 1), once the
  handler has returned. — **Why:** that is what C12 asks for (never inside the signal); waiting
  a whole extra tick would add nothing. — **Impact:** none; the tests check "valid inside the
  handler, gone by the next tick".
- DEV-11: `tests/scenes/f012_game_test.gd` (a test helper class for T7) is not in §6's file
  list. — **Why:** the game tests needed their own helper on top of `F012SceneTest`; the lead
  put it in T7's brief and forgot the table. — **Impact:** none (review round 1, CR-11).
- DEV-12: after code review round 1 the lead amended C5, C7, C10, AC21, AC22, AC23 and the
  `TownGate` contract (each marked "review round 1"). — **Why:** CR-1, CR-2, CR-3, CR-4, CR-5
  and CR-9 showed the rules as written were incomplete. — **Impact:** `TownGate` gains an
  engaged state; the session snapshot gains one key.
- DEV-13: `TownScene` refuses any global transform but the identity as a setup error
  (`ec5b964`), a rule the spec did not have until review round 2 put it in C9 (CR-13). —
  **Why:** F-011's review found the same defect in the floor scene (its CR-4); the town builds
  its room the same way. — **Impact:** one more setup error; `Game` adds both scenes under a
  plain `Node`, so nothing shipped is affected.
- DEV-14: `project.godot` overrides two built-in actions: `ui_accept` gains pad A and
  `ui_cancel` gains pad B (their keys are listed again unchanged). — **Why:** review round 3,
  CR-17: in this project the built-ins had no pad button, so only Y chose in the gate list. —
  **Impact:** every focused `Control` in the project now answers pad A, which is the point;
  pad A is also `dodge`, covered by a town test. The override binds the keys to all devices
  where the built-ins bind one device: a superset. No game action was added or changed, and
  `tests/test_input_map.gd` is untouched; a new `tests/test_ui_input_map.gd` pins the two.
- DEV-10: one sentence of F-011's README paragraph was reworded (the floor debug scenes are no
  longer "placeholders until the loop is wired"). — **Why:** it became false. — **Impact:** none.
- DEV-5: `# gdlint:disable=max-public-methods` on six long test files
  (`test_tower_progress.gd`, `test_tower_session.gd`, `test_hud.gd`, `test_f012_town.gd`,
  `test_gate_menu.gd`, `test_shipped_tower.gd`). — **Why:** gdlint's cap
  is 20; same precedent as F-011 DEV-3. — **Impact:** none at runtime.

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
- ASSUMPTION-6 (T1): a safe room with spawn tiles is reported as `spawn_count: a safe room
  needs 0 spawns`; the spawn-distance rule still runs on any spawn it has. A town that isn't
  safe gets "must be a safe room" plus its own combat-rule errors, all prefixed `town: `. A
  room id repeated inside one floor is reported by `FloorData` only, not again by the tower.
- ASSUMPTION-7 (T1): `TownGate` — a tile owns its left and top edges (`floori`, like
  `FloorRun`); `setup()` arms the latch; before `setup()`, `check()` is false and the return
  position is the input position.
- ASSUMPTION-8 (T2): `TowerProgress.setup()` clamps a negative floor count to 0;
  `from_dict()` is refused before `setup()`, emits nothing, and refuses non-bool flags.
  `get_entries()` stops at the first locked floor.
- ASSUMPTION-9 (T2): `TowerSession` — `setup()` emits no `place_changed`; the floor number is
  kept through the death pause; a negative `death_return_delay` counts as 0; `tick()` doesn't
  guard a negative delta. A replay's clear still lets the player leave through the door.
- ASSUMPTION-10 (T2): the "cleared during this visit" flag is not in the session snapshot: a
  restored floor starts over (`FloorRun` isn't part of it either), so its exit stays shut
  until the floor is cleared again. `from_dict()` keeps the same `TowerProgress` object and
  emits `place_changed` only if the place differs. A town snapshot must have floor 0, start
  room 0 and no time left.
- ASSUMPTION-11 (T3): with `death_restarts_room` on, `player_died` is not emitted (F-011's
  behaviour exactly). Since review round 1 (CR-4) the debug keys do nothing after a reported
  death; `skip_room()` called directly still works, and the session ignores room reports
  during the death pause.
- ASSUMPTION-12 (T4): the health bar draws its back rect with no player (an empty bar); the
  banner counts down only while visible; the location label starts empty and `Game` sets it.
  HUD placement: bar 96 × 10 px top left, location top right, banner top centre at y = 24.
- ASSUMPTION-13 (T5): `GateMenu` handles its keys itself in `_input` while open and marks them
  handled; other keys (N) pass through. The focus is clamped, it doesn't wrap. Key repeat is
  not a press. `choose()` and `cancel()` do nothing while closed. The list has no scrolling:
  fine for 3 floors, not for 100 (§10 Q5).
- ASSUMPTION-14 (T5): on a setup error the town's debug key is off too and `get_progress()` is
  null unless one was injected. After a cancel the player is put on the return tile and kept
  there until any running or buffered dash has ended (review round 1, CR-2; the "0.1 tile of
  drift" this entry first described no longer exists).
- ASSUMPTION-15 (T6): the gate is x = 10..13, so its centre line is a tile edge and `P` can't
  sit exactly under it: `P` is at tile (12, 10), half a tile right (corrected in review round 1, CR-11: the log first said (11, 10)). The two blocks are at
  (7..8, 4..5) and (15..16, 4..5), mirrored about the gate's centre line. The fixture
  town differs only in `P`, which is at (11, 10).
- ASSUMPTION-16 (T7): the "You died" banner is shown when `Game` sees the death pause, for
  `death_return_delay` seconds; with a delay of 0 there is no pause and no banner. Clearing
  the last floor always says "no floor above yet", also on a replay. In a floor the location
  counts combat rooms only (`Room 1 / 3`, then `Boss`).
- ASSUMPTION-17 (T7): on a setup error `Game` keeps only the HUD (empty bar, no location) and
  its getters return null. (The debug skip during the death pause this entry first described
  no longer exists: review round 1, CR-4.)

### Things the Auditor should look at closely
- **Read this branch as the diff from `a864404`** (the tip of `feature/F-011-floor-structure`).
  F-011 is still in review; anything it changes means a rebase here (DEV-2).
- **C2 (rules only in core).** `Game`, `TownScene` and `GateMenu` should contain no `if` about
  unlocking, boss reached or whether a floor may be entered. The one sanctioned exception is
  `TownScene._clear_highest_unlocked_floor()` (debug N, C17), which calls `TowerProgress`
  directly.
- **C12 (no scene freed inside its own signal).** `Game`'s handlers only report to the session;
  `place_changed` sets `_is_shown_stale`; the swap is in `Game._physics_process`, which relies
  on physics priority 2 > `FloorScene`/`TownScene` 1 > the room's `CombatRunner` 0. The old
  scene is `remove_child` + `queue_free`. See DEV-9 for the timing wording.
- **`FloorScene` defaults (C11).** Three new exports default to F-011's behaviour; the 47
  F-011 scene tests are untouched. After a reported death `_physics_process` returns at the
  top, but `skip_room()` and `restart_room()` still work (ASSUMPTION-11, -17).
- **`RoomData.validate()` changed for safe rooms only** (`_check_spawns` branches on
  `is_safe_room` first). F-011's room tests are untouched.
- **Session snapshot.** "Cleared during this visit" is saved since review round 1 (CR-5;
  ASSUMPTION-10 is superseded). Still open for slice 4: `Game` rebuilds only on
  `place_changed`, so a restore that keeps the place but changes the floor would leave the
  old floor on screen (CR-8).
- **Same-tick death and boss kill (C5)** holds by the order of checks in
  `FloorScene._physics_process`, not by a rule in `FloorRun` (CR-7).
- **Input in the gate list.** `GateMenu._input` consumes `ui_*`, `move_up/down` and `interact`
  while open. `dodge` (Space) is also `ui_accept` (§10 Q6). If `Game` ever refused a choice
  the town would leave the player without input; it can't today because the list is exactly
  what the session accepts.
- **The player is held exactly where the list opened** (review round 1, CR-1), on a gate tile
  of the border row; the open gate has no collision and nothing lies beyond it, so the hold is
  what keeps the player in the room. A cancel puts the player back inside (C10).
- **Found, not fixed (F-011 code):** the boss bar's label in `room.gd` is 23 px tall for 8 px
  text, because its size is set before the font override. The text is top-aligned so it looks
  right; only the control's rectangle is oversized (§10 Q7).
- **Tests that change tunables:** `F012GameTest` sets `Tunables.tower.banner_duration` and
  `death_return_delay` per test and restores both in `after_each`.
- **Not done by anyone:** nobody has played the loop with a keyboard or a gamepad. The lead
  rendered `main.tscn` to images with a scratch driver (town, gate list open, floor 1 room 1
  with the HUD): everything draws where the tests say. The boss room, the banners and a
  death were not rendered. No full fought run is tested: the end-to-end tests skip rooms and
  kill with direct hits.

### How to test
```sh
export GODOT_BIN=/path/to/Godot_v4.7.2-stable
tools/test                      # 123 scripts, 1579 tests, all passing (about 7.5 min)
tools/lint                      # on Windows: .venv/Scripts/gdlint src tests && .venv/Scripts/gdformat --check src tests
tools/check_core_purity
```
One script: `"$GODOT_BIN" --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/scenes/test_f012_game.gd -gexit`.
All of this feature's scene tests: `-gdir=res://tests/scenes -gselect=f012`.

By hand (Gate B): open the project and press F5. See §5 "How to verify manually". `N` skips a
room in a floor and unlocks the next floor in the town; `R` restarts a room; `F3` hides the
debug overlay.

Final state (`41760e4`): 1579/1579 tests, gdlint clean, gdformat 248 files unchanged, core purity ok,
and `main.tscn` boots headless with no error.

After the round 4 fix (`983846b`): 1578/1578 tests, gdlint clean, gdformat 248 files unchanged, core
purity ok, and `main.tscn` boots headless with no error.

After the round 3 notes (`2f5cb54`): 1572/1572 tests, gdlint clean, gdformat 248 files unchanged,
core purity ok, and `main.tscn` boots headless with no error.

After the review round 1 fixes and the merge of F-011's (`ec5b964`): 1542/1542 tests, gdlint clean,
gdformat 247 files unchanged, core purity ok.

Final gate run by the lead on the tree committed as `9216679`: 1462/1462 tests (1135 from the F-011
branch, none changed, plus 327 new), gdlint clean, gdformat 247 files unchanged, core purity ok
(self-test: 19 rules).

---

## 9. Code Review  ·  _Auditor_

<!-- review-round: 1 verdict: CHANGES_REQUESTED -->

**Reviewed commit:** 9216679 (as the diff from `a864404`, the tip of F-011)

**Date:** 2026-11-18 · **Verdict:** CHANGES_REQUESTED · **By:** Auditor (lead, D-014)

How this round was done (D-014): a fresh reviewer sub-agent that wrote neither the spec nor
the code read `AGENTS.md`, this file and the whole diff, and ran scratch probes against the
real scenes. The lead then checked each finding against the code before recording it here.
`tools/test` (1462 tests), lint and `tools/check_core_purity` had passed on this tree and were
not rerun.

One blocking finding, four that should be fixed, one question for Lucas. The core
(`TowerProgress`, `TowerSession`, `TownGate`, `TowerData`) held up: no state-machine hole was
found under out-of-order, repeated or misplaced reports, both `from_dict`s are atomic, and the
scene swap in `Game` is safe. Every problem is at the input boundary of the gate list and of
the death pause, where the tests only walked and only sent synthetic action events.

### AC evidence

| AC | Result | Evidence |
|---|---|---|
| AC1 | ✅ | `tower_tunables.gd:12`, `tunables.gd:66`; `test_tower_tunables.gd:11` |
| AC2 | ✅ | `room_data.gd:266`; `test_safe_room.gd:15` |
| AC3 | ✅ | `floor_data.gd:26`; `test_safe_room.gd:106` |
| AC4 | ✅ | `tower_data.gd:14`; `test_tower_data.gd:12` |
| AC5 | ✅ | `town_gate.gd:21`; `test_town_gate.gd:20` |
| AC6 | ✅ | `tower_progress.gd:30`; `test_tower_progress.gd:16` |
| AC7 | ✅ | `tower_progress.gd:55`; `test_tower_progress.gd:113` |
| AC8 | ✅ | `tower_progress.gd:88`; `test_tower_progress.gd:162` |
| AC9 | ✅ | `tower_session.gd:67`; `test_tower_session.gd:25` |
| AC10 | ✅ | `tower_session.gd:84`; `test_tower_session.gd:116` |
| AC11 | ✅ | `tower_session.gd:108`; `test_tower_session.gd:215` |
| AC12 | ✅ | `tower_session.gd:116`; `test_tower_session.gd:279` (30/60/120 Hz at :294) |
| AC13 | ✅ | `tower_session.gd:138`; `test_tower_session.gd:383`. Met as written, but the round trip loses a flag (CR-5). |
| AC14 | ✅ | `floor_scene.gd:63`; `test_f012_floor_scene.gd:12` |
| AC15 | ✅ | `floor_scene.gd:78`, `:157`; `test_f012_floor_scene.gd:98` |
| AC16 | ✅ | `floor_scene.gd:47`, `:86`; `test_f012_floor_scene.gd:154` |
| AC17 | ✅ | `health_bar.gd:47`; `test_hud.gd:17` |
| AC18 | ✅ | `hud.gd:73`; `test_hud.gd:196` |
| AC19 | ✅ | `hud.gd:63`; `test_hud.gd:221` |
| AC20 | ✅ | `town_scene.gd:36`, `:112`; `test_f012_town.gd:23` |
| AC21 | ❌ | `town_scene.gd:59`, `:123`; `test_f012_town.gd:150`. The list opens and holds the right entries, but "never ends more than 1 tile from where the menu opened" is false for a dash (CR-1). The tests only walk. |
| AC22 | ✅ | `town_scene.gd:128`, `gate_menu.gd:107`; `test_f012_town.gd:263`. By the letter; see CR-2. |
| AC23 | ✅ | `gate_menu.gd:54`, `:124`; `test_gate_menu.gd:20`. See CR-3 for the stick. |
| AC24 | ✅ | `town_scene.gd:67`, `:144`; `test_f012_town.gd:413` |
| AC25 | ✅ | `data/floors/town.tres`, `tower.tres`, `tunables.gd:57`; `test_shipped_tower.gd:30` |
| AC26 | ✅ | `scenes/main.tscn:10`, `game.gd:43`; `test_f012_main.gd:13`, `test_f012_game.gd:25` |
| AC27 | ✅ | `test_f012_game.gd:139` (rooms cleared by direct hits, doors walked) |
| AC28 | ✅ | `game.gd:113`, `:227`; `test_f012_game.gd:230` |
| AC29 | ✅ | `game.gd:99`, `:198`; `test_f012_game.gd:304` |
| AC30 | ✅ | `game.gd:64`, `:144`; `test_f012_game.gd:376` (timing as DEV-9) |
| AC31 | ✅ | `test_f012_main.gd:85` |
| AC32 | ✅ | `game.gd:48`, `:121`; `test_f012_game.gd:449` |

### Checks

- **Rejected options (§3):** none implemented. No `change_scene_to_file`, no `Area2D` or prompt
  for the gate, no door per floor; the boss door leads to town; the room restart on death
  exists only behind the `death_restarts_room` default; `_remove_shown()` is called only from
  `_ready` and `_physics_process`.
- **Constraints:** C1, C3, C4, C6, C8, C9, C11–C17, C19 met. C10 violated (CR-1). C2 met for
  unlocking, entries and entry rules, with two soft spots (CR-7, CR-9). C5 met as written, but
  it doesn't say the dead player stops (CR-4). C7 met as written (CR-5). G1–G6, G9 ok; G7 see
  CR-5; G8 needs a ruling (CR-6).
- **Deviations:** DEV-1 to DEV-10 justified; DEV-9 is correct. One unlogged: the test helper
  `tests/scenes/f012_game_test.gd` is not in §6's file list for T7 (CR-11). A test helper is
  not treated as blocking.
- **Assumptions:** reasonable and reversible, except ASSUMPTION-10 (CR-5). ASSUMPTION-15 is
  wrong about the shipped file (CR-11). ASSUMPTION-14 and -17 understate what happens (CR-1,
  CR-4).
- **F-011 behaviour with the default exports:** unchanged. The one addition is a
  `floor_exited` emission nobody listens to.

### Findings

**CR-1 🔴 A dash into the gate carries the player out of the room (AC21, C10).** Verified by
running the real town scene.
- **Where:** `src/world/town/town_scene.gd:123` (`_open_gate_menu`).
- **Problem:** opening the list only sets `input_enabled = false`. A dash in progress runs to
  its end (3 tiles in 0.15 s), the open gate has no collision and nothing lies beyond it.
  Measured: a dash north from (11.5, 1.6); the list opened at y = 0.93 and the player settled
  at y = −1.40, that is 2.33 tiles from where it opened and 1.4 tiles outside the room.
- **Why it matters:** AC21 says "never ends more than 1 tile", C10 says the player doesn't
  move. Dashing is the normal way to cross the town, so this shows on the first visit.
- **Suggested fix:** hold the player where the list opened for as long as the gate is engaged
  (the latch's state belongs in `TownGate`, see CR-9), and add a dash test to AC21.

> **Builder reply (lead):** fixed in `add2f1b`. `TownGate` has an engaged state: the check that fires records the player's position, and `TownScene` puts the player back on it every tick while the gate is engaged, a dash included. AC21 now tests a walk-in and a dash-in for 60 ticks, exact position, never outside the grid; with the hold removed six of those tests fail. C10 and AC21 were amended (`8be0759`).

**CR-2 🟡 "Stay in town" chosen with Space makes the player dodge on the same tick.** Verified
with Space; gamepad A and a mouse click (which is `attack`) follow from the same mechanism.
- **Where:** `town_scene.gd:134` (`_on_menu_closed`), `gate_menu.gd:24`,
  `src/entities/player/player_input.gd:70`.
- **Problem:** Space is both `ui_accept` and `dodge`. Input is given back inside the input
  phase, and that tick's `Input.is_action_just_pressed("dodge")` is still true. Measured: the
  player was put on the return tile, dashed, and the list reopened 4 ticks later.
- **Why it matters:** the reopened list has its focus on the highest floor, so a second press
  enters a floor, and a floor can only be left by dying or clearing it (§10 Q1). §10 Q6 names
  the key overlap but not this consequence.
- **Suggested fix:** give input back on the next physics tick, after the room's runner has
  run, not in the handler. Add a test that sends a real key event.

> **Builder reply (lead):** fixed in `add2f1b`. Closing the list only releases the gate; input comes back in `TownScene._physics_process`, after that tick's runner has run with input off, and not before a running or buffered dash has ended (a cancel during a dash would otherwise carry the player back through the gate). A test closes the list with a real, held Space key: it fails on the old code (one dash) and passes now. Not tested: a mouse click on "Stay in town". Buttons fire on release, when `attack` is no longer "just pressed", so a click can't act on that tick.

**CR-3 🟡 A gamepad stick moves the focus once per motion event.** Verified with synthetic
`InputEventJoypadMotion`.
- **Where:** `src/ui/town/gate_menu.gd:138` (`_is_pressed`).
- **Problem:** `event.is_action_pressed()` is true for every motion event past the deadzone,
  not only for the crossing. Five events moved the focus from 5 to 0.
- **Why it matters:** the player arrives holding the stick up, so the focus lands on "Floor 1
  — from the start" instead of the last floor entry (AC23).
- **Suggested fix:** for joypad motion also require `Input.is_action_just_pressed(action)`.
  Add a test.

> **Builder reply (lead):** fixed in `6472012`. A stick counts as a press only when it crosses the deadzone, tracked per action, because `Input.is_action_just_pressed` turned out to be true for every motion event of a frame. A stick already held when the list opens is not a push. The follow-up in the same commit: left and right do nothing in the list (each button is its own left and right neighbour, and `ui_left`/`ui_right` are consumed), so a diagonal push moves exactly one step.

**CR-4 🟡 A dead player keeps full control during the death pause, and debug R revives them.**
Verified by running.
- **Where:** `src/world/floors/floor_scene.gd:71`, `:86`.
- **Problem:** nothing turns the player's input off on death, and `PlayerMotor` has no dead
  state. With "You died" showing and 0 HP the player walked 1.54 tiles in 20 ticks and started
  an attack. R rebuilt the room at 100 HP while the session stayed in the death pause; the town
  still came.
- **Why it matters:** no outcome changes (the session ignores everything in the pause), but it
  reads as a bug for 1.5 s on every death. C5 doesn't say the dead player stops: a spec gap.
- **Suggested fix:** when the death is reported, turn the player's input off and ignore the
  debug keys until the room is rebuilt. Add the rule to C5.

> **Builder reply (lead):** fixed in `996fc6e`. With `death_restarts_room` off, the reported death turns the player's input off and N and R do nothing until the room is rebuilt; `skip_room()` and `restart_room()` called directly still work. Measured in the real game with W, J and Space held for the 1.5 s pause: the player stays on the same spot, idle, at 0 HP. C5 says so (`8be0759`). The same fix round made `TownScene` refuse any origin but the world's (`ec5b964`), the town's version of F-011's CR-4.

**CR-5 🟡 The session snapshot drops "cleared during this visit" (G7).** From reading.
- **Where:** `src/core/floors/tower_session.gd:138`; `test_tower_session.gd:444` asserts the
  loss.
- **Problem:** `to_dict()` → `from_dict()` gives a session that behaves differently, while
  `FloorRun`'s own snapshot keeps `floor_cleared`.
- **Why it matters:** once save/load restores both, a save made in a cleared boss room loads
  into a soft lock: the run won't report the clear again, the session refuses the exit, and
  there is nothing left to die to. Nothing writes a snapshot yet, hence 🟡 and not 🔴.
- **Suggested fix:** put the flag in the snapshot (valid only when the place is `FLOOR`) and
  change that test.

> **Builder reply (lead):** fixed in `8de6c4c`. The snapshot has `cleared_in_run`; it may be true only on a floor that the progress says is cleared, and anything else is refused. A restored cleared floor lets the player out and doesn't report the clear twice. C7 says so (`8be0759`).

**CR-6 🟡 G8: entering a floor is a player action with no command object.** From reading.
- **Where:** `src/world/game.gd:193`.
- **Problem:** `GateMenu._input` → `choose` → `TownScene` → `Game._on_floor_chosen` →
  `session.enter_floor()` is one chain from an input handler to a state change. §4 never
  mentions G8.
- **Why it matters:** it is one narrow call with two primitives, cheap to wrap later, but the
  spec should say whether menu choices count as player actions.
- **Suggested fix:** a §10 question for Lucas / Direction.

> **Builder reply (lead):** no code change. §10 Q8 asks Lucas / Direction whether a menu choice is a player action under G8; the lead's view is in the question.

**CR-7 🔵 C5's same-tick rule holds by statement order in the glue.** From reading.
`floor_scene.gd:66` checks HP before the clear; `FloorRun.report_room_cleared(0)` would still
clear a boss room. Either let core refuse a boss-room clear at 0 HP or note the exception
under C2.

> **Builder reply (lead):** not changed. `FloorRun` is F-011's, and its ASSUMPTION-5 says a clear with a dead player still clears. For this one case the rule holds by the order in `FloorScene._physics_process` (HP first), which AC16's same-tick test pins. Noted under "Things the Auditor should look at closely".

**CR-8 🔵 `Game` rebuilds only on `place_changed`.** From reading. `game.gd:64`, `:189`: a
`from_dict()` that keeps the place but changes the floor emits nothing, so the old floor would
stay on screen. Unreachable until save/load.

> **Builder reply (lead):** not changed. Unreachable until something restores a session; noted in §8 for the save/load feature (slice 4).

**CR-9 🔵 Whether the latch runs depends on a UI node.** From reading. `town_scene.gd:60`:
"the list is open" lives only in `GateMenu`. Keep an engaged state in `TownGate` (fits CR-1).

> **Builder reply (lead):** fixed in `add2f1b` with CR-1: `TownScene` asks `TownGate.is_engaged()`, not whether the list is open.

**CR-10 🔵 Test hygiene.** Verified by running. `tests/ui/test_gate_menu.gd:260` sends echo
presses for E, Up and Escape and never releases them, so those actions stay pressed for the
rest of the run. The key helpers set only `physical_keycode`, so the built-in `ui_*` actions
never match them: the comment at `:279` ("ui_up and move_up at once") is not what runs, which
is how CR-2 got through.

> **Builder reply (lead):** fixed in `6472012`: the menu tests release every key and axis in `after_each` and assert nothing is left pressed, and their key events now set `keycode` as well as `physical_keycode`, so they really match `ui_*`. `F012SceneTest`'s key helpers got the same change in `add2f1b`.

**CR-11 🔵 Log accuracy.** `tests/scenes/f012_game_test.gd` needs a DEV entry. ASSUMPTION-15
says `P` is at (11, 10) and that the shipped town equals the fixture: `data/floors/town.tres`
has `P` at (12, 10), the fixture at (11, 10).

> **Builder reply (lead):** fixed in `8be0759`: DEV-11 logs the helper file; ASSUMPTION-15 now says `P` is at (12, 10) and that the fixture town differs.

**CR-12 🔵 Notes.** `game.gd:194` ignores a refused `enter_floor()`, which would leave the town
without input (can't happen today). Debug keys default to on in `main.tscn`, so R is a free
full heal: turn them off before a stranger plays (slice 3).

> **Builder reply (lead):** noted, no change. Debug keys stay on while nothing is saved (ASSUMPTION-5); turning them off belongs to the build a stranger plays (slice 3).

**Not checked in this round:** a rendered run, a real keyboard, mouse or gamepad (CR-2's
gamepad and mouse variants are reasoned, not run); shipped bosses fighting a dead player for
the whole pause; five of the data-test files were read by test name and in part, not line by
line.

<!-- review-round: 2 verdict: CHANGES_REQUESTED -->

**Reviewed commit:** c22e990 (code as of `ec5b964`; the round 1 fixes are `9216679..ec5b964`,
including the merge `7f71ab5` of F-011's fixes)

**Date:** 2026-11-18 · **Verdict:** CHANGES_REQUESTED · **By:** Auditor (lead, D-014)

How this round was done: a fresh reviewer sub-agent that did neither round 1 nor any fix
extracted HEAD into a scratch folder and ran there. Baseline: the 9 test scripts the fixes
touch, 349/349. Then, in a second copy, it removed each fix in turn and reran them: 34 tests
failed, each one belonging to the fix that was removed. It also wrote its own probes for the
gate list, the town and the game. The lead recorded the result below. No existing test was
weakened: the edits to old tests are the ones the amended C7 and C10 require.

One round 1 finding is not resolved (CR-3), and the fixes added a rule the spec doesn't state
(CR-13). Everything else is resolved or validly accepted, and the probes of the engaged gate,
the cancel path, the death pause and the snapshot flag found nothing broken.

### Round 1 findings

| Finding | Result | Evidence |
|---|---|---|
| CR-1 | ✔ resolved | `town_gate.gd:29`, `town_scene.gd:70`. Without the hold exactly the six AC21 tests fail. Probe: dashes from four distances at 30 and 60 ticks/s (the tests use 120) were held on the gate row, 0 ticks off position in 60. |
| CR-2 | ✔ resolved | `town_scene.gd:73`, `:163`, `:179`. With input given back in the handler 4 tests fail, the real-Space one included; with the dash wait removed 2 fail. The player can't be left without input: a dash always ends and a buffered dash expires after 0.12 s. A click on "Stay in town" is still untested; the reasoning in the reply holds. |
| CR-3 | ✘ not resolved | See below. |
| CR-4 | ✔ resolved | `floor_scene.gd:72`, `:90`. Without it 4 floor-scene tests and the game test fail. Every rebuild makes a new player with input as built. The default path is untouched; between `a864404` and HEAD only F-011's own two scene-test files changed. |
| CR-5 | ✔ resolved | `tower_session.gd:148`, `:168`, `:187`. Without the restore the round-trip test fails. Refused in the town, in the death pause and on a floor the progress says is not cleared. |
| CR-6 | ✔ accepted | §10 Q8 asks. |
| CR-7 | ✔ accepted | Pinned by AC16's same-tick test. |
| CR-8 | ✔ accepted | Unreachable until something restores a session. |
| CR-9 | ✔ resolved | `town_scene.gd:70` asks `TownGate.is_engaged()`; `test_ac21_the_hold_does_not_depend_on_the_list_being_open`. |
| CR-10 | ✔ resolved | `test_gate_menu.gd` `after_each` releases keys and axes and asserts nothing stays pressed; key events set both key codes. |
| CR-11 | ✔ resolved | DEV-11; `town.tres` has `P` at (12, 10), as ASSUMPTION-15 now says. |
| CR-12 | ✔ accepted | — |

**CR-3 ✘ not resolved (🟡): one stick push still moves two steps.** Verified by running.
- **Where:** `src/ui/town/gate_menu.gd:150`, `:168`, `:175`.
- **Problem:** the fix tracks "already held" per action. Up is `[ui_up, move_up]`, both bound
  to left stick up, with deadzones 0.5 (built-in) and 0.2 (`project.godot`). A push that ramps
  crosses 0.2 on one event and 0.5 on a later one, and each crossing counts as a press. On a
  five-entry list the values −0.1, −0.3, −0.45, −0.7, −1.0 moved the focus 4 → 3 → 2. A stick
  resting at −0.4 when the list opens and then pushed to −0.9 moves one step. 1.0 → 0.4 → 0.6
  without letting go counts as a new push.
- **Why the tests miss it:** every stick test jumps from inside both deadzones straight to
  −0.9 or −1.0. A real stick always passes through the values in between.
- **Suggested fix:** track per direction, not per action: a stick event is a push only when no
  action of that direction was held by the stick before it. Add a ramped-push test and a
  partial-hold-at-open test.

### New findings

> **Builder reply (lead):** fixed in `a772a52`. The stick is tracked per direction: a motion event is a push only when no action of that direction was held before it, and the direction stays held until every action of it is released. Seven new tests use the reviewer's values (the ramp −0.1 … −1.0, a stick resting at −0.4 when the list opens, the wobble 1.0 → 0.4 → 0.6); five of them fail on the old code.

**CR-13 🟡 The town's origin rule is in the code but in no constraint.** Verified by reading.
- **Where:** `src/world/town/town_scene.gd:114`. Its comment cites C9 (which is about
  `TowerData`) and F-011's C6 (which names the floor scene only).
- **Problem:** `ec5b964` added a setup error that only §8's Progress line and the CR-4 reply
  mention. Read strictly an unlogged deviation is 🔴; it is written down in two places and is
  the right behaviour, hence 🟡.
- **Suggested fix:** one sentence in a constraint and a DEV line.

> **Builder reply (lead):** fixed in `19a57bf`: C9 states the town's origin rule and DEV-13 logs it.

**CR-14 🔵 §8 and the amended spec lag the fixed code.** Verified by reading. "The player can
stand slightly outside the room on the gate tiles" and ASSUMPTION-14's "about 0.1 tile of
drift" are no longer true; DEV-4 describes an AC21 wording that round 1 replaced; C10 and AC22
say input comes back "on the next physics tick", while the code also waits for a running or
buffered dash to end.

> **Builder reply (lead):** fixed in `19a57bf`: C10 and AC22 mention the dash wait; DEV-4 is marked superseded; ASSUMPTION-14 and the "look closely" line say the player is held exactly.

**Not checked in this round:** a real keyboard, mouse or gamepad and a rendered frame (CR-3 is
from synthetic motion events); a click on "Stay in town"; bosses attacking a dead player for
the whole pause; a JSON round trip of the snapshots (both require `is int`, and Godot's JSON
parser returns floats, so a JSON save would be refused: a note for slice 4).

<!-- review-round: 3 verdict: APPROVE_WITH_NOTES -->

**Reviewed commit:** 8905f83 (the stick fix `a772a52`, the spec edits `19a57bf`, and the merge
of F-011's round 2)

**Date:** 2026-11-18 · **Verdict:** APPROVE_WITH_NOTES · **By:** Auditor (lead, D-014)

A narrow round by the round 2 reviewer, on a fresh extraction of this commit. The full suite
passed on it (1549 tests), with lint, format and core purity clean.

| Item | Result | Evidence |
|---|---|---|
| CR-3 | ✔ resolved | `gate_menu.gd:150`, `:178`. The round 2 probe, unchanged, now passes all three cases; a ramp in steps of 0.05 up, back to 0 and down gave one step, nothing, one step. Against the old menu 5 of the 7 new tests fail; the other 2 guard against over-fixing. Nothing else broke: keys and d-pad one step per press, repeats ignored, left and right ignored, a ramped diagonal one step, held across a reopen not a push, `open()` while open fine. |
| CR-13 | ✔ resolved | C9 matches `town_scene.gd:116`; DEV-13 logs it. |
| CR-14 | ✔ resolved | C10 and AC22 match `town_scene.gd:73`, `:179`; the three §8 lines are true now. |
| Merge `8905f83` | nothing lost | It changes only F-011 round 2's three files; no conflict marker; nothing under `src`. |

Correction to round 2's own count, carried into F-011's file: the 15 rooms hold 42 enemies
(10 + 17 + 15), not 41.

### New findings

**CR-15 🔵 A key or d-pad press can leave the stick's "held" flag stale, and one stick push is
dropped.** Verified by running.
- **Where:** `src/ui/town/gate_menu.gd:151`, `:178`, `:92`.
- **Problem:** the flag is read from `Input.is_action_pressed`, which is also true for W, the
  arrow keys and the d-pad, and it is refreshed only in `open()` and on stick events. With W or
  d-pad up held when the list opens and then released, the next stick push up is dropped
  whole; the second counts.
- **Why it matters:** a player who walks in on keys or the d-pad and then uses the stick loses
  one push. Minor and self-correcting.
- **Suggested fix:** derive the flag from the stick alone, or refresh it on every event.

> **Builder reply (lead):** fixed in `2f5cb54`. The stick's state now comes only from joypad motion events, and it is tracked while the list is closed too, so a stick already held when the list opens is known to be held. Keys and the d-pad never change it, and the stick never blocks them: a key and a stick push are two presses. Tests: W or d-pad up held at open, released, then a stick flick moves one step (both failed before).

**CR-16 🔵 A release that overshoots the centre counts as a push back.** Verified with
synthetic events; suspected on hardware.
- **Where:** `gate_menu.gd:150`.
- **Problem:** a push starts at the smaller deadzone (0.2) and ends below the same value.
  −1.0, −0.5, 0.1, 0.25, 0.1, 0.0 moved the focus back down a step; jitter between −0.25 and
  −0.15 moved it three.
- **Suggested fix:** start a push only at the larger deadzone and end it below the smaller
  one; the band in between is the hysteresis.

> **Builder reply (lead):** fixed in `2f5cb54`. A push starts only when the stick is past the larger deadzone of its direction (every action of it pressed: 0.5 today) and ends only inside the smaller one (none pressed: 0.2); both come from the input map, no new tunable. The reviewer's overshoot and jitter sequences are tests and failed before. One round 2 expectation is reversed by this and its test renamed: a stick resting at −0.4 when the list opens has not pushed yet, so going on to −0.9 is one step.

**CR-17 🟡 On a gamepad, A and B do nothing in the gate list; only Y chooses.** Verified by
running. It dates from T5, not from the fixes.
- **Where:** `gate_menu.gd:25`; `project.godot` doesn't override the built-in actions.
- **Problem:** in this project the built-in `ui_accept` is Enter, keypad Enter and Space, and
  `ui_cancel` is Escape; neither has a pad button (printed from `InputMap` at runtime). Pad
  buttons A, B and X did nothing on an open list; Y (`interact`) chose. Round 1's note under
  CR-2 that gamepad A "follows from the same mechanism" assumed A was `ui_accept`; it isn't.
- **Why it matters:** a pad player can't confirm with the bottom button or cancel with a
  button, and nothing on screen says Y. Not a soft lock (Y chooses, "Stay in town" plus Y
  cancels), and AC23 is met by its words, hence 🟡.
- **Suggested fix:** give the list pad buttons for choose and cancel (A is also `dodge`, so
  CR-2's Space test needs a pad twin), or put it to Lucas.

> **Builder reply (lead):** fixed in `2f5cb54`, in the input map so that later menus get it too: `project.godot` now overrides the built-in `ui_accept` (Enter, keypad Enter, Space, pad A) and `ui_cancel` (Escape, pad B). `tests/test_ui_input_map.gd` pins both and the four `ui_*` directions; `tests/test_input_map.gd` passes unchanged. In the list pad A chooses once, pad B cancels once, X does nothing, Y still chooses, and no single press matches two choose actions. Pad A is also `dodge`: a town test closes the list on "Stay in town" with a held pad A and sees no dash, and it fails if input is given back in the handler. Logged as DEV-14; AC23 says so.

**Not checked in this round:** a real gamepad, keyboard or mouse (every stick and button result
is from synthetic events); a rendered frame.

<!-- review-round: 4 verdict: CHANGES_REQUESTED -->

**Reviewed commit:** 32454cd (the round 3 fixes are in `2f5cb54`)

**Date:** 2026-11-18 · **Verdict:** CHANGES_REQUESTED · **By:** Auditor (lead, D-014)

A narrow round by the same reviewer on a fresh extraction. On the fix commit the full suite
passed (1572 tests), lint, format and core purity were clean, and `main.tscn` booted headless
with no error. A 🟡 alone would be APPROVE_WITH_NOTES by the letter of `AGENTS.md`; this one
reopens the case CR-3 was raised for, so the round asks for the change.

| Item | Result | Evidence |
|---|---|---|
| CR-15 | ✔ resolved as asked | The round 3 probe, 15/15: W or d-pad up held at open, released, then a stick push counts; keys and the stick no longer block each other. But see CR-18. |
| CR-16 | ✔ resolved | The overshoot, jitter and wobble sequences move nothing extra; the ramp steps once, at −0.7. |
| CR-17 | ✔ resolved | Pad A chooses once and pad B cancels once, on the press; X does nothing, Y still chooses. The override against a blank 4.7.2 project: the keys are identical; the only difference is the device (the built-ins bind device 16, the override all devices), a superset. Nothing else in the project reacts to A or B: the list's buttons are the only focusable controls. In the real `Game`, A outside the list is one dodge and B does nothing; a floor chosen with a held A starts no dodge. The pad A town test fails when input is given back in the handler. |
| Regressions in the list | none in the round 3 probe set | Keys, d-pad, repeats, left and right, ramped diagonal, two openings, `open()` while open. |
| Spec text | matches | AC23 and DEV-14 against `gate_menu.gd:176` and `project.godot`. DEV-14's "keys listed again unchanged" is true for the keys, not for the device. |

### New finding

**CR-18 🟡 A menu built while the stick is already held doesn't know it is held; letting go
then moves the focus.** Verified by running with synthetic events. A regression from `2f5cb54`.
- **Where:** `src/ui/town/gate_menu.gd:44` (the state starts empty), `:67`, `:176` (it comes
  only from motion events this instance receives), `:97` (round 3's seed in `open()` is gone).
  `Game` builds a new `TownScene`, and so a new `GateMenu`, on every return to town.
- **Problem:** a stick held at a constant value sends no events. If it is up before the town
  is built and stays up until the list opens, the menu thinks it is at rest, and the first
  event past 0.5, the start of a release included, counts as a push. Measured at menu level
  (stick at −1.0, then the menu is created and opened: a release moves the focus 4 → 3) and in
  the real `Game` (die in the boss room, stick up during the death pause, town, gate: the list
  opens on "Floor 1 — at the boss" and letting go moves it to "Floor 1 — from the start"). The
  same sequences on `8905f83`'s menu leave the focus alone.
- **Why it matters:** it is CR-3's own case, on the die-and-retry path this feature exists
  for. One more press then enters the floor from the start.
- **Why the tests miss it:** every held-at-open test creates the menu first and moves the
  stick afterwards.
- **Suggested fix:** seed the stick's state from the stick itself when the list opens
  (`Input.get_joy_axis` is stick-only), counting a direction past its smaller deadzone as
  already pushed. That also restores round 2's expectation for a stick resting at −0.4.

> **Builder reply (lead):** fixed in `983846b`. When the list opens it reads the stick's own axes (`Input.get_joy_axis`, the axes taken from the bindings of the list's direction actions, every connected pad plus device 0, which is where a synthetic event lands in a headless test). A direction the stick is past the smaller deadzone in counts as already pushed, so neither a small change nor letting go is a push; a stick resting at −0.4 at open is back to round 2's expectation (no step on −0.9). Tracking while the list is closed is removed, since the reading at open replaces it. Tests: the stick is pushed before the menu instance exists (up and down), and in the real `Game` through a death and a rebuilt town; those three and the −0.4 test failed on the round 3 code. Not covered: a pad connected after the list has opened is only known from its events.

**Note on the record itself:** in round 3 the lead corrected an enemy count (41 → 42) by
editing earlier review lines of F-011's file in place. `AGENTS.md` says a review only grows.
The edits are undone and the correction stands as its own line (see F-011 §9).

**Not checked in this round:** a real gamepad, keyboard or mouse (CR-18 included: every stick
result is from synthetic events); more than one pad at once; a rendered frame.

<!-- review-round: 5 verdict: APPROVE_WITH_NOTES -->

**Reviewed commit:** 52b00dc (the CR-18 fix is `983846b`)

**Date:** 2026-11-18 · **Verdict:** APPROVE_WITH_NOTES · **By:** Auditor (lead, D-014)

A narrow round by the same reviewer on a fresh extraction. On the fix commit the full suite
passed (1578 tests), lint, format and core purity were clean, and `main.tscn` booted headless
with no error. No blocking finding and no open 🟡: the feature is ready for Gate B.

| Item | Result | Evidence |
|---|---|---|
| CR-18 | ✔ resolved | `gate_menu.gd:98`, `:180`. The round 4 probes, unchanged, pass: stick at −1.0 before the menu exists, then a small change and a plain release leave the focus alone; in the real `Game`, through a death and a rebuilt town, the list opens on "Floor 1 — at the boss" and stays there through the release. Against the round 3 menu the 4 tests the reply names fail. |
| CR-15, CR-16, CR-17 | still hold | The round 3 and round 4 probes pass on this code; pad A and B behave as in round 4. |
| Regressions in the list | none | Keys, d-pad, repeats, left and right, ramped diagonal, two openings, `open()` while open. |
| The seeding | nothing wrong found | New probe, 9/9: held up at open then flipped straight down; held diagonally at open; a key and the stick both held at open; `open()` while open with the stick held or mid-push; no stale reading after a release made while the list was closed. A synthetic stick on device 1 is not seen headless (only connected pads and device 0 are asked): a test artefact, since a real pad is in the connected list. |

Round 2's expectation for a stick resting at −0.4 when the list opens (no step on −0.9) is back,
and the reviewer agrees with it.

### New finding

**CR-19 🔵 One new test's name says a key and the stick are held; only the key is.** Verified
by reading. `tests/ui/test_gate_menu.gd:747`: it holds W, opens, releases W and pushes the
stick. The named case works (the reviewer's probe passes) but has no test in the repository.

> **Builder reply (lead):** fixed in `41760e4`: the test now holds the stick and W before the menu
> exists and checks that neither release moves the focus; the W-only scenario keeps a test
> under an honest name. AC23 also states the reading at open.

**Not checked by any round:** a real gamepad, keyboard or mouse. Every stick and button result
in rounds 1 to 5 is from synthetic events, including the premise of CR-18 (a held stick sends
no event) and the claim that a real pad on a device other than 0 is in the connected list. Two
pads at once, a pad connected after the list has opened, and a rendered frame of the list with
a pad in hand. These are for Gate B.

---

## 10. Open Questions  ·  _Anyone (append)_

| # | Raised by | Question | Blocking? | Answer (Lucas/Planner) |
|---|---|---|---|---|
| Q1 | Lead | → Lucas: there is no way to leave a floor in the middle of a run except dying. Wanted before the pause menu exists (slice 3), e.g. a "return to town" key? | no | |
| Q2 | Lead | → Lucas (Gate B): values to judge — death pause 1.5 s, banner 2.5 s, town size, back to town after every boss. | no | |
| Q3 | Lead | → Direction: `PHASE1.md` rows F-012, F-013 and part of F-015 are built here as one feature; later rows need renumbering. F-011's row still says "Not started". | no | |
| Q4 | Lead | → Art & Game Feel: look of the health bar, location text, banners and the gate list (all placeholders; FX1, CX8). | no | |
| Q5 | Lead | → Direction: the gate list is a plain column with no scrolling. It holds 3 floors; by slice 5 (floors 4–6, two entries each) it needs paging or a different shape. | no | |
| Q6 | Lead | → Lucas (Gate B): `dodge` (Space) is also `ui_accept`, so a second Space press right after dashing into the gate chooses the focused entry (the highest floor). Annoying or fine? | no | |
| Q7 | Lead | → Direction / F-011's review: the boss bar label in `src/world/floors/room.gd` sets its size before the font override and ends up 23 px tall (found in T7's layout tests). Harmless today; fix with F-011's review changes or a later feature? | no | |
| Q8 | Auditor (lead) | → Lucas / Direction (review CR-6): G8 says player actions go through a command layer. Entering a floor goes from the gate list straight to `TowerSession.enter_floor(floor, at_boss)`: one call with two plain values, no command object. Does a menu choice count as a player action under G8? The lead's view: treat that one call as the command boundary for now and wrap it in a command when co-op needs it (phase 3). | no | |

---

## 11. Director Notes  ·  _Lucas_

<Overrides, priorities, gut calls. Everyone obeys these.>
