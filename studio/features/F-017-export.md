---
id: F-017
title: Export builds — a Windows build for other people, developer tools off (slice 3, third part)
status: IN_PROGRESS      # DRAFT | PLAN_REVIEW | PLAN_CHANGES | APPROVED | IN_PROGRESS | CODE_REVIEW | CODE_CHANGES | DONE | PARKED
owner_now: Builder       # who must act next: Planner | Auditor | Builder | Lucas
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
- The debug scenes under `scenes/debug/`: they stay in the project and are not in a build
  (the build starts `scenes/main.tscn`, and a release exe refuses a scene argument). Running
  a debug scene from the project with `-- --no-dev-tools` is not supported: its own overlay
  keeps its keys.
- Hiding the green rings around the player and the enemies, or rewording the boss bar: they
  are the game's placeholder look today (§10 Q2).

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
  - **Those three are all the readers of a `debug_*` action in `main.tscn`'s tree**
    (`src/ui/debug_overlay.gd:20-22`, ungated; `src/world/floors/floor_scene.gd:101-107` and
    `src/world/town/town_scene.gd:88-92`, behind `debug_keys_enabled`; plan review).
    `debug_reload_tunables`, `debug_pulse_toggle`, `debug_shake_toggle`, `debug_ai_toggle`
    (F5, P, K, I) are read only by `MotorDebugOverlay`, which only the debug scenes hold, so
    they do nothing in `main.tscn` today; `Player` reads no input. Each of the seven actions
    has exactly one key (`project.godot:95-129`: F3, F5, P, K, R, I, N) and shares none with
    a game action. In a pause the game is disabled, so only F3 acts there.
  - The enemy's text is made visible in two places (`src/entities/enemies/enemy.gd:161`,
    every frame, and `:283`).
- **Not developer tools** (they stay in a build): what `CombatDebugDraw` draws (the red
  sectors of live hits, which are the only drawing of the player's swing, and the green
  rings of the hurtboxes), the enemies' bodies, health bars and telegraphs, the damage
  numbers, the boss bar with its text (`warden  400 / 400  stage 1`: the only boss HP number),
  the HUD, the wave and drop markers.
- `OS.is_debug_build()` is true for the editor binary (also when it runs the game with
  `--path`, as Lucas and the tests do) and for a debug export; false for a release export.
- Autoloads today: `Tunables`, `UserSettings` (`project.godot`). Tests that change an autoload's
  values restore them in `after_each`.
- The project's `config/version` is `0.1.0`, its name `Hundred Gates`.
- A release build writes its log to `user://logs/`; `user://settings.cfg` is the only file the
  game writes. Both are in `%APPDATA%\Godot\app_userdata\Hundred Gates\`, the folder runs
  from the project use too.
- **Measured by plan review, with throwaway exports in a private copy (Godot 4.7.2, only the
  x86_64 Windows templates installed):** a headless release export takes about 8 s, exits 0,
  prints the banner and `[ DONE ] savepack`, and gives one byte-identical file of 109.6 MB
  (the template with a 0.45 MB pack embedded); Godot does **not** create the output folder
  (exit 1, `The given export path doesn't exist`); the pack's table holds paths without
  `res://` (405 files under `.godot`, `data`, `scenes`, `src` and `project.binary`); a
  resource is listed as `<path>.remap` or `<path>`; `.txt` and `.md` files and the `studio`
  and `tools` folders are never exported; a release exe exits 0 whatever is missing (84
  error lines on stderr with `data/*` excluded, exit 0) and refuses a scene or `--path`
  argument; `OS.is_debug_build()` is false in it and true in a debug export; `--
  --no-dev-tools` reaches `OS.get_cmdline_user_args()` in both; on this machine `python3`
  on PATH is the Microsoft Store stub (exit 49); a missing template gives exit 1 and `No
  export template found at the expected path:` with the path.

Relevant decisions: D-003 (headless tests), D-014 (reviews), D-016 (slice 3).
Relevant features: F-012 (the debug keys, C17), F-015 (the shell, settings), F-016 (Q6).

---

## 3. Options Considered  ·  _Planner_

### ✅ Chosen: one switch, read where the tools live; a preset and a script
- **How it works:** an autoload `DevTools` holds one boolean, `enabled`: true in a debug
  binary, false in a release export, and false when the game is started with the user argument
  `--no-dev-tools` (so the off state can be run and tested from the project). The four places
  that show or obey a developer tool ask it, each where it reads the key or shows the text. `export_presets.cfg` has one preset, a release
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
  is not under the shell at all; and a `Game` built without the shell would keep its keys.
- **Tempting because:** `debug_keys_enabled` already travels that way.

### ❌ Rejected: checking the exe by its size, by byte needles, or by its exit code
- **How it would work:** the first draft of C6: the exe is larger than the template, holds
  the bytes of two paths and not those of `res://tests/`, and exits 0 when run.
- **Why rejected:** measured in plan review. A build without the floors' data passes all of
  it (the title appears; the data is loaded on Start) and so the check lies; a release exe
  exits 0 with 84 error lines; `res://studio/` can never be found; export shrinks the
  template, so a good exe is only 0.3 MB larger and a bad one can be smaller.
- **Tempting because:** each is one line of shell.

### ❌ Rejected: a hidden key to turn the tools on in a build; publishing the build; other platforms
Lucas decided against each (§1). Not even partially.

---

## 4. Constraints  ·  _Planner_

Hard rules for this feature. Violating any of these = automatic `CODE_CHANGES`.

| ID | Constraint | Reason |
|---|---|---|
| C1 | **`DevTools`** (`src/autoload/dev_tools.gd`, a Node, autoload `DevTools`, after `Tunables` and `UserSettings`): `const NO_DEV_TOOLS_ARGUMENT: String = "--no-dev-tools"`; one pure static function `is_enabled_for(is_debug_build: bool, user_arguments: PackedStringArray) -> bool` (true for a debug build whose arguments do not hold the constant); `var enabled: bool`, set once in `_init()` from `OS.is_debug_build()` and `OS.get_cmdline_user_args()`. Nothing else in it. Nothing in `src/core` reads it. | One switch; G6 |
| C2 | **The switch is read where the tool is.** `DebugOverlay`: hidden at start and deaf to `debug_toggle` when the switch is off, whatever `debug_overlay_visible_on_start` says. `FloorScene` and `TownScene`: a debug key acts only when `DevTools.enabled and debug_keys_enabled` (**the switch wins**: a `Game` built with its keys on still has none when the switch is off). `Enemy`: its debug text is shown only when the switch is on, in both places that show it. `Shell` and `Game` are not changed. | Lucas: all off in a build; plan review PR-1 |
| C3 | **With the switch off, no `debug_*` input action does anything** in the game the shell runs. A test reads every action whose name starts with `debug_` from the InputMap (seven today), so a new one is covered. | No back door |
| C4 | **With the switch on, everything is as on `main`.** Every existing test passes unedited (the test binary is a debug build). What §2 lists as not developer tools is shown in both states. | No regression |
| C5 | **`export_presets.cfg`** (committed), exactly: one preset `[preset.0]` with `name="Windows Desktop"`, `platform="Windows Desktop"`, `runnable=true`, `export_filter="all_resources"`, `include_filter=""`, `exclude_filter="tests/*, addons/gut/*, scenes/debug/*"`, `export_path="builds/windows/HundredGates.exe"`, and `[preset.0.options]` with `binary_format/embed_pck=true` and `binary_format/architecture="x86_64"`. No other key: no signing, no custom template, no company name, no absolute path, no personal data. | The file plan review exported with; one file to send |
| C6 | **`tools/export`** (bash, in the style of `tools/test`; sources `tools/_godot.sh`; imports through `godot_import`): makes `builds/windows/`, runs `--headless --export-release "Windows Desktop"`, and then **checks**, failing with a non-zero exit and one line saying why, unless: (a) Godot exited 0 and its stdout and stderr together hold no line with `ERROR` (a missing template is reported with Godot's own line); (b) the exe ends with an embedded pack (the `GDPC` trailer) whose file table is not empty; (c) **the table is complete:** every `.gd`, `.tres` and `.tscn` file the project has under `src/` and `data/`, and `scenes/main.tscn`, has an entry (`<path>` or `<path>.remap`); (d) **the table holds nothing else:** its top-level names are exactly `.godot`, `data`, `scenes`, `src` and `project.binary`, and under `scenes` only `main.tscn` (listed as `main.tscn` or `main.tscn.remap`); (e) on Windows, the exe run with `--headless --quit-after 300`, with `APPDATA` pointing at a fresh temporary folder, exits 0 and prints no line with `ERROR` on stdout or stderr (elsewhere this check is skipped with a printed line saying so). Then it writes `builds/HundredGates-<version>-windows.zip` (deflated) holding exactly `HundredGates.exe` and `README.txt`, `<version>` read from `project.godot`'s `config/version`, and prints the zip's path and size. It uses no network and publishes nothing. | Lucas: a zip on this machine; a check that cannot be passed by a build that cannot play (plan review PR-5) |
| C7 | **`README.txt`** for the player, kept at `tools/export_readme.txt` and copied into the zip: how to start (extract the whole zip first, then run `HundredGates.exe`; Windows may say it protected the PC because the file is unsigned: "More info", then "Run anyway"; on a managed PC that choice may be missing), the controls for keyboard and mouse and for a gamepad **as `project.godot`'s input map has them** (move, aim, attack, dodge, interact, pause), that progress is not saved yet, that the look is placeholder, and where the settings file is. No name, e-mail or other personal detail. Plain ASCII, lines of at most 78 characters. | A stranger starts it without Lucas beside them |
| C8 | **`builds/` is ignored by git** (`.gitignore`). No built file is ever committed. | A build is not source |
| C9 | **Portable bash.** The script runs on this Windows machine in Git Bash and is written to run on macOS. The Python it uses for the pack table and the zip is a small file of its own, `tools/export_pack.py` (standard library only); the interpreter is the first of `.venv/Scripts/python.exe`, `.venv/bin/python`, `python3`, `python` **that runs `-c ""` successfully**. No `zip` command, no PowerShell. Paths with spaces work. | The project's tools are bash (F-000); PR-9 |
| C10 | **Tests** (GUT, the debug binary): a test sets `DevTools.enabled` false and restores it in `after_each` (the pattern used for `Tunables`). No existing test file is edited. | C4 |

**Must not break:** every F-001 to F-016 behaviour; the whole suite (3,125 tests on `main`);
running the game from the project behaves exactly as today; `gdlint`, `gdformat --check`,
`tools/check_core_purity`, the headless boot.

---

## 5. Acceptance Criteria  ·  _Planner_

- [ ] AC1: `DevTools.enabled` is true in the test binary; `DevTools.is_enabled_for` is tested
  for the four combinations of (debug build, the argument present) and for an argument list
  that holds only other arguments.
- [ ] AC2: with the switch off, in the real `main.tscn`: the overlay is hidden at start though
  `debug_overlay_visible_on_start` is true, and `debug_toggle` leaves it hidden; on a floor R
  does not restart the room and N does not skip it, in town N clears no floor, **also in a
  `Game` built with `debug_keys_enabled` true**; every enemy's debug text is hidden, after a
  frame and **at once after a kill, before the next frame, in a room without reinforcements**
  (the second place that shows it runs on a death, and the body stays drawn there), while its
  body, bar, telegraph and damage numbers are as before.
- [ ] AC3: with the switch off, for **every** action in the InputMap whose name starts with
  `debug_` (read from the InputMap in the test; at least seven), pressed **two ways** (each
  event bound to it sent pressed and then released between two ticks, and an
  `InputEventAction`), in four places, nothing changes: **title** (the flow state, the menu's
  entries and focus, no game exists); **town** (the flow state, the session's `to_dict()`, the
  overlay hidden); **a floor in a fight** (the flow state, the session's `to_dict()`, the room
  index, the identity of `Tunables`' resources, and the room's sim snapshot equal to that of a
  twin game that pressed nothing, at the same sim time; twins run one after the other on a
  fixture tower without loot); **the pause menu** (the flow state stays `PAUSED`, the entries
  and the focus are the same, the game is still stopped).
- [ ] AC4: with the switch on, each thing AC2 lists works as on `main` (overlay shown and
  toggled, R and N act, the text shown), and the whole suite passes with no existing test file
  edited.
- [ ] AC5 (the lead's run, in §8): the game started from the project with a script kept
  outside the repository that prints `root.get_node("DevTools").enabled` (a `-s` script
  cannot name an autoload), once as `godot --path . -s <script>` (true) and once as
  `godot --path . -s <script> -- --no-dev-tools` (false).
- [ ] AC6: `tools/export` on this machine ends with exit code 0 and a zip that holds exactly
  `HundredGates.exe` and `README.txt`. **Each check of C6 is seen failing once**, in a scratch
  copy, with the script's line in §8: (a) a preset for an architecture whose template is not
  installed (arm64); (b) a preset with `binary_format/embed_pck=false` (the exe then has no
  trailer); (c) a preset that also excludes `data/floors/*`; (d) a preset whose filter lacks
  `tests/*`; (e) a script whose `_ready()` loads a path that does not exist (the export is
  clean and the table complete; the exe prints `ERROR` and exits 0).
- [ ] AC7: the exported `HundredGates.exe`, started in a window on this machine, shows the
  title without the FPS text; after Start, the town without it; a game can be started and a
  floor entered; pressing F3, R and N changes nothing; an enemy on floor 1 has no text under
  it. Seen in screenshots (the lead's run, §8).
- [ ] AC8: `README.txt`'s controls match `project.godot`'s input map, action by action
  (checked by the lead against the file; listed in §8); it is plain ASCII with no line over 78
  characters (checked by `tools/export`).
- [ ] AC9: `git status` is clean after `tools/export` (nothing under `builds/` is seen by git);
  `export_presets.cfg` is exactly C5's; the exe's run leaves nothing in the real user folder.
- [ ] AC10: `gdlint src tests`, `gdformat --check src tests`, `tools/check_core_purity` and
  the headless boot are clean; the full suite passes.

**How to verify manually (Lucas, Gate B):** extract `builds/HundredGates-0.1.0-windows.zip`
somewhere else, run `HundredGates.exe`, play a floor. No FPS text; F3, R and N do nothing;
nothing is written under the enemies. Then run the game from the project as before:
everything a developer had is still there.

---

## 6. Task Breakdown  ·  _Planner_

One commit per task, one implementer, in order.

| # | Task | Files likely touched | Notes |
|---|---|---|---|
| T1 | The switch and what obeys it | `src/autoload/dev_tools.gd`, `project.godot` (one autoload line), `src/ui/debug_overlay.gd`, `src/world/floors/floor_scene.gd`, `src/world/town/town_scene.gd`, `src/entities/enemies/enemy.gd`, `tests/autoload/test_dev_tools.gd`, `tests/scenes/test_f017_dev_tools.gd` | AC1–AC4. `Shell` and `Game` are not touched. A leaked `false` would fail `tests/ui/test_debug_overlay.gd`, `test_f012_main.gd`, `test_f015_main.gd`, `test_f016_gate.gd`, `test_f014_room.gd`, `test_f004_debug.gd`: run them after |
| T2 | The preset, the script, its Python file, the README, the ignore line | `export_presets.cfg`, `tools/export`, `tools/export_pack.py`, `tools/export_readme.txt`, `.gitignore` | AC6, AC8, AC9. The export templates are installed on this machine. The five failures of AC6 are shown in a scratch copy, never in the checkout |
| T3 | Lead: AC5's two runs, the build, the exe started in a window with screenshots, the README checked against the input map, the final gate | §8 | AC5, AC7, AC10; no code |

---

## 7. Plan Review  ·  _Auditor_

<!-- review-round: 1 verdict: CHANGES_REQUESTED -->

**Reviewed commit:** 9b44bae · **Date:** 2026-11-21 · **Verdict:** CHANGES_REQUESTED ·
**By:** Auditor (lead, D-014)

Two fresh reviewers. One read the switch (C1 to C4) against the code and probed the engine in
a scratch project: APPROVE_WITH_NOTES. The other took the export side and **tried it**: about
fifteen throwaway exports in a private copy with the installed templates: CHANGES_REQUESTED.
Findings merged and renumbered.

### PR-1 🟡 Two mechanisms for R and N, and "which wins" unsaid  ·  C2, C3
C3 switches readers "at the place it is read" (`src/world/floors/floor_scene.gd:101-107`,
`src/world/town/town_scene.gd:88-92`); C2, AC2 and T1 switched them in `Shell` instead and T1
listed neither file. `Game` defaults to keys on, so a `Game` built without the shell would
keep them with the switch off.
> **Planner reply (lead):** accepted: the readers ask `DevTools.enabled and
> debug_keys_enabled`; the switch wins; `Shell` and `Game` are not touched (C2, AC2, T1).

### PR-2 🟡 AC1 and AC5 against C1  ·  C1
"Nothing else in it" forbade the static function AC1 tests. AC5 cannot be a GUT test: GUT
merges user arguments into its own and quits on an unknown one. `--no-dev-tools` without the
`--` before it is not a user argument and leaves the tools on.
> **Planner reply (lead):** accepted: C1 names `is_enabled_for`; AC5 is two runs of the lead
> with the full commands written out.

### PR-3 🟡 AC3 cannot be judged as written  ·  AC3
On the title there is no game; the town has no room index; nothing checked the flow state or
the focus (R in a pause must not resume); "pressed" was undefined.
> **Planner reply (lead):** accepted: AC3 lists what is compared in each of the four places
> and what "pressed" is (every bound event, and an `InputEventAction`).

### PR-4 🟡 The hurtbox rings and the boss bar's text: developer tools or the look?  ·  §2
`CombatDebugDraw` is in every room; it draws a green ring on the player and every enemy and
fills live hits (the only drawing of the player's swing). The boss bar shows the data id and
`stage 1`. The spec called all of it the look without naming them.
> **Planner reply (lead):** both stay and §2 says so. Lucas's answer named the FPS overlay,
> the debug keys and the text under enemies. Put to him as §10 Q2.

### PR-5 🔴 The checks pass on a build that shows the title and cannot start a game  ·  C6
Measured: with `data/floors/*` also excluded the export exits 0, the exe run headless exits 0
and prints no `ERROR`, and both path needles are present; the floors are loaded only on Start.
A release exe exits 0 whatever is missing (84 error lines on stderr with `data/*` excluded).
`res://studio/` and `res://tools/` can never be found (never exported); `res://tests/` only
through a cache. The size check is brittle: export shrinks the template by 0.14 MB, the good
exe is 0.31 MB over it, and a wrong one can be under it.
> **Planner reply (lead):** accepted, and C6's checks are replaced: the script reads the
> embedded pack's file table and requires it complete (every `.gd`, `.tres`, `.tscn` of `src`
> and `data`, and the main scene) and free of anything else; the run check reads stdout and
> stderr. The reviewer's prototype gave 0 missing on the good build, 21 on the one without
> floors, and showed `addons` and `tests` with no exclude filter. §3 rejects the first draft's
> checks by name. AC6 shows each check failing once; AC7 starts a real game in the exe.

### PR-6 🟡 Godot does not create `builds/windows/`  ·  C6
Exit 1, `The given export path doesn't exist`.
> **Planner reply (lead):** accepted (C6).

### PR-7 🟡 The run check writes into Lucas's real user folder  ·  C6
The exe's log goes to the folder his settings file is in.
> **Planner reply (lead):** accepted: `APPDATA` is a fresh temporary folder for that run
> (C6, AC9).

### PR-8 🟡 macOS and the run check; `python3` on this machine  ·  C9
A Windows exe cannot run on macOS. Here `python3` on PATH is the Microsoft Store stub.
> **Planner reply (lead):** accepted: the run check is skipped off Windows with a printed
> line; a Python counts only if it runs (C6, C9).

### PR-9 🔵 Smaller points
The preset's minimum (without the two filter keys Godot prints an `ERROR`; without the
options the pack is a separate file); `*.md`, `studio/*` and `tools/*` in the filter exclude
nothing; the zip must be deflated (38 MB, over a mail attachment's usual 25 MB); the README
should say to extract first and that a managed PC may have no "Run anyway"; the enemy's text
is shown from two lines; §2 was wrong about `Player`; the debug scenes with the argument are
half off; `const … :=` against the code style.
> **Planner reply (lead):** accepted, all: C5 is the file the reviewer exported with; C6
> (deflated); C7; §2; §1; C1.

**Checked and found sound:** the three readers of a debug action in `main.tscn`'s tree are all
there are; F5, P, K and I do nothing in `main.tscn`; `OS.is_debug_build()` is true for the
editor binary and the debug template and false for the release template; every autoload's
`_init()` runs before any `_ready()`, and a third autoload changes nothing for the first two;
no test lists autoloads or counts the root's children; C10 is achievable; the overlay must be
hidden, not removed (a test pins Main's two children); debug keys share no key with a game
action. Export: works with only the x86_64 templates, byte-identical across runs; the filter
removes only GUT, the tests and the eleven debug scenes; nothing leaks through
`project.binary` or the class and UID caches; excluding GUT breaks nothing; "selected scenes"
mode drops everything reached by `preload`; a headless export does not rewrite the preset;
the version is read from `project.godot`; a path with a space works.

**Not checked:** macOS; the preset as the editor's dialog would rewrite it; a windowed run of
the exe (AC7); SmartScreen and antivirus on another PC (on this one Defender is on and the exe
ran about fifteen times); whether a release export needs the debug template.

<!-- review-round: 2 verdict: APPROVE_WITH_NOTES -->

**Reviewed commit:** 23c8a72 · **Date:** 2026-11-21 · **Verdict:** APPROVE_WITH_NOTES ·
**By:** Auditor (lead, D-014)

The same two reviewers on the amended spec. Both: APPROVE_WITH_NOTES.

**Round 1 findings:** PR-1, PR-3 to PR-9 ✔ resolved; PR-2 partly (PR-10).

**Measured again on the export side:** with C5's exact text the export exits 0 with no `ERROR`
line and the same table of 405 files; the exe's run prints no `ERROR` on stdout or stderr.
Check (c) holds for all 201 files (a `.gd` is listed as `x.gd.remap` and `x.gdc`, a `.tres` or
`.tscn` as `<path>.remap`; `.uid` files are not in the table and are not asked for; nothing
under `src/` or `data/` is legitimately left out). Check (d) holds: the top level is exactly
`.godot`, `data`, `project.binary`, `scenes`, `src`.

### PR-10 🟡 AC5's script cannot name the autoload  ·  AC5
A `-s` script holding `DevTools.enabled` does not compile (`Identifier not found`); reading
`root.get_node("DevTools").enabled` works (true, and false with `-- --no-dev-tools`).
> **Planner reply (lead):** accepted (AC5).

### PR-11 🟡 AC2's "after a hit" does not reach the second place  ·  AC2, `src/entities/enemies/enemy.gd:283`
That line runs on a death, an arrival and a restore, not on a hit, and the every-frame line
overwrites it: a check after a frame passes with it ungated.
> **Planner reply (lead):** accepted: at once after a kill, before the next frame, in a room
> without reinforcements (AC2).

### PR-12 🟡 Two of AC6's five failures cannot be produced as written  ·  AC6
An empty exclude filter fails at check (a), not (d): with GUT included the export itself
prints `ERROR: Cannot set object script`. A `main.tscn` that names a missing script also
fails at (a), and the exe built from it prints nothing (the reference is dropped at export).
What works: a filter that lacks only `tests/*` (clean export, `tests` at the top level), and a
script whose `_ready()` loads a path that does not exist (clean export, complete table, the exe
prints two `ERROR` lines and exits 0).
> **Planner reply (lead):** accepted (AC6 d, e).

### PR-13 🔵 How to cut the trailer; the main scene's entry  ·  AC6 (b), C6 (d)
`binary_format/embed_pck=false` goes through the whole script and gives an exe without the
trailer. The entry under `scenes` is `main.tscn.remap`.
> **Planner reply (lead):** accepted (AC6 b, C6 d).

**Checked and found sound:** AC3 can be built with the helpers that exist (only "every bound
event" needs a new helper in the new test file); reading `DevTools.enabled` in scenes built
outside `main.tscn` works under GUT (the autoload is there and true); a static call through
the autoload compiles with the project's strict settings; AC6 (a) and (c) are producible as
written (exit 1 with Godot's own line; 20 files missing).

---

## 8. Implementation Log  ·  _Builder_

**Started:** 2026-11-21  ·  **Branch:** `feature/F-017-export`

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
| Q2 | Lead | → Lucas, at Gate B: two things stay in a build because they are the game's look today, not developer tools: the green ring around the player and every enemy (where a hit lands), and the boss bar's text ("warden  400 / 400  stage 1"). Hide either for other people? | no | |
| Q3 | Lead | → Lucas: the zip is about 38 MB, over the 25 MB many mail services allow. A drive link or a chat app will carry it. | no | |

---

## 11. Director Notes  ·  _Lucas_

