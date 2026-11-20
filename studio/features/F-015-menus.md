---
id: F-015
title: Menus — title screen, pause menu, death screen, settings
status: PLAN_REVIEW      # DRAFT | PLAN_REVIEW | PLAN_CHANGES | APPROVED | IN_PROGRESS | CODE_REVIEW | CODE_CHANGES | DONE | PARKED
owner_now: Auditor       # who must act next: Planner | Auditor | Builder | Lucas
created: 2026-11-20
updated: 2026-11-20
depends_on: [F-003, F-012, F-014, D-006, D-010, D-014, D-016]
pillars: [1]
department: Direction    # the death and leave rules belong to Floors (studio/design/floors.md)
---

# F-015 — Menus

> **How to use this file.** This is the single source of truth for this feature.
> Every agent reads the WHOLE file before acting. Write only in the sections you own
> (see studio/README.md). Never delete another role's text — reply under it.
>
> **This feature runs under D-016:** the lead (Claude Code) wrote §1–§6 and gates the work; up to
> two implementer sub-agents write code; only the lead commits and writes §8. The plan review
> (§7) and the code review (§9) run as D-014 sets. The branch is cut from `main`.

---

## 1. Goal  ·  _Planner_

**Player-facing outcome (one sentence):**
The game starts on a title screen; while playing, the pause key stops the game and offers
Resume, Return to town, Settings and Quit to title; dying shows a death screen that says where
you died and waits for you to return to town; and two settings (screen shake, fullscreen) are
remembered between launches.

**Why now:** F-011 to F-014 made floors 1–3 playable end to end, but the game starts inside the
town with no way to stop, leave a floor or quit, and a death sends you to town after 1.5 s
whether you read it or not. This is the first part of slice 3 (D-016), chosen by Lucas on
2026-11-20: "Menus + tutorial" first, with the tutorial split off as its own feature.

**Decided by Lucas on 2026-11-20 (chat):**
- Menus are built first.
- The death screen says where you died (floor, room, kills) and **stays until you press a
  button** to return to town.
- The pause menu has Resume, **Return to town**, Settings and Quit. Returning keeps what you
  earned (floors cleared, bosses reached); the floor's rooms start over next time.
- No tutorial in this feature: "No tutorial yet create kind like a new slice for tutorial only".

**Out of scope (explicitly):**
- Any tutorial, hint or key prompt (its own feature, D-016).
- Save/load of progress (slice 4). Quitting to the title loses the progress, and the menu says so.
- Volume and any audio setting (no audio exists), key rebinding, resolution or vsync settings,
  a language setting.
- "Try again at the boss" on the death screen (Lucas chose the plain return). The gate list
  already offers it.
- The look: fonts, colours, art, fades, animated transitions, sounds. Everything is plain labels
  and buttons on flat rectangles, like the gate list (→ Art & Game Feel).
- Turning the debug keys and the FPS overlay off for a stranger's build (the export feature).
- Pausing in the debug scenes (`scenes/debug/*`): they have no shell.
- Any change to combat, rooms, waves, the heal rule or the gate list's behaviour.

---

## 2. Context  ·  _Planner_

- **What exists.** `scenes/main.tscn` holds `DebugOverlay` and `Game` (`src/world/game.gd`).
  `Game` builds a `TowerSession` (core) in `_ready`, shows the town at once, and every physics
  tick shows what the session says: a `TownScene` or a `FloorScene`. The `Hud` is a child of
  `Game`.
- **Death today (F-012/C5).** `FloorScene` reports the death once; `Game` calls
  `TowerSession.report_player_died()`; the session is in `DEATH_PAUSE` for `death_return_delay`
  (1.5 s, `data/tunables/tower.tres`) of ticked time, then goes to the town by itself. `Game`
  shows the banner "You died". The floor keeps running behind it (enemies keep moving); the
  player takes no input and the floor's debug keys do nothing.
- **Leaving a floor today (F-012/C6).** Only through the cleared boss room's exit, or by dying.
  F-012 §10 Q1 asked for a way out; Lucas's answer is this feature's Return to town.
- **The one existing menu** is the gate list, `GateMenu` (`src/ui/town/gate_menu.gd`, 290 lines,
  77 tests in `tests/ui/test_gate_menu.gd`). It moves its own focus and handles the stick itself
  because Godot's focus navigation repeated and jumped sideways (F-012 review CR-3, CR-15, CR-16,
  CR-18). It consumes its keys in `_input` while open.
- **Input facts that shape this feature** (`project.godot`):
  - `pause` is Escape and pad Start. `ui_cancel` is Escape and pad B. So **Escape is both**.
  - `ui_accept` is Enter, keypad Enter, Space and pad A. `dodge` is Space and pad A. `attack` is
    J, the left mouse button and pad X. So **the key that chooses a menu entry is also the dash**,
    and a click is also an attack.
  - `PlayerInput` (`src/entities/player/player_input.gd`) reads
    `Input.is_action_just_pressed()` for dodge and attack inside the physics tick. A press is
    "just pressed" for the first physics tick that runs after it. F-012 met this at the gate
    (review CR-2) and gave the input back one tick late.
- **GUT and the tree pause.** GUT's own nodes have the default process mode, so
  `get_tree().paused = true` would stop the test runner's waits. The pause in this feature never
  touches `SceneTree.paused` (C6).
- **Screen shake.** `PlaceholderShake` (`src/world/camera/placeholder_shake.gd`) is a child of
  each room's player and reads `data/tunables/screen_shake.tres` (`screen_shake_enabled`) in
  `_ready`; `debug_shake_toggle` (K) flips the node's own flag. A new room builds a new node.
- **Glossary.** "Screen" alone already means the visible area in tiles (F-013). This spec says
  "title screen" and "death screen" for the two menus Lucas named, and "menu" for the rest.
- **Tooling on Windows:** as in F-011 §2 (`GODOT_BIN`, `.venv/Scripts/gdlint`). The full suite
  takes about 11 minutes.
- Design docs: `studio/design/floors.md`, section "The tower loop" (binding; T8 updates its
  death and leave lines), and `studio/DECISIONS.md` D-006.

---

## 3. Options Considered  ·  _Planner_

### ✅ Chosen: a `Shell` node above `Game`, driven by a core `ShellFlow`; one menu panel for every menu
- **How it works:** `scenes/main.tscn` holds `DebugOverlay` and a new `Shell`
  (`src/world/shell.gd`). The shell owns a `ShellFlow` (core, `RefCounted`): a small state
  machine with the states TITLE, PLAYING, PAUSED, SETTINGS, CONFIRM_LEAVE, CONFIRM_QUIT and DEAD.
  The shell creates the `Game` when the player starts and frees it on a quit to the title. It
  pauses by setting `Game.process_mode = PROCESS_MODE_DISABLED`. One `MenuPanel` (a heading, a
  body text, a column of entries) shows whatever the flow's state needs; the texts and entries
  of each state come from one script, `ShellMenus`. The column's focus, keys and stick handling
  are the gate list's, moved into a shared base class `ListMenu` that `GateMenu` now extends.
  The death rule changes in core: `TowerSession` stays in the death pause until
  `confirm_death()`, and gains `leave_floor()`.
- **Why chosen:** every rule of the flow and of the loop is plain logic with tests
  (`ShellFlow`, `TowerSession`); the game below the shell needs three small methods and no
  knowledge of menus; five menus cost one panel; the gate list's hard-won input handling is
  reused, with its 77 tests as the proof that moving it changed nothing.
- **Costs we're accepting:** one more autoload (`UserSettings`, C12); `GateMenu` is refactored
  although its behaviour must not change; the F-012 tests of the automatic return to town are
  rewritten for the new rule; the menus look as plain as the gate list.
- **Would revisit if:** a menu needs more than a column of entries (sliders for volume, a
  key-binding grid, an inventory), or co-op needs a pause that does not stop the world.

### ❌ Rejected: `get_tree().paused = true`
- **How it would work:** the engine's own pause; menus run with `PROCESS_MODE_ALWAYS`.
- **Why rejected:** GUT's nodes stop with the tree, so no test could wait while paused; the
  debug overlay stops too; and every node added later must remember its process mode.
- **Tempting because:** it is the tutorial way and one line.

### ❌ Rejected: pausing by not stepping the sim (a flag on `CombatRunner`)
- **How it would work:** the runner skips its ticks while a flag is set.
- **Why rejected:** everything outside the runner keeps running: the HUD's banner time, the
  camera's smoothing and shake, `Game`'s session tick, the town's gate latch, input sampling.
  Each needs its own check, and the next node added would be missed.
- **Tempting because:** it keeps the physics bodies in place and looks like "the logic's pause".

### ❌ Rejected: one scene per menu, switched with `change_scene_to_file()`
- **Why rejected:** the pause and the death screen sit over a running or stopped game that must
  stay loaded; five scenes repeat one layout; tests could not drive the flow in one tree.
- **Tempting because:** each menu would be editable on its own in the editor.

### ❌ Rejected: Godot's built-in focus navigation for the new menus
- **Why rejected:** F-012's review found the stick repeating and jumping sideways with it
  (CR-3, CR-15, CR-16, CR-18); the gate list fixed that by moving the focus itself. Two kinds of
  menu input would also feel different to the hand.
- **Tempting because:** it needs no code.

### ❌ Rejected: a second copy of the gate list's input code for the new menus
- **Why rejected:** 200 lines of stick and focus handling in two places; a fix in one is missed
  in the other.
- **Tempting because:** `GateMenu` would not be touched.

### ❌ Rejected: keeping the timed return to town and only dressing it up
- Decided by Lucas 2026-11-20: the death screen waits for a button.

### ❌ Rejected: settings passed down from the shell through `Game`, the scenes, `Room` and `Player`
- **Why rejected:** five layers would carry a value only the camera's shake reads, and the debug
  scenes (no shell) would need a second path.
- **Tempting because:** no autoload is added.

### ❌ Rejected: the settings file read by the autoload when the game boots
- **Why rejected:** every test would then run with whatever the machine's settings file says
  (shake off on one machine fails the shake tests there).
- **Tempting because:** the settings would be ready before any scene.

---

## 4. Constraints  ·  _Planner_

| ID | Constraint | Reason |
|---|---|---|
| C1 | Everything under `src/core/` extends `RefCounted` or `Resource` and passes `tools/check_core_purity`. `ShellFlow` and `GameSettings` are core; file access is not (C12). | G6 |
| C2 | **The flow is decided in core.** `ShellFlow` (`src/core/shell/shell_flow.gd`) has `enum State { TITLE, PLAYING, PAUSED, SETTINGS, CONFIRM_LEAVE, CONFIRM_QUIT, DEAD }`, starts in TITLE, and changes state only through the methods of the table below. Each returns `true` and emits `state_changed(state)` once when it acts, and returns `false` and changes nothing otherwise. The shell shows what the flow says and never keeps a state of its own about which menu is open. | G6, testability |
| C3 | **Death waits (amends F-012/C5).** `TowerSession.report_player_died()` still starts `DEATH_PAUSE` with `death_return_delay` on the clock, and `tick()` still counts it down, but reaching 0 no longer leaves the pause. New: `can_confirm_death() -> bool` is true in `DEATH_PAUSE` once the time left is 0 (at once when the delay is 0); `confirm_death() -> bool` then goes to the town and returns true, and is refused (false, nothing changes) in every other case. Everything else of F-012/C5 holds: progress made before the death is kept, a death and a boss kill in one tick is a death, the dead player takes no input and the floor's debug keys do nothing. The snapshot keeps its keys; a `DEATH_PAUSE` with 0 s left is now a state that lasts. | Lucas, 2026-11-20; D-006 |
| C4 | **Leaving a floor by choice (amends F-012/C6).** `TowerSession.leave_floor() -> bool` goes to the town from `Place.FLOOR` and is refused anywhere else (the town, the death pause). It changes no progress: floors cleared and bosses reached before it stay, including a boss room entered or a floor cleared during this visit. Nothing else changes about C6: `report_floor_exited()` still needs the cleared boss room. | Lucas, 2026-11-20; D-006 |
| C5 | `Game` gains exactly three public methods and decides nothing in them: `confirm_death() -> bool` and `leave_floor() -> bool` return what the session's methods return; `is_pause_allowed() -> bool` is true when the game was built without setup errors, the session's place is TOWN or FLOOR, and the town's gate list is not open. `Game` no longer shows the "You died" banner (the death screen says it) and the constant `DEATH_BANNER` is removed. `Game` still never frees or replaces a scene inside one of that scene's signals (F-012/C12), and still works without a shell (tests and tools instantiate `game.tscn` alone). | G6; F-012/C12 |
| C6 | **Pausing is `Game.process_mode = Node.PROCESS_MODE_DISABLED`,** set and cleared only by the shell. `SceneTree.paused` is never set. While the flow's state is PAUSED, SETTINGS (reached from the pause menu), CONFIRM_LEAVE or CONFIRM_QUIT the game is disabled; in DEAD it runs (the session's delay is ticked by `Game`, and the room keeps moving behind the death screen as it does today); in TITLE there is no `Game` node. A pause changes nothing in the game: the sim's snapshot (`CombatSim.to_dict()`) and the session's are the same before the pause and after the resume, and a fight paused in the middle ends the same as the same fight never paused. | GUT; G1 |
| C7 | **A menu choice never acts in the game (the input guard).** Whenever the flow enters PLAYING (start, resume, leave confirmed, death confirmed), the `Game` stays disabled until one full physics tick has run with it disabled, and runs from the next tick on. So the press that chose the entry is no longer "just pressed" when the player's input is read again: Space or pad A never dashes, a click never attacks, and Escape or Start never pauses again. This holds at any frame rate and physics rate, including a frame with no physics tick and a frame with two. A key still held when the game runs again is a held key (movement keys move). | `ui_accept` = dodge, click = attack (§2) |
| C8 | **One press, one step.** A single input event causes at most one flow change. Escape (both `pause` and `ui_cancel`) with a menu open goes back one step and does not pause again; with the gate list open it closes the gate list and does not pause (`is_pause_allowed()` is false while it is open, and the gate list consumes the event). `pause` is handled in the shell's `_unhandled_input`, after every menu's `_input`. | Escape is two actions |
| C9 | **`ListMenu` is the gate list's input, moved, not rewritten.** `src/ui/menus/list_menu.gd` (`class_name ListMenu`, extends `Control`) holds what `GateMenu` has today for a column of buttons: the focus index, the four action families, the stick tracking with its seeding at open, navigation events consumed while open, clamped focus, `is_open()`, `close()`, `get_focus_index()`. `GateMenu` extends it and keeps its public API, its signals, its strings and its scene path. **`tests/ui/test_gate_menu.gd` and `tests/scenes/test_f012_town.gd` are not edited and stay green.** A disabled entry can hold the focus and is skipped by nothing, but choosing it does nothing. | Regression safety; one menu feel |
| C10 | `MenuPanel` (`src/ui/menus/menu_panel.gd` + `.tscn`, extends `ListMenu`) shows a heading, a body text (hidden when empty) and entries. It decides nothing: `open(heading, body, entries, focus_id)` shows them, `entry_chosen(id: StringName)` and `cancelled` report what the player did, `set_entry_text(id, text)` and `set_entry_enabled(id, enabled)` change an entry in place without moving the focus. Every text, entry id and default focus of every menu is in `ShellMenus` (`src/ui/menus/shell_menus.gd`, static functions and constants, F-012/C16's rule: no player-facing string anywhere else). | G6; one place for strings |
| C11 | **`GameSettings` (core)** holds `screen_shake_enabled: bool` and `fullscreen: bool`, emits `changed` when a value really changes, and has `to_dict()` / `from_dict()`. `from_dict()` never fails and never crashes: a missing key or a value that is not a `bool` leaves that setting at its default, unknown keys are ignored. Defaults come from `data/tunables/shell.tres` (`ShellTunables`: `default_screen_shake_enabled = true`, `default_fullscreen = false`). | G2, G7-style robustness |
| C12 | **`UserSettings` autoload** (`src/autoload/user_settings.gd`, the project's second autoload) holds the one `GameSettings` (`UserSettings.settings`) and does the file work: `load_from(path) -> bool`, `save_to(path) -> bool`, `reset_to_defaults()`. **It never reads or writes a file by itself**: only the shell calls `load_from()` (once, in its `_ready`) and `save_to()` (after each change), with its exported `settings_path`, default `UserSettings.DEFAULT_PATH = "user://settings.cfg"` (a `ConfigFile`, section `settings`). A missing file is the defaults, silently. An unreadable or malformed file is the defaults and one warning. A failed save is one warning; the setting still applies for this run. No test touches `user://settings.cfg`: tests use their own path and delete it. | Tests must not depend on the machine (§3) |
| C13 | **The shake setting.** `PlaceholderShake` shakes only when the data's `screen_shake_enabled` **and** `UserSettings.settings.screen_shake_enabled` are both true. It follows the setting while it lives: turning it off in the settings menu stops the running shake of the room on screen and no new one starts; turning it on again lets the next hit shake. The debug toggle (K) and a data reload behave as they do today. With the setting at its default nothing about F-003's shake changes. | Accessibility; F-003/C10, C18 |
| C14 | **Fullscreen** is applied by the shell through an injectable `window_mode_applier: Callable` (default: `DisplayServer.window_set_mode` with `WINDOW_MODE_FULLSCREEN` or `WINDOW_MODE_WINDOWED`), once after `load_from()` and on every change of the setting. Tests replace the callable; nothing else calls `DisplayServer` for this. | Testable without a window |
| C15 | **Quitting.** "Quit" on the title screen calls the shell's injectable `quit_handler: Callable` (default: `get_tree().quit`). "Quit to title" frees the `Game` with `queue_free()` after removing it from the tree, never from inside one of its signals, and a later Start builds a new `Game` with fresh progress. | Testable; F-012/C12's reason |
| C16 | **A game that cannot start.** If the new `Game` reports setup errors (`get_setup_errors()` not empty), the shell frees it, the flow goes back to TITLE (`start_failed()`), and the title's body says so (`ShellMenus.START_FAILED_FORMAT`, with the number of errors). The errors are still logged by `Game`. | F-012/C9: bad data builds nothing |
| C17 | All numbers are data or exports: `death_return_delay` stays in `data/tunables/tower.tres` (meaning changed, C3); the settings' defaults in `data/tunables/shell.tres`; sizes, positions, colours and the dim's opacity are `@export`s of `MenuPanel` and `Shell`. New paths are constants (`Tunables.SHELL_TUNABLES_PATH`, `Shell.GAME_SCENE_PATH`, `UserSettings.DEFAULT_PATH`). | G2, G5 |
| C18 | **Existing tests.** Only these existing test files may be edited, and only for the reason given: `tests/core/floors/test_tower_session.gd` and `tests/scenes/test_f012_game.gd` (the automatic return is now a confirmed one; the banner is gone); `tests/scenes/test_f014_game.gd` (its death tests wait for the delay, not the town); `tests/core/floors/test_tower_tunables.gd` (only if a comment or name refers to the old meaning); `tests/scenes/f012_game_test.gd` and `tests/scenes/test_f012_main.gd` (the main scene now starts on the title screen; `spawn_main()` starts the game through the shell); `tests/ui/test_hud.gd` (only if it uses `Game.DEATH_BANNER`). Every edit is listed in §8 with the test's name and what changed. No test is deleted without a replacement that checks the new rule. All other tests stay green unedited. | Regression safety |
| C19 | No new input action and no change to `project.godot`'s `[input]` section; the only `project.godot` change is the `UserSettings` autoload line. No third-party code. | G4; `tests/test_input_map.gd` |

**The flow's methods (C2).** `can_pause` and `on_floor` are plain values the shell reads from the
game (`Game.is_pause_allowed()`, the session's place) and passes in.

| Method | From | To | Notes |
|---|---|---|---|
| `start_game()` | TITLE | PLAYING | |
| `start_failed()` | PLAYING | TITLE | C16 |
| `pause(can_pause: bool)` | PLAYING | PAUSED | refused when `can_pause` is false |
| `resume()` | PAUSED | PLAYING | |
| `open_settings()` | TITLE, PAUSED | SETTINGS | remembers where it came from |
| `close_settings()` | SETTINGS | where it came from | |
| `ask_leave(on_floor: bool)` | PAUSED | CONFIRM_LEAVE | refused when `on_floor` is false |
| `ask_quit()` | PAUSED | CONFIRM_QUIT | |
| `cancel_confirm()` | CONFIRM_LEAVE, CONFIRM_QUIT | PAUSED | |
| `confirm_leave()` | CONFIRM_LEAVE | PLAYING | |
| `confirm_quit()` | CONFIRM_QUIT | TITLE | |
| `player_died()` | PLAYING | DEAD | |
| `death_confirmed()` | DEAD | PLAYING | |
| `back()` | PAUSED, SETTINGS, CONFIRM_* | as `resume()`, `close_settings()`, `cancel_confirm()` | false in TITLE, PLAYING, DEAD |

Also: `get_state()`, `is_game_paused() -> bool` (true in PAUSED, CONFIRM_LEAVE, CONFIRM_QUIT, and
in SETTINGS reached from PAUSED), `get_settings_origin() -> State`. The flow is not game state and
has no snapshot: a loaded game starts in PLAYING.

**The menus (C10).** Entry ids are `StringName` constants of `ShellMenus`. "Focus" is the entry
focused when the menu opens. Cancel is `ui_cancel` or `pause`.

| State | Heading | Body | Entries (id: text) | Focus | Cancel |
|---|---|---|---|---|---|
| TITLE | `Hundred Gates` | empty, or the start-failed line (C16) | `start`: Start · `settings`: Settings · `quit`: Quit | `start` | nothing |
| PAUSED | `Paused` | empty | `resume`: Resume · `leave`: Return to town (only when the session's place is FLOOR) · `settings`: Settings · `quit_to_title`: Quit to title | `resume` | resume |
| SETTINGS | `Settings` | empty | `shake`: `Screen shake: On` / `Screen shake: Off` · `fullscreen`: `Fullscreen: On` / `Fullscreen: Off` · `back`: Back | `shake` | back |
| CONFIRM_LEAVE | `Return to town?` | `This floor's rooms start over next time. Floors you cleared and bosses you reached stay.` | `confirm`: Return to town · `cancel`: Keep fighting | `cancel` | back to PAUSED |
| CONFIRM_QUIT | `Quit to title?` | `Progress is not saved yet. Everything you unlocked will be lost.` | `confirm`: Quit to title · `cancel`: Cancel | `cancel` | back to PAUSED |
| DEAD | `You died` | the HUD's location line, then its kills line when it shows one (two lines), then `You keep everything you unlocked.` | `return`: Return to town (disabled until `can_confirm_death()`) | `return` | nothing |

- Coming back to PAUSED from SETTINGS or a confirm puts the focus on the entry that led there
  (`settings`, `leave`, `quit_to_title`); coming back to TITLE from SETTINGS, on `settings`.
- Choosing `shake` or `fullscreen` flips the setting, rewrites that entry's text in place, keeps
  the focus on it, applies it (C13, C14) and saves (C12).
- Behind a menu over the game the shell draws a dim rectangle (`dim_color`, default black at
  0.6 opacity); behind the title screen an opaque one (`title_color`). The menu layer is above
  the HUD and the gate list (`CanvasLayer.layer = 10`).

**Must not break:** everything F-001 to F-014 do in the debug scenes and in the game: the gate
list (its tests unedited), the floor walk, waves, the kills line (still frozen in the death
pause), room-clear healing, the camera, the debug keys while playing, the debug overlay (F3 works
on every menu, since it is outside `Game`).

---

## 5. Acceptance Criteria  ·  _Planner_

Core (pure, no nodes):
- [ ] AC1: `ShellFlow` starts in TITLE. Every row of the methods table acts from its "From" states
  and is refused (false, no signal, same state) from every other state: a table-driven test over
  all 7 states × all 14 methods.
- [ ] AC2: `open_settings()` from TITLE then `close_settings()` ends in TITLE; from PAUSED, in
  PAUSED; `is_game_paused()` is false for the first SETTINGS and true for the second. `back()`
  does what the table says in each state.
- [ ] AC3: `TowerSession`: after `report_player_died()` and any number of ticks past the delay the
  place is still `DEATH_PAUSE` and `get_death_time_left()` is 0; `can_confirm_death()` is false
  before the delay has passed and true after; `confirm_death()` is refused before, and after it
  returns true, the place is TOWN and the progress is what it was. With a delay of 0,
  `can_confirm_death()` is true in the tick of the death. `confirm_death()` is refused in the
  town and on a floor.
- [ ] AC4: `TowerSession.leave_floor()` from a floor: place TOWN, true; a boss room entered and a
  floor cleared during the visit stay marked; it is refused in the town and in the death pause.
  After it, `enter_floor()` works again and starts the floor at room 0 (or at the boss when
  asked and reached).
- [ ] AC5: The session's snapshot still round-trips in every place, including `DEATH_PAUSE` with
  time left and with 0 left; a restored `DEATH_PAUSE` with 0 left can be confirmed.
- [ ] AC6: `GameSettings`: defaults come from `ShellTunables`; a setter emits `changed` only when
  the value changes; `to_dict()` → `from_dict()` round-trips; `from_dict()` with a missing key, a
  non-bool value, an extra key or an empty dictionary keeps the defaults for what it could not
  read and never errors.

Settings on disk and in the game:
- [ ] AC7: `UserSettings.save_to(path)` then `load_from(path)` on fresh settings gives the saved
  values. `load_from()` of a missing file returns the defaults with no warning; of a file that
  is not a `ConfigFile`, the defaults and one warning. The autoload reads and writes nothing
  until one of the two is called (a test checks no file appears at `DEFAULT_PATH`'s test stand-in
  after boot and a settings change).
- [ ] AC8: With the user's shake setting off, a hit that shakes today leaves the camera's offset
  at zero and `get_current_intensity()` at 0; turning the setting off during a shake clears it at
  once; turning it on again lets the next hit shake. With the data's flag off the setting cannot
  turn shake on. K and a data reload behave as before (existing F-003 tests unedited and green).
- [ ] AC9: Choosing `fullscreen` calls the shell's `window_mode_applier` once with the new mode;
  the shell also calls it once at start with the loaded value. Choosing either setting writes
  the file at the shell's `settings_path`; a new shell on the same path starts with those values.

Menus as nodes:
- [ ] AC10: `GateMenu` extends `ListMenu`; `tests/ui/test_gate_menu.gd` and
  `tests/scenes/test_f012_town.gd` pass with no edit (`git diff main -- <those files>` is empty).
- [ ] AC11: `MenuPanel.open()` shows the heading, the body (hidden when empty), one button per
  entry in order, and focuses `focus_id`. Keys, the d-pad and the stick move the focus as in the
  gate list (clamped, one step per push, no sideways move); `ui_accept` and `interact` and a
  click choose; `ui_cancel` emits `cancelled`. A disabled entry can be focused, and choosing it
  by key, pad or click emits nothing. `set_entry_text()` and `set_entry_enabled()` change the
  entry and leave the focus where it was. While closed it handles no input.
- [ ] AC12: `ShellMenus` gives, for each state of the menus table, exactly that heading, body,
  entries and focus (the PAUSED menu with and without `leave`; the SETTINGS texts for all four
  on/off combinations; the DEAD body with and without a kills line; the TITLE body with and
  without the start-failed line).

The shell (the real `scenes/main.tscn`, driven with real input events through
`Input.parse_input_event`, at 60 physics ticks/s unless said):
- [ ] AC13: The main scene starts on the title screen: no `Game` node exists, the panel shows the
  TITLE menu, the debug overlay still toggles with F3. Start builds the game; the town is shown,
  the menu is hidden, the player stands still.
- [ ] AC14: While playing in the town and on a floor, Escape and pad Start each open the pause
  menu: the `Game`'s `process_mode` is `PROCESS_MODE_DISABLED`, the physics tick count of the
  room's sim does not advance over 30 frames, enemies and projectiles do not move, the HUD's
  banner time does not run. In the town the menu has no `leave` entry; on a floor it has.
- [ ] AC15: Resume (the entry, Escape, pad B, pad Start) closes the menu and the game runs again;
  `CombatSim.to_dict()` and the session's snapshot right after the resume equal the ones taken
  right before the pause. A scripted fight paused for 60 frames in the middle of a dash and of an
  enemy's attack ends with the same final snapshot as the same fight never paused.
- [ ] AC16 (the input guard, C7): with the player's input on, resuming with Space, with pad A,
  with Enter, with a left click on Resume, with Escape and with pad Start: the player does not
  dash and does not attack in the 10 ticks after the resume, and the pause menu does not open
  again. The same for Start on the title (the player in the town does not dash), for "Return to
  town" on the death screen, and for the leave confirm. Run at 30, 60 and 120 physics ticks/s,
  and with the test stepping two physics ticks in one frame and none in a frame. A movement key
  held through the resume moves the player.
- [ ] AC17: With the gate list open, Escape closes the gate list and no pause menu opens; pad
  Start does nothing. During the death pause and on the title screen `pause` does nothing.
- [ ] AC18: Pause → Settings → Back returns to the pause menu with the focus on Settings; the
  game stayed disabled throughout. Title → Settings → Back returns to the title with the focus
  on Settings. Escape in Settings goes back one step only (to the pause menu, which stays open).
- [ ] AC19: On a floor: Pause → Return to town → the confirm opens with the focus on "Keep
  fighting"; choosing it or Escape returns to the pause menu (focus on Return to town) and the
  session is still on the floor. Choosing "Return to town" there: the town is shown, the menu is
  closed, the progress is unchanged, and entering the same floor again starts at room 1 with
  full HP (or at the boss when chosen and reached).
- [ ] AC20: Pause → Quit to title → the confirm opens with the focus on Cancel; Cancel or Escape
  returns to the pause menu. Confirming: no `Game` node is left in the tree after the next frame,
  the title screen is shown, and Start then begins with fresh progress (only floor 1 unlocked).
  No error line and no orphan node from two quit-and-start rounds in a row.
- [ ] AC21: Quit on the title screen calls `quit_handler` once and nothing else.
- [ ] AC22: When the player dies on a floor: the death screen opens in the same tick the session
  enters the death pause; its body is the HUD's location line, the kills line when the room has
  one (a wave room: yes; a boss room: no), and the keep line; the HUD shows no "You died" banner;
  the entry is disabled, and choosing it by any means does nothing, until `death_return_delay`
  has passed; then it is enabled without the menu being rebuilt (the focus stays on it).
- [ ] AC23: Choosing "Return to town" on the death screen: the town is shown with a living player
  at full HP, the menu is closed, the flow is PLAYING, the progress is what it was at the death,
  and a boss room reached in that run is offered "at the boss" by the gate. Nothing returns to
  town by itself: after 20 s on the death screen the session is still in the death pause.
- [ ] AC24: A kill that lands in the player's death tick still counts on the death screen's kills
  line (F-014 CR-11's case), and the HUD's kills and location lines do not change during the
  death pause.
- [ ] AC25: A tower with invalid data: Start shows the title screen again with the start-failed
  line naming the number of errors; no `Game` node is left; a second Start behaves the same.
- [ ] AC26: A single Escape press never causes two changes: from CONFIRM_QUIT it lands in PAUSED
  (not PLAYING), from SETTINGS reached from pause in PAUSED, from PAUSED in PLAYING with no new
  pause. Checked with one real key event per case.

Whole project:
- [ ] AC27: `tools/test` passes (every test that existed before, with only the edits C18 allows,
  plus the new ones), with no "Orphans" line and no leak line at exit; `gdlint src tests` and
  `gdformat --check src tests` are clean; `tools/check_core_purity` passes; the main scene boots
  headless with no error line; the debug scenes still open and run as before.
- [ ] AC28: Rendered check by the lead (not a test): a screenshot of each of the six menus at
  640 × 360 from the real main scene, with no text clipped or overlapping the HUD's lines, the
  focused entry visibly marked, and the disabled death entry visibly different from the enabled
  one.

**How to verify manually:** start the game: the title screen. Start. Walk around the town, press
Escape: the pause menu, no "Return to town". Resume with Space: you must not dash. Enter floor 1,
start a fight, press Escape in the middle of a dash: everything freezes; Resume: it continues.
Pause → Settings: switch screen shake off, go back, take a hit: no shake. Switch fullscreen on.
Quit the game from the title and start it again: both settings are as you left them. On a floor:
Pause → Return to town → Keep fighting; then again → Return to town: you are in the town and the
floor starts over. Die on a floor: the death screen names the floor and room, the button is grey
for a moment, then press it: you are in town. Die in a boss room and check the gate offers "at
the boss". Pause → Quit to title → confirm → Start: only floor 1 is unlocked. With a gamepad:
Start pauses, the stick moves one entry per push, A chooses, B goes back.

---

## 6. Task Breakdown  ·  _Planner_

Two implementers, disjoint files per pair. The lead gates and commits each task.

| # | Task | Files likely touched | Notes |
|---|---|---|---|
| T1 | `ShellFlow` (C2) | `src/core/shell/shell_flow.gd`, `tests/core/shell/test_shell_flow.gd` | AC1, AC2. Pair with T2. |
| T2 | `GameSettings`, `ShellTunables`, the `UserSettings` autoload, the shake setting (C11–C13) | `src/core/shell/game_settings.gd`, `src/core/tunables/shell_tunables.gd`, `data/tunables/shell.tres`, `src/autoload/tunables.gd`, `src/autoload/user_settings.gd`, `project.godot` (autoload line only), `src/world/camera/placeholder_shake.gd`, `tests/core/shell/test_game_settings.gd`, `tests/core/test_shell_tunables.gd`, `tests/autoload/test_user_settings.gd`, `tests/scenes/test_f015_shake.gd` | AC6, AC7, AC8. |
| T3 | The death and leave rules in `TowerSession`; `Game`'s three methods; the banner removed (C3–C5) | `src/core/floors/tower_session.gd`, `src/core/tunables/tower_tunables.gd` (comment), `src/world/game.gd`, `tests/core/floors/test_f015_session.gd`, `tests/scenes/test_f015_game.gd`, and the edits C18 allows in `test_tower_session.gd`, `test_f012_game.gd`, `test_f014_game.gd`, `f012_game_test.gd` (death helpers only) | AC3, AC4, AC5, and the game half of AC22–AC24. Pair with T4. The main scene is unchanged here, so `test_f012_main.gd` stays green. |
| T4 | `ListMenu` out of `GateMenu`; `MenuPanel`; `ShellMenus` (C9, C10) | `src/ui/menus/list_menu.gd`, `src/ui/menus/menu_panel.gd`, `src/ui/menus/menu_panel.tscn`, `src/ui/menus/shell_menus.gd`, `src/ui/town/gate_menu.gd`, `tests/ui/test_f015_menu_panel.gd`, `tests/ui/test_f015_shell_menus.gd` | AC10, AC11, AC12. `ShellMenus` takes plain values (texts, bools), not nodes. |
| T5 | The `Shell`: flow wiring, the pause, the input guard, the death screen, settings, quit, start failure; the main scene (C6–C8, C14–C16) | `src/world/shell.gd`, `src/world/shell.tscn`, `scenes/main.tscn`, `tests/scenes/f015_shell_test.gd` (helpers), `tests/scenes/test_f015_shell.gd` | AC13–AC15, AC17–AC21, AC25, AC26, the shell half of AC9 and AC22–AC24. After T1–T4. |
| T6 | The main scene's existing tests, and the input guard with real events at three rates | `tests/scenes/f012_game_test.gd` (`spawn_main()` only), `tests/scenes/test_f012_main.gd`, `tests/scenes/test_f015_guard.gd` | AC16 and the rest of C18. Pair with T5 once the shell's public names are fixed (below). |
| T7 | Rendered check and screenshots (lead) | scratch only | AC28. |
| T8 | Docs (lead) | `studio/design/floors.md` (the loop's death and leave lines), `studio/GLOSSARY.md`, `studio/features/F-012-the-loop.md` (§10 Q1 answered), `studio/STATUS.md` | |
| T9 | Final gate (lead) | — | AC27. |

**The shell's public names (so T5 and T6 can be written side by side):**
`class_name Shell extends Node`; exports `tower_data: TowerData` (null loads the shipped tower,
passed to the `Game`), `player_input_enabled: bool = true` (passed to the `Game`),
`settings_path: String = UserSettings.DEFAULT_PATH`; vars `window_mode_applier: Callable`,
`quit_handler: Callable`; methods `get_flow() -> ShellFlow`, `get_game() -> Game` (null on the
title screen), `get_menu() -> MenuPanel`, `is_guarding() -> bool` (true while C7 holds the game
back). Node paths: `MenuLayer/Dim`, `MenuLayer/Menu`. The game node is added as a child named
`Game`.

---

## 7. Plan Review  ·  _Auditor_

---

## 8. Implementation Log  ·  _Builder_

**Started:** —  ·  **Branch:** `feature/F-015-menus`

### Progress

### Deviations from plan

### Assumptions made (small, reversible)

### Things the Auditor should look at closely

### How to test

---

## 9. Code Review  ·  _Auditor_

---

## 10. Open Questions  ·  _Anyone (append)_

| # | Raised by | Question | Blocking? | Answer (Lucas/Planner) |
|---|---|---|---|---|
| Q1 | Lead | → Lucas, at Gate B: the lead's choices you did not make. Both "Return to town" and "Quit to title" ask once more before acting; the settings are screen shake and fullscreen only; the title screen is Start, Settings, Quit; the death screen's button is grey for 1.5 s (`death_return_delay`) so a mashed key cannot skip it. | no | |
| Q2 | Lead | → Lucas, at Gate B: the room keeps moving behind the death screen (enemies walk around your body) for as long as you wait, as it did for 1.5 s before. Fine, or should the room freeze? | no | |
| Q3 | Lead | → Lucas / Direction: quitting to the title loses all progress until save/load exists (slice 4). The menu warns about it. | no | |
| Q4 | Lead | → Direction: F-012 §10 Q8 (is a menu choice a player action under G8?) now also covers "Return to town" and the death screen's button: both reach `TowerSession` the way the gate's choice does, with no command object. Still open; it matters for co-op. | no | |
| Q5 | Lead | → Art & Game Feel: the look of every menu (plain buttons, 8 px font, flat dim). | no | |

---

## 11. Director Notes  ·  _Lucas_

