---
id: F-015
title: Menus — title screen, pause menu, death screen, settings
status: CODE_REVIEW      # DRAFT | PLAN_REVIEW | PLAN_CHANGES | APPROVED | IN_PROGRESS | CODE_REVIEW | CODE_CHANGES | DONE | PARKED
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
- **GUT and the tree pause.** With `get_tree().paused = true` GUT's frame waits still return,
  but its time-based waits (`wait_seconds`, `wait_until`) stop until something unpauses
  (measured in plan review round 1). The pause in this feature never touches
  `SceneTree.paused` (C6).
- **Measured in plan review round 1** (probes on the real `game.tscn`, headless):
  - A press is "just pressed" for exactly one physics tick, the first that runs after it,
    whether that tick comes in the same frame, several frames later, or as one of several
    ticks in a frame (48 cases: 30, 60 and 120 ticks/s; Space, pad A, pad X, the left mouse
    button).
  - A node enabled inside a physics tick by a node that is processed earlier runs in that
    same tick.
  - With `process_mode = PROCESS_MODE_DISABLED` on `Game` nothing below it runs
    (`_process`, `_physics_process`, `_input`, `_unhandled_input`), the camera stays current
    and the picture does not jump on resume. But the physics server keeps stepping, and a
    later slide along a wall corner then differs by up to 0.07 px for 9 to 14 ticks; with
    the 2D physics space also set inactive there is no difference (9 of 9 runs).
  - A disabled `Button` can hold the focus and ignores the GUI's own presses, but
    `pressed.emit()` by code still calls its handler.
  - In a GUT run a positional mouse click does not reach a control below GUT's own layer
    (128).
- **Screen shake.** `PlaceholderShake` (`src/world/camera/placeholder_shake.gd`) is a child of
  each room's player and reads `data/tunables/screen_shake.tres` (`screen_shake_enabled`) in
  `_ready`; `debug_shake_toggle` (K) flips the node's own flag. A new room builds a new node.
- **Glossary.** "Screen" alone already means the visible area in tiles (F-013). This spec says
  "title screen" and "death screen" for the two menus Lucas named, and "menu" for the rest.
- **Tooling on Windows:** as in F-011 §2 (`GODOT_BIN`, `.venv/Scripts/gdlint`). The full suite
  takes about 11 minutes.
- Design docs: `studio/design/floors.md`, section "The tower loop" (binding; T9 updates its
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
  knowledge of menus; six menus cost one panel; the gate list's hard-won input handling is
  reused, with its 77 tests as the proof that moving it changed nothing.
- **Costs we're accepting:** one more autoload (`UserSettings`, C12); `GateMenu` is refactored
  although its behaviour must not change; the F-012 tests of the automatic return to town are
  rewritten for the new rule; the menus look as plain as the gate list.
- **Would revisit if:** a menu needs more than a column of entries (sliders for volume, a
  key-binding grid, an inventory), or co-op needs a pause that does not stop the world.

### ❌ Rejected: `get_tree().paused = true`
- **How it would work:** the engine's own pause; menus run with `PROCESS_MODE_ALWAYS`.
- **Why rejected:** the debug overlay and everything else outside the game stops too unless
  each node opts out, and every node added later must remember its process mode; GUT's
  time-based waits stop while paused (§2). Disabling one subtree needs none of that.
- **Tempting because:** it is the tutorial way and one line.

### ❌ Rejected: pausing by not stepping the sim (a flag on `CombatRunner`)
- **How it would work:** the runner skips its ticks while a flag is set.
- **Why rejected:** everything outside the runner keeps running: the HUD's banner time, the
  camera's smoothing and shake, `Game`'s session tick, the town's gate latch, input sampling.
  Each needs its own check, and the next node added would be missed.
- **Tempting because:** it keeps the physics bodies in place and looks like "the logic's pause".

### ❌ Rejected: one scene per menu, switched with `change_scene_to_file()`
- **Why rejected:** the pause and the death screen sit over a running or stopped game that must
  stay loaded; six scenes repeat one layout; tests could not drive the flow in one tree.
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

### ❌ Rejected: the settings held on the `Tunables` autoload, or in a `static var` of `GameSettings`
- **Why rejected:** `Tunables` is the designer's data, read from `res://` and reloadable; the
  player's settings are per machine and written at run time, and mixing them invites a
  reload that wipes a setting. A `static var` in a core class is a hidden global with no
  owner for the file work.
- **Tempting because:** no second autoload.

### ❌ Rejected: the settings file read by the autoload when the game boots
- **Why rejected:** every test would then run with whatever the machine's settings file says
  (shake off on one machine fails the shake tests there).
- **Tempting because:** the settings would be ready before any scene.

---

## 4. Constraints  ·  _Planner_

| ID | Constraint | Reason |
|---|---|---|
| C1 | Everything under `src/core/` extends `RefCounted` or `Resource` and passes `tools/check_core_purity`. `ShellFlow` and `GameSettings` are core; file access is not (C12). | G6 |
| C2 | **The flow is decided in core.** `ShellFlow` (`src/core/shell/shell_flow.gd`) has `enum State { TITLE, PLAYING, PAUSED, SETTINGS, CONFIRM_LEAVE, CONFIRM_QUIT, DEAD }`, starts in TITLE, and changes state only through the methods of the table below. Each returns `true` and emits `state_changed(state: State, previous: State)` once when it acts, and returns `false` and changes nothing otherwise. The shell shows what the flow says and keeps no state of its own about which menu is open or which one it came from. | G6, testability |
| C3 | **Death waits (amends F-012/C5).** `TowerSession.report_player_died()` still starts `DEATH_PAUSE` with `death_return_delay` on the clock, and `tick()` still counts it down, but reaching 0 no longer leaves the pause. New: `can_confirm_death() -> bool` is true in `DEATH_PAUSE` once the time left is 0 (at once when the delay is 0); `confirm_death() -> bool` then goes to the town and returns true, and is refused (false, nothing changes) in every other case. Everything else of F-012/C5 holds: progress made before the death is kept, a death and a boss kill in one tick is a death, the dead player takes no input and the floor's debug keys do nothing. The snapshot keeps its keys; a `DEATH_PAUSE` with 0 s left is now a state that lasts. | Lucas, 2026-11-20; D-006 |
| C4 | **Leaving a floor by choice (amends F-012/C6).** `TowerSession.leave_floor() -> bool` goes to the town from `Place.FLOOR` and is refused anywhere else (the town, the death pause). It changes no progress: floors cleared and bosses reached before it stay, including a boss room entered or a floor cleared during this visit. Nothing else changes about C6: `report_floor_exited()` still needs the cleared boss room. | Lucas, 2026-11-20; D-006 |
| C5 | `Game` gains exactly three public methods and decides nothing in them: `confirm_death() -> bool` and `leave_floor() -> bool` return what the session's methods return; `is_pause_allowed() -> bool` is true when the game was built without setup errors, the session's place is TOWN or FLOOR, what is shown matches the session (not between a place change and the tick that rebuilds), and the town's gate list is not open. `Game` no longer shows the "You died" banner (the death screen says it): the constant `DEATH_BANNER` is removed, and when the death pause starts `Game` hides whatever banner is showing (new `Hud.hide_banner()`), so no "+30 HP" sits under the death screen. The kills line is still fed once in that tick (F-014 CR-11) and then left alone. `Game` still never frees or replaces a scene inside one of that scene's signals (F-012/C12), and still works without a shell (tests and tools instantiate `game.tscn` alone and call `confirm_death()` themselves). The shell reads the HUD's location and kills lines for the death screen through `Game.get_hud()`: presentation reading presentation, nothing is decided from it. | G6; F-012/C12 |
| C6 | **Pausing is `Game.process_mode = Node.PROCESS_MODE_DISABLED`,** set and cleared only by the shell. `SceneTree.paused` is never set. **Whenever the game is disabled the shell also sets the 2D physics space inactive** (`PhysicsServer2D.space_set_active(get_viewport().world_2d.space, false)`), and active again when it enables the game, frees it, or leaves the tree (§2: without it a pause shifts later wall contact). While the flow's state is PAUSED, SETTINGS (reached from the pause menu), CONFIRM_LEAVE or CONFIRM_QUIT the game is disabled; in DEAD it runs (the session's delay is ticked by `Game`, and the room keeps moving behind the death screen as it does today); in TITLE there is no `Game` node. A pause changes nothing in the game: nothing below `Game` ticks, the sim's snapshot (`CombatSim.to_dict()`) and the session's are the same before the pause and after the resume, and a scripted run paused in the middle is tick for tick the same afterwards as the same run never paused. The picture stays as it was, a running shake's offset included (at most `max_offset_px`; accepted, §10 Q6). | GUT; G1 |
| C7 | **A menu choice never acts in the game (the input guard).** Whenever the flow enters PLAYING (start, resume, leave confirmed, death confirmed) the shell disables the `Game` at once if it is not already (C6) and counts its own physics ticks from then: it does nothing in the first and enables the `Game` in its **second** `_physics_process` after the choice, never in the input callback and never in the first tick (§2: a node enabled early in a tick runs in that tick). `is_guarding()` is true from the choice until that enable. The shell's `process_physics_priority` is 3, after `Game`'s 2. So the tick in which the press is "just pressed" (the first after it, §2) always passes with the game disabled: Space or pad A never dashes, a click never attacks, and Escape or Start never pauses again. `pause` is refused while guarding. A key still held when the game runs again is a held key (movement keys move). After a leave or a death is confirmed the old floor stays on screen until the game runs again and swaps (two or three ticks): tests wait for it. | `ui_accept` = dodge, click = attack (§2) |
| C8 | **One press, one step.** A single input event causes at most one flow change. Who handles what: `ListMenu` (so `MenuPanel` and the gate list) handles `ui_cancel` and nothing of `pause`; `MenuPanel` reports it as `cancelled`, which the shell answers with `flow.back()`. The shell's `_unhandled_input` handles `pause` only: `flow.pause(game.is_pause_allowed())` in PLAYING (refused while guarding), `flow.back()` in every other state (which does nothing in TITLE and DEAD). So Escape (both actions) with a menu open is consumed by the menu and goes back one step; with the gate list open it closes the gate list and never reaches the shell; pad Start (only `pause`) with a menu open reaches the shell and goes back one step; with the gate list open it does nothing (`is_pause_allowed()` is false). | Escape is two actions |
| C9 | **`ListMenu` is the gate list's input, moved, not rewritten.** `src/ui/menus/list_menu.gd` (`class_name ListMenu`, extends `Control`) holds what `GateMenu` has today for a column of buttons: the focus index, the four action families, the stick tracking with its seeding at open, navigation events consumed while open, clamped focus, `is_open()`, `close()`, `get_focus_index()`. `GateMenu` extends it and keeps its public API, its signals, its strings and its scene path. **`tests/ui/test_gate_menu.gd` and `tests/scenes/test_f012_town.gd` are not edited and stay green.** One addition, which the gate list never meets (it disables nothing): a disabled entry can hold the focus and is not skipped, and choosing it by key, pad, click or the menu's own `choose` does nothing (the code path that presses the focused button checks `disabled` first, since `pressed.emit()` ignores it, §2). | Regression safety; one menu feel |
| C10 | `MenuPanel` (`src/ui/menus/menu_panel.gd` + `.tscn`, extends `ListMenu`) shows a heading, a body text (hidden when empty) and entries. It decides nothing: `open(heading, body, entries, focus_id)` shows them and takes the focus (again each time it is called, since hiding drops it), `choose(id: StringName)` is what a key, a pad button and a click all reach, `entry_chosen(id: StringName)` and `cancelled` report what the player did, `set_body(text)`, `set_entry_text(id, text)` and `set_entry_enabled(id, enabled)` change the menu in place without moving the focus. Every text, entry id and default focus of every menu is in `ShellMenus` (`src/ui/menus/shell_menus.gd`, static functions and constants, F-012/C16's rule: no player-facing string anywhere else); its functions take plain values (the state, the previous state, texts, bools), never nodes. | G6; one place for strings |
| C11 | **`GameSettings` (core)** holds `screen_shake_enabled: bool` and `fullscreen: bool`, emits `changed` when a value really changes, and has `to_dict()` / `from_dict()`. `from_dict()` never fails and never crashes: a missing key or a value that is not a `bool` leaves that setting at its default, unknown keys are ignored. Defaults come from `data/tunables/shell.tres` (`ShellTunables`: `default_screen_shake_enabled = true`, `default_fullscreen = false`). | G2, G7-style robustness |
| C12 | **`UserSettings` autoload** (`src/autoload/user_settings.gd`, the project's second autoload) holds the one `GameSettings` (`UserSettings.settings`, created once and never replaced, so a listener stays connected) and does the file work: `load_from(path) -> bool`, `save_to(path) -> bool`, `reset_to_defaults()`. `load_from()` and `reset_to_defaults()` change that object in place and it emits `changed` for what really changed. **The autoload never reads or writes a file by itself**: only the shell calls `load_from()` (once, in its `_ready`) and `save_to()` (after each change), with its exported `settings_path`, default `UserSettings.DEFAULT_PATH = "user://settings.cfg"` (a `ConfigFile`, section `settings`); **an empty `settings_path` means the shell neither loads nor saves**. A missing file is the defaults, silently. An unreadable or malformed file is the defaults and one warning. A failed save returns false with one warning; the setting still applies for this run. **No test touches `user://settings.cfg` or the real window:** every test that puts a shell or the main scene in the tree does it through the helpers (`F015ShellTest.spawn_shell()`, `F012GameTest.spawn_main()`), which set a path of their own under `user://test_f015/` (or the empty one), a stub `window_mode_applier` and a stub `quit_handler` before the node enters the tree, and whose `after_each` calls `UserSettings.reset_to_defaults()` and deletes their file. Every other test that changes `UserSettings.settings` (T2's) resets it in its own `after_each`. | Tests must not depend on the machine (§3) |
| C13 | **The shake setting.** `PlaceholderShake` shakes only when the data's `screen_shake_enabled` **and** `UserSettings.settings.screen_shake_enabled` are both true. It follows the setting through the settings' `changed` signal, not by polling, so it also works while the game is disabled: turning it off in the settings menu clears the running shake of the room on screen at once (offset zero) and no new one starts; turning it on again lets the next hit shake. The debug toggle (K) and a data reload behave as they do today. With the setting at its default nothing about F-003's shake changes. A freed camera leaves no connection behind. | Accessibility; F-003/C10, C18 |
| C14 | **Fullscreen** is applied by the shell through an injectable `window_mode_applier: Callable` (default: `DisplayServer.window_set_mode` with `WINDOW_MODE_FULLSCREEN` or `WINDOW_MODE_WINDOWED`), once in the shell's `_ready` with the settings' value (after `load_from()` when there is a path, and also when there is none) and once per change, in the handler of the choice: the shell does not connect to the settings' `changed` signal. Tests replace the callable; nothing else calls `DisplayServer` for this. | Testable without a window |
| C15 | **Quitting.** "Quit" on the title screen calls the shell's injectable `quit_handler: Callable` (default: `get_tree().quit`). "Quit to title" frees the `Game` with `queue_free()` after removing it from the tree, never from inside one of its signals, and a later Start builds a new `Game` with fresh progress. | Testable; F-012/C12's reason |
| C16 | **A game that cannot start.** On Start the shell builds the `Game` first (disabled, C7). If it reports setup errors (`get_setup_errors()` not empty) the shell frees it, the flow stays in TITLE (no flow method is called) and the title's body shows `ShellMenus.START_FAILED_FORMAT` with the number of errors (`MenuPanel.set_body()`); the errors are still logged by `Game`. The shell remembers that count (a number, not a menu state) until a Start succeeds, and the title menu shows the line whenever it is shown meanwhile (also after Settings and Back). Only a game that built calls `flow.start_game()`. | F-012/C9: bad data builds nothing; C8 |
| C17 | All numbers are data or exports: `death_return_delay` stays in `data/tunables/tower.tres` (meaning changed, C3); the settings' defaults in `data/tunables/shell.tres`; sizes, positions, colours and the dim's opacity are `@export`s of `MenuPanel` and `Shell`. New paths are constants (`Tunables.SHELL_TUNABLES_PATH`, `Shell.GAME_SCENE_PATH`, `UserSettings.DEFAULT_PATH`). | G2, G5 |
| C18 | **Existing tests.** Only these existing test files may be edited, and only for the reason given: `tests/core/floors/test_tower_session.gd`, `tests/scenes/test_f012_game.gd` and `tests/scenes/test_f013_camera_game.gd` (the automatic return is now a confirmed one; the banner is gone); `tests/scenes/test_f014_game.gd` (its death tests wait for the delay, not the town); `tests/core/floors/test_tower_tunables.gd` (only if a comment or name refers to the old meaning); `tests/scenes/f012_game_test.gd` and `tests/scenes/test_f012_main.gd` (the main scene now starts on the title screen; `spawn_main()` starts the game through the shell, so `tests/scenes/test_f014_shipped.gd` needs no edit); Every edit is listed in §8 with the test's name and what changed. No test is deleted without a replacement that checks the new rule. All other tests stay green unedited. | Regression safety |
| C19 | No new input action and no change to `project.godot`'s `[input]` section; the only `project.godot` change is the `UserSettings` autoload line. No third-party code. | G4; `tests/test_input_map.gd` |
| C20 | The debug overlay draws above every menu: `src/ui/debug_overlay.tscn` gets `layer = 100` (the menu layer is 10, GUT's own is 128). Nothing else about it changes. | F3 must stay visible on the title screen |
| C21 | **The shell follows the session by polling, after the game.** In its own `_physics_process` (priority 3, after `Game`'s 2), when the flow is PLAYING, the shell is not guarding and the session's place is `DEATH_PAUSE`, it calls `flow.player_died()` and opens the death screen in that same tick, after `Game` has fed the kills line. While the flow is DEAD it sets the `return` entry's enabled state from `can_confirm_death()` every tick. It connects to no signal of the session or of a scene. For the two choices that change the session, the game is asked first and the flow moves only when it said yes: `game.confirm_death()` then `flow.death_confirmed()`, `game.leave_floor()` then `flow.confirm_leave()`; a refusal changes nothing and the menu stays. So a session restored into the death pause (G7) gets its death screen too. | F-014 CR-11's order; no soft lock |

**The flow's methods (C2).** `can_pause` and `on_floor` are plain values the shell reads from the
game (`Game.is_pause_allowed()`, the session's place) and passes in.

| Method | From | To | Notes |
|---|---|---|---|
| `start_game()` | TITLE | PLAYING | |
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
has no snapshot: a loaded game starts in PLAYING, and the shell's poll (C21) takes it to DEAD when
the session was saved in the death pause.

**The menus (C10).** Entry ids are `StringName` constants of `ShellMenus`. "Focus" is the entry
focused when the menu opens. "Cancel" is what `flow.back()` does there, reached by `ui_cancel`
through the menu or by `pause` through the shell (C8).

| State | Heading | Body | Entries (id: text) | Focus | Cancel |
|---|---|---|---|---|---|
| TITLE | `Hundred Gates` | empty, or the start-failed line after a failed Start (C16; a later successful Start and quit shows it empty again) | `start`: Start · `settings`: Settings · `quit`: Quit | `start` | nothing |
| PAUSED | `Paused` | empty | `resume`: Resume · `leave`: Return to town (only when the session's place is FLOOR) · `settings`: Settings · `quit_to_title`: Quit to title | `resume` | resume |
| SETTINGS | `Settings` | empty | `shake`: `Screen shake: On` / `Screen shake: Off` · `fullscreen`: `Fullscreen: On` / `Fullscreen: Off` · `back`: Back | `shake` | back |
| CONFIRM_LEAVE | `Return to town?` | `This floor's rooms start over next time. Floors you cleared and bosses you reached stay.` | `confirm`: Return to town · `cancel`: Keep fighting | `cancel` | back to PAUSED |
| CONFIRM_QUIT | `Quit to title?` | `Progress is not saved yet. Everything you unlocked will be lost.` | `confirm`: Quit to title · `cancel`: Cancel | `cancel` | back to PAUSED |
| DEAD | `You died` | the HUD's location line, then its kills line when it shows one (two lines), then `You keep everything you unlocked.` | `return`: Return to town (disabled until `can_confirm_death()`) | `return` | nothing |

- Coming back to PAUSED from SETTINGS or a confirm puts the focus on the entry that led there
  (`settings`, `leave`, `quit_to_title`); coming back to TITLE from SETTINGS, on `settings`.
  `ShellMenus` works this out from the signal's `previous` state (C2), not from anything the
  shell remembers.
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
  all 7 states × all 13 methods. The signal carries the new state and the one before it.
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
  values. `load_from()` of a missing file gives the defaults and returns false with no warning;
  of a file that is not a `ConfigFile`, the defaults and false. `save_to()` on a path that
  cannot be written returns false and the setting keeps its new value. `load_from()` and
  `reset_to_defaults()` keep the same `GameSettings` object and emit `changed` only when a value
  changed. `user_settings.gd` has no `_ready`, `_init` or `_enter_tree` that touches a file
  (read by the reviewer; the lead checks at T10 that the full suite leaves this machine's real
  `user://settings.cfg` as it was).
- [ ] AC8: With the user's shake setting off, a hit that shakes today leaves the camera's offset
  at zero and `get_current_intensity()` at 0; turning the setting off during a shake clears it at
  once, also when the camera's subtree is disabled (`PROCESS_MODE_DISABLED`); turning it on again
  lets the next hit shake. With the data's flag off the setting cannot turn shake on. K and a
  data reload behave as before (existing F-003 tests unedited and green). After a room is
  rebuilt and the old camera freed, the settings' `changed` signal has one connection, and none
  after the game is freed.
- [ ] AC9: Choosing `fullscreen` calls the shell's `window_mode_applier` once with the new mode;
  the shell also calls it once at start with the loaded value. Choosing either setting writes
  the file at the shell's `settings_path`; a new shell on the same path starts with those values.
  A shell with an empty `settings_path` creates no file and still applies the change.

Menus as nodes:
- [ ] AC10: `GateMenu` extends `ListMenu`; `tests/ui/test_gate_menu.gd` and
  `tests/scenes/test_f012_town.gd` pass with no edit (`git diff main -- <those files>` is empty).
- [ ] AC11: `MenuPanel.open()` shows the heading, the body (hidden when empty), one button per
  entry in order, and focuses `focus_id`. Keys, the d-pad and the stick move the focus as in the
  gate list (clamped, one step per push, no sideways move); `ui_accept`, `interact` and
  `choose(id)` choose (a click is the button's own `pressed`, which reaches `choose`: tests call
  it, since a positional click cannot get under GUT's layer); `ui_cancel` emits `cancelled`;
  a `pause` event is not handled and not consumed. A disabled entry can be focused, and choosing
  it by key, pad or `choose()` emits nothing. `set_body()`, `set_entry_text()` and
  `set_entry_enabled()` change the menu and leave the focus where it was. While closed it
  handles no input. Opened again after being hidden, it has the focus again.
- [ ] AC12: `ShellMenus` gives, for each state of the menus table, exactly that heading, body,
  entries and focus (the PAUSED menu with and without `leave`; the SETTINGS texts for all four
  on/off combinations; the DEAD body with and without a kills line; the TITLE body with and
  without the start-failed line), and the focus for every (state, previous state) pair the flow
  can produce.

The shell (`src/world/shell.tscn` through `F015ShellTest.spawn_shell()` for AC13 to AC15,
AC17 to AC26, the death and leave cases of AC16 and the first sentence of AC29; the real
`scenes/main.tscn` for the rest of AC16 and AC29). Input is real events through
`Input.parse_input_event`, posted between ticks (after `await get_tree().process_frame`), keys
with both `keycode` and `physical_keycode` set; "a click on an entry" is a left mouse button
event (so `attack` is "just pressed") followed in the same frame by the panel's `choose(id)`.
60 physics ticks/s unless said:
- [ ] AC13: The shell starts on the title screen: no `Game` node exists, the panel shows the
  TITLE menu. Start builds the game; the town is shown, the menu is hidden, the player stands
  still. The 2D physics space is active whenever the game runs and after the shell is freed.
- [ ] AC14: While playing in the town and on a floor, Escape and pad Start each open the pause
  menu: the `Game`'s `process_mode` is `PROCESS_MODE_DISABLED`, the 2D physics space is
  inactive, the room's sim time (`CombatSim.get_time()`) does not advance over 30 frames, enemies
  and projectiles do not move, and a banner that was showing is still showing after a pause
  longer than its duration and is gone one duration after the resume. In the town the menu has no `leave` entry; on a floor it has. Tests of the paused state
  step frames without the helpers that submit player commands.
- [ ] AC15: Resume (the entry, Escape, pad B, pad Start) closes the menu and the game runs again;
  `CombatSim.to_dict()` and the session's snapshot right after the resume equal the ones taken
  right before the pause. Two scripted runs, each paused for 60 frames and compared tick by tick
  (position and snapshot) with the same run never paused, show no difference: a fight paused in
  the middle of a dash and of an enemy's attack, and a walk and dash into a wall corner of the
  town for 300 ticks (the case that differs without C6's physics space rule).
- [ ] AC16 (the input guard, C7): in the real main scene with the player's input on, resuming
  with Space, with pad A, with Enter, with a click on Resume, with Escape and with pad Start: the
  player does not dash and does not attack in the 10 ticks after the game runs again, and the
  pause menu does not open again. The same for Start on the title (the player in the town does
  not dash), for "Return to town" on the death screen, and for the leave confirm. Run at 30, 60
  and 120 physics ticks/s, and in two more timings at 60: with three or more frames that have no
  physics tick between the press and the next tick, and with the main thread stalled
  (`OS.delay_msec`) so that the frame after the press runs two or more ticks. A press posted
  inside a tick (after `await get_tree().physics_frame`) is guarded as well. A movement key
  held through the resume moves the player. `is_guarding()` is true from the choice until the
  game runs, and `pause` during it does nothing. Each of the two extra timings is asserted
  before the guard is: the test counts the physics ticks per frame it really got and fails if
  the timing was not produced. The resume and Start cases run through the real main scene
  (T7); the death screen's and the leave confirm's run through `shell.tscn` (T6), at 60 and
  120 ticks/s.
- [ ] AC17: With the gate list open, Escape closes the gate list and no pause menu opens; pad
  Start does nothing. During the death pause and on the title screen `pause` does nothing. In
  the ticks between a gate choice and the floor being shown `pause` does nothing.
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
  one (a wave room: yes; a boss room: no), and the keep line; the HUD shows no banner at all (a
  "+30 HP" that was showing is gone);
  the entry is disabled, and choosing it by any means does nothing, until `death_return_delay`
  has passed; then it is enabled without the menu being rebuilt (the focus stays on it).
- [ ] AC23: Choosing "Return to town" on the death screen: the town is shown with a living player
  at full HP, the menu is closed, the flow is PLAYING, the progress is what it was at the death,
  and a boss room reached in that run is offered "at the boss" by the gate. Nothing returns to
  town by itself: after 20 s of ticked time on the death screen (2,400 ticks at 120 ticks/s, with the delay shortened for the test) the session is still in the death pause.
- [ ] AC24: A kill that lands in the player's death tick still counts on the death screen's kills
  line (F-014 CR-11's case), and the HUD's kills and location lines do not change during the
  death pause.
- [ ] AC25: A tower with invalid data: Start leaves the title screen up with the start-failed
  line naming the number of errors; the flow never left TITLE (no `state_changed`); no `Game`
  node is left and the physics space is active; a second Start behaves the same.
- [ ] AC26: A single Escape press never causes two changes: from CONFIRM_QUIT it lands in PAUSED
  (not PLAYING), from SETTINGS reached from pause in PAUSED, from PAUSED in PLAYING with no new
  pause. Checked with one real key event per case, and the same three with one pad Start press.
- [ ] AC29: A session put into the death pause by `from_dict()` while the shell is playing shows
  the death screen on the shell's next tick, and it can be confirmed. In the real main scene:
  the title screen is what a launch shows, the debug overlay (F3) is drawn above it, and after
  Start everything `tests/scenes/test_f012_main.gd` and `test_f014_shipped.gd` check still holds.

Whole project:
- [ ] AC27: `tools/test` passes (every test that existed before, with only the edits C18 allows,
  plus the new ones), with no "Orphans" line and no leak line at exit; `gdlint src tests` and
  `gdformat --check src tests` are clean; `tools/check_core_purity` passes; the main scene boots
  headless with no error line; the debug scenes still open and run as before.
- [ ] AC28: Rendered check by the lead (not a test; it is also the only check of a real click on
  an entry, of the focus mark and of fullscreen in a real window): a screenshot of each of the six menus at
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
| T3 | The death and leave rules in `TowerSession`; `Game`'s three methods; the banner removed (C3–C5) | `src/core/floors/tower_session.gd`, `src/core/tunables/tower_tunables.gd` (comment), `src/world/game.gd`, `src/ui/hud/hud.gd` (`hide_banner()`, its header comment), `tests/core/floors/test_f015_session.gd`, `tests/scenes/test_f015_game.gd`, and the edits C18 allows in `test_tower_session.gd`, `test_f012_game.gd`, `test_f013_camera_game.gd`, `test_f014_game.gd`, `f012_game_test.gd` (death helpers only) | AC3, AC4, AC5, and the game half of AC22–AC24. Pair with T4. The main scene is unchanged here, so `test_f012_main.gd` stays green. |
| T4 | `ListMenu` out of `GateMenu`; `MenuPanel`; `ShellMenus` (C9, C10) | `src/ui/menus/list_menu.gd`, `src/ui/menus/menu_panel.gd`, `src/ui/menus/menu_panel.tscn`, `src/ui/menus/shell_menus.gd`, `src/ui/town/gate_menu.gd`, `tests/ui/test_f015_menu_panel.gd`, `tests/ui/test_f015_menu_texts.gd` | AC10, AC11, AC12. `ShellMenus` takes plain values (texts, bools), not nodes. |
| T5 | The `Shell`, part 1: the scene, the title screen, Start and its failure, Quit, the pause and resume, the physics space, the input guard, `pause` and cancel (C6–C8, C15, C16) | `src/world/shell.gd`, `src/world/shell.tscn`, `tests/scenes/f015_shell_test.gd` (helpers: `spawn_shell()`, C12's hygiene), `tests/scenes/test_f015_shell.gd` | AC13–AC15, AC17, AC21, AC25, and AC26's PAUSED case. After T1–T4. `scenes/main.tscn` is not touched: nothing existing can fail. At this commit the pause menu's `leave`, `settings` and `quit_to_title` entries and the title's `settings` entry are shown and do nothing; T6 gives them their handlers. |
| T6 | The `Shell`, part 2: settings (apply, save, fullscreen), the two confirms, leaving a floor, quitting to the title, the death screen and its poll (C12, C14, C15, C21) | `src/world/shell.gd`, `tests/scenes/test_f015_shell_flow.gd`, `tests/scenes/test_f015_shell_death.gd` | AC9, AC18–AC20, AC22–AC24, AC26, AC29's first sentence, AC16's death and leave cases. After T5; pair with T7. |
| T7 | The main scene switches to the shell, in one commit with its tests: `scenes/main.tscn`, the overlay's layer, `spawn_main()`, the input guard through the real main scene at three rates (C7, C18, C20) | `scenes/main.tscn`, `src/ui/debug_overlay.tscn`, `tests/scenes/f012_game_test.gd` (`spawn_main()` and `after_each()` only), `tests/scenes/test_f012_main.gd`, `tests/scenes/test_f015_guard.gd`, `tests/scenes/test_f015_main.gd` | AC16's resume and Start cases, the rest of AC29, the rest of C18. After T5. |
| T8 | Rendered check and screenshots (lead) | scratch only | AC28. |
| T9 | Docs (lead) | `studio/design/floors.md` (the loop's death and leave lines, the "lives for one run" line, FX5), `studio/GLOSSARY.md` (Death pause redefined; Pause, Shell, Title screen, Death screen, Input guard added), `studio/features/F-012-the-loop.md` (§10 Q1 answered), `studio/STATUS.md` | |
| T10 | Final gate (lead) | — | AC27, and C12's check of the real settings file. |

**The shell's public names (so T6 and T7 can be written side by side once T5 has landed):**
`class_name Shell extends Node`; exports `tower_data: TowerData` (null loads the shipped tower,
passed to the `Game`), `player_input_enabled: bool = true` (passed to the `Game`),
`settings_path: String = UserSettings.DEFAULT_PATH` (empty: no file, C12); vars
`window_mode_applier: Callable`, `quit_handler: Callable`; methods `get_flow() -> ShellFlow`,
`get_game() -> Game` (null on the title screen), `get_menu() -> MenuPanel`,
`is_guarding() -> bool` (true while C7 holds the game back). Node paths: `MenuLayer/Dim`,
`MenuLayer/Menu`. The game node is added as a child named `Game`. In `scenes/main.tscn` the
shell is the node `Shell`.

---

## 7. Plan Review  ·  _Auditor_

<!-- review-round: 1 verdict: CHANGES_REQUESTED -->

**Reviewed commit:** 00697ef · **Date:** 2026-11-20 · **Verdict:** CHANGES_REQUESTED · **By:** Auditor (lead, D-014)

Two fresh reviewers, read-only, neither wrote the spec. One read §1–§6 against the code, the
design docs and the decisions. The other tested the spec's engine assumptions in a private copy
of `00697ef` with GUT probes on the real `game.tscn` (process modes, "just pressed" timing, event
order, the tree pause, quit and rebuild, a signal on a held object, disabled buttons). The lead
checked each finding before recording it: PR-1 and PR-11 by reading the tests and docs, PR-2 by
running the reviewer's wall probe again (same numbers).

### PR-1 🔴 C18's list of tests that may be edited misses one that must change  ·  C18, AC27, T3
`tests/scenes/test_f013_camera_game.gd:100-109` (`test_ac5_the_town_after_a_death_in_a_floor`)
kills the player and waits for the town. With C3 it times out, C18 says every unlisted test stays
green unedited, so T3's commit would be red and AC27 unreachable. A search of every test for
`kill_player`, `set_death_delay`, `DEATH_PAUSE`, `DEATH_BANNER`, `spawn_main` and `spawn_game`
found no other miss; `test_hud.gd` and `test_f014_hud.gd` use the literal "You died" on the HUD
alone and stay green.
> **Planner reply (lead):** accepted. The file is in C18 and T3. `test_hud.gd` is off the list
> (it never needed an edit).

### PR-2 🔴 "A paused fight ends the same as one never paused" is false at walls with `process_mode` alone  ·  C6, AC15
Measured: a walk and dash into the town's north-west corner for 300 ticks, never paused, repeats
exactly (0 differing ticks in 3 runs). Paused once for 1 to 240 frames anywhere before the corner:
9 to 14 later ticks differ, by at most 0.066 px. The cause is the physics server stepping while the
game is disabled (`disable_mode = KEEP_ACTIVE` does not help); with the 2D physics space set
inactive during the pause there are 0 differences in 9 of 9 runs. The fight probe (dash, enemy
attack, pending arrival, projectile in flight) showed no difference either way. Invisible to a
player, but an exact-equality AC would pass or fail by where the script walks.
> **Planner reply (lead):** accepted, by making the claim true: C6 now also sets the physics
> space inactive whenever the game is disabled, and AC15 compares tick by tick and adds the
> corner walk as its second run.

### PR-3 🟡 T5's commit is red until T6 lands, and T5 is most of the feature  ·  T5, T6
T5 switched `scenes/main.tscn` while `spawn_main()` still looked for a `Game` child: all of
`test_f012_main.gd` and `test_f014_shipped.gd:45` would fail until T6.
> **Planner reply (lead):** accepted. The shell is now tested through its own scene (T5, T6) and
> the main scene switches in one commit with its helper and tests (T7). T5 is split in two.

### PR-4 🟡 The spec did not say how the shell learns of a death; the obvious ways break AC22 or AC24  ·  C2, C5
`place_changed` fires inside `FloorScene`'s tick (priority 1), before `Game` (priority 2) feeds
the kills line for the death tick; a shell that listens reads the line too early (AC24), one that
polls at priority 0 is a tick late (AC22). The shell also reads the HUD although `hud.gd:4` says
nothing reads it.
> **Planner reply (lead):** accepted. New C21: the shell polls the session at priority 3 and
> connects to no session or scene signal. C5 says the shell may read the two HUD lines.

### PR-5 🟡 Focus-on-return needs the previous state, which C2 forbade the shell to keep  ·  C2, the menus table
> **Planner reply (lead):** accepted. `state_changed(state, previous)`; `ShellMenus` derives the
> focus from the pair (AC12).

### PR-6 🟡 Settings would leak between tests through the autoload and the real main scene  ·  C12, C14
Every `spawn_main()` test would run the shell's `_ready`: the machine's real settings file read
into the global settings, and the real window applier called. Unsaid too: whether loading replaces
the settings object (orphaning C13's listeners) and whether it emits `changed`.
> **Planner reply (lead):** accepted. C12: one object, changed in place; an empty path means no
> file; every test goes through helpers that set a test path and stubs and reset afterwards; the
> lead checks the real file at T10.

### PR-7 🟡 Who treats `pause` as cancel was stated three ways  ·  the menus table, C8, AC11
> **Planner reply (lead):** accepted. C8 now says it once: the menus handle `ui_cancel` only, the
> shell's `_unhandled_input` handles `pause` only. Measured: pad Start with a menu open reaches
> the shell's `_unhandled_input`; an Escape consumed by a menu reaches nothing else.

### PR-8 🟡 The guard's mechanism was left to guess, and one obvious way fails  ·  C7, AC16
Measured: a node enabled inside a tick by a node processed earlier runs in that same tick (36 of
36 probes acted; the real player dashed). One full tick disabled, then enable: 0 of 36. Also for
the test: a press posted inside a tick is "just pressed" in the next one, and AC16's "two ticks in
a frame and none" named no way to produce them.
> **Planner reply (lead):** accepted. C7 names the mechanism (enable in the shell's second tick
> after the choice, priority 3) and AC16 says where events are posted and how the two extra
> timings are made.

### PR-9 🟡 AC7's last sentence could not be tested; a failed save had no AC  ·  AC7, C12
> **Planner reply (lead):** accepted. AC7 rewritten; the "no file by itself" rule is checked by
> reading and by the lead's check of the real file.

### PR-10 🟡 A session restored into the death pause under a playing shell would never show the death screen  ·  the methods table's note, AC5
> **Planner reply (lead):** accepted. C21's poll covers it; AC29.

### PR-11 🟡 Two design-doc lines contradicted and not in the docs task  ·  T8
`floors.md:121-122` ("Progress … lives for one run of the game") is no longer true after a quit
to the title; FX5 asks the question this feature answers; the glossary's "Death pause" is no
longer short, and "pause" gets a second meaning.
> **Planner reply (lead):** accepted. All three are in T9.

### PR-12 🟡 Smaller guesses  ·  C5, C7, C8, C13, C16
(a) Start on bad data was two flow changes from one event. (b) The death banner used to replace a
running "+30 HP"; nothing said what happens to it now. (c) After a leave or death confirm the old
floor shows for a few ticks. (d) `is_pause_allowed()` was true between a gate choice and the swap,
with the session on FLOOR and the town still shown. (e) Nothing checked that turning shake off
while the game is disabled clears the offset.
> **Planner reply (lead):** accepted: (a) C16 builds the game before `start_game()` and
> `start_failed()` is gone (13 methods); (b) C5: the banner is hidden at the death; (c) C7 says so;
> (d) C5 and AC17; (e) C13 and AC8.

### PR-13 🟡 Clicks cannot be tested as written, and "choosing a disabled entry does nothing" needs new code  ·  AC11, AC16, C9
A positional click does not reach a control under GUT's layer 128. `GateMenu._press_focused()`
calls `pressed.emit()`, which fires on a disabled button.
> **Planner reply (lead):** accepted. Tests use `choose(id)`; a real click is part of the lead's
> rendered check (AC28). C9 names the disabled check as its one addition.

### PR-14 🔵 The debug overlay would be hidden under the title screen  ·  AC13
> **Planner reply (lead):** accepted. C20: the overlay's layer is 100.

### PR-15 🔵 Wording, and an unlisted option  ·  §2, §3, AC14
"Five menus" (there are six); `CombatSim` has `get_time()`, no tick count; the tree-pause
rejection overstated what stops in GUT (only the time-based waits; measured); holding the settings
on `Tunables` or in a `static var` was not listed.
> **Planner reply (lead):** accepted, all four.

### PR-16 🔵 Three things measured that the spec should own  ·  C6
The paused picture keeps a frozen shake offset (up to 6 px). The pad Start press that pauses stays
in the player's device events and flips the aim mode to the gamepad on resume (correct: it was a
pad press). `run_ticks()` submits player commands that nobody consumes while paused.
> **Planner reply (lead):** the first is accepted as it is (C6, §10 Q6); the second needs nothing;
> the third is a note in AC14.

### PR-17 🔵 Scope: fullscreen and the start-failure handling were not asked for
> **Planner reply (lead):** kept, and Lucas is told (§10 Q1). Fullscreen is a few lines behind an
> injectable call and a build for a stranger needs it; without the start-failure rule bad data
> would leave a blank screen behind the title.

**Checked by the reviewers, nothing found:** §2's input facts against `project.godot`; §2's
account of `Game`, `TowerSession`, `FloorScene`, `PlaceholderShake` and the cited F-012 rules;
`GateMenu`'s 77 tests use only its public API, so the move can leave them unedited; every AC has a
task; T1∥T2 and T3∥T4 are on disjoint files; the contradictions with `floors.md`'s death and leave
lines, F-012 C5/C6 and G8 were flagged in the spec; no `process_mode`, `paused` or `Area2D` use
exists in `src`. Measured true: everything below a disabled `Game` stops and the sim and session
snapshots are equal across a pause; the camera stays current with no jump; quit and rebuild three
times leaves 0 orphans and no error line; a camera connected to a signal of a held object leaves
no connection once freed; a `Game` added already disabled builds and later runs the same.

**Not checked:** real OS events, a real pad, a real window (fullscreen, focus visuals); the guard
on the real player at 30 and 60 ticks/s (probe nodes only; the real player at 120); why the
physics stepping changes wall contact; the wall difference inside a fight; `tower_progress.gd`,
`test_f012_town.gd` and `test_tower_session.gd` line by line.

<!-- review-round: 2 verdict: APPROVE_WITH_NOTES -->

**Reviewed commit:** 5c32c45 · **Date:** 2026-11-20 · **Verdict:** APPROVE_WITH_NOTES · **By:** Auditor (lead, D-014)

The reviewer who read the spec in round 1, read-only, on the amended text. It ran nothing.

**Round 1 findings:** PR-1 to PR-17 ✔ resolved, each checked against the amended text (PR-2 by
C6's physics-space rule and AC15's corner walk, not measured again; PR-17 as a decision). Three
left a slip behind, recorded as PR-22 below.

### PR-18 🟡 AC14 asked for the banner's time left, which nothing exposes  ·  AC14, `src/ui/hud/hud.gd:34`
> **Planner reply (lead):** accepted. AC14 now checks what can be seen: still showing after a
> pause longer than its duration, gone one duration after the resume.

### PR-19 🟡 C12's test hygiene did not fit T7's file scope and missed T2's tests  ·  C12, T7, T2
> **Planner reply (lead):** accepted. T7 may edit `after_each()` too; C12 covers every test that
> changes the settings.

### PR-20 🟡 AC16's two extra timings could pass without having happened  ·  AC16
> **Planner reply (lead):** accepted. The test asserts the timing it got before it asserts the
> guard.

### PR-21 🟡 Four guesses left in the sequences  ·  C7, C14, C16, C21, T5
The order of the game's call and the flow's on a confirm, and what a refusal does; whether the
title still shows the start-failed line after Settings and Back; whether the window applier is
called at start with no settings file; what three pause-menu entries do at T5's commit.
> **Planner reply (lead):** accepted, all four: C21 (game first, flow only on yes), C16 (the
> shell remembers the count until a Start succeeds), C14 (called once at start either way, and no
> connection to `changed`, which also keeps AC8's connection count true), T5's note.

### PR-22 🔵 Cross-references and wording
AC7 named T9 for the lead's check (it is T10); §5's header put all of AC29 and AC16 on the main
scene; two test files shared a name; the guard's death and leave cases had no task; C18 listed
`test_debug_overlay.gd`, which pins no layer; §3 still said "five scenes".
> **Planner reply (lead):** accepted, all six. AC16's death and leave cases now run through
> `shell.tscn` in T6; T4's test file is `test_f015_menu_texts.gd`.

**Traced by the reviewer with no guess left:** a death in the tick of a pause press (the pause
wins before the death tick; after it the flow is DEAD in the same tick); `pause` during the guard
and while the shown scene is stale (refused); quit to the title while the physics space is
inactive, then Start; the shell leaving the tree while paused. Every AC has a task and no commit
is red in the order T1 to T7; T7 can land before T6.

**Not checked in this round:** any engine behaviour (the space-inactive measurement, tick order
at priority 3, `OS.delay_msec` producing frames with several ticks); whether 20 s on the death
screen (AC23) is affordable in suite time; `tower_progress.gd`, `test_f012_town.gd` and
`test_tower_session.gd` line by line.

**Gate A (lead, D-016):** Lucas's answers and "Yes, start" of 2026-11-20 are Gate A; the file
skips `APPROVED`. He has not read this spec: what he did not decide is in §10 Q1 to Q3.

---

## 8. Implementation Log  ·  _Builder_

**Started:** 2026-11-20  ·  **Branch:** `feature/F-015-menus`

### Progress
- [x] T1 — e546137
- [x] T2 — b89f7b5
- [x] T3 — 24a8b78
- [x] T4 — 25c1b88
- Full suite on 24a8b78 (T1 to T4): 151 scripts, 2274 tests, all passing (726 s), no "Orphans" line.
- [x] T5 — 24af208
- [x] T6 — 8c7980d
- [x] T7 — 4bfec51
- [x] T8 — rendered check by the lead on 4bfec51, results under "How to test"
- [x] T9 — docs, with this commit
- [ ] T10 — the final gate comes after the code review; the full suite on 4bfec51 (T1 to T7) is
  156 scripts, 2442 tests, all passing (888 s), no "Orphans" line, no leak line.
- [x] Code review round 1 — CR-3, CR-7, CR-9, CR-10, CR-12 9625676; CR-1, CR-2, CR-4, CR-5, CR-6,
  CR-7, CR-8, CR-9, CR-11 8429634; CR-13 answered. Full suite on 8429634: 157 scripts, 2480
  tests, all passing (971 s), no "Orphans" line, no leak line.
- [x] Code review round 2 — CR-14 4c4820b (the log); CR-15, CR-16, CR-18, CR-20 936e9ad; CR-17,
  CR-19 ec7b44b; CR-21 answered. Full suite on ec7b44b: 158 scripts, 2547 tests, all
  passing (1070 s), no "Orphans" line, no leak line.
- [x] Code review round 3 — CR-22, CR-26 (the log) acbbc6f; CR-23, CR-24, CR-25, CR-27 a25c43d;
  CR-26 accepted (DEV-15); CR-28 answered. Full suite on a25c43d: 158 scripts, 2571 tests,
  all passing (1081 s), no "Orphans" line, no leak line.

### Deviations from plan
- DEV-1: the file went from `PLAN_REVIEW` to `IN_PROGRESS` without `APPROVED` — **Why:** D-016,
  Lucas's answers and go-ahead in chat are Gate A — **Impact:** none on the code.
- DEV-2: T4 has two files §6 does not list: `src/ui/menus/menu_entry.gd` (`MenuEntry`: id, text,
  enabled) and `tests/ui/test_f015_list_menu.gd` — **Why:** the lead added them in the task's
  brief: `MenuPanel.open()` takes typed entries instead of dictionaries, and the base class's one
  addition (the disabled entry) needed a test of its own, since `MenuPanel.choose()` checks
  `disabled` too and hid a mutation of the base — **Impact:** `ShellMenus.entries()` returns
  `Array[MenuEntry]`.
- DEV-3: T4 ran beside T2 and T3 beside T4's end, not in the pairs §6 names — **Why:** T4 only
  needed T1 — **Impact:** none; the files of the three are disjoint and each was gated alone.
- DEV-4: in T3 the code was written before its new tests — **Why:** the implementer's order —
  **Impact:** each new test was then shown to fail for the right reason by 10 mutations in a
  private copy (old timed return, `can_confirm_death()` ignoring the time, `leave_floor()` in the
  death pause, progress reset on leave, the three `is_pause_allowed()` conditions, no
  `hide_banner()`, no feed of the death tick, no clamp at 0); all were caught.
- DEV-5: `GateMenu` changed in two ways beyond losing the moved code: its `_ready` sets the
  base's `_panel` and `_list` and calls `super` (the `@onready` vars are gone), and
  `_clear_buttons()` no longer clears `_entries` (`open()` reassigns it on the next line) —
  **Why:** the base cannot know the subclass's node paths or its entry type — **Impact:** none
  that a test or a caller can see; the 77 gate tests and the town's 59 pass unedited.

- DEV-6 (T5): **the physics space comes back one tick after the game, not with it** (C6 says
  "active again when it enables the game") — **Why:** measured. The physics server steps after
  every node of a tick. The shell enables the game in its own tick, after the game's nodes were
  already passed, so with the space switched on there the server takes one step in which nothing
  moved, and a later slide along a wall corner then differs from a never-paused run by 4e-6 px
  at one tick. With the space switched on in the shell's next tick (the tick the game first runs
  in) the three corner runs and the fight run show no differing tick. Restoring C6's letter fails
  those three tests — **Impact:** in the first tick the game runs in, `is_guarding()` is already
  false and the space is still inactive until the shell's turn in that tick; movement is not
  affected (the twins are equal), and tests that assert the space wait one more tick. The space
  is switched in one function, `Shell._set_game_running()`, plus that one-tick follow.
- DEV-7 (T6): **the shell follows the session in both directions** (an extension of C21 by the
  lead, after the T6 implementer pointed at the gap) — **Why:** only the death screen's entry
  could leave DEAD. A death pause ended any other way (`game.confirm_death()` called directly, a
  session restored into the town or a floor) would have left the death screen up with a dead
  button — **Impact:** in DEAD, when the session's place is no longer the death pause, the
  shell's poll calls `flow.death_confirmed()`; the entry's own path is unchanged and still
  changes the flow exactly once (tested).
- DEV-8 (T5, T6): the shell's tests could not be watched failing before the shell existed (the
  script did not load) — **Impact:** the proof is the mutations, all in private copies: no guard,
  a one-tick guard, the space not stopped, not reactivated on leaving the tree, `pause` let
  through while guarding, an Escape that changes twice, a failed game left in the tree, the
  space reactivated with the game (DEV-6's evidence); the poll a tick late, the HUD read before
  the game fed it, the flow before the game on both confirms, the entry enabled from the start
  or never followed, a confirm without the guard, a quit that leaves the game or the stopped
  space, a settings choice that reopens the panel, does not save, or calls the window twice. Each
  failed at least one test; the lists are in the commit reviews, not repeated here.
- DEV-9 (T7): AC16's timing "three or more frames with no physics tick" is produced by holding
  `Engine.physics_ticks_per_second` at 1 for four frames right after the press, then restoring
  60 — **Why:** a headless frame takes about 6 ms, so at 60 ticks/s at most two frames fall
  between ticks, and `Engine.time_scale` does not change the tick spacing — **Impact:** the
  count of tickless frames is asserted before the guard is judged, as AC16 asks. For Start in
  that timing the test uses a one-room fixture tower: with the shipped tower (whose build blocks
  the thread for about 0.8 s) and the rate held at 1, the camera's transform became invalid (10
  engine warnings a case). The game never changes its tick rate; see "look at closely".
- DEV-10 (T7): `spawn_main(prepare)` now passes the main scene's `Shell`, not its `Game`, to
  `prepare` — **Why:** the game does not exist before Start — **Impact:** none; no caller passes
  `prepare`.

- DEV-11 (code review CR-2): **a pointer guard the spec does not have.** For
  `MenuPanel.pointer_guard_seconds` (0.3) of real time after a menu opens its entries ignore the
  mouse — **Why:** the second click of a double click landed on whatever entry the new menu put
  under the cursor (Fullscreen switched on; a quit with no confirmation) — **Impact:** a
  deliberate click in the first 0.3 s after a menu opens does nothing; keys and the pad are not
  delayed. The gate list has no such guard (it closes on a choice).
  **After code review round 2 (CR-15, CR-16), 936e9ad:** it is a choose guard,
  `MenuPanel.choose_guard_seconds`. For those 0.3 s `ui_accept` and `interact` choose nothing
  either (the focus still moves, `ui_cancel` still goes back, `choose(id)` by code is free), and
  a mouse button event the OS marks as a double click never chooses, at any time. So keys and
  the pad ARE delayed now, by the same 0.3 s. The scene tests' helper sets the guard to 0; the
  panel's tests and the click tests run with the default.
  **`ListMenu` changed for this, a second addition to the moved code (C9 names one; code
  review CR-22):** a hook `_may_choose_by_key()`, true in the base, asked at the top of
  `_press_focused()`. `MenuPanel` answers false during its guard. `GateMenu` and its tests are
  untouched and the gate list chooses by key at once, as before.
- DEV-12 (code review CR-3): from T7 (4bfec51) to 9625676 `test_f015_guard.gd` and
  `test_f015_main.gd` put the main scene in the tree with spawners of their own, against C12's
  letter — **Why:** `spawn_main()` chooses Start with the input off, and T7's brief told the
  implementer to write a local helper — **Impact:** none since 9625676 (one helper,
  `spawn_main_on_title()`); the lead's brief was the cause.
- DEV-13 (code review CR-1): **the game's bodies stay in the physics space while it is
  stopped** (`DISABLE_MODE_KEEP_ACTIVE`, set by the shell at each stop), which C6 does not say —
  **Why:** measured: a disabled node's bodies leave the space and come back, and that shifted a
  later wall slide by up to 0.004 px — **Impact:** a body below `Game` that is disabled by
  anything else after a pause also stays in the space; nothing disables one today.
- DEV-14 (code review CR-10, CR-11): `UserSettings.load_from()` walks every section of the file
  and frees objects it finds, and the default window applier does nothing in a window embedded
  in the editor; neither is in C12 or C14 — **Why:** a hand-written `Object(Node,…)` left an
  orphan; an embedded window cannot change its mode — **Impact:** none on a settings file the
  game wrote.
  **After code review round 2 (CR-17), ec7b44b:** the first half is replaced. `load_from()`
  does not use `ConfigFile` to read (C12 says "a `ConfigFile`"): it reads the bytes and takes
  only `[settings]` and `key=true` / `key=false`. A file over 64 KB, one with a NUL byte, and
  one with content and no `[settings]` line are "not a settings file": the defaults, false,
  one warning. `save_to()` still writes through `ConfigFile`.
- DEV-15 (code review rounds 2 and 3): **the menus' click rules, as they ended up, and one case
  left open.** After round 3 (a25c43d): (a) for `choose_guard_seconds` (0.3) after a menu opens,
  clicks and the choose keys do nothing; (b) a mouse press during that time starts it again; (c)
  a press the OS marks as a double click is discarded when the menu opened since the previous
  mouse press, at any time. **Left open, accepted:** a double click on Resume resumes and the
  player attacks once, because the attack is read from the mouse button's state, not from the
  event the menu could discard — **Impact:** one attack in the first moments after a resume by
  double click; a deliberate click more than 0.3 s after a menu opened acts on whatever is
  under it, also when it was meant as the tail of a slow triple click. `save_to()` writes the
  settings file by hand and `src` has no `ConfigFile` left (C12 says "a `ConfigFile`": the
  file's bytes are the same).

**Existing tests edited (C18), all in T3 except the last two bullets.** No test was deleted; eight were renamed.
- `tests/scenes/f012_game_test.gd`: new helper `confirm_death_when_ready(limit)` (ticks until
  `can_confirm_death()`, then `game().confirm_death()`). Nothing else.
- `tests/core/floors/test_tower_session.gd`: the helper `_tick_until_town` became
  `_tick_and_confirm` (used by `test_ac11_a_cleared_visit_followed_by_a_death_still_returns_to_town_with_progress`
  and `test_ac12_a_boss_reached_before_dying_is_still_reached`). Renamed and changed to the new
  rule: `test_ac12_ticking_allows_the_return_within_one_step_of_the_delay`,
  `test_ac12_the_pause_counts_down_and_the_town_comes_once_it_is_confirmed`,
  `test_ac12_after_the_confirmed_pause_the_floor_is_gone_and_the_timer_is_zero`,
  `test_ac12_a_delay_of_zero_still_waits_in_the_pause_for_the_confirmation`.
  `test_ac13_a_death_pause_round_trips_with_the_time_left` now also checks that the restored
  pause stays at 0, can be confirmed and goes to the town.
- `tests/scenes/test_f012_game.gd`: a confirm before the wait for the town in
  `test_ac27_the_full_loop_on_a_fixture_tower`,
  `test_ac29_the_location_follows_the_town_every_room_the_boss_and_the_way_back`,
  `test_ac29_the_health_bar_shows_the_current_rooms_player_after_every_swap`,
  `test_ac29_the_provider_never_answers_with_a_freed_player_through_the_whole_loop`,
  `test_ac30_inside_the_player_died_handler_the_floor_is_still_shown_and_the_pause_keeps_it`,
  `test_c5_dying_in_the_boss_room_keeps_the_boss_reached`,
  `test_c5_a_player_and_a_boss_dying_in_the_same_tick_is_a_death_and_the_floor_is_not_cleared`,
  `test_c5_a_second_death_after_coming_back_works_the_same`,
  `test_cr18_a_stick_held_up_through_the_death_pause_does_not_move_the_new_towns_list`,
  `test_cr4_during_the_death_pause_nothing_the_person_does_has_any_effect`. "You died" checks
  became "no banner" there and in three renamed tests:
  `test_c5_the_death_shows_no_banner_and_the_return_shows_none_either`,
  `test_ac33_a_heal_in_the_death_pause_shows_no_banner`,
  `test_ac33_dying_after_a_heal_hides_the_heal_banner`.
- `tests/scenes/test_f013_camera_game.gd`: `test_ac5_the_town_after_a_death_in_a_floor` confirms
  before it waits for the town.
- `tests/scenes/test_f014_game.gd`:
  `test_ac20_after_a_death_and_the_town_the_same_room_starts_its_waves_again` confirms before it
  waits for the town.
- `tests/core/floors/test_tower_tunables.gd`: not edited.
- T6, `tests/scenes/test_f015_shell.gd` (T5's own file): `test_ac17_pause_does_nothing_in_the_death_pause`
  expected the flow to stay PLAYING with no menu; with the death screen it expects DEAD, the
  death screen still up, and no change from Escape or pad Start.
- T7, `tests/scenes/f012_game_test.gd`: `spawn_main()` builds the main scene, gives its shell a
  settings file of the test's own, two stubs and the input off, chooses Start and waits for the
  guard and one more tick; `after_each()` also resets the settings, deletes that file and
  reactivates the physics space. `tests/scenes/test_f012_main.gd`:
  `test_ac26_main_starts_in_the_town_with_the_hud_showing_town_and_full_hp` became
  `test_ac26_main_after_start_is_in_the_town_with_the_hud_showing_town_and_full_hp` (the game's
  parent is the shell, the shell's is `Main`); `test_ac26_main_still_holds_the_debug_overlay`
  now counts the overlay and the shell. `tests/scenes/test_f014_shipped.gd`: not edited.
- Review fixes (9625676), `tests/scenes/f012_scene_test.gd`, **a file C18 does not list**: the
  comment on `hold_key_between_ticks()` only (it said a tap is never "just pressed"; measured
  otherwise, code review CR-7). No code of that helper changed. In the same commit
  `tests/scenes/f012_game_test.gd` lost the dead constant `GAME_NODE`, got the process id in
  `spawn_main()`'s file name and a corrected comment (CR-7, CR-9, CR-12).

### Assumptions made (small, reversible)
- ASSUMPTION-1 (T1): `get_settings_origin()` is TITLE before the settings were ever opened and
  keeps the last origin after `close_settings()`; `state_changed` is emitted after the state has
  changed, so a listener that asks `get_state()` sees the new one.
- ASSUMPTION-2 (T2): `GameSettings.new(defaults)` takes the `ShellTunables` and `reset()` goes
  back to them; `from_dict()` puts a setting whose key is missing or not a bool at its default
  even when its current value was different, so a partial file gives the same values every time.
- ASSUMPTION-3 (T2): `load_from()` returns true for any file that was read as a `ConfigFile`,
  also one with no `settings` section (the defaults); false only for a missing or unreadable one.
- ASSUMPTION-4 (T2): `ShellTunables` has no `validate()`: two bools cannot be invalid.
- ASSUMPTION-5 (T2): for a malformed settings file Godot prints its own
  `ERROR: ConfigFile parse error` before the one warning C12 asks for; it will be in the real
  game's log too. "One warning" and "no warning" are checked by reading: GUT cannot count
  `push_warning`.
- ASSUMPTION-6 (T2): the camera's own flag (`shake_enabled`: K, a data reload) and the player's
  setting are two values that are never copied into each other; `shake()` needs both, and
  `is_shake_on()` (the debug overlay's line) still reports the node's flag only.
- ASSUMPTION-7 (T2): AC8's tests build the F-011 floor fixture, not a `Game`: same camera, same
  `restart_room()`.
- ASSUMPTION-8 (T4): `ListMenu` ignores a focus index out of range and a press with no buttons
  (the old `GateMenu` would have crashed there; its list always has the stay entry).
- ASSUMPTION-9 (T4): the base's cancel is a virtual method (`_on_cancel_pressed()`), not a
  signal; the three exports (font size, minimum width, separation) live in `ListMenu`, and
  `MenuPanel` adds `heading_font_size` and `content_separation_px`; `set_body()`,
  `set_entry_text()` and `set_entry_enabled()` also work on a closed panel, and an unknown id
  does nothing.
- ASSUMPTION-10 (T4): `ShellMenus.focus(TITLE, previous)` is `settings` only when `previous` is
  SETTINGS and `start` otherwise; `START_FAILED_FORMAT` reads
  "Could not start: the game data has %d error(s). See the log."
- ASSUMPTION-11 (T3): `Hud.hide_banner()` also zeroes the banner's time, so the next banner runs
  its own full time; `is_pause_allowed()` in the town answers true if there is no valid town
  node while the shown scene is not stale (not reachable: the gate list cannot be open then);
  the `Hud.hide_banner()` tests are in `tests/scenes/test_f015_game.gd`.

- ASSUMPTION-12 (T5): `Shell.GUARD_TICKS = 2` is a constant, not an export: it is C7's
  mechanism, and 1 lets a press posted inside a tick through. New tests run at 120 ticks/s (the
  helpers' rate) unless they set another; §5's "60 unless said" is met by the guard tests, which
  run at 30, 60 and 120.
- ASSUMPTION-13 (T6): the game is freed where the flow reaches TITLE from CONFIRM_QUIT
  (`_on_state_changed`), before the title menu is shown, not in the entry's handler; `shake` and
  `fullscreen` act only in SETTINGS, `confirm` only in the two confirms, `return` only in DEAD.
- ASSUMPTION-14 (T6): a refused leave or death confirm cannot come from the menus; the tests
  produce one by moving the session behind the open menu, and by forcing the disabled entry.
- ASSUMPTION-15 (T6, T7): "a click on an entry" in tests is a left mouse button press held until
  the case ends, plus the panel's `choose(id)` in the same frame. The death and leave cases of
  AC16 turn the player's input on just before the confirm (it is off for the scripted walk).
- ASSUMPTION-16 (T7): `Engine.physics_jitter_fix` is 0 during the guard tests and restored
  after; `GAME_NODE` in `f012_game_test.gd` is unused now and kept.
  **After code review round 1:** `GAME_NODE` is removed (CR-12).
- ASSUMPTION-18 (round 2 fixes): **ASSUMPTION-3 and ASSUMPTION-5 no longer hold.** A file with
  content and no `[settings]` line now returns false with one warning (it returned true), and
  Godot prints no error line of its own for any settings file; the tests count warnings and
  errors with a `Logger`, so "one warning" and "none" are asserted, not read. In the reader:
  the section line must be exactly `[settings]`; keys and `true` / `false` are case-sensitive;
  the last line of a key decides, and one that is neither `true` nor `false` makes the key its
  default; a comments-only file is "content" (warning), a blank or BOM-only file is empty
  (true, silent); a directory at the path is still "missing". The branch for a file that
  exists and cannot be opened is not covered by a test (not producible on Windows here). In
  `MenuPanel`: every mouse button event with the double-click flag is consumed, press or
  release; a key that arrives between the guard's deadline and the next frame is still refused
  (up to one frame late, never early); `is_choose_guarded()` replaces
  `is_pointer_guarded()`. In the twins: the fight uses the implementer's own seed (3), not the
  reviewer's 1 and 4, because its walk and schedule differ; the 60 ticks/s twin after a death
  is a random walk because the four-leg slide never differs at that rate.
- ASSUMPTION-19 (round 3 fixes): mouse wheel ticks are button presses to the engine, so they
  clear the panel's double-click flag and, during a guard, start it again; only a press is
  consumed for the double-click rule, never a release; a press on a closed panel is not looked
  at; the guard is judged by real time at the press, not by when `_process` last ran. In the
  settings file: of two BOMs only the first is stripped (the second makes its line something
  else: with `[settings]` on that line the file is "not a settings file"); a write that fails
  after the file was opened removes the file (not covered by a test: not producible here).
- ASSUMPTION-17 (review fixes): `MenuPanel.is_pointer_guarded()` is public, for the tests;
  the pointer guard is measured with `Time.get_ticks_msec()`, so it does not depend on the frame
  rate; `_enter_tree` stops the space whenever the game node is disabled, the guard's two ticks
  included; in the settings file an object nested in an array or a dictionary is treated like
  one at the top; `test_user_settings.gd` has a folder per process instead of the process id in
  its file names.

### Things the Auditor should look at closely
- **The guard for the death and leave confirms is proven by its state, not by a dash.** The town's
  player does not exist yet in the tick where the press is "just pressed", and the dead player
  cannot dash, so removing the guard there fails the tests on `is_guarding()` and the game's
  `process_mode`, not on a dash. The resume and Start cases do fail by a real dash or attack (14
  of 16 guard tests with the game enabled in the input callback).
- **Enter, Escape and pad Start cannot dash or attack under any mutation**; their guard cases only
  prove that the pause does not reopen and the flow stays PLAYING. The stalled-frame timing is
  caught by no mutation alone; it is kept because AC16 asks for it.
- **DEV-6's tick.** In the first tick the game runs after a pause, the physics space is still
  inactive while the game's nodes run (`move_and_slide`, the wall sweeps). The twins say nothing
  differs; a reader of `Shell._set_game_running()` should check the reasoning.
- **The camera with the tick rate held at 1** (DEV-9): position smoothing at speed 8 with a 1 s
  physics delta overshoots and the transform goes invalid. Not reachable in the game, whose tick
  rate never changes; not investigated further.
- **Start takes about 0.8 s on the shipped tower**: the whole `Game` (tower validation, the town)
  is built in the frame of the choice, and the next frame runs 8 physics ticks, all inside the
  guard or with the player standing in the town.
- `Game.is_pause_allowed()`'s third condition, `_is_shown_stale`, and `Shell._follow_the_session()`
  run at different priorities (2 and 3) in the same tick; the death screen opening "in the same
  tick" depends on that order.
- A malformed settings file prints Godot's own `ERROR: ConfigFile parse error` besides the one
  warning (ASSUMPTION-5); a failed save prints its warning (twice in the suite's log, from the
  two tests that provoke it).

### How to test
Branch `feature/F-015-menus`. Windows tooling as in F-011 §2.
- Everything: `tools/test` (about 15 minutes). On 4bfec51: 156 scripts, 2442 tests, all
  passing (888 s), no "Orphans" line, no leak line; afterwards this machine's `user://` holds
  no `settings.cfg` and no `test_f015` folder. `gdlint src tests`: no problems. `gdformat --check
  src tests`: 296 files unchanged. `tools/check_core_purity`: ok. The main scene boots headless
  with no error or warning line.
- One file: `"$GODOT_BIN" --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/scenes/test_f015_shell.gd -gexit`.
  The feature's test files: `tests/core/shell/test_shell_flow.gd`, `test_game_settings.gd`,
  `tests/core/test_shell_tunables.gd`, `tests/autoload/test_user_settings.gd`,
  `tests/core/floors/test_f015_session.gd`, `tests/ui/test_f015_list_menu.gd`,
  `test_f015_menu_panel.gd`, `test_f015_menu_texts.gd`, `tests/scenes/test_f015_shake.gd`,
  `test_f015_game.gd`, `test_f015_shell.gd`, `test_f015_shell_flow.gd`,
  `test_f015_shell_death.gd`, `test_f015_main.gd`, `test_f015_guard.gd`.
- **Rendered check (T8, AC28), by the lead on 4bfec51**, the real main scene in a real 1280 × 720
  window, driven by a scratch script with an empty settings path (nothing written to `user://`):
  14 screenshots, one of each of the six menus and their variants. No text is clipped and none
  overlaps the HUD's lines; the focused entry has a white frame; the death screen's entry is grey
  while disabled and white once enabled. Real positional clicks: on Start (the game started), on
  the disabled Return to town (nothing changed), on the enabled one (the town). Fullscreen: the
  window mode read 0, then 3 after the choice (the screenshot is 1920 × 1080, the picture scaled
  by 3), then 0 after the second choice. The focus came back to `settings`, `leave` and
  `quit_to_title` after Back, the leave's cancel and Escape on the quit confirm. Seen and left
  as they are: the debug overlay's text is large and sits top left over the game as before; the
  enemies' debug labels show through the dim; after a mouse click Godot hides the focus frame
  until the next key (the entry still has the menu's focus).
- **After code review round 1** (9625676, 8429634): the full suite on 8429634 is 157 scripts,
  2480 tests, all passing (971 s), no "Orphans" line, no leak line; nothing is left in this
  machine's `user://`. The suite is longer than on 4bfec51 (888 s): the slide twins run in real
  time (720 ticks at 120 ticks/s each) and the click tests wait out the 0.3 s pointer guard.
  New test file: `tests/scenes/test_f015_clicks.gd`.
- **After code review round 2** (936e9ad, ec7b44b): the full suite on ec7b44b is 158 scripts,
  2547 tests, all passing (1070 s), no "Orphans" line, no leak line; `gdlint src tests`: no
  problems; `gdformat --check`: nothing to change; `tools/check_core_purity`: ok; the main scene
  boots headless with no error or warning line; nothing is left in this machine's `user://`.
  New test file: `tests/scenes/test_f015_twins.gd` (about 75 s, real time).
- **After code review round 3** (a25c43d): the full suite is 158 scripts, 2571 tests, all
  passing (1081 s), no "Orphans" line, no leak line, no click test retried or pending;
  `gdlint src tests`: no problems; `gdformat --check`: nothing to change;
  `tools/check_core_purity`: ok; the main scene boots headless with no error or warning line;
  nothing is left in this machine's `user://`.
- **Not done by anyone:** real keyboard, mouse or gamepad play. Every event above was posted by
  code. A real pad was never connected. That is Gate B.

---

## 9. Code Review  ·  _Auditor_

<!-- review-round: 1 verdict: CHANGES_REQUESTED -->

**Reviewed commit:** 8f51d37 (code as of 4bfec51; the diff `main..8f51d37` under `src`, `scenes`, `data`, `tests` and `project.godot`)

**Date:** 2026-11-20 · **Verdict:** CHANGES_REQUESTED · **By:** Auditor (lead, D-014)

Two fresh reviewers, read-only, on private copies of `8f51d37`; neither wrote the spec or the
code. One read the diff against the spec in `AGENTS.md`'s order and made small targeted runs. The
other attacked the running game: a random bot with every tick checked against invariants (16
runs at 30, 60 and 120 ticks/s, 42,500 steps, 57,956 ticks, 70 Starts, 133 deaths, 1,368 guards
watched: no violation, no error line), paused-and-unpaused twins, scripted sequences, broken
settings files, real positional clicks outside GUT, and 18 mutations of the new code. The lead ran
the probes of CR-1 and CR-2 again on the reviewers' copies and got the same results.

**AC evidence** (the reader's table, checked by reading the assertions, not the test names):
AC1 to AC14 ✅ · AC15 ✅ for what it tests, ❌ as a promise (CR-1, CR-5) · AC16 ✅ with the limits
§8 states (the death and leave cases are proven by the guard's state; Enter, Escape and pad Start
only prove that nothing pauses again) · AC17 to AC26 ✅ · AC27 the lead's run (156 scripts, 2442
tests on 4bfec51) · AC28 the lead's rendered check, and it missed CR-2 · AC29 ✅ (the overlay
"above" by layer number only).

**Rejected options:** none implemented (`process_mode`, `space_set_active` and `paused` appear
only in `shell.gd`; no timer, tween or await in `src`; the settings are read only by
`Shell._ready`; `list_menu.gd` is the moved code, compared line by line with
`main:src/ui/town/gate_menu.gd`). **Constraints:** C1 to C21 and G1 to G9 hold except C6 (CR-1)
and C12's letter (CR-3). **Deviations:** DEV-1 to DEV-10 are accurate (the reader re-ran DEV-6's
evidence: with the space switched on together with the game the three corner twins fail at tick
288); one deviation was not logged (CR-3). **Assumptions:** all reasonable and reversible.

### CR-1 🔴 A pause changes a later wall slide: C6's "tick for tick the same" is false  ·  `src/world/shell.gd:301-308`
Fixture town, the player at tile (2.5, 11.5), a scripted walk of 720 ticks in four legs with a
dash every 60 ticks. One pause at tick 30, 100, 200, 250 or 340, of any length, even zero frames:
positions differ from the never-paused run from about tick 346 on, for more than 300 ticks, by up
to 0.004 px, and in several schedules the final snapshot differs too. Two never-paused runs are
identical; 23 of 24 random schedules differ. Cause, confirmed by experiment: disabling `Game`
with the default `disable_mode` takes every body out of the physics space and puts it back on
enable; with `DISABLE_MODE_KEEP_ACTIVE` on the town's 33 collision objects all 10 schedules
match. Stopping the space (C6, DEV-6) does not cover it. Not reproduced in the shipped town or in
fights (48 twins identical). Nothing a player could see; but the spec promises it and G1 leans on
it. AC15's corner walks pass because they never slide along a side wall across the seams between
wall bodies.
> **Builder reply (lead):** fixed in 8429634. At each stop the shell sets every collision object
> below the game to `DISABLE_MODE_KEEP_ACTIVE` before it disables the game
> (`Shell._keep_bodies_in_space()`; rooms are rebuilt, so it is done every time). The reviewer's
> walk is now a test: seven single pauses (ticks 30 to 500; 1, 5 and 60 frames and a pause of
> none) and a seeded schedule of eight pauses of four kinds, position and snapshot compared at
> every tick. In the implementer's mutation run six of them fail without the new step. The
> implementer also measured DEV-6 again with the fix in place: with the space switched on
> together with the game the three corner twins still differ at tick 288 by 3.8e-6 px, so the
> one-tick lag stays.

### CR-2 🔴 A double click acts on the menu that opens under the cursor  ·  `src/ui/menus/menu_panel.gd:41-53`
Real positional clicks at 640 × 360. A double click on "Settings" (title screen, pause menu) ends
in the settings menu with **Fullscreen switched on and saved**: the first click rebuilds the
centred panel and the new "Fullscreen" entry lies exactly where "Settings" was. A double click on
the top 2 px of "Quit to title" in the town's pause menu **quits to the title with no
confirmation** (the confirm's own "Quit to title" overlaps it by 3 px) and the progress is gone.
Lower on that entry the second click hits Cancel or nothing; on a floor nothing overlaps. The
lead's rendered check (AC28) made single clicks only.
> **Builder reply (lead):** fixed in 8429634 with a pointer guard in `MenuPanel`: for
> `pointer_guard_seconds` (an export, 0.3) of real time after `open()` the entries take no
> pointer input; keys, the pad and `choose()` are not affected and the in-place changes do not
> start it again (two slow clicks on Fullscreen still toggle twice). Real positional clicks are
> now tests (`tests/scenes/test_f015_clicks.gd`, the menu layer raised above GUT's for the
> test): the double click on Settings from the title, the town's pause menu and a floor's, at
> gaps of 2, 8 and 20 frames and 100 ms, changes no setting and never calls the window; the
> double click on the top 0.5 px and 1.5 px of Quit to title ends in the confirm with the game
> alive. In the implementer's run on the code before the fix four of the nine fail. Logged as
> DEV-11 (a rule the spec did not have) and put to Lucas as §10 Q8 (the 0.3 s).

### CR-3 🔴 by the unlogged-deviation rule (🟡 in substance): two test files put the main scene in the tree without C12's helpers  ·  `tests/scenes/test_f015_guard.gd:394`, `tests/scenes/test_f015_main.gd:21`
Both instantiate `scenes/main.tscn` themselves and repeat the stub wiring, because
`spawn_main()` chooses Start with the input off. They are safe today (they reuse the helper's
file and `after_each`), but there are four spawners to keep safe and §8 logs no deviation.
> **Builder reply (lead):** fixed in 9625676: `F015ShellTest.spawn_main_on_title()`, wired by the
> same private function as `spawn_shell()`; both test files use it and their own spawners are
> gone. The gap between T7 and this fix is logged as DEV-12.

### CR-4 🟡 No test pins a pause in DEV-6's one-tick lag  ·  `src/world/shell.gd:153-155`, `:301-308`
Between the enabling tick and the next the game runs, `_space_follows` is true and the space is
off; real input can arrive there. The code is right (the reader's probe passes). But with
`_space_follows` never cleared the space comes back on during the pause, and all 179 tests of the
six shell and main test files still pass.
> **Builder reply (lead):** fixed in 8429634: two tests pause in that tick (the press posted
> inside the tick, and between ticks at 30 ticks/s); with the flag never cleared both fail.

### CR-5 🟡 AC15's twins are weaker than the AC  ·  `tests/scenes/test_f015_shell.gd:888-904`
The corner walk compares the position at every tick but the snapshot only at the end ("tick by
tick (position and snapshot)"); and no test slides along a side wall across seams (CR-1).
> **Builder reply (lead):** fixed in 8429634: the corner twins compare the snapshot at every tick;
> the slide twins are CR-1's.

### CR-6 🟡 Two holes the mutations found  ·  `src/world/shell.gd:121-122`, `tests`
No test makes a real click (so CR-2 was invisible to the suite). Removing
`set_input_as_handled()` in `Shell._unhandled_input` fails no test. (A third survivor,
`ask_leave(true)` in place of `ask_leave(_is_on_floor())`, is equivalent: the entry only exists
on a floor.) 16 of 18 mutations were killed.
> **Builder reply (lead):** fixed in 8429634: the real clicks of CR-2, and a spy that must not see
> a `pause` event the flow acted on and must see one it refused. The equivalent mutant is left.

### CR-7 🟡 Comments that are wrong  ·  `src/world/shell.gd:20`, `:41-44`, `:68`, `tests/scenes/f012_game_test.gd:69`, `f015_shell_test.gd` header and `:112`, `:125`, `test_f015_shell.gd:710`
Six comments send the reader to "DEV-1" for the space lag; it is DEV-6. The `GUARD_TICKS` comment
says 1 lets the press through; for a press that arrives between ticks (all real input) one tick
is enough, the second is only needed for a press posted inside a tick. The helpers say a tap is
never "just pressed"; measured in 4.7.2, a press and release posted together between two ticks is
"just pressed" in the next tick.
> **Builder reply (lead):** fixed in 9625676 and 8429634. The implementer measured it again
> (a key, a pad button and a mouse button at 60 and 120 ticks/s, tap and hold): posted between
> ticks, "just pressed" in the next tick; posted inside a tick, in the tick after the one
> running; in all 24 cases. No test's logic leaned on the false sentence: the guard tests hold
> their keys.

### CR-8 🔵 `Shell._exit_tree` has no counterpart  ·  `src/world/shell.gd:95-96`
A shell removed and added again while paused comes back with the flow PAUSED, the game disabled
and the space active (the reader's probe). Nothing reparents the shell today.
> **Builder reply (lead):** fixed in 8429634: `_enter_tree` stops the space again when the game is
> disabled; two tests.

### CR-9 🔵 The tests' files in `user://` are not private to a run  ·  `tests/scenes/f015_shell_test.gd:42`, `f012_game_test.gd:78`, `tests/autoload/test_user_settings.gd:6`
A private copy of the project has the same `user://` as the checkout, and the file names carry
no process id: two suites at once would read and delete each other's files. Related: four lines
in `test_f015_shell.gd` and `test_f015_shell_flow.gd` read the modified time of the real
`user://settings.cfg`, which goes near C12's "no test touches".
> **Builder reply (lead):** fixed in 9625676 (the process id in the helpers' file names, a folder
> per process for `test_user_settings.gd`) and 8429634 (the four lines are gone; the lead looks
> at the real folder after each full run).

### CR-10 🔵 A settings file can instantiate an object  ·  `src/autoload/user_settings.gd:17-32`
`fullscreen=Object(Node,…)` in the file makes `ConfigFile` create the node: one orphan and a leak
line at exit. Measured too, and accepted as they are: a file with a UTF-8 BOM is read as the
defaults with no warning and overwritten at the next change; binary garbage prints Godot's own
error besides the one warning (ASSUMPTION-5); empty files, wrong types, a 16.5 MB file, a
directory at the path, a read-only file and a missing folder all leave a shell that starts and
applies changes for the run.
> **Builder reply (lead):** fixed in 9625676: a value of the file that is an object, or holds
> one in an array or a dictionary, in any section, is dropped, and freed when it is not counted
> by reference; tests check that no orphan and no object is left. The BOM file and the binary
> garbage are pinned by tests as they are.

### CR-11 🔵 Fullscreen in a window embedded in the editor (a suspicion, not verified)
`DisplayServer.window_set_mode(FULLSCREEN)` on a game window embedded in the editor may error and
do nothing, and "Fullscreen: On" would then be saved and tried again at every embedded launch.
> **Builder reply (lead):** not verified either (it needs the editor). The default applier now
> does nothing when `Engine.is_embedded_in_editor()` (8429634); the setting is still flipped and
> saved. Told to Lucas in §10 Q9.

### CR-12 🔵 Duplicated test plumbing  ·  `tests/scenes/f012_game_test.gd`, `f015_shell_test.gd`, `test_f015_guard.gd`, `test_f015_main.gd`
`MAIN_SETTINGS_DIR` and `TEST_DIR`; three guard-wait loops; two click posters; `_dim()` three
times; `after_each` resets the settings and the space in the subclass and in the base;
`GAME_NODE` is dead (ASSUMPTION-16).
> **Builder reply (lead):** partly: `GAME_NODE` is gone and the stub wiring is one function
> (9625676). The rest is left: each loop and click poster is small, and the double reset is the
> price of `F012GameTest` and `F015ShellTest` each being safe alone.

### CR-13 🔵 Measured, for the record
A press of J or Space in the two guard ticks after Resume is dropped (it acts from the third
tick on). Space and Escape in the same frame while playing: the pause wins and the dash is lost.
Escape and pad Start in the same frame: two changes from two events (a pause and straight back).
After a pause the mouse aim jumps to where the mouse went meanwhile. A double click on the title's
Quit calls the quit handler twice.
> **Builder reply (lead):** noted, no change. The dropped presses are the guard doing its job
> (two ticks, 33 ms at 60 ticks/s); the rest is what the events say.

**Tried, found nothing:** every C6 and C7 sequence the reader traced and probed (a pause in the
lag; a death in the first tick after a resume; a pause before a death tick, then a leave; quit
and Start in one frame; the shell freed while guarding; a Start that fails); C8 for Escape, pad
Start, pad B, Space, Enter and a click through every handler in every state; real positional
single clicks on nine entries; wave-fight twins and brute-into-wall twins (24 of 24 identical
each, with bolts in flight and arrivals pending); Start and Quit to title 20 times (97 nodes,
2,133 objects, 0 orphans, 0 settings listeners from round 2 to round 20); die, return and enter
20 times; N, R, F3, K, F5, P and I while paused and on the title; Escape held with 30 repeat
events; the gate list closed and the game paused in one frame, then resumed with Space; a leave
after the boss died; the boss and the player dying in one tick; a leave in the middle of a fight
and the same floor again; double `choose()` of Start, the confirms and the death entry in one
frame; the 11 debug scenes and the main scene for 400 frames with no error or warning line.

**Not checked:** a real keyboard, mouse or gamepad, fullscreen on a real window (the reviewers
were headless); twins at 30 and 60 ticks/s; CR-1 on a shipped floor (only the shipped town, where
it did not differ); a buffered dash across a pause with real keys; the stick held across a pause
into the gate list; the debug scenes were booted, not driven; the camera with the tick rate held
at 1 (DEV-9); `test_f015_menu_panel.gd`, `test_game_settings.gd` and most of
`test_f015_session.gd` beyond their names and spot checks; the full suite.

<!-- review-round: 2 verdict: CHANGES_REQUESTED -->

**Reviewed commit:** 3ed383d (the fixes 9625676 and 8429634: the diff `8f51d37..3ed383d` under `src` and `tests`)

**Date:** 2026-11-20 · **Verdict:** CHANGES_REQUESTED · **By:** Auditor (lead, D-014)

The same two reviewers, read-only, on new private copies of `3ed383d`, each with a `user://` of
its own. The reader checked every fix against its finding and re-ran the mutations; the other
re-ran its three defects, then attacked the fixes: 96 paused-and-unpaused twins with 4 to 20
pauses of 10 kinds each (wall walks in the fixture and the shipped town, shipped floor 1 with
room changes and with a fight, a walk after a death and after a leave) at 120, 60 and 30 ticks/s;
its random bot with real clicks (13 runs, 34,000 steps, 79,427 ticks, 4,588 clicks); a click
probe outside GUT; settings files; 21 mutations of the new code.

**Round 1 findings:**
- CR-1 ✔ resolved. The reviewer's ten single-pause schedules and its 24 random slide twins (23
  differed before) are identical without its experiment switch; 96 new twins, 0 differ. With
  `_keep_bodies_in_space()` removed six of the suite's slide twins fail. See CR-19 for what the
  suite's own twins still miss.
- CR-2 ✔ resolved as far as it went: all 84 double clicks of round 1 (0 to 120 ms apart, every
  height) now do only what the first click does, and 2,341 bot clicks that landed in the guard
  did nothing. What is left is new: CR-15.
- CR-3 ✔ resolved (DEV-12 is accurate). CR-4 ✔ resolved (with `_space_follows` never cleared both
  new tests fail). CR-5 ✔ resolved. CR-6 ✔ resolved (the spy test fails without
  `set_input_as_handled()`). CR-7 ✔ resolved, but see CR-14. CR-8 ✔ resolved (a nit: CR-20).
  CR-9 ✔ resolved. CR-10 ✔ for what the reply said; CR-17 for what it did not reach.
  CR-11 mitigated, still not verified (it needs the editor). CR-12 partly, as replied; accepted.
  CR-13 noted.

### CR-14 🔴 by the rule (🔵 in substance): an existing test file was edited and §8 does not name it  ·  `tests/scenes/f012_scene_test.gd:143-149`
9625676 corrected the comment on `hold_key_between_ticks()` (CR-7). The file is not on C18's
list and appears nowhere in §8. The edit is a comment and it is right.
> **Builder reply (lead):** logged in 4c4820b, under "Existing tests edited" in §8, with what
> else that commit changed in `f012_game_test.gd`. The lead's brief had allowed the comment
> and the lead's log missed it.

### CR-15 🟡 A second click later than the guard still acts on the menu that opened  ·  `src/ui/menus/menu_panel.gd:26`, `:149-156`
Real positional clicks. A slow double click, the second click 310, 350 or 500 ms after the first:
on the title's "Settings" Fullscreen is switched on; 1 px below the top of "Quit to title" in the
town's pause menu the game quits with no confirmation. At 250 and 290 ms nothing happens. A
triple click whose third click comes after the guard does the same. The guard measured 312 ms at
144 fps, 328 at 60, 366 at 30; Windows' default double-click time is 500 ms. And a stall ends the
guard early: with the thread blocked for 500 ms in the frame of the first click, the queued
second click arrived after the guard's real time and acted.
> **Builder reply (lead):** fixed in 936e9ad: a mouse button event the OS marks as a double
> click (`InputEventMouseButton.double_click`) is consumed while a `MenuPanel` is open, at any
> time, so the slow double click and the stalled frame no longer choose; tests post the second
> press 350 and 500 ms after the first and after a 500 ms stall, with the flag, and nothing
> changes; the same second click without the flag (a deliberate click) acts. **Limits:** the
> flag is set by hand in the tests; no real mouse has produced it (§10 Q8). A triple click's
> third click is an ordinary click and acts once the 0.3 s have passed: accepted.

### CR-16 🟡 A double press of Enter, Space or pad A on "Settings" switches Screen shake off and saves it  ·  `src/ui/menus/shell_menus.gd:156`, `src/ui/menus/list_menu.gd`
Title: Down, Enter, Enter. Pause menu: Down, pad A twice. A click on Settings, then Space 80 ms
later. The settings menu opens with the focus on `shake` and a choice by key has no guard. Not
new with the fixes: round 1's code did the same and nobody reported it. (A double Enter on "Quit
to title" lands on Cancel.)
> **Builder reply (lead):** fixed in 936e9ad: the guard is now a choose guard. For
> `choose_guard_seconds` (0.3) after a menu opens, `ui_accept` and `interact` choose nothing
> (the key is still consumed); moving the focus, `ui_cancel` and `choose(id)` by code are not
> guarded. `ListMenu` got one hook for it, true in the base; the gate list is unchanged and its
> tests are unedited. Tests: Down, Enter, Enter on the title; pad A twice on the pause menu; a
> click then Space; each 80 ms apart: the settings menu is open, Screen shake is on, nothing
> was saved, and a third press after the guard switches it. DEV-11 is extended below.

### CR-17 🟡 The settings file is read by a parser that builds what the file names  ·  `src/autoload/user_settings.gd:23-32`, `:44`
`_drop_objects()` cleans up after `ConfigFile`, and cannot be complete: an object followed by a
line the parser refuses, an object inside a list with a bad item, or `Object(Node)` with no
property list makes `load_from()` return before the cleanup (one orphan a load, a leak line at
exit); an object inside another object's property is not found; and
`Object(RefCounted,"script":Resource("user://x.gd"))` runs that script's `_init` inside
`ConfigFile.load()`, before any cleanup (the reviewer's planted script wrote its marker file).
Hand-written files only, and acceptable for a local settings file; a save file must never be read
this way (slice 4).
> **Builder reply (lead):** fixed in ec7b44b by not using the parser: `load_from()` reads the
> bytes and understands only a `[settings]` line and `key=true` / `key=false` for the two known
> keys. Nothing is built from the file; `_drop_objects()` is gone. Tests write every object
> shape the reviewers tried, and a script that would create a marker file if run: no orphan, the
> object count unchanged, no marker, the other keys read. In the implementer's mutation run,
> going back to `ConfigFile.load()` fails 21 of the 52 tests. `save_to()` still writes through
> `ConfigFile` and the reader reads that back (all four combinations). Noted for slice 4 in
> §10 Q10.

### CR-18 🟡 The double-click tests can fail on a busy machine, and assume the headless window  ·  `tests/scenes/test_f015_clicks.gd:24-26`, `:266-323`
The second click is posted 2, 8 or 20 frames or 100 ms after the first and must land inside the
0.3 s guard; nothing checks that it did. Idle, 9 of 9 pass; with 24 busy loops on 12 cores one
failed (the frames outlasted the guard and Fullscreen switched on): a false failure, in the gate.
The tests also post canvas positions as window positions, right only while the root's final
transform is the identity.
> **Builder reply (lead):** fixed in 936e9ad: a watcher stamps the real time and the guard's
> state when each press arrives; a case is judged only when its second press really was inside
> the guard, is retried up to three times otherwise, and then fails with the numbers. Positions
> go through the viewport's final transform. The implementer ran the file three times beside
> eleven other test files (21 of 21 each, no retry needed) and forced the retry path with a
> 0.05 s guard (it failed with the measured numbers, as it should).

### CR-19 🟡 Two holes in the twins  ·  `tests/scenes/test_f015_shell.gd`, `src/world/shell.gd:337`
`DISABLE_MODE_MAKE_STATIC` in place of `KEEP_ACTIVE` passes all 69 tests of `test_f015_shell.gd`,
while the reviewer's fight on shipped floor 1 differs under it in 2 of 4 seeds (by 0.06 px at
tick 976, by 60.8 px at tick 756): enemies force their server body to static, and that mode
resets it on enable. And every slide in the suite is in the town built at Start: nothing slides
in a town built after a death or after a leave, where the reviewer's twins differ on the code
before the fix in 5 of 6. 16 of 21 mutations were killed; two more survivors are in code CR-17
removes, and two could not be told from the real code by any run (only `StaticBody2D` kept; the
keep done after the disable).
> **Builder reply (lead):** fixed in ec7b44b: `tests/scenes/test_f015_twins.gd`, six twins with
> seeded schedules of 10 to 14 pauses of seven kinds: a fight on shipped floor 1 at 120 and at
> 60 ticks/s, a floor 1 walk through two room changes, a wall slide in the town built after a
> death and after a leave, and a random walk after a death at 60. In the implementer's mutation
> runs each is moved by at least one mutation: `MAKE_STATIC` fails both fight twins (first
> difference at tick 454 of 720 and 244 of 360); no keep step, or the keep only at the first
> stop, fails the three town twins; the space left running fails the room-change twin and the
> two slides; no one-tick lag fails the two slides. The two mutants nobody could tell from the
> real code are left.

### CR-20 🔵 `Shell._enter_tree` uses the current viewport's space, the rest the one cached in `_ready`  ·  `src/world/shell.gd:94`, `:110-116`
> **Builder reply (lead):** fixed in 936e9ad: `_space` is read in `_enter_tree` and used
> everywhere.

### CR-21 🔵 Measured, for the record
Clicks are ignored for 0.3 s after any menu appears: on Start right after the launch, and on the
death screen's entry when a death delay shorter than the guard has already enabled it. A new
entry under a cursor that does not move is not drawn as hovered until the mouse moves, but takes
a click at once (also with no guard: the engine's doing). A double click on Resume attacks when
its second click comes two or more ticks later (the game is running again by then). A
`Resource("res://…")` value in the settings file is left alone.
> **Builder reply (lead):** noted. With 936e9ad a double click the OS marks never chooses, so
> the Resume case needs two deliberate clicks; and since ec7b44b the settings file's values are
> never parsed as anything but `true` and `false`.
> **Correction (lead, after round 3, CR-26):** the sentence about Resume is wrong. The first
> click closes the panel, so on 936e9ad the flagged second press is not consumed and the player
> attacks. See CR-26's reply for what was done.

**Tried, found nothing:** the pointer guard closed, hidden, reopened or set to 0 during a guard
(no button is left ignoring the mouse); a button held across a key-driven menu change and
released on the new menu; a press at +100 ms held to +450 ms; a drag from Start to Settings;
right and middle clicks; the gate list (no guard, a click chooses at once, as before); the death
entry under a resting cursor with delays of 0, 0.1 and 0.6 s; bodies after Start, after a room
change and after repeated stops (33 of 33 and 27 of 27 kept and in the space; `Game` alone never
gets the mode); the bot's clicks outside the guard on an enabled entry (2,016, all acted) and no
setting flipped by a click on another entry; settings files holding a Node, a plain Object, a
Window, a Button, a body, a camera, a project script or 1,000 objects (no orphan, no leak line);
the round 1 sequences again (12 of 12), Start and Quit and die and return 20 times each with no
growth; the 11 debug scenes and the main scene booted with no error or warning line. C2, C8, C9
and C12 still hold after the fixes; DEV-11 to DEV-13 and ASSUMPTION-17 are accurate.

**Not checked:** a real mouse, keyboard or pad and a real window (hover and stall results are
headless); the editor's embedded window (CR-11); a stall produced by the game itself; twins
longer than 16 s and floors other than shipped floor 1; a windowed GUT run; the full suite.

<!-- review-round: 3 verdict: CHANGES_REQUESTED -->

**Reviewed commit:** 1606865 (the fixes 936e9ad and ec7b44b: the diff `3ed383d..1606865` under `src` and `tests`)

**Date:** 2026-11-20 · **Verdict:** CHANGES_REQUESTED · **By:** Auditor (lead, D-014)

The same two reviewers, read-only, on new private copies of `1606865`. The reader checked every
fix against its finding, read the new settings reader as a parser and re-ran mutations. The other
re-ran its round 2 findings, fuzzed the settings reader (13,314 files against a reference reader
of its own, written from the doc comment alone: 0 mismatches, no engine line, no script run, no
orphan, slowest load 41 ms), attacked the choose guard with keys, pad and real positional clicks,
ran its random bot with the guard at 0.3 (13 runs, 34,000 steps, 94,759 ticks: no violation) and
32 mutations of the new code (26 killed). The reader calls the round blocking "by the log rule
alone"; the two 🟡 about clicks below are the lead's reason to fix before Gate B.

**Round 2 findings:**
- CR-14 ✔ resolved. CR-17 ✔ resolved (every object shape and the planted script: nothing built,
  nothing run, no engine line). CR-19 ✔ resolved (`MAKE_STATIC` fails both fight twins, at ticks
  454 and 244; the six twins compare a snapshot hash and the positions at every tick over a fixed
  number of ticks, so none can pass on an empty or short trace). CR-20 ✔ resolved.
- CR-15 ✔ resolved for the double click: a flagged second press at 100, 310, 350 and 500 ms does
  nothing; with the rule switched off five click tests fail. Two things are left, both new:
  CR-23 and CR-24.
- CR-16 ✔ resolved: Down, Enter, Enter; Down, pad A, pad A; a click then Space: nothing at 20,
  80, 250 and 290 ms, a choice at 310 and 350 ms. A key held across the guard's end (700 ms of key
  repeat) never chooses; Escape, pad B and pad Start act at once on all seven menus; 701 bot
  key presses inside a guard did nothing and 1,018 outside it all acted.
- CR-18 ✔ resolved as designed: the verdict is no longer wrong under load, only honest (CR-25).
- CR-21: noted, and one sentence of the reply is wrong: CR-26.

### CR-22 🔴 by the rule (🔵 in substance): `ListMenu` got a second addition and §8 does not say so  ·  `src/ui/menus/list_menu.gd:226-233`
C9 says "One addition" (the disabled entry). 936e9ad adds the hook `_may_choose_by_key()` and a
check in `_press_focused()`; only §9's reply to CR-16 mentions it. Harmless: the base answers
true, `gate_menu.gd` and the gate list's two test files are untouched (empty diff), the 77 gate
tests pass, and the gate list behaves the same on `main` and on the branch for Enter, Space, E,
pad A, pad Y, a click and a flagged click.
> **Builder reply (lead):** logged in acbbc6f, under DEV-11 in §8.

### CR-23 🟡 A quick second click on the same entry is dropped  ·  `src/ui/menus/menu_panel.gd:66-70`
Every mouse button event flagged as a double click is consumed while the panel is open, also when
no menu opened between the two clicks. In the settings menu a click on "Fullscreen" and a second
one 100 to 480 ms later, flagged as a real mouse would send it, flips it once; 2, 3, 4, 5 quick
clicks give 1, 2, 2, 3 toggles; a flagged press on Back does nothing however long the menu has
been open. `test_two_slow_clicks_on_fullscreen_toggle_twice` passes because its second click is
not flagged.
> **Builder reply (lead):** fixed in a25c43d. A flagged press is consumed only when the panel
> opened since the previous mouse button press (one flag: set by `open()`, cleared by any
> press and by the consume). Tests with real positional clicks: a flagged second click on
> Fullscreen 100, 250 and 400 ms after the first toggles it twice; 2, 3, 4 and 5 quick clicks
> with every second one flagged toggle once each; a flagged press on Back after an ordinary
> click goes back. In the implementer's mutation run, consuming every flagged press as before
> fails seven tests.

### CR-24 🟡 The third click of a triple click still acts on the menu that opened  ·  `src/ui/menus/menu_panel.gd`
Three clicks on one spot at +200/+400 ms or +280/+560 ms, the second flagged and the third not:
on the title's "Settings" Fullscreen is switched on; 1 px below the top of "Quit to title" in the
town's pause menu the game quits with no confirmation. At +100/+200 ms nothing happens. The same
goes for a second click the OS does not flag (the mouse moved past its double-click rectangle)
310 ms or more after the first. Which presses Windows flags is reasoned from the Win32 documents,
not measured: no real mouse was used in any round.
> **Builder reply (lead):** fixed in a25c43d for clicks that come quickly: a mouse button press
> that arrives while the choose guard runs starts it again from that press, so both triple
> clicks (+200/+400 and +280/+560 ms) change nothing on Settings and do not quit; a fourth click
> 0.35 s after the third acts (tests). A second, unflagged click more than 0.3 s after the last
> one is a deliberate click and acts: accepted. Still reasoned, not measured: what a real mouse
> flags (§10 Q8).

### CR-25 🟡 Three holes in the tests  ·  `tests/autoload/test_user_settings.gd`, `tests/scenes/test_f015_clicks.gd:359-375`
`rfind("=")` in `UserSettings._read_line` passes all 52 settings tests, and then reads
`fullscreen=a=b` as true. The fast double-click cases count frames (8 and 20) and under 24 busy
loops those outlasted the guard: one case failed after three tries with its numbers (an honest
failure, but a red gate for a reason that is not the code); eight copies of the file at once all
passed. And the two mutations nobody could tell from the real code in round 2 (only
`StaticBody2D` kept; the keep done after the disable) still pass the new twins.
> **Builder reply (lead):** fixed in a25c43d except the last: tests pin the first `=` as the
> separator (`fullscreen=a=b`, `fullscreen=true=false`, `fullscreen=a=true` after a good line,
> `a=fullscreen=true`); the click cases use gaps in real time (30, 100 and 200 ms, no frame
> counts) and a case whose timing could not be produced in three tries is `pending()` with its
> numbers, not failed. The two mutants are left: three rounds of twins could measure no
> difference under them.

### CR-26 🔵 The reply to CR-21 is wrong about Resume  ·  §9
A double click on Resume still attacks: the first click closes the panel, so the flagged second
press is not consumed and reaches the game (both reviewers ran it: IDLE, then ATTACKING within 10
ticks, at 60, 100, 150 and 400 ms).
> **Builder reply (lead):** corrected under CR-21's reply (acbbc6f). **Not fixed, accepted.** The
> implementer first made the closed panel consume that press and measured that the player
> attacks all the same: `PlayerInput` reads `Input.is_action_just_pressed()`, which the engine
> sets before any `_input`, and consuming the event does not undo it. Stopping it would mean
> changing how the player's input is read (F-001) or holding attacks after every resume. The
> consume was taken out again, so the code does only what has an effect; the panel's header says
> so. Logged as DEV-15 and put to Lucas as §10 Q11.

### CR-27 🔵 Two choices that could bite later  ·  `src/autoload/user_settings.gd:114`, `src/ui/menus/menu_panel.gd:33`
The settings file is written by `ConfigFile` and read by hand: if Godot changes how it writes a
bool, saved settings would read as defaults (two tests would notice). `choose_guard_seconds` is
an export with its default in code; C17 allows that, and `data/tunables/shell.tres` would put it
beside the other shell values.
> **Builder reply (lead):** the first is fixed in a25c43d: `save_to()` writes the three lines
> itself, the same bytes `ConfigFile` wrote (tested for all four combinations, and a file
> written by a real `ConfigFile` still loads); `src` no longer uses `ConfigFile`. The second is
> left as an export: moving it to the data file would make the shell overwrite what the tests'
> helper sets on the panel; C17 allows it, and §10 Q8 says where the number is.

### CR-28 🔵 Measured, for the record
The choose keys are dropped for 0.3 s after any menu opens: five Spaces 20 ms apart from the
opening toggle nothing; Enter 200 ms after a death screen with a 0.1 s delay does nothing though
the entry is enabled; Back by Enter inside the 0.3 s does nothing while Escape goes back at once.
A flagged press in the game with no menu open attacks, as it must. A BOM file with real settings
is now read; a 16.5 MB file is refused in 22 ms with one warning.
> **Builder reply (lead):** noted. The 0.3 s on the choose keys is §10 Q8.

**Tried, found nothing:** the settings reader with `\r`-only line ends, bytes above 0x7F, several
`=`, tabs, `[settings]` twice and after another section, a bare, a partial and a double BOM, a
60,000-character line, files of 65,535, 65,536, 65,537 and 131,072 bytes; the shell started on an
empty file, garbage, a directory at the path, a read-only file and a missing folder, and a later
change saved and read back in all four combinations; nothing else in `src` reads a user file;
Enter down at +100 ms and up at +450 ms; Enter, Down, Enter inside the guard (the focus moved,
nothing chosen); five Enters after the guard (five toggles); 72 flagged presses on every entry of
the seven menus at 0, 100, 400 and 1,000 ms; flagged right, middle and wheel events and clicks on
empty space; Space 100 ms after an Escape resume (it dashes: the game runs); 24 twins of round 2's
scenarios at 120 ticks/s (0 differ). C2, C8, C10, C12, C13, G5 and G6 hold; the additions to
DEV-11 and DEV-14 and ASSUMPTION-18 are accurate apart from CR-22 and CR-23; no existing test file
was edited in the two commits.

**Not checked:** a real mouse (which presses the OS flags), a real pad, a real window, the
editor's embedded window; the branch for a settings file that exists and cannot be opened; twins
at 60 and 30 ticks/s in this round; the stalled frame and hover of round 2 again; the full suite.

---

## 10. Open Questions  ·  _Anyone (append)_

| # | Raised by | Question | Blocking? | Answer (Lucas/Planner) |
|---|---|---|---|---|
| Q1 | Lead | → Lucas, at Gate B: the lead's choices you did not make. Both "Return to town" and "Quit to title" ask once more before acting; the settings are screen shake and fullscreen only (you did not ask for fullscreen); the title screen is Start, Settings, Quit; the death screen's button is grey for 1.5 s (`death_return_delay`) so a mashed key cannot skip it. | no | |
| Q2 | Lead | → Lucas, at Gate B: the room keeps moving behind the death screen (enemies walk around your body) for as long as you wait, as it did for 1.5 s before. Fine, or should the room freeze? | no | |
| Q3 | Lead | → Lucas / Direction: quitting to the title loses all progress until save/load exists (slice 4). The menu warns about it. | no | |
| Q4 | Lead | → Direction: F-012 §10 Q8 (is a menu choice a player action under G8?) now also covers "Return to town" and the death screen's button: both reach `TowerSession` the way the gate's choice does, with no command object. Still open; it matters for co-op. | no | |
| Q5 | Lead | → Art & Game Feel: the look of every menu (plain buttons, 8 px font, flat dim). | no | |
| Q6 | Lead | → Art & Game Feel (plan review PR-16): a pause in the middle of a screen shake freezes the picture up to 6 px off centre until you resume. Accepted for the placeholder shake. | no | |
| Q7 | Lead | → Lucas, at Gate B: pressing Start now takes about 0.8 s before the town appears (the whole game is built at that moment instead of at launch). Fine for now, or should the title screen say "Loading"? | no | |
| Q8 | Lead | → Lucas, at Gate B (code review CR-2): for 0.3 s after a menu opens, mouse clicks on its entries do nothing, so the second click of a double click cannot switch a setting or quit by accident. Keys and the pad are not delayed. Does the mouse feel slow in the menus? The number is `pointer_guard_seconds` on the menu panel. **Changed in round 2 (CR-15, CR-16):** the 0.3 s now also hold back Enter, Space and pad A (moving and going back are not delayed), the number is `choose_guard_seconds`, and a double click never chooses at any speed. Please double-click "Settings" with a real mouse once: the double-click mark comes from Windows and no test could produce a real one. **Round 3 (CR-23, CR-24):** quick clicks on the same entry all count (click Fullscreen twice fast: it should go on and off), and clicking fast right after a menu opens keeps being ignored until you stop for 0.3 s. | no | |
| Q9 | Lead | → Lucas (code review CR-11): when you run the game inside the editor's own window (Godot's embedded game view), choosing Fullscreen changes the setting and saves it but leaves the window alone; run it in its own window or as an export to see fullscreen. Not verified in the editor by anyone. | no | |
| Q10 | Lead | → Direction, for the save/load spec (slice 4; code review CR-17): Godot's `ConfigFile` and `str_to_var` build objects and can run a script named in the text they read. A save file must be read as plain data (JSON, or a reader that builds nothing), never through them. The settings file is read by hand since ec7b44b. | no | |
| Q11 | Lead | → Lucas, at Gate B (code review CR-26): a double click on "Resume" resumes the game and your character attacks once (the second click lands in the running game). Stopping it means changing how attacks are read or holding them back after every resume. Leave it, or fix it? | no | |

---

## 11. Director Notes  ·  _Lucas_

