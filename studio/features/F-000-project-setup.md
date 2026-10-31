---
id: F-000
title: Project setup & architecture skeleton
status: PLAN_REVIEW      # DRAFT | PLAN_REVIEW | PLAN_CHANGES | APPROVED | IN_PROGRESS | CODE_REVIEW | CODE_CHANGES | DONE | PARKED
owner_now: Auditor       # who must act next: Planner | Auditor | Builder | Lucas
created: 2026-10-31
updated: 2026-10-31
depends_on: [D-001, D-002]
pillars: []              # infrastructure — enables all pillars
---

# F-000 — Project setup & architecture skeleton

> **How to use this file.** This is the single source of truth for this feature.
> Every agent reads the WHOLE file before acting. Write only in the sections you own
> (see studio/README.md). Never delete another role's text — reply under it.

---

## 1. Goal  ·  _Planner_

**Player-facing outcome (one sentence):**
None directly — after this, any agent can clone the repo, open it in Godot, run the game,
run tests and lint headless, and start F-001 without making structural decisions.

**Why now:** Every later feature depends on folder layout, config, input actions, tests
and the G6–G9 architecture rules. Deciding these once here stops the Builder from
inventing structure feature by feature.

**Out of scope (explicitly):**
- Any gameplay: no player character, movement, enemies, combat, tilemaps.
- Command layer implementation (G8) — only the empty `src/commands/` folder. The first
  real command arrives with player movement (F-001), where its shape can be designed
  against a real use case.
- Save/load system (G7) — phase 2.
- Any networking.
- Art style decisions beyond the base resolution placeholder.

---

## 2. Context  ·  _Planner_

- Repo is empty except the `studio/` kit, `CLAUDE.md`, `AGENTS.md`.
- Engine: Godot 4, GDScript (D-001). Architecture must stay online-ready (D-002, G6–G9).
- Folder layout and code style are already defined in `PROJECT.md` — implement exactly.
- Lucas works on macOS (zsh); agents may run on Linux. Everything must work on both.

---

## 3. Options Considered  ·  _Planner_

### Decision A — Test framework

#### ✅ Chosen: GUT (Godot Unit Test)
- **How it works:** Addon in `addons/gut/`; tests are GDScript files in `tests/`;
  runs from editor or headless CLI (`godot --headless -s addons/gut/gut_cmdln.gd`).
- **Why chosen:** Pure GDScript, long-established, simple API, headless CLI exit codes
  work for automated checks by agents.
- **Costs we're accepting:** Fewer features than gdUnit4 (e.g. less scene-runner tooling).
- **Would revisit if:** We need scene/input simulation tests that GUT can't do cleanly.

#### ❌ Rejected: gdUnit4
- **How it would work:** Addon with richer assertions, scene runner, C# support.
- **Why rejected:** More surface area than phase 1 needs; we don't use C#.
- **Tempting because:** Better scene-testing story — revisit with the "would revisit" signal above.

#### ❌ Rejected: No test framework yet
- **Why rejected:** G6 logic in `src/core/` is exactly what should be unit-tested, and
  agents need a pass/fail signal from day one.
- **Tempting because:** "Nothing to test yet" — but adding it later means untested core code.

### Decision B — Where tunables live

#### ✅ Chosen: Custom `Resource` (`GameTunables`) in `data/tunables/game_tunables.tres`, loaded by a `Tunables` autoload
- **How it works:** `class_name GameTunables extends Resource` with `@export` typed fields.
  Autoload `Tunables` loads the `.tres` at startup and exposes it as `Tunables.game`.
- **Why chosen:** Editable in the Godot inspector (Lucas tunes without code), typed,
  plain-text diff, same mechanism we'll use for G9 content.
- **Costs we're accepting:** One autoload. Tunables split into more resources later as it grows.
- **Would revisit if:** Live-reload while game is running becomes necessary.

#### ❌ Rejected: JSON/CFG config files
- **Why rejected:** Untyped, no inspector editing, parse-error risk, a second mechanism next to Resources.
- **Tempting because:** Familiar from web dev.

#### ❌ Rejected: `const` values in a script
- **Why rejected:** Breaks G2 — Lucas would have to edit code to tune feel.

### Decision C — Base resolution & scaling

#### ✅ Chosen: 640×360 base viewport, `canvas_items` stretch, `keep` aspect, integer scaling, nearest filtering
- **Why chosen:** 16:9, scales cleanly to 1280×720 / 1920×1080 / 2560×1440; enough room
  for top-down readability of boss telegraphs (pillar 2).
- **Costs we're accepting:** Placeholder — may change once art style is set (Q1).
- **Would revisit if:** Art from NoNe Class course work targets a smaller sprite scale.

#### ❌ Rejected: 320×180
- **Why rejected:** Very tight for top-down combat with multiple enemies + telegraphs.
- **Tempting because:** Classic chunky pixel look, less art per screen.

---

## 4. Constraints  ·  _Planner_

| ID | Constraint | Reason |
|---|---|---|
| C1 | No gameplay code or scenes in this feature | Scope (§1) |
| C2 | Nothing in `src/core/` may extend `Node2D`/`CanvasItem`/`Control` or reference `Sprite2D`, `AnimationPlayer`, `AnimatedSprite2D`, textures | G6 |
| C3 | `addons/` contains only GUT | G4 |
| C4 | All scripts statically typed; `gdlint` passes with zero errors | PROJECT.md code style |
| C5 | `godot --headless --quit` on the project exits with code 0 and no errors | Proves headless viability (D-002, phase 3–4) |
| C6 | Exact Godot version recorded in `README.md` and `PROJECT.md` | Reproducible for every agent |
| C7 | Tools scripts are POSIX shell (`#!/usr/bin/env bash`), work on macOS (BSD tools) and Linux (GNU tools) | Lucas on macOS, agents on Linux |

**Must not break:** existing `studio/`, `CLAUDE.md`, `AGENTS.md` — do not move or edit them
except updating `PROJECT.md` version (C6) and `STATUS.md`.

---

## 5. Acceptance Criteria  ·  _Planner_

- [ ] AC1: Fresh clone opens in Godot with zero errors and zero warnings in the Output panel.
- [ ] AC2: Folder structure matches `PROJECT.md` → Folder conventions (empty folders kept with `.gitkeep`).
- [ ] AC3: Running the project opens `scenes/main.tscn` at 640×360 base, integer-scaled, nearest filtering.
- [ ] AC4: A debug overlay shows FPS, Godot version, game version (`application/config/version`), and is toggled with F3.
- [ ] AC5: Given `data/tunables/game_tunables.tres` has `debug_overlay_visible_on_start = false`, when the game runs, then the overlay starts hidden — changed only in the inspector, no code edit.
- [ ] AC6: Input map defines `move_up`, `move_down`, `move_left`, `move_right`, `attack`, `dodge`, `interact`, `pause`, `debug_toggle`, each with keyboard **and** gamepad bindings (except `debug_toggle`, keyboard only).
- [ ] AC7: `tools/test` runs GUT headless; one sample test on a `src/core/` class passes; exit code 0. A deliberately failing test makes exit code non-zero.
- [ ] AC8: `tools/lint` runs `gdlint` + `gdformat --check` on `src/`, `tests/`, `tools/`; passes.
- [ ] AC9: `tools/check_core_purity` fails if any file in `src/core/` violates C2, passes otherwise.
- [ ] AC10: `godot --headless --quit` exits 0 (C5).
- [ ] AC11: Root `README.md` explains: Godot version, how to open, how to run tests/lint/purity check, link to `studio/README.md`.

**How to verify manually:** Clone, open in Godot, press F5 → window with overlay;
F3 hides/shows it. In the inspector set `debug_overlay_visible_on_start` to false, run
again → overlay hidden. Run `tools/test` and `tools/lint` → both green.

---

## 6. Task Breakdown  ·  _Planner_

| # | Task | Files likely touched | Notes |
|---|---|---|---|
| T1 | Init Godot project, `.gitignore` (`.godot/`, `*.import` cache rules per Godot 4 defaults), `.gitattributes` (LF line endings) | `project.godot`, `.gitignore`, `.gitattributes` | Pin version (C6) |
| T2 | Create folder structure with `.gitkeep` | all folders in PROJECT.md | AC2 |
| T3 | Display settings: 640×360, stretch `canvas_items`, aspect `keep`, integer scale, default texture filter nearest | `project.godot` | AC3 |
| T4 | Input map actions with keyboard + gamepad | `project.godot` | AC6; WASD + arrows, Space=dodge, J/LMB=attack, E=interact, Esc=pause, F3=debug |
| T5 | `GameTunables` resource + `.tres` + `Tunables` autoload | `src/core/game_tunables.gd`, `data/tunables/game_tunables.tres`, `src/autoload/tunables.gd` | AC5; start with `debug_overlay_visible_on_start: bool` only |
| T6 | `main.tscn` + debug overlay scene | `scenes/main.tscn`, `src/ui/debug_overlay.gd/.tscn` | AC4 |
| T7 | Add GUT, `tests/core/test_game_tunables.gd`, `tools/test` script | `addons/gut/`, `tests/`, `tools/` | AC7 |
| T8 | gdtoolkit config (`gdlintrc`), `tools/lint`, `tools/check_core_purity` | root, `tools/` | AC8, AC9; gdtoolkit is a dev tool via pip, not a game dependency |
| T9 | Root `README.md`, update `PROJECT.md` version, `STATUS.md` | docs | AC11, C6 |

---

## 7. Plan Review  ·  _Auditor_

**Verdict:** `PENDING` <!-- APPROVE | APPROVE_WITH_NOTES | CHANGES_REQUESTED -->
**Reviewed:** YYYY-MM-DD

---

## 8. Implementation Log  ·  _Builder_

**Started:** —  ·  **Branch:** `feature/F-000-project-setup`

### Progress
- [ ] T1
- [ ] T2
- [ ] T3
- [ ] T4
- [ ] T5
- [ ] T6
- [ ] T7
- [ ] T8
- [ ] T9

### Deviations from plan
### Assumptions made (small, reversible)
### Things the Auditor should look at closely
### How to test

---

## 9. Code Review  ·  _Auditor_

**Verdict:** `PENDING`
**Reviewed commit:** —  ·  **Round:** 1

---

## 10. Open Questions  ·  _Anyone (append)_

| # | Raised by | Question | Blocking? | Answer (Lucas/Planner) |
|---|---|---|---|---|
| Q1 | Planner | Final base resolution / sprite size depends on art style from the course. Keep 640×360 until then? | no | |

---

## 11. Director Notes  ·  _Lucas_

