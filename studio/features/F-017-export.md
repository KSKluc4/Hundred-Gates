---
id: F-017
title: Export builds — a Windows build for other people, developer tools off (slice 3, third part)
status: PLAN_REVIEW      # DRAFT | PLAN_REVIEW | PLAN_CHANGES | APPROVED | IN_PROGRESS | CODE_REVIEW | CODE_CHANGES | DONE | PARKED
owner_now: Auditor       # who must act next: Planner | Auditor | Builder | Lucas
created: 2026-11-21
updated: 2026-11-21
depends_on: [F-000, F-012, F-015, F-016, D-003, D-014, D-016]
pillars: [1]
department: Direction
---

# F-017 — Export builds

> **How to use this file.** This is the single source of truth for this feature.
> Every agent reads the WHOLE file before acting. Write only in the sections you own
> (see studio/README.md). Never delete another role's text — reply under it.

---

## 1. Goal  ·  _Planner_

**Player-facing outcome (one sentence):**
Someone who is not Lucas unzips one file on a Windows PC, runs `HundredGates.exe` and plays
the game as a player sees it: no FPS text, no debug keys, no developer text under the enemies.

**Why now:** slice 3 (D-016) ends with a playtest by someone who is not Lucas, and that needs
a build. Function before looks (D-016, note of 2026-11-21). It also answers F-016 §10 Q6: the
debug keys pay out swords.

**Decided by Lucas (2026-11-21, in chat; his answers are Gate A, D-016):** Windows only for
now; all developer tools off in a build, on as today when the game is run from the project;
the build is a zip on this machine that he sends himself, nothing is published; the lead may
download Godot's export templates (done: `Godot_v4.7.2-stable_export_templates.tpz`, 1,281 MB,
from the official `godotengine/godot-builds` release, SHA-512 checked against the release's
`SHA512-SUMS.txt`; the four Windows x86_64 files and `version.txt` are installed in Godot's
templates folder on this machine).

**Out of scope (explicitly):**
- macOS and Linux builds (later, each its own small step); code signing; an installer; an
  icon; a splash screen of our own.
- Publishing anywhere: GitHub Releases, itch.io, Steam. No upload of any kind.
- A hidden key that turns the developer tools on in a build (Lucas chose "all off").
- Removing or changing any developer tool: they stay exactly as they are when run from the
  project.
- Save/load, a version number on the title screen, crash reporting, telemetry.
- The debug scenes under `scenes/debug/`: they stay in the project and are not in a build's
  way (the build starts `scenes/main.tscn`).

---

## 2. Context  ·  _Planner_

What exists (from `main` at `67624f1`):
- **No export setup at all:** no `export_presets.cfg`, no build script, no `builds/` folder.
  `.gitignore` has `.godot/`, `/android/`, `.venv/`, `__pycache__/`, `.studio/`.
- **Tools:** `tools/_godot.sh` (`resolve_godot`, `godot_import`, `PROJECT_ROOT`,
  `REQUIRED_GODOT_VERSION`), `tools/test`, `tools/lint`, `tools/check_core_purity`. They are
  bash; on this Windows machine they run in Git Bash with `GODOT_BIN` set, and Python is the
  project's `.venv` (`.venv/Scripts` on Windows, `.venv/bin` elsewhere).
- **Developer tools in the game the shell runs (`scenes/main.tscn`):**
  - `DebugOverlay` (`src/ui/debug_overlay.gd`, CanvasLayer 100 in `main.tscn`): FPS, Godot and
    game version; shown at start when `Tunables.game.debug_overlay_visible_on_start` (true in
    `data/tunables/game_tunables.tres`); toggled by the `debug_toggle` action.
  - Debug keys: `debug_reset` (R: restart the room) and `debug_next_room` (N: skip the room) in
    `FloorScene`, `debug_next_room` in `TownScene` (marks a floor cleared), all behind
    `debug_keys_enabled`, which `Game` (default true) passes down.
  - The text under every enemy (`Enemy`'s `DebugLabel`: state, cooldown, target).
  - `debug_reload_tunables`, `debug_pulse_toggle`, `debug_shake_toggle`, `debug_ai_toggle`
    are read by `MotorDebugOverlay` (`src/ui/debug/motor_debug_overlay.gd`), which the debug
    scenes use; `Player` reloads data on F5 (`src/entities/player/player.gd:86-115`). Whether
    any of these is reachable from `main.tscn` is for the Builder to establish (AC3 covers
    every `debug_*` action whatever the answer).
- **Not developer tools** (they stay in a build): the telegraphs and shapes drawn by
  `CombatDebugDraw` (they are the placeholder look of attacks), the enemies' health bars, the
  damage numbers, the boss bar, the HUD, the drop markers.
- `OS.is_debug_build()` is true for the editor binary (also when it runs the game with
  `--path`, as Lucas and the tests do) and for a debug export; false for a release export.
- Autoloads today: `Tunables`, `UserSettings` (`project.godot`). Tests that change an autoload's
  values restore them in `after_each`.
- The project's `config/version` is `0.1.0`, its name `Hundred Gates`.
- A release build writes its log to `user://logs/`; `user://settings.cfg` is the only file the
  game writes.

Relevant decisions: D-003 (headless tests), D-014 (reviews), D-016 (slice 3).
Relevant features: F-012 (the debug keys, C17), F-015 (the shell, settings), F-016 (Q6).

---

## 3. Options Considered  ·  _Planner_

### ✅ Chosen: one switch, read where the tools live; a preset and a script
- **How it works:** an autoload `DevTools` holds one boolean, `enabled`: true in a debug
  binary, false in a release export, and false when the game is started with the user argument
  `--no-dev-tools` (so the off state can be run and tested from the project). The three places
  that show or obey a developer tool ask it. `export_presets.cfg` has one preset, a release
  build for Windows x86_64 with the game's data embedded in the exe and the tests, GUT, the
  studio documents and the tools left out. `tools/export` builds it, checks it, and zips it
  with a short README for the player.
- **Why chosen:** nothing a developer uses changes; the off state is the same code path in a
  build and in a test; a build is one command and checks itself.
- **Costs we're accepting:** a third autoload; a debug export (`--export-debug`) has the tools
  on, which is what a debug export is for; the checks of the built exe are a script's, not
  GUT's (GUT cannot export).
- **Would revisit if:** a second platform arrives (the script takes the preset's name then),
  or a playtester's problem needs the tools on their machine (the hidden key Lucas declined).

### ❌ Rejected: strip the developer tools from the scenes of a build
- **Why rejected:** two sets of scenes, or an export plugin, to remove what one boolean hides.
- **Tempting because:** "not in the build" sounds safer than "off in the build".

### ❌ Rejected: a custom feature tag in the preset (`OS.has_feature("playtest")`)
- **Why rejected:** it cannot be switched on when running from the project, so the off state
  could only be seen by exporting; tests could not reach it.
- **Tempting because:** feature tags are Godot's own way.

### ❌ Rejected: pass the switch down from `Shell` through `Game`, the scenes, the room, the enemy
- **Why rejected:** five levels of plumbing for one constant of the process; `DebugOverlay`
  is not under the shell at all.
- **Tempting because:** `debug_keys_enabled` already travels that way.

### ❌ Rejected: a hidden key to turn the tools on in a build; publishing the build; other platforms
Lucas decided against each (§1). Not even partially.

---

## 4. Constraints  ·  _Planner_

Hard rules for this feature. Violating any of these = automatic `CODE_CHANGES`.

| ID | Constraint | Reason |
|---|---|---|
| C1 | **`DevTools`** (`src/autoload/dev_tools.gd`, a Node, autoload `DevTools` after `Tunables` and `UserSettings`): `var enabled: bool`, set once in `_init()` to `OS.is_debug_build() and not OS.get_cmdline_user_args().has(NO_DEV_TOOLS_ARGUMENT)`, with `const NO_DEV_TOOLS_ARGUMENT := "--no-dev-tools"`. Nothing else in it. Nothing in `src/core` reads it. | One switch; G6 |
| C2 | **With `DevTools.enabled` false:** `DebugOverlay` is hidden whatever `debug_overlay_visible_on_start` says, and `debug_toggle` does not show it; the game the shell builds has its debug keys off (`Game.debug_keys_enabled` false, so R and N do nothing on a floor and N nothing in town); the text under every enemy is not shown. | Lucas: all off in a build |
| C3 | **With `DevTools.enabled` false, no `debug_*` input action does anything** in the game the shell runs: for every action of the InputMap whose name starts with `debug_`, pressing it in the title, in town, on a floor and in a pause changes no state (the session's snapshot, the room, the player, the tunables in use, what is visible). Whatever reads such an action in `main.tscn`'s tree is switched by `DevTools.enabled` at the place it is read. | No back door; a test lists the actions from the InputMap, so a new one is covered |
| C4 | **With `DevTools.enabled` true, everything is as on `main`.** Every existing test passes unedited (the test binary is a debug build). The telegraphs, health bars, damage numbers, boss bar, HUD and drop markers are shown in both states. | No regression; they are the game's look |
| C5 | **`export_presets.cfg`** (committed): exactly one preset, `Windows Desktop`, platform Windows Desktop, architecture x86_64, runnable, the pack embedded in the executable, export path `builds/windows/HundredGates.exe`. It exports all resources **except** `tests/*`, `addons/gut/*`, `studio/*`, `tools/*`, `scenes/debug/*` and `*.md`. No signing, no credentials, no personal data in the file. | One file to send; nothing of the studio or the tests in a player's hands |
| C6 | **`tools/export`** (bash, in the style of `tools/test`; sources `tools/_godot.sh`): refreshes the import, runs `--headless --export-release "Windows Desktop"`, then **checks** and fails (non-zero, a line saying why) unless: the exe exists and is larger than the release template alone; Godot's output has no line with `ERROR` or `SCRIPT ERROR`; the exe contains the bytes of `scenes/main.tscn`'s path and of `data/items/loot_catalog.tres`'s, and none of `addons/gut`, `res://tests/`, `res://studio/`, `res://tools/`; the exe, run with `--headless --quit-after 300`, exits 0 and prints no line with `ERROR`. Then it writes `builds/HundredGates-<version>-windows.zip` holding exactly `HundredGates.exe` and `README.txt`, `<version>` read from `project.godot`'s `config/version`. It prints the zip's path and size. It needs no network and publishes nothing. | Lucas: a zip on this machine; a build that checks itself |
| C7 | **`README.txt`** for the player, kept at `tools/export_readme.txt` and copied into the zip: how to start (unzip, run `HundredGates.exe`; Windows may say it protected the PC because the file is unsigned: "More info", then "Run anyway"), the controls for keyboard and mouse and for a gamepad **as `project.godot`'s input map has them** (move, aim, attack, dodge, interact, pause), that progress is not saved yet, that the look is placeholder, and where the settings file is. No name, e-mail or other personal detail. Plain ASCII, lines of at most 78 characters. | A stranger starts it without Lucas beside them |
| C8 | **`builds/` is ignored by git** (`.gitignore`). No built file is ever committed. | A build is not source |
| C9 | **The script works on this Windows machine in Git Bash and is written to work on macOS** (the Python it uses for the zip and the byte checks is found in `.venv/Scripts` or `.venv/bin`, else `python3`, else `python`; no `zip` command, no PowerShell). A missing export template is reported in one line naming the folder Godot looks in. | The project's tools are bash (F-000) |
| C10 | **Tests** (GUT, the debug binary): `DevTools` is set false in a test and restored in `after_each` (the pattern used for `Tunables`). No existing test file is edited. | C4 |

**Must not break:** every F-001 to F-016 behaviour; the whole suite (3,125 tests on `main`);
running the game from the project behaves exactly as today; `gdlint`, `gdformat --check`,
`tools/check_core_purity`, the headless boot.

---

## 5. Acceptance Criteria  ·  _Planner_

- [ ] AC1: `DevTools.enabled` is true in the test binary; the rule of C1 is one pure static
  function of (is a debug build, the user arguments) tested for the four combinations and for
  an argument list that only contains other arguments.
- [ ] AC2: with `DevTools.enabled` false, in the real `main.tscn`: the overlay is hidden at
  start though `debug_overlay_visible_on_start` is true, and pressing `debug_toggle` leaves it
  hidden; a game started through the shell has `debug_keys_enabled` false; on a floor R does
  not restart the room and N does not skip it; in town N clears no floor; every enemy's debug
  text is hidden while its body, bar, telegraph and damage numbers are as before.
- [ ] AC3: with `DevTools.enabled` false, for **every** action in the InputMap whose name
  starts with `debug_` (read from the InputMap in the test, at least the seven of today),
  pressed on the title, in town, on a floor in a fight, and in the pause menu: the session's
  `to_dict()`, the room index, the room's sim snapshot at the same tick as a twin game that
  did not press it, the identity of `Tunables`' resources and the overlay's visibility are
  unchanged.
- [ ] AC4: with `DevTools.enabled` true, each of the things AC2 lists works as on `main`
  (overlay shown and toggled, R and N act, the text shown), and the whole suite passes with
  no existing test file edited.
- [ ] AC5: starting the game from the project with `-- --no-dev-tools` gives
  `DevTools.enabled == false` (shown by a headless run that prints it, or a test of the real
  argument path).
- [ ] AC6: `tools/export` on this machine ends with exit code 0 and a zip that holds exactly
  `HundredGates.exe` and `README.txt`; every check of C6 has a way to be seen failing (the
  script is run with each condition broken once: a missing template, a preset that does not
  exclude the tests, an exe that prints an error) and the result is in §8.
- [ ] AC7: the exported `HundredGates.exe`, started in a window on this machine, shows the
  title without the FPS text; after Start, the town without it; pressing the `debug_toggle`
  key, R and N changes nothing; an enemy on floor 1 has no text under it. Seen in screenshots
  (the lead's run, §8).
- [ ] AC8: `README.txt`'s controls match `project.godot`'s input map, action by action
  (checked by the lead against the file; listed in §8).
- [ ] AC9: `git status` is clean after `tools/export` (nothing under `builds/` is seen by git);
  `export_presets.cfg` holds no path outside the project, no user name and no credential.
- [ ] AC10: `gdlint src tests`, `gdformat --check src tests`, `tools/check_core_purity` and
  the headless boot are clean; the full suite passes.

**How to verify manually (Lucas, Gate B):** unzip `builds/HundredGates-0.1.0-windows.zip`
somewhere else, run `HundredGates.exe`, play a floor. No FPS text; R, N and the overlay key do
nothing; nothing is written under the enemies. Then run the game from the project as before:
everything a developer had is still there.

---

## 6. Task Breakdown  ·  _Planner_

One commit per task, one implementer, in order.

| # | Task | Files likely touched | Notes |
|---|---|---|---|
| T1 | The switch and what obeys it | `src/autoload/dev_tools.gd`, `project.godot` (one autoload line), `src/ui/debug_overlay.gd`, `src/world/shell.gd` (the game it builds), `src/entities/enemies/enemy.gd`, anything else in `main.tscn`'s tree that reads a `debug_*` action (to be found), `tests/autoload/test_dev_tools.gd`, `tests/scenes/test_f017_dev_tools.gd` | AC1–AC5. First establish, and report, every reader of a `debug_*` action reachable from `main.tscn` |
| T2 | The preset, the script, the README, the ignore line | `export_presets.cfg`, `tools/export`, `tools/export_readme.txt`, `.gitignore` | AC6, AC8, AC9. The export templates are installed on this machine |
| T3 | Lead: the build run, the exe started in a window with screenshots, the README checked against the input map, the final gate | §8 | AC7, AC10; no code |

---

## 7. Plan Review  ·  _Auditor_

---

## 8. Implementation Log  ·  _Builder_

**Started:** —  ·  **Branch:** `feature/F-017-export`

### Progress
- [ ] T1
- [ ] T2
- [ ] T3

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
| Q1 | Lead | → Lucas, at Gate B: the README for the player (`tools/export_readme.txt`) is the first thing a stranger reads. Its words are the lead's; change what you like. | no | |

---

## 11. Director Notes  ·  _Lucas_

