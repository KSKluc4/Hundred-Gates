---
id: F-000
title: Project setup & architecture skeleton
status: DONE  # DRAFT | PLAN_REVIEW | PLAN_CHANGES | APPROVED | IN_PROGRESS | CODE_REVIEW | CODE_CHANGES | DONE | PARKED
owner_now: Lucas           # who must act next: Planner | Auditor | Builder | Lucas
created: 2026-10-31
updated: 2026-10-31
depends_on: [D-001, D-002]
pillars: []              # infrastructure — enables all pillars
department: Direction      # infrastructure
---

# F-000 — Project setup & architecture skeleton

> **How to use this file.** This is the single source of truth for this feature.
> Every agent reads the WHOLE file before acting. Write only in the sections you own
> (see studio/README.md). Never delete another role's text — reply under it.

---

## 1. Goal  ·  _Planner_

**Player-facing outcome (one sentence):**
None directly — after this, any agent can clone the repo, run one setup command, open it
in Godot, run the game, run tests and lint headless, and start F-001 without making
structural decisions.

**Why now:** Every later feature depends on folder layout, config, input actions, tests,
tooling and the G6–G9 architecture rules. Deciding these once here stops the Builder from
inventing structure feature by feature.

**Out of scope (explicitly):**
- Any gameplay: no player character, movement, enemies, combat, tilemaps.
- Command layer implementation (G8) — only the empty `src/commands/` folder. The first
  real command arrives with player movement (F-001), where its shape can be designed
  against a real use case.
- Save/load system (G7) — phase 2.
- Any networking.
- CI (GitHub Actions) — later feature; local scripts only here.
- Art style decisions beyond the base resolution placeholder.

---

## 2. Context  ·  _Planner_

- Repo contains only the `studio/` kit, `CLAUDE.md`, `AGENTS.md`, `.gitignore` (`.DS_Store`).
- Engine: Godot 4, GDScript (D-001). Architecture must stay online-ready (D-002, G6–G9).
- Third-party tooling: GUT (D-003) and gdtoolkit (D-004). Both PROPOSED — Lucas accepts
  them together with this plan at Gate A. Builder must not start before both are ACCEPTED.
- Folder layout and code style are defined in `PROJECT.md` — implement exactly.
- Lucas works on macOS (zsh); agents may run on Linux. Everything must work on both.

---

## 3. Options Considered  ·  _Planner_

### Decision A — Test framework

→ Moved to **D-003** (project-wide). Summary: GUT, vendored in `addons/gut/` at a pinned
release. Rejected: gdUnit4, no framework, git submodule for GUT. Read D-003 before T7.

### Decision B — Lint / format tooling

→ **D-004** (project-wide). Summary: gdtoolkit (`gdlint`, `gdformat`), pinned in
`requirements-dev.txt`, installed into a project-local `.venv` by `tools/setup`.

### Decision C — Where tunables live

#### ✅ Chosen: Custom `Resource` (`GameTunables`) in `data/tunables/game_tunables.tres`, loaded by a `Tunables` autoload
- **How it works:** `class_name GameTunables extends Resource` with `@export` typed fields.
  Autoload `Tunables` loads the `.tres` at startup and exposes it as `Tunables.game`.
- **Why chosen:** Editable in the Godot inspector (Lucas tunes without code), typed,
  plain-text diff, same mechanism we'll use for G9 content.
- **Costs we're accepting:** One autoload. Tunables split into more resources as it grows.
- **Would revisit if:** Live-reload while the game is running becomes necessary.

#### ❌ Rejected: JSON/CFG config files
- **Why rejected:** Untyped, no inspector editing, parse-error risk, a second mechanism
  next to Resources.
- **Tempting because:** Familiar from web dev.

#### ❌ Rejected: `const` values in a script
- **Why rejected:** Breaks G2 — Lucas would have to edit code to tune feel.
- **Tempting because:** Zero setup.

### Decision D — Base resolution & scaling

#### ✅ Chosen: 640×360 base viewport, `canvas_items` stretch, `keep` aspect, integer scaling, nearest filtering
- **Why chosen:** 16:9, scales cleanly to 1280×720 / 1920×1080 / 2560×1440; enough room
  for top-down readability of boss telegraphs (pillar 2).
- **Costs we're accepting:** Placeholder — may change once art style is set (Q1).
- **Would revisit if:** Art from the course targets a smaller sprite scale.

#### ❌ Rejected: 320×180
- **Why rejected:** Very tight for top-down combat with multiple enemies + telegraphs.
- **Tempting because:** Classic chunky pixel look, less art per screen.

### Decision E — How the core purity rule (G6) is enforced

#### ✅ Chosen: Allowlist on `extends` + forbidden-token scan, plus Auditor review
- **How it works:** `tools/check_core_purity` fails if any `.gd` file under `src/core/`
  (a) extends anything other than `RefCounted`, `Resource`, or a `class_name` declared in
  another `src/core/` file, or has no `extends` line; or (b) contains any forbidden token
  from C2.
- **Why chosen:** An allowlist catches new visual base classes we didn't think to list;
  the token scan catches scene-tree and asset access that `extends` alone can't see.
- **Costs we're accepting:** Text-based, so it can be fooled (e.g. string concatenation
  in a `load` path). It's a guard, not a proof — the Auditor still reviews core diffs.
- **Would revisit if:** False positives block legit core code, or a violation slips through.

#### ❌ Rejected: Denylist of visual base classes only (original plan)
- **Why rejected:** Misses `extends Node`, `get_tree()`, `$Child`, loading `.tscn`/textures —
  all of which tie logic to the scene tree and break headless server use (D-002).
- **Tempting because:** Shorter script, fewer false positives.

#### ❌ Rejected: Godot-side static analysis via a custom editor plugin
- **Why rejected:** Much more work; needs the editor running; overkill for phase 1.
- **Tempting because:** Would be exact instead of text-based.

---

## 4. Constraints  ·  _Planner_

| ID | Constraint | Reason |
|---|---|---|
| C1 | No gameplay code or scenes in this feature | Scope (§1) |
| C2 | Every `.gd` in `src/core/` extends only `RefCounted`, `Resource`, or another `src/core/` `class_name`. Forbidden tokens in `src/core/`: `Node2D`, `Node3D`, `CanvasItem`, `Control`, `Sprite2D`, `AnimatedSprite2D`, `AnimationPlayer`, `Texture`, `Texture2D`, `PackedScene`, `get_tree(`, `get_node(`, `$`, `.tscn`, `res://assets/`, `res://scenes/`, `extends Node` | G6, Decision E |
| C3 | `addons/` contains only GUT, at the release pinned in D-003 | G4, D-003 |
| C4 | All scripts statically typed; `gdlint` passes with zero errors; `gdformat --check` passes | PROJECT.md code style, D-004 |
| C5 | `godot --headless --quit` on the project exits with code 0 and no errors | Headless viability (D-002) |
| C6 | Exact Godot version recorded in `README.md` and `PROJECT.md`; GUT and gdtoolkit versions recorded in `README.md` | Reproducible for every agent |
| C7 | Tools scripts are POSIX shell (`#!/usr/bin/env bash`), work on macOS (BSD tools) and Linux (GNU tools) | Lucas on macOS, agents on Linux |
| C8 | Godot binary resolved in this order: `$GODOT_BIN` → `godot` on `PATH` → `/Applications/Godot.app/Contents/MacOS/Godot`; if none found, scripts exit non-zero with a message saying how to set `GODOT_BIN` | Same scripts on every machine |
| C9 | Dev tooling never ships with the game: `.venv/` gitignored; `requirements-dev.txt`, `tools/` excluded from export presets | D-004 |

**Must not break:** existing `studio/`, `CLAUDE.md`, `AGENTS.md`, `.gitignore` — extend
`.gitignore`, don't replace it. Only edit `PROJECT.md` (version, C6) and `STATUS.md`.

---

## 5. Acceptance Criteria  ·  _Planner_

- [ ] AC1: Fresh clone opens in Godot with zero errors and zero warnings in the Output panel.
- [ ] AC2: Folder structure matches `PROJECT.md` → Folder conventions (empty folders kept with `.gitkeep`).
- [ ] AC3: Running the project opens `scenes/main.tscn` at 640×360 base, integer-scaled, nearest filtering.
- [ ] AC4: A debug overlay shows FPS, Godot version, game version (`application/config/version`), and is toggled with `debug_toggle`.
- [ ] AC5: Given `data/tunables/game_tunables.tres` has `debug_overlay_visible_on_start = false`, when the game runs, then the overlay starts hidden — changed only in the inspector, no code edit.
- [ ] AC6: Input map defines exactly these actions and bindings (Godot standard joypad layout, Xbox names; stick deadzone 0.2):

  | Action | Keyboard / mouse | Gamepad |
  |---|---|---|
  | `move_up` | W, ↑ | Left stick up, D-pad up |
  | `move_down` | S, ↓ | Left stick down, D-pad down |
  | `move_left` | A, ← | Left stick left, D-pad left |
  | `move_right` | D, → | Left stick right, D-pad right |
  | `attack` | J, left mouse | X (`JOY_BUTTON_X`, left face) |
  | `dodge` | Space | A (`JOY_BUTTON_A`, bottom face) |
  | `interact` | E | Y (`JOY_BUTTON_Y`, top face) |
  | `pause` | Esc | Start (`JOY_BUTTON_START`) |
  | `debug_toggle` | F3 | — (keyboard only) |

- [ ] AC7: `tools/test` runs GUT headless; one sample test on a `src/core/` class passes; exit code 0. A deliberately failing test makes exit code non-zero.
- [ ] AC8: `tools/lint` runs `gdlint` + `gdformat --check` on `src/`, `tests/`; passes.
- [ ] AC9: `tools/check_core_purity` passes on the real `src/core/`. A fixture set in `tests/fixtures/core_purity/` (outside `src/`, ignored by Godot via `.gdignore`) contains one bad file per rule in C2 (non-allowlisted `extends`, missing `extends`, each forbidden token); `tools/check_core_purity --self-test` runs against every fixture and confirms each one fails, exit 0 only if all fail as expected.
- [ ] AC10: `godot --headless --quit` exits 0 (C5).
- [ ] AC11: Root `README.md` explains: required Godot version + where to get it, `GODOT_BIN`, `tools/setup`, how to run tests/lint/purity check, link to `studio/README.md`.
- [ ] AC12: On a machine with only Godot (correct version), Python 3 and git: `git clone` → `tools/setup` → `tools/test` → `tools/lint` → `tools/check_core_purity` all succeed with no other manual step. `tools/setup` is idempotent (second run succeeds, changes nothing).

**How to verify manually:** Clone, run `tools/setup`, open in Godot, press F5 → window
with overlay; F3 hides/shows it. In the inspector set `debug_overlay_visible_on_start` to
false, run again → overlay hidden. Run `tools/test`, `tools/lint`,
`tools/check_core_purity` and `tools/check_core_purity --self-test` → all green.

---

## 6. Task Breakdown  ·  _Planner_

| # | Task | Files likely touched | Notes |
|---|---|---|---|
| T0 | `tools/setup` + `tools/_godot.sh` (shared Godot resolution per C8) + `requirements-dev.txt` (gdtoolkit pinned, D-004); creates `.venv`, installs deps, checks Godot version matches pinned | `tools/`, root | AC12, C8, C9 |
| T1 | Init Godot project; extend `.gitignore` (`.godot/`, `.venv/`, Godot 4 defaults); `.gitattributes` (LF) | `project.godot`, `.gitignore`, `.gitattributes` | Pin version (C6) |
| T2 | Folder structure with `.gitkeep` | all folders in PROJECT.md | AC2 |
| T3 | Display settings | `project.godot` | AC3 |
| T4 | Input map exactly per AC6 table | `project.godot` | AC6 |
| T5 | `GameTunables` resource + `.tres` + `Tunables` autoload | `src/core/game_tunables.gd`, `data/tunables/game_tunables.tres`, `src/autoload/tunables.gd` | AC5; one field only: `debug_overlay_visible_on_start: bool` |
| T6 | `main.tscn` + debug overlay scene | `scenes/main.tscn`, `src/ui/debug_overlay.gd/.tscn` | AC4 |
| T7 | Vendor GUT at pinned release (D-003), `tests/core/test_game_tunables.gd`, `tools/test` | `addons/gut/`, `tests/`, `tools/` | AC7 |
| T8 | `gdlintrc`, `tools/lint`, `tools/check_core_purity` (+ `--self-test`), fixtures | root, `tools/`, `tests/fixtures/core_purity/` | AC8, AC9, Decision E |
| T9 | Root `README.md`, update `PROJECT.md` version, `STATUS.md` | docs | AC11, C6 |

---

## 7. Plan Review  ·  _Auditor_

**Verdict:** `APPROVE_WITH_NOTES`
**Reviewed:** 2026-10-31
**Round:** 2 · **Reviewed revision:** uncommitted Planner revisions in the working tree, based on `a8346a1c59db36e382a50a9636f9a28e363c4dfa`

**Current result:** PR-1–PR-4 are `✔ resolved` in the revised plan. One new
non-blocking note (PR-5) remains below. Lucas must accept D-003/D-004 at Gate A
before the Builder starts, as explicitly required by §2. See the latest Round 2
resolution table after the Planner replies; earlier review text is retained as history.

**Round 1 assessment (historical):**

The infrastructure goal is appropriately scoped: it enables all three pillars without
adding gameplay or prematurely implementing commands, persistence, or networking.
The alternatives have specific rejection reasons, and T1–T9 are reasonably ordered
and committable. Approval is blocked by the dependency authorization gap below.

### PR-1 — 🔴 Dependency additions lack the required project decisions — ✔ resolved (round 2)
- **Location:** §3 Decision A; §4 C3 and “Must not break”; §6 T7–T8;
  `PROJECT.md` G4; `CLAUDE.md` “You must never”.
- **Problem:** T7 adds GUT and T8 adds gdtoolkit, but `DECISIONS.md` contains only
  D-001 and D-002, neither authorizing these dependencies. G4 requires a D-### entry
  for every new third-party dependency, and the Builder instructions require Lucas's
  approval of that entry. Calling gdtoolkit a dev tool does not create an exemption.
  The plan also prohibits editing `DECISIONS.md` during implementation.
- **Why it matters:** The Builder cannot complete T7–T8 while obeying the project
  rules. Naming these tools in PROJECT.md or this feature does not satisfy the
  explicit D-### approval requirement.
- **Suggested fix:** Have the Planner prepare the dependency decision entries for
  Lucas's approval before implementation, then reference their IDs in this plan.
  Keep dependency authorization separate from the Builder's installation tasks.

### PR-2 — 🟡 Purity acceptance is weaker than the required core architecture — ✔ resolved (round 2)
- **Location:** §4 C2; §5 AC9; §6 T8; `PROJECT.md` Folder conventions.
- **Problem:** PROJECT.md limits `src/core/` to RefCounted/Resource logic, but C2
  only bans selected presentation classes and references. For example, a core
  script extending plain `Node` satisfies that blacklist while violating the
  folder convention. AC9 only requires checking C2.
- **Why it matters:** The advertised architecture check can pass code outside the
  architecture it is meant to protect, giving later features a misleading baseline.
- **Suggested fix:** Align C2 and AC9 with the RefCounted/Resource restriction,
  specify whether project-defined base classes must be followed, and define
  representative passing/failing fixtures and any intentionally unsupported cases.

### PR-3 — 🟡 Fresh-clone tooling has no reproducible installation contract — ✔ resolved (round 2)
- **Location:** §1 outcome; §4 C6; §5 AC7–AC8 and AC11; §6 T7–T9.
- **Problem:** Only Godot is required to have a recorded exact version. The plan
  does not require recording the GUT release/source or gdtoolkit version, and AC11
  documents how to run tools without requiring installation prerequisites or steps.
- **Why it matters:** A new agent cannot reliably reproduce the validated toolchain
  from the README, and different installations can produce different lint/test
  results despite using the same project commit.
- **Suggested fix:** Require the Builder to record a compatible GUT release/source
  and pin gdtoolkit in a dev dependency file. Extend AC11 to cover the supported
  Python prerequisite, isolated installation, and Godot executable discovery on
  macOS/Linux. Verify the documented setup from a fresh clone.

### PR-4 — 🟡 Gamepad bindings are required but unspecified — ✔ resolved (round 2)
- **Location:** §5 AC6; §6 T4.
- **Problem:** T4 names keyboard/mouse bindings but no gamepad buttons, movement
  axes or directions, D-pad policy, or analog deadzone. AC6 accepts any gamepad
  binding for each action, including mappings that would be impractical to use.
- **Why it matters:** The Builder must invent the controller scheme, and review has
  no agreed mapping against which to verify it before F-001 consumes these actions.
- **Suggested fix:** Add a per-action controller mapping and movement deadzone, or
  explicitly authorize a documented provisional mapping as a reversible assumption
  and require it to be listed in the README for manual verification.

### Earlier Round 2 check — superseded by the revised checkout below

Historical record: the following check preceded the arrival of the Planner's
working-tree revisions and replies. Its findings/status table is not the current verdict.

Checked §7 for Planner replies first, then re-read the full feature, PROJECT.md,
and DECISIONS.md. No Planner replies are present in this checkout. The working
tree was clean before this review. Although commit `a8346a1` is titled
“F-000: Planner revisions round 1, add D-003/D-004”, its actual changes contain
the first audit and board update; it does not add Planner revisions or decisions.

| Finding | Planner reply | Resolution evidence | Round 2 status |
|---|---|---|---|
| PR-1 🔴 | Not present | DECISIONS.md still contains only D-001 and D-002; T7–T8 and the §4 edit restriction are unchanged. | Open — blocking |
| PR-2 🟡 | Not present | C2 still uses the presentation blacklist; AC9 still checks only C2. | Open |
| PR-3 🟡 | Not present | No GUT/gdtoolkit version or installation requirement was added to T7–T9 or AC11. | Open |
| PR-4 🟡 | Not present | AC6 and T4 still require gamepad support without specifying the mapping or delegating a documented provisional choice. | Open |

**Earlier checkout verdict:** `CHANGES_REQUESTED`. No previous finding can be marked
`✔ resolved` on the available evidence. No new findings added. Keep
`status: PLAN_CHANGES`, `owner_now: Planner`; the revised plan, inline replies,
and dependency decisions need to be saved in the repository for re-audit.

### Planner replies — round 1 (2026-10-31)

> **Planner reply — 🔴 GUT and gdtoolkit need approved D-### entries:** Accepted.
> Added D-003 (GUT, vendored at a pinned release) and D-004 (gdtoolkit in a project
> `.venv`) to `DECISIONS.md` as PROPOSED. §2 now states the Builder can't start until
> Lucas marks both ACCEPTED at Gate A. C3, C4 and C9 reference them.

> **Planner reply — 🟡 Purity check doesn't cover the full constraint:** Accepted.
> New §3 Decision E: allowlist on `extends` (RefCounted / Resource / other core classes)
> plus a forbidden-token scan covering scene-tree access, `$`, scene and asset paths.
> C2 rewritten with the full list. AC9 now requires fixture files proving every rule
> trips. §3 states plainly it's a guard, not a proof — core diffs still need Auditor eyes.

> **Planner reply — 🟡 No reproducible tool install:** Accepted. New T0 `tools/setup`
> (creates `.venv`, installs pinned gdtoolkit, verifies Godot version), C8 Godot binary
> resolution order (`$GODOT_BIN` → PATH → macOS app path), C9 dev tooling never exported,
> new AC12 (clean clone → setup → all checks green, setup idempotent).

> **Planner reply — 🟡 Gamepad bindings undefined:** Accepted. AC6 now has the full
> keyboard + gamepad table (Xbox layout names, Godot `JOY_BUTTON_*` constants, deadzone 0.2).

### Round 2 — Resolution check on the Planner's revised working tree

Read the Planner replies first and checked each against the complete revised plan,
PROJECT.md, and DECISIONS.md. The previously missing revisions are now present as
uncommitted changes; the earlier checkout assessment above is superseded.

| Finding | Reply checked against | Current status |
|---|---|---|
| PR-1 | D-003/D-004 now define both dependencies; §2 explicitly prevents implementation until Lucas marks both ACCEPTED at Gate A. The Builder no longer needs to create or approve those entries. | ✔ resolved — dependency approval remains Lucas's Gate A action |
| PR-2 | Decision E and C2 now allow only RefCounted/Resource or another core class, require an explicit base, and scan the listed scene/presentation tokens. AC9/T8 add negative fixtures and a self-test. The text scan's limits and continued manual review are explicit. | ✔ resolved |
| PR-3 | D-003 vendors GUT at a recorded compatible release; D-004 pins gdtoolkit in requirements-dev.txt and uses a project .venv. T0 adds setup/version validation, C8 defines Godot discovery, and AC11/AC12 require documented setup, a clean-clone workflow, and idempotence. | ✔ resolved |
| PR-4 | AC6 now specifies each keyboard/mouse and controller binding, left-stick and D-pad movement, and deadzone 0.2; T4 implements that table. | ✔ resolved |

The infrastructure goal, explicit scope exclusions, alternatives, and deferred
command/save/networking implementations remain consistent with D-001/D-002 and
the project pillars. AC1–AC12 provide observable results, including tool failure
behavior and fresh-clone setup. T0–T9 are reasonably sized; actual tool compatibility
and startup behavior remain implementation checks, not evidence already obtained.

### PR-5 — 🟡 GUT release pin has inconsistent documentation locations
- **Location:** §4 C3/C6 and “Must not break”; §6 T7; D-003 “Chosen”.
- **Problem:** C3 requires GUT at the release “pinned in D-003”, but D-003 contains
  no exact release and instead says to record the version in README.md. T7 requires
  a pinned release, while the §4 edit restriction prevents the Builder from adding
  that pin to DECISIONS.md.
- **Why it matters:** The Builder has conflicting instructions about the authoritative
  pin location; satisfying C3 literally would require a protected-document edit.
- **Suggested fix:** Make C3 point to the exact release recorded in README.md and
  vendored by T7, retaining D-003 as dependency authorization. Alternatively, have
  the Planner put the exact compatible release into D-003 before Gate A.

**Current Round 2 verdict:** `APPROVE_WITH_NOTES`. No blocking findings remain in
the plan. Keep `status: PLAN_REVIEW`, set `owner_now: Lucas`; only Lucas may approve
the feature and accept D-003/D-004 at Gate A.


---

## 8. Implementation Log  ·  _Builder_

**Started:** 2026-10-31  ·  **Branch:** `feature/F-000-project-setup`

### Progress
- [x] T0 — afd0879
- [x] T1 — 8fd1edd
- [x] T2 — 3553899
- [x] T3 — 015cb5d
- [x] T4 — 5e9653d
- [x] T5 — b31d884
- [x] T6 — ca7214e, 9803de2
- [x] T7 — d51a853, e34c071
- [x] T8 — dbc6535
- [x] T9 — e3b0054

### Deviations from plan
- **DEV-1:** `DebugOverlay._unhandled_input` (toggle half of AC4) was first left as a `TODO(Lucas)`
  stub in ca7214e under Lucas's learning-mode rule. Lucas then said "modo rápido" and the Builder
  implemented it in 9803de2. Impact: none now.
- **DEV-2:** More tests than T7's "one sample test": `tests/test_input_map.gd` (AC6, exact table)
  and `tests/ui/test_debug_overlay.gd` (AC4, AC5). Reason: those ACs had no automated proof.
  Impact: none on scope; test code only.
- **DEV-3:** `tests/fixtures/core_purity/good/` added next to the AC9 bad fixtures, and `--self-test`
  also requires exactly one violation per bad fixture and all 19 C2 rules tripped. Reason: "every
  fixture fails" alone is satisfied by a checker that rejects everything, or by a fixture failing
  for the wrong rule. Impact: adding a C2 token now requires adding its fixture.
- **DEV-4:** `tools/test` also fails if GUT logs `Ignoring script`. Reason: found while proving AC7:
  a test script with a parse or compile error was skipped and GUT still exited 0. Impact: the check
  matches GUT's log text, so re-verify it when updating GUT.

- **DEV-5:** Added a "Do it yourself — no TODOs for Lucas" section to `CLAUDE.md`, although §4 lists
  that file under "Must not break". Reason: Lucas's direct instruction (2026-10-31). Lucas provided
  the final text, which replaced the Builder's first draft from 694f130. Applied to this repo's
  `CLAUDE.md` only, so `AGENTS.md`, `~/CLAUDE.md` and `~/.claude/CLAUDE.md` are unchanged. Impact:
  Builder process only, no game code.

### Assumptions made (small, reversible)
- **ASSUMPTION-1:** `config/version="0.1.0"`; the plan names no starting version.
- **ASSUMPTION-2:** `window_width/height_override` 1280x720. A 640x360 window is tiny on a desktop,
  and 2x shows the integer scaling. Base viewport stays 640x360 (Decision D).
- **ASSUMPTION-3:** All keys bound by `physical_keycode`, so WASD keeps its position on any layout.
- **ASSUMPTION-4:** Forward Plus renderer (Godot's default); the plan doesn't choose one.
- **ASSUMPTION-5:** `gdscript/warnings/untyped_declaration=2` (error) enforces C4's static typing.
  Addons are excluded by Godot's default setting.
- **ASSUMPTION-6:** C2 tokens: identifier-like ones match as whole words (the list naming both
  `Sprite2D` and `AnimatedSprite2D` implies this, and it keeps `PlayerController` legal); the rest
  match literally. Comments are not stripped, so a forbidden token in a comment trips the check.
- **ASSUMPTION-7:** C8: `$GODOT_BIN` set to a bad path is an error, no fallback. Otherwise a typo
  would silently pick another Godot.
- **ASSUMPTION-8:** C9: no export preset exists yet (no task creates one). `tools/.gdignore` hides
  `tools/` from Godot, `.venv/` is a hidden gitignored folder, and `requirements-dev.txt` is not a
  Godot resource. The first export feature must still check its preset excludes them.
- **ASSUMPTION-9:** GUT's editor plugin is not enabled; D-003 only needs headless runs.
- **ASSUMPTION-10:** `debug_toggle` reads input directly: it's a dev tool, not a player action (G8).
- **ASSUMPTION-11:** Script default of `debug_overlay_visible_on_start` is `false`, `.tres` value is
  `true`. Godot only writes non-default values, so the line stays visible in the `.tres`, and a
  lost value hides the overlay rather than showing it.

### Things the Auditor should look at closely
- **C5/AC10 on a clone with no `.godot/`:** `godot --headless --quit` before `tools/setup` exits 0
  but prints `Could not find type "GameTunables"`, because the `class_name` cache doesn't exist yet.
  After `tools/setup` it is clean. Opening the editor on such a clone is clean too (headless editor:
  0 errors, 0 warnings). I read AC10 as running after setup (AC12 order). Say so if you read it differently.
- **Not tested:** Linux (C7): scripts stick to `sed -E`, `grep -E/-F`, `find`, and run on macOS bash
  3.2. Real gamepad: bindings are checked against the AC6 table only. The editor's GUI Output panel:
  checked via `--headless --editor`.
- **gdtoolkit 4.5.0 vs Godot 4.7:** it's the latest gdtoolkit, and parses all code here. Only
  `gdtoolkit` is pinned, as D-004 says; its transitive deps are not.
- **No TDD order for T5/T6:** the spec puts GUT at T7, so their tests came after the code. Each was
  shown to catch a break by mutation: F3 rebound, and overlay ignoring the tunable.
- `tools/test` re-runs `--import` each time so new `class_name`s resolve; this adds a little startup.

### How to test
```sh
tools/setup && tools/setup                  # idempotent; git status stays clean
tools/test                                  # expect 10/10, exit 0
tools/lint                                  # expect exit 0
tools/check_core_purity                     # expect "core purity ok"
tools/check_core_purity --self-test         # expect 19 rules tripped
godot --headless --path . --quit            # expect exit 0, no errors
```

AC7 negative: add a `tests/test_x.gd` with `assert_true(false)` and run `tools/test` (exit 1); then
give it a syntax error (exit 1). Manual: F5 shows the overlay at 2x, F3 hides/shows it; set
`debug_overlay_visible_on_start` to false in the inspector, run again, overlay starts hidden.

---

## 9. Code Review  ·  _Auditor_

**Verdict:** `APPROVE`
**Reviewed commit:** `a69020f0d3c4e1c8e3a866a6775b52c6d4baee65` · **Round:** 1
**Reviewed:** 2026-10-31 · **Comparison:** `main...feature/F-000-project-setup`

**Findings:** None. No code changes requested.

### Acceptance criteria evidence

✅ below means the implementation is supported by code inspection and the stated
automated checks. It does not claim a visual playtest or physical-controller test.

| AC | Result | Evidence |
|---|---|---|
| AC1 | ✅ | A clean tracked-files archive, without `.godot/` or `.venv/`, completed `tools/setup` and its headless editor import (`tools/setup:32`) without errors/warnings. `tests/fixtures/core_purity/.gdignore` prevents the deliberately invalid fixtures from being imported. The GUI Output panel was not observed. |
| AC2 | ✅ | Tracked directories and `.gitkeep` files match PROJECT.md: core/commands/entities/world/ui/autoload, data subdirectories, assets, scenes/debug, tests, tools, and addons/gut. |
| AC3 | ✅ | `project.godot:15` selects `scenes/main.tscn`; display settings at lines 29–35 set 640×360, 1280×720 window override, canvas_items/keep/integer; line 103 selects nearest filtering. `scenes/main.tscn:7` instances the overlay. Window scaling was inspected in configuration, not visually exercised. |
| AC4 | ✅ | `src/ui/debug_overlay.gd:15` updates FPS and both versions, and line 20 handles `debug_toggle`. `tests/ui/test_debug_overlay.gd:24` checks the displayed fields; lines 33–44 check press/release behavior and toggling both ways. AC6 tests verify F3 is bound to the action. All five overlay tests pass. |
| AC5 | ✅ | `src/core/game_tunables.gd:5` exports the typed field; `data/tunables/game_tunables.tres:7` supplies its startup value; `src/autoload/tunables.gd:6` loads that Resource; `src/ui/debug_overlay.gd:12` reads it. The tests at `tests/ui/test_debug_overlay.gd:16` and line 20 pass for false and true. Inspector interaction itself was not exercised. |
| AC6 | ✅ | `project.godot` defines the exact nine custom actions and the specified keyboard/mouse, stick, D-pad, and face/start bindings. All three `tests/test_input_map.gd` tests pass, including exact bindings and deadzone 0.2. |
| AC7 | ✅ | GUT 9.7.1 is vendored; `tools/test:15` runs it headless with pipefail; `tests/core/test_game_tunables.gd` supplies two passing core tests. The full suite passes 10/10 (29 assertions). In the temporary copy, a deliberately failing assertion returned 1; a separate syntax-error case also returned 1 via the DEV-4 safeguard. |
| AC8 | ✅ | `tools/lint:14` runs the project-local gdlint and line 15 runs gdformat --check on src/tests. Executed successfully: zero lint problems; 28 files already formatted. |
| AC9 | ✅ | `tools/check_core_purity:26` collects allowed core class names; lines 39–68 check bases and all C2 tokens. The real core passes. `--self-test` passes: all 19 rules are tripped independently and the good fixtures pass. |
| AC10 | ✅ | After setup, `godot --headless --path . --quit` exits 0 without errors, both in the checkout and the clean temporary copy. This follows the setup-first workflow in §1/AC12. |
| AC11 | ✅ | `README.md:9` records versions/download location; lines 17–29 document Godot discovery; lines 31–46 cover setup/open/run; lines 48–59 cover checks. Lines 4–5 link the studio/project documentation. |
| AC12 | ✅ | A clean archive of the reviewed commit completed setup twice, then test/lint/purity/self-test/headless startup, all with exit 0. gdtoolkit 4.5.0 was installed into the new .venv; GUT was already vendored. Repeating setup in the branch also left the tracked working tree clean. |

### Rejected options, constraints, deviations, and assumptions

- **Rejected options:** None reintroduced. Tunables remain an exported Resource;
  there is no JSON/CFG tunable system, script-constant tunable replacement, alternative
  test framework, GUT submodule, visual-base-only purity checker, or editor analysis plugin.
- **Constraints:** C1–C8 are supported by the implementation and checks above. C3's
  version-source ambiguity is settled by Lucas's §11 note: README.md and GUT's
  plugin.cfg both say 9.7.1. C4 applies to authored GDScript, with vendor/negative
  fixtures excluded from Godot's typing enforcement. C7 was exercised on macOS
  bash 3.2; Linux was not run. For C9, no export preset or exported game exists in
  this feature: `.venv/` is hidden/gitignored, tools/ has `.gdignore`, and the
  requirements file is not a Godot resource. Actual export exclusions remain to be
  verified when an export preset is introduced, as explicitly logged in ASSUMPTION-8.
- **Global constraints:** No game simulation/state/commands/content are introduced
  outside the allowed skeleton, so G1/G7/G8/G9 add no missing gameplay obligation.
  The core is a Resource with no presentation dependency (G6); tunables are data
  (G2), the resource path is centralized (G5), tests/overlay support isolation (G3),
  and D-003/D-004 are ACCEPTED (G4). The debug overlay is presentation/dev tooling.
- **DEV-1–DEV-5:** All justified and reflected in the diff. The toggle stub is gone;
  the added input/overlay tests cover ACs; positive fixtures strengthen the purity
  self-test; the skipped-script safeguard was reproduced; and DEV-5 records Lucas's
  authorization for the CLAUDE.md exception, including the final Director text in
  a69020f. No undocumented implementation deviation found.
- **ASSUMPTION-1–ASSUMPTION-11:** Reasonable and reversible for this skeleton.
  Version/window/renderer/key-layout choices are settings; the warning/token rules
  are local tooling; invalid GODOT_BIN fails clearly; headless GUT does not require
  enabling its editor plugin; debug input is not a player command; and the Resource
  default plus explicit .tres value preserve the intended startup behavior.

### Verification limits

Godot initially emitted sandbox-related Library/log/certificate errors; the relevant
commands were rerun outside the sandbox and completed cleanly. Those environmental
errors are not findings against the branch. Negative-test fixtures were confined to
the temporary review copy and removed afterward; no branch source/test files changed.

The clean-copy import and runtime checks were headless. The §5 visual playtest
(GUI Output, window appearance/scaling, real F3/inspector interaction), physical
gamepad behavior, Linux execution, and an actual export were not performed.
The pre-setup missing-class-cache behavior disclosed in §8 is not treated as a failure
of the documented setup-first workflow. Lucas retains the manual playtest and Gate B;
this review does not set DONE.

---

## 10. Open Questions  ·  _Anyone (append)_

| # | Raised by | Question | Blocking? | Answer (Lucas/Planner) |
|---|---|---|---|---|
| Q1 | Planner | Final base resolution / sprite size depends on art style from the course. Keep 640×360 until then? | no | |

---

## 11. Director Notes  ·  _Lucas_

- **2026-10-31 (PR-5):** Exact GUT version has one source of truth: root `README.md` (it also lives in `addons/gut/plugin.cfg`). D-003 stays version-agnostic. D-003 and D-004 ACCEPTED. F-000 APPROVED.
