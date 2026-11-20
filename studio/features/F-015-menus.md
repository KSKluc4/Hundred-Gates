---
id: F-015
title: Menus — title screen, pause menu, death screen, settings
status: IN_PROGRESS      # DRAFT | PLAN_REVIEW | PLAN_CHANGES | APPROVED | IN_PROGRESS | CODE_REVIEW | CODE_CHANGES | DONE | PARKED
owner_now: Builder       # who must act next: Planner | Auditor | Builder | Lucas
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
| Q1 | Lead | → Lucas, at Gate B: the lead's choices you did not make. Both "Return to town" and "Quit to title" ask once more before acting; the settings are screen shake and fullscreen only (you did not ask for fullscreen); the title screen is Start, Settings, Quit; the death screen's button is grey for 1.5 s (`death_return_delay`) so a mashed key cannot skip it. | no | |
| Q2 | Lead | → Lucas, at Gate B: the room keeps moving behind the death screen (enemies walk around your body) for as long as you wait, as it did for 1.5 s before. Fine, or should the room freeze? | no | |
| Q3 | Lead | → Lucas / Direction: quitting to the title loses all progress until save/load exists (slice 4). The menu warns about it. | no | |
| Q4 | Lead | → Direction: F-012 §10 Q8 (is a menu choice a player action under G8?) now also covers "Return to town" and the death screen's button: both reach `TowerSession` the way the gate's choice does, with no command object. Still open; it matters for co-op. | no | |
| Q5 | Lead | → Art & Game Feel: the look of every menu (plain buttons, 8 px font, flat dim). | no | |
| Q6 | Lead | → Art & Game Feel (plan review PR-16): a pause in the middle of a screen shake freezes the picture up to 6 px off centre until you resume. Accepted for the placeholder shake. | no | |

---

## 11. Director Notes  ·  _Lucas_

