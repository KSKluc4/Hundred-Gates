---
id: F-001
title: Warrior movement + dash
status: CODE_REVIEW       # DRAFT | PLAN_REVIEW | PLAN_CHANGES | APPROVED | IN_PROGRESS | CODE_REVIEW | CODE_CHANGES | DONE | PARKED
owner_now: Lucas           # who must act next: Planner | Auditor | Builder | Lucas
created: 2026-10-31
updated: 2026-10-31
depends_on: [F-000, D-001, D-002, D-005]
pillars: [2]
department: Combat
---

# F-001 — Warrior movement + dash

> **How to use this file.** This is the single source of truth for this feature.
> Every agent reads the WHOLE file before acting. Write only in the sections you own
> (see studio/README.md). Never delete another role's text — reply under it.

---

## 1. Goal  ·  _Planner_

**Player-facing outcome (one sentence):**
In a test room, the player moves the Warrior in 8 directions with near-instant response,
aims a facing direction with mouse or right stick, and dashes with a short invulnerable
start — and it feels sharp enough that dodging is fun on its own.

**Why now:** Combat principle 3: *"Dodge is the core defensive verb. It must feel
responsive before anything else exists."* Attacks, enemies and bosses are all tuned
against how fast the player moves and dodges, so this comes first. It is also the first
real use of the core / command / data architecture (G6, G8, G9), so it sets the pattern
every later feature copies.

**Out of scope (explicitly):**
- Attacks, the sword chain, hitboxes/hurtboxes, damage, HP, death (next features).
- Hitstop and screen shake (arrive with the hit/hurt feature).
- Enemies, bosses, floors, town hub.
- Final art, animation, VFX, sound. Placeholder shapes only.
- Camera polish (smoothing, lookahead, shake). A plain follow camera is enough.
- Input rebinding UI, settings menu.
- Other classes. Only the Warrior exists; but class data must not assume it is the only one (D-005).
- What happens when dashing into enemies (pass through or block) — decided with enemies.

---

## 2. Context  ·  _Planner_

What the Builder needs to know that isn't obvious from the code:
- **Source of truth:** `studio/design/combat.md` → sections *Player → Movement*,
  *Player → Dash*, *Answered questions* CQ2–CQ4, *Rejected*, *Tunables index*.
- **Existing systems this touches (checked against `main` by Direction):** F-000 tooling
  (GUT, gdtoolkit, `tools/test`, `tools/lint`, core purity check).
  - **Commands:** `src/commands/` is empty — no base class exists. T4 creates a minimal
    `Command` base (`src/commands/command.gd`, `extends RefCounted`, no logic).
  - **Tunables:** F-000's `Tunables` autoload (`src/autoload/tunables.gd`) exposes
    `Tunables.game`. Add `Tunables.player_combat` there (path constant + preload, same
    pattern). Do **not** create a second autoload.
  - **Class data:** `Player` has `@export var class_data: ClassData`, defaulting to
    `data/classes/warrior.tres` via a path constant. Another class later = assign a
    different resource, no code change (D-005).
  - The core motor **never** reads the autoload: the glue passes both resources in.
  - **Input map:** F-000 already defines `move_up/down/left/right` (keys + left stick +
    D-pad) and `dodge` (Space + A). **Reuse them.** The dash is the `dodge` action (it is
    the same verb; see GLOSSARY "Dash"). The **only** new action is
    `debug_reload_tunables` (F5). No `aim_*` actions: stick magnitudes are read as raw
    axes and filtered once, by the input contract in §4 C14 (PR-5).
- **Relevant prior decisions:**
  - D-001 — Godot 4.7.2, GDScript, static typing.
  - D-002 — offline now, online-ready architecture (G6–G9 apply in full).
  - D-005 — one fixed class per character, classes are data in `data/classes/`.
    Anything a future class could do differently lives in the class resource; rules
    shared by every class live in `data/tunables/player_combat.tres`.
- **Units:** design values are in **tiles** and **seconds**. 1 tile = 16 px for now
  (pending Art & Game Feel, CX1). Convert in exactly one place.
- **Tick:** logic runs in `_physics_process` at Godot's default 60 ticks/s, always
  using `delta` (G1). Nothing may assume 60.
- **Relevant prior features:** F-000 (setup/tooling).

---

## 3. Options Considered  ·  _Planner_

> This section is what stops context loss. Be honest about trade-offs.
> The Builder MUST NOT implement anything listed under Rejected.

### ✅ Chosen: Pure-logic motor in core + thin physics body as glue
- **How it works:**
  - `PlayerMotor` (`RefCounted`, `src/core/`) owns the movement/dash state machine,
    timers, facing, input buffer and the **desired velocity**. It never touches nodes,
    `Input`, sprites or physics.
  - An input reader in `src/entities/player/` turns device input into **commands**
    (`MoveCommand`, `AimCommand`, `DashCommand`) each tick. The motor only ever receives
    commands (G8).
  - `Player` (`CharacterBody2D`) is glue. Exact per-tick order is §4 C15. In short:
    commands → `motor.tick(delta)` → body velocity = motor's tick displacement / delta →
    `move_and_slide()` → `motor.sync_position(body position)`.
  - `PlayerInput` splits into a pure, testable mapper (`PlayerInputMapper`, takes an
    `InputSample` of raw values, returns commands) and a thin node that fills the sample
    from Godot's `Input`/events. Device rules: §4 C16.
  - Godot physics handles wall collision.
- **Why chosen:** Satisfies G6 (logic separate from presentation), G7 (motor state is
  plain data), G8 (input → commands) with very little code. Physics stays in the engine
  instead of being reinvented. A headless Godot server can run the same scene later.
- **Costs we're accepting:** Position is split across two places (body moves, motor
  stores). Wall collision depends on Godot physics, so the core motor alone can't
  predict collisions.
- **Would revisit if:** Phase 3/4 needs server-authoritative movement with prediction or
  rollback, and Godot physics turns out not to be deterministic enough.

### ❌ Rejected: All movement logic inside the `CharacterBody2D` script
- **How it would work:** `player.gd` reads `Input` directly in `_physics_process`, sets
  velocity, handles dash timers itself.
- **Why rejected:** Breaks G6 and G8. Logic can't be unit-tested without a scene, and input
  can't later be replaced by network commands without a rewrite (exactly what D-002 forbids).
- **Tempting because:** It's how almost every Godot tutorial does it, and it's about a
  third of the code.

### ❌ Rejected: Custom collision inside the core motor
- **How it would work:** The motor resolves wall collision itself against a pure-data
  map representation.
- **Why rejected:** Rebuilds what Godot physics already does, for a benefit (fully
  engine-free logic) we only might need in phase 4.
- **Tempting because:** It makes the core 100% engine-independent, which looks like the
  "purest" reading of G6.

### ❌ Rejected: Dash as an impulse that decays with friction
- **How it would work:** On dash, add a big velocity burst that friction slowly eats.
- **Why rejected:** Travel distance then depends on friction, tick rate and remaining
  speed. Lucas can't tune "3 tiles in 0.15 s" directly, and the i-frame window no longer
  maps cleanly to a distance. That makes the dodge less readable (pillar 2).
- **Tempting because:** It feels "physical", and it's one line.

### ❌ Rejected (from design/combat.md — do not implement)
- **Rolling dodge**, **dash without i-frames**, **i-frames for the whole dash**,
  **stamina for dodge**, **auto-aim**, **aim = movement direction only**.
  Reasons are in `studio/design/combat.md → Rejected`.

---

## 4. Constraints  ·  _Planner_

Hard rules for this feature. Violating any of these = automatic `CODE_CHANGES`.

| ID | Constraint | Reason |
|---|---|---|
| C1 | All timing and movement use `delta` and tick in `_physics_process`. Same inputs give the same result within the §5 tolerances at 30, 60 and 120 ticks/s. | G1 |
| C2 | No movement/dash number in code. Every value comes from `data/classes/warrior.tres` or `data/tunables/player_combat.tres`. Fixed rules (e.g. "i-frames start at dash start") are behavior, not numbers. Validation bounds in C17 are rules, not tunables. | G2, D-005 |
| C3 | `src/core/` scripts extend only `RefCounted` or `Resource`. They never call `Input`, never reference `Node`, sprites, animation or the scene tree. The core purity check from F-000 passes. | G6 |
| C4 | **Player intentions** (move, aim, dash) reach the motor **only** via `submit(command)`. The motor's complete public mutating API is exactly: `submit()`, `tick()`, `setup()`, `apply_data()`, `sync_position()`, `from_dict()` — each with the effects listed in C18 and nothing else. Input handlers only ever call `submit()`. | G8 (PR-1) |
| C5 | Snapshot boundary: `to_dict()` / `from_dict()` are only valid **between ticks with no pending commands** (after `tick()` returns, before the next `submit()`). The snapshot contains: position, velocity, facing, motor state, dash direction, dash elapsed, latched dash params (C17), cooldown remaining, buffered dash flag + age, invulnerability flag. Round-trip loses nothing. Commands are per-tick and never retained, so no intention is stored. | G7 (PR-1) |
| C6 | No global or static mutable state in the motor, mapper or glue. Two players in the same scene are fully independent. | D-002 (co-op) |
| C7 | Values are stored in tiles and seconds. Tile → pixel conversion happens in one place (`Units.TILE_SIZE_PX`). | CX1 pending |
| C8 | **I-frames are an exact time interval** `I = [fire_time, fire_time + dash_iframe_duration)` on the motor clock (C15), using the latched duration. The tail of the dash after `I` ends is **vulnerable**. `is_invulnerable()` after a tick is true **iff `I` overlaps that tick's interval `[tick_start, tick_end)`** — so the tick a dash fires in always reports true, even for sub-tick windows, and a tick that only contains the tail reports false. `get_iframe_window()` returns `I` (motor-clock seconds, or empty) for exact checks by the future hit system. `invulnerability_changed` fires when the tick-end value changes. No validation bound depends on the tick rate. | CQ3 (PR-9) |
| C9 | Dash cooldown starts **when the dash ends**, not when it starts. | design/combat.md |
| C10 | During a dash, move input is ignored and the dash direction is fixed at fire time. Facing still updates. | design/combat.md |
| C11 | No new addons or dependencies. | G4 |
| C12 | F-000 input actions keep their names, bindings and deadzones. No `dash` action — the dash uses `dodge`. Only new action: `debug_reload_tunables` (F5). | F-000 must-not-break |
| C13 | Hot-reload swaps data without resetting motor state (rules in C17). | AC16 |
| C14 | **Stick contract (move and aim, one formula):** read the raw stick vector `r` (axes, clamped to length 1). `dz` = `PlayerCombatTunables.stick_deadzone`, radial. If `|r| <= dz` → zero. Else magnitude `m = (|r| − dz) / (1 − dz)`, direction `r / |r|`. Example: raw 0.5, dz 0.2 → 0.375. Digital (keys, D-pad): components ±1, normalized to length 1. Move = stick if its `m > 0`, else digital. The resource `dz` is the **only** runtime filter on stick magnitudes; the reader never uses action strengths for sticks, so nothing is filtered twice. A reloaded `dz` applies from the next tick. | PR-5 |
| C15 | **Tick timeline** (one physics tick, `delta`). The motor keeps a clock `time` (seconds since `setup()`, in the snapshot). (1) The input node builds an `InputSample`; the mapper submits this tick's `MoveCommand` + `AimCommand` (always) and `DashCommand` (only on the tick `dodge` was pressed). Commands apply for the whole tick. (2) `motor.tick(delta)`: a. facing from this tick's aim/move (C16); b. a `DashCommand` sets the buffer with press time = tick start (replacing any older one); c. **phase loop — consume `delta` in segments, never rounding to tick boundaries:** set `remaining = delta`; repeat while `remaining > 0`: if not dashing and a buffered dash is **eligible now** (cooldown remaining ≤ 0 and `time − press_time ≤ input_buffer_window`, inclusive) → **fire at this exact instant**: latch dash params, direction = this tick's move input else facing, start `I` (C8), clear buffer; if dashing → advance by `s = min(remaining, dash time left)` at speed `dash_distance / dash_duration`; if the dash ends inside the segment, velocity becomes 0 and cooldown starts with the full `dash_cooldown` at that instant; if not dashing → advance by `s = min(remaining, cooldown remaining if > 0 and a buffer is waiting, else remaining)` with normal movement (step d) and cooldown decreasing by `s`; then `time += s`, `remaining −= s`. A dash and its whole cooldown may start and end inside one tick. d. **Normal movement is integrated exactly**, not with Euler steps: velocity moves linearly toward `move_speed × m × dir` with constant acceleration `move_speed / accel_time` (or `/ decel_time` when slowing; time 0 = instant), and displacement over a segment is the exact integral (`v0·s + ½·a·s²` until the target is reached, then constant). e. a buffer whose age exceeds `input_buffer_window` at the end of the tick is dropped. f. the sum of all segment displacements is the tick displacement. (3) Glue sets `velocity = tick_displacement_px / delta`, calls `move_and_slide()` (which uses the physics step delta), then `motor.sync_position(global_position)`. | G1 (PR-3, PR-8) |
| C16 | **Aim device rules.** Aim mode is `MOUSE` or `GAMEPAD`; initial mode `MOUSE`; initial facing `Vector2.DOWN` (never zero). Switch to `MOUSE` only on a physical mouse event: motion with relative length ≥ 2 px, or a mouse button press. Camera/player movement that changes the mouse's world position is **not** an event. Switch to `GAMEPAD` on any joypad button press, or either stick with raw `|r| > dz`. Keyboard input never switches mode. Several qualifying events in one tick: the last one received wins. `MOUSE` aim = direction from player to mouse world position; if that distance < 0.25 tiles → no aim (zero). `GAMEPAD` aim = right stick per C14 (zero below dz). Motor facing: aim non-zero → aim direction; else move non-zero → move direction; else keep last facing. The active joypad is the one that produced the last qualifying event (default: first connected). | PR-4 |
| C17 | **Data validity and hot-reload.** Valid ranges: `move_speed` > 0; `move_accel_time`, `move_decel_time` ≥ 0; `dash_distance` > 0; `dash_duration` > 0; 0 < `dash_iframe_duration` < `dash_duration`; `dash_cooldown` ≥ 0; `input_buffer_window` ≥ 0; 0 ≤ `stick_deadzone` < 1. Each resource has `validate() -> PackedStringArray` (empty = valid). Reload is **atomic**: load both files ignoring cache; if either fails to load or validate, nothing changes and the overlay shows "reload rejected: <errors>". Invalid data at `setup()` is refused (`push_error`, motor stays in its previous state / not started). **Latching:** dash distance, duration and i-frame duration are latched when a dash fires; a mid-dash reload affects the next dash. Remaining cooldown and buffer age are kept as-is; new `dash_cooldown` applies to the next cooldown, new `input_buffer_window` from the next tick. Move speed/accel/decel and `stick_deadzone` apply from the next tick. | PR-6 |
| C18 | **Lifecycle API effects (exhaustive).** `setup(class_data, tunables, start_position_tiles, initial_facing = Vector2.DOWN)`: validate, store data, reset all state. `apply_data(class_data, tunables)`: validate, replace data only (C17). `sync_position(position_px)`: overwrite position only — the physics result is authoritative in the scene; in core tests nobody calls it and the motor's own integration stands. `from_dict(d)`: replace state per C5; the glue then sets `global_position` from the motor before the next tick. `tick()` and `submit()` per C15. | PR-1 |

**Must not break:** F-000 tooling. `tools/test`, `tools/lint` and the core purity check
all pass. F-000's input-map test keeps every original assertion (T7 migrates it).

---

## 5. Acceptance Criteria  ·  _Planner_

Testable, observable. The Auditor checks each one.

**Tolerances and oracle (PR-3).** Tests run the same scripted command sequence at 30, 60
and 120 ticks/s and sample only at times that are multiples of 1/30 s. Position tolerance
**0.01 tiles** for dash distance (exact by C15) and settled-speed travel; **0.2 tiles** for
any final position after mixed sequences (AC13); timing tolerance **one 30 Hz tick
(1/30 s)** for state changes and invulnerability windows. Where acceleration matters,
the oracle is the exact piecewise-constant-acceleration kinematics of C15 step d (identical at every rate, since commands only change at 1/30 s multiples in tests).

- [ ] AC1 — **Movement speed:** After velocity has settled at full speed (accel finished),
      holding a full-magnitude input for 1.0 s moves the Warrior `move_speed` tiles
      (± 0.01) in any of the 8 directions. Diagonal is not faster than cardinal.
- [ ] AC2 — **Analog:** For raw stick magnitudes 0.1, 0.2, 0.5, 1.0 with `stick_deadzone`
      0.2, settled speed is 0, 0, `0.375 × move_speed`, `move_speed` (C14, boundary 0.2 → 0).
- [ ] AC3 — **Accel/decel:** From standstill, settled full speed is reached within
      `move_accel_time` (+ one tick); from full speed with zero input, speed is 0 within
      `move_decel_time` (+ one tick). With either value at 0, the change happens in the
      same tick.
- [ ] AC4 — **Facing (mouse mode):** In `MOUSE` mode, facing = direction from Warrior to the
      mouse world position every tick, also while moving and dashing; mouse within 0.25
      tiles → facing falls back per C16.
- [ ] AC5 — **Facing (gamepad mode):** In `GAMEPAD` mode: right stick above dz → facing =
      right stick direction; else move direction; else unchanged. Mode switching follows C16
      exactly (both directions, noise below dz doesn't switch, camera movement doesn't switch).
- [ ] AC6 — **Dash direction:** Dash goes in the move input direction of the tick it fires;
      with no move input, in the facing direction. Immediately after `setup()` with no aim
      input, a stationary dash goes `Vector2.DOWN`.
- [ ] AC7 — **Dash travel:** In open space, one dash covers exactly `dash_distance` tiles
      (± 0.01) over `dash_duration` (± one 30 Hz tick), at constant speed.
- [ ] AC8 — **Dash and walls:** Dashing straight into a wall stops at the wall; dashing at
      45° into a wall slides along it. The Warrior's body never overlaps world geometry.
      (Automated scene test, T9b.)
- [ ] AC9 — **I-frames:** Per C8: the window `I` is exact (`get_iframe_window()` matches
      latched fire time and duration to float precision at every rate), the tick-end flag
      follows the overlap rule, and the tail is vulnerable. Covered explicitly: a sub-tick
      i-frame window (e.g. 0.01 s at 30 Hz → true after the fire tick, false after the next),
      a sub-tick whole dash (fires and ends in one tick: flag true, state not DASHING, both
      signals emitted), and a sub-tick vulnerable tail.
- [ ] AC10 — **Dash end:** No dash momentum carries over: velocity is 0 at dash end and then
      follows normal accel from the current move input.
- [ ] AC11 — **Cooldown:** A new dash can't fire until `dash_cooldown` after the previous
      dash ended (overshoot carried per C15).
- [ ] AC12 — **Buffer:** A dash pressed during a dash or cooldown fires on the first eligible
      tick if its age ≤ `input_buffer_window` (inclusive), else it is dropped. A newer press
      replaces the older one. Direction is read at fire time.
- [ ] AC13 — **Frame-rate independence:** A scripted sequence of moves, aim changes and
      **5 consecutive dash + cooldown cycles** ends at the same position (± 0.2 tiles) with
      dash fire times and i-frame windows equal (± 1 µs) at 30, 60 and 120 ticks/s. Runs at
      least twice: with default data, and with `dash_duration = 0.141`, `dash_cooldown =
      0.329`, `input_buffer_window = 0.12` and DashCommands every 0.1 s (Auditor PR-8 case:
      expected fire times 0, 0.47, 0.94, 1.41, 1.88 s at every rate).
- [ ] AC14 — **Serialization:** Snapshot (per C5) mid-dash, mid-i-frames, mid-cooldown and
      with a buffered dash; restore into a fresh motor; the next 30 ticks of both motors
      under the same commands are identical.
- [ ] AC15 — **Independence:** Two motors (and two mappers) ticked side by side with
      different inputs don't affect each other.
- [ ] AC16 — **Hot-reload:** `debug_reload_tunables` (F5) in the debug scene reloads both
      files and applies them per C17: valid edits apply with state kept; an invalid file
      (e.g. `dash_iframe_duration ≥ dash_duration`) is rejected atomically and shown on the
      overlay. Tested during a dash, during i-frames, during cooldown and with a buffer.
- [ ] AC17 — **Coverage map (PR-2):**
      - Core motor tests (`tests/core/player/`): AC1–AC3, AC6, AC7, AC9–AC15, the motor part
        of AC4/AC5 (facing from aim/move commands), C17 validation and latching.
      - Input mapper tests (`tests/entities/player/`, plain GUT, no scene): C14 math, C16
        device switching both ways, noise, camera movement not switching, mouse-on-player
        fallback, AC2 via raw samples, `dz` reload through the mapper.
      - Physics scene test (GUT with physics frames): AC8, and AC16 end-to-end in the
        debug scene.
      - F-000 input-map test migrated (T7). `tools/test`, `tools/lint`, core purity pass.

**How to verify manually (feel test):**
Open `scenes/debug/f001_movement.tscn` and play 2 minutes with KB/M, then 2 with a gamepad.
- Movement should feel like the Warrior is glued to your hand: no slide on stop, no
  "waking up" on start.
- Tapping dash should feel instant. Mash it and you should get a steady rhythm of dashes
  (buffer working), never a "swallowed" press.
- Dash into a wall: no jitter, no clipping.
- Watch the overlay: the i-frame tint should clearly end *before* the dash ends.
  Can you feel the vulnerable tail? If it feels unfair, that's a tunable, not a bug.
- Edit `warrior.tres` (e.g. `dash_distance` to 4.0), press F5, feel the difference.

---

## 6. Task Breakdown  ·  _Planner_

Small, ordered, each independently committable.

| # | Task | Files likely touched | Notes |
|---|---|---|---|
| T1 | Unit conversion | `src/core/units.gd` (`Units`) | `TILE_SIZE_PX := 16` + `tiles_to_px()`, `px_to_tiles()`. `# CX1: tile size pending Art & Game Feel`. |
| T2 | Data resource types + validation | `src/core/classes/class_data.gd` (`ClassData`), `src/core/tunables/player_combat_tunables.gd` (`PlayerCombatTunables`) | Fields as before: `ClassData` (`id`, `display_name`, `weapon_family`, `move_speed`, `move_accel_time`, `move_decel_time`, `dash_distance`, `dash_duration`, `dash_iframe_duration`, `dash_cooldown`); `PlayerCombatTunables` (`input_buffer_window`, `stick_deadzone`). Each has `validate()` per C17. `# D-005` on `ClassData`. |
| T3 | Data files + autoload | `data/classes/warrior.tres`, `data/tunables/player_combat.tres`, `src/autoload/tunables.gd` | Values from design/combat.md *Tunables index*. Add `Tunables.player_combat` (path constant + preload). |
| T4 | Commands | `src/commands/command.gd` (base), `move_command.gd`, `aim_command.gd`, `dash_command.gd` | Plain data, extend `Command` (`RefCounted`). `MoveCommand(direction)` already mapped per C14. `AimCommand(direction)` unit vector or zero. |
| T5 | `PlayerMotor` core | `src/core/player/player_motor.gd` | States `IDLE`, `MOVING`, `DASHING`. API exactly C4/C18 + getters `get_tick_displacement_px()`, `get_position_px()`, `get_facing()`, `get_state()`, `is_invulnerable()`, `get_cooldown_remaining()`, `has_buffered_dash()`, `to_dict()`. Tick per C15. Signals: `dash_started`, `dash_ended`, `invulnerability_changed(is_invulnerable)`. |
| T6 | Core motor tests | `tests/core/player/test_player_motor.gd` (+ helpers) | Coverage per AC17 core list, at 30/60/120 Hz with the §5 oracle. Must include the AC13 PR-8 data set and the three AC9 sub-tick cases. |
| T7 | Input mapper + node + input map | `src/entities/player/input_sample.gd`, `player_input_mapper.gd`, `player_input.gd`; `project.godot`; `tests/test_input_map.gd`; `tests/entities/player/test_player_input_mapper.gd` | Mapper is pure (no `Input`), implements C14/C16. Node fills `InputSample` from `Input` and input events. Add only `debug_reload_tunables` (F5). **Migrate the F-000 input-map test:** extend the exact action set and assert the new binding, keeping every original F-000 assertion unchanged (PR-7). |
| T8 | Player glue | `src/entities/player/player.gd` (`Player`, `CharacterBody2D`), `player.tscn` | Per tick exactly C15 step 3. `@export var class_data: ClassData` (default warrior). Placeholder circle + facing line. World collision layer only. Logic never reads visuals. |
| T9 | Debug scene + overlay | `scenes/debug/f001_movement.tscn`, `src/ui/debug/motor_debug_overlay.gd` | Room ~30×20 tiles, walls, pillars, a 45° wall. Follow camera. Overlay: state, velocity (tiles/s), facing, aim mode, i-frame flag (+ player tint), cooldown, buffered dash, ticks/s, last reload result. F5 → atomic reload (C17). |
| T9b | Physics scene tests | `tests/scenes/test_f001_walls.gd` | AC8 straight + 45° wall with scripted commands over physics frames; AC16 valid/invalid reload end-to-end. |
| T10 | Glossary | `studio/GLOSSARY.md` | Rows: Dash, I-frames, Facing, Input buffer, Class, Aim mode, Deadzone. |

---

## 7. Plan Review  ·  _Auditor_

**Verdict:** `APPROVE_WITH_NOTES`
**Reviewed:** 2026-10-31 · **Round:** 3
**Reviewed revision:** `a744ad1766b9dd5112fbd43b3ad2c0a3a9553709`

**Current result:** PR-1–PR-9 are `✔ resolved`. PR-8/PR-9's Planner replies were
checked first and are preserved below. No blocking finding remains. One new
non-blocking documentation note (PR-10) follows the Round 3 resolution check.

**Round 1 assessment (historical):**

The test-room movement/aim/dash outcome serves pillar 2, with clear scope exclusions.
The class/resource split follows D-005, and the chosen architecture and rejected
alternatives have specific reasons. No unflagged contradiction with combat.md's
movement/dash decisions was found. CX1 and enemy collision can remain deferred as
stated. Approval is blocked by the conflicting mutation and test contracts below.

### PR-1 — 🔴 C4 forbids mutations required by the chosen architecture — ✔ resolved (round 2)
- **Location:** §3 Chosen; §4 C4/C5/C13; §5 AC14/AC16; §6 T5/T8/T9.
- **Problem:** C4 says motor state changes only through commands and `tick(delta)`.
  T8 nevertheless writes position through `set_position_px()` every tick, T9 calls
  `apply_data()` to replace data, and AC14 requires `from_dict()` to restore state.
  These are explicitly required writes outside the two allowed entry points.
- **Why it matters:** The Builder cannot follow both C4 and the required API; any
  otherwise-correct implementation can trigger the automatic constraint failure.
  This is also the first motor/command contract that later features will copy.
- **Suggested fix:** Restrict C4's command-only rule to player intentions, and list
  the authorized glue/lifecycle operations and their allowed effects. Define who
  advances position in open-space core tests versus the scene, when body position
  overrides motor position, and how a restored motor initializes the body before
  the next tick. State the snapshot boundary and include all retained intentions,
  dash direction, and pending commands needed for identical continuation (or require
  an empty command queue at that boundary). Keep physics resolution outside core.

> **Planner reply (Direction):** Accepted. C4 now limits *intentions* to commands and lists the exhaustive lifecycle API; C18 defines each call's effects (physics result authoritative in scene, motor integration in core tests, glue sets body from motor after restore). C5 fixes the snapshot boundary (between ticks, no pending commands, commands never retained) and its full contents, including dash direction and latched params.

### PR-2 — 🔴 AC17 demands core-only coverage that T6 explicitly excludes — ✔ resolved (round 2)
- **Location:** §5 AC4/AC5/AC8/AC17; §6 T6/T7/T9; §3 Chosen/Rejected.
- **Problem:** AC17 requires AC1–AC15 to be tested at core level, which includes
  wall collision (AC8) and device arbitration/mouse world-position conversion
  (AC4/AC5). The architecture puts those responsibilities outside the motor. T6
  expressly makes AC8 manual-only, and gives no test task for AC4/AC5's input reader.
- **Why it matters:** The stated acceptance coverage cannot be delivered by the
  planned tests without bringing input/physics into core or recreating rejected
  collision logic. Aim adapter bugs would otherwise be left to the feel test.
- **Suggested fix:** Replace the blanket AC17 claim with an explicit coverage map:
  pure motor tests for movement/dash/timers/facing commands/serialization; input-reader
  tests for actual device-to-command behavior; and a physics scene test for walls,
  or an explicit manual-only AC8 exception. Update T6/T7/T9 to match that choice.

> **Planner reply (Direction):** Accepted. §5 now has a coverage map (AC17): pure motor tests, pure input-mapper tests (new `PlayerInputMapper` + `InputSample`, §3), and an automated physics scene test for walls (AC8) and reload (T9b). T6/T7/T9/T9b updated.

### PR-3 — 🟡 Timing boundaries and the numeric test oracle are underspecified — ✔ resolved (round 2)
- **Location:** §4 C1/C8–C10; §5 tolerance statement and AC1/AC3/AC7/AC9–AC13; §6 T5/T6/T8.
- **Problem:** The plan does not define command/timer ordering within a tick, what
  happens to the part of a tick after dash/cooldown expiry, or which speed/rate sets
  “one tick of travel”. A 0.15 s dash spans 4.5 ticks at 30 Hz, so whole-tick rounding
  needs a stated policy. “Accounting for accel” also leaves AC1's expected distance
  undefined: ideal linear acceleration at the defaults covers 4.875 tiles in the
  first second from rest, rather than 5.0.
- **Why it matters:** Different reasonable implementations disagree about first-tick
  invulnerability, buffer expiry, dash distance, and repeated-dash cadence. A single
  dash can fit the tolerance while repeated rounding accumulates beyond AC13.
- **Suggested fix:** Define the tick timeline, including same-tick input ordering,
  exact-boundary buffer eligibility, timer overshoot, and partial-dash movement fed
  to the physics glue. Specify a numerical tolerance and observation times shared
  by tests at all three rates. Measure AC1 at settled speed or give the acceleration
  integral/discretization oracle. Include repeated dash/cooldown cycles with durations
  not divisible by the tick interval, not just an isolated dash. The glue must account
  for [move_and_slide using the physics step's delta](https://docs.godotengine.org/en/stable/classes/class_characterbody2d.html#class-characterbody2d-method-move-and-slide).

> **Planner reply (Direction):** Accepted. C15 defines the full tick timeline: input ordering, inclusive buffer boundary, exact-distance dash with clipped final-tick displacement, zero movement for the rest of that tick, overshoot carried into cooldown, and how the glue feeds displacement/delta to `move_and_slide()`. §5 defines numeric tolerances, 1/30 s sampling for all rates, the `move_toward` oracle (AC1 now measured at settled speed), and AC13 now runs 5 dash+cooldown cycles with non-divisible durations.

### PR-4 — 🟡 “Last used device” and initial/zero aim have no deterministic rule — ✔ resolved (round 2)
- **Location:** §5 AC4–AC6; §6 T4/T5/T7.
- **Problem:** AC4 refers to the last used *aim* device while AC5 refers to the last
  used device generally. It is unclear whether keyboard movement, a pad button,
  left-stick movement, right-stick noise, or only actual aiming switches mode.
  No initial mode/facing or rule for the mouse exactly on the player is specified.
- **Why it matters:** A controller can lose aim priority to incidental mouse events,
  or keyboard movement can select an unintended fallback. An immediate stationary
  dash also needs a valid nonzero facing before the first aim input.
- **Suggested fix:** Define qualifying events, noise thresholds, same-tick priority,
  initial mode/facing, and the coincident-mouse fallback. Explicitly distinguish
  physical mouse activity from a changing mouse world vector caused by the follow
  camera/player moving. Add adapter tests for switching both ways, inactive/noisy
  devices, moving while aiming, and a stationary dash immediately after setup.

> **Planner reply (Direction):** Accepted. C16: initial mode MOUSE, initial facing DOWN, exact qualifying events for each mode (mouse motion ≥ 2 px or click; joypad button or stick above dz), keyboard never switches, camera-driven mouse world changes don't count, last event in a tick wins, mouse within 0.25 tiles → no aim. AC5/AC6 and the mapper tests cover switching, noise, moving while aiming and a dash right after setup.

### PR-5 — 🟡 Analog magnitude and the authoritative deadzone need one contract — ✔ resolved (round 2)
- **Location:** §2 Input map; §5 AC2/AC16; §6 T3/T4/T7; F-000 action deadzones.
- **Problem:** AC2 does not say whether m is raw stick magnitude or a value already
  remapped through the deadzone. T4 says MoveCommand is already deadzoned, while T7
  also fixes aim action deadzones at 0.2 and player_combat.tres owns stick_deadzone.
  The input reader's use of these two sources, including after F5, is unspecified.
  [Godot's get_vector implementation](https://github.com/godotengine/godot/blob/master/core/input/input.cpp)
  remaps magnitudes above its deadzone: raw 0.5 with deadzone 0.2 becomes 0.375.
- **Why it matters:** `move_speed × 0.5` and `move_speed × 0.375` are different AC2
  outcomes, and applying another threshold can discard otherwise-valid analog input.
  The tunable could also change in the resource without changing actual input behavior.
- **Suggested fix:** Define raw-to-command magnitude mathematically, including radial
  versus per-axis thresholding and the equality boundary. Choose one authoritative
  runtime deadzone from the resource and specify how both sticks use it without double
  filtering or changing F-000's bindings. Test representative raw magnitudes and a
  deadzone hot-reload through the input reader, not just constructed MoveCommands.

> **Planner reply (Direction):** Accepted. C14: one radial formula for both sticks with Godot-style remap (raw 0.5, dz 0.2 → 0.375), equality boundary → zero, digital normalized, stick wins over digital when non-zero. The resource `stick_deadzone` is the only runtime filter; sticks are read as raw axes so nothing is filtered twice. `aim_*` actions removed — only `debug_reload_tunables` is new, F-000 bindings untouched. AC2 tests raw magnitudes; dz reload tested through the mapper.

### PR-6 — 🟡 Hot-reload lacks valid-data and active-phase semantics — ✔ resolved (round 2)
- **Location:** §4 C2/C8/C13; §5 AC16; §6 T2/T5/T9.
- **Problem:** No allowed ranges or invalid-load policy are defined for editable
  movement/dash data. `dash_duration = 0` makes distance/duration undefined, and
  `dash_iframe_duration >= dash_duration` removes the required vulnerable tail.
  Even valid edits have an ambiguous effect mid-dash: changing duration after a dash
  starts can mean recomputing expiry from elapsed time or preserving its old remaining
  timer. AC16 requires immediate data application and preserved state without resolving this.
- **Why it matters:** The explicit tuning workflow can produce division errors or
  violate a non-negotiable dodge rule. Two implementations can preserve the same
  timers while giving different speed/i-frame/cooldown behavior after reload.
- **Suggested fix:** Specify valid ranges/cross-field invariants (retaining the explicit
  zero accel/decel case) and atomic behavior for invalid resources or failed disk loads.
  Define which active-phase values are latched until the next dash and which update
  on the next tick, while keeping the promised state. Add automated valid/invalid
  reload tests during dash, invulnerability, cooldown, and an active buffer.

> **Planner reply (Direction):** Accepted. C17: valid ranges and cross-field invariant (0 < iframes < duration, zero accel/decel kept), atomic reload (all-or-nothing, rejection shown on overlay), invalid data refused at setup. Latching: dash distance/duration/i-frames latched at fire; remaining cooldown and buffer age kept; other values from next tick. AC16 tests valid and invalid reload during dash, i-frames, cooldown and buffer.

### PR-7 — 🟡 Adding the new actions requires an explicit F-000 test migration — ✔ resolved (round 2)
- **Location:** §2 Input map; §4 C12/“Must not break”; §6 T6/T7;
  `tests/test_input_map.gd:7–16` and `_expected_bindings()`.
- **Problem:** The existing test asserts that every non-ui action equals exactly
  F-000's nine-action table. Adding aim_left/right/up/down and debug_reload_tunables
  necessarily fails it, but no task includes extending this test or its expected table.
- **Why it matters:** Following the listed input-map work leaves tools/test red;
  deleting or weakening the old assertion would lose the promised binding protection.
- **Suggested fix:** Include the existing input-map test in T7: extend the exact action
  set and new binding/deadzone assertions while retaining every F-000 binding assertion.
  Keep this regression migration distinct from the new motor-only tests.

> **Planner reply (Direction):** Accepted. T7 now includes migrating `tests/test_input_map.gd`: extend the exact action set with `debug_reload_tunables` only and keep every F-000 assertion unchanged. Since `aim_*` actions were dropped (PR-5), the migration is one action.

### Round 2 — Planner reply and resolution check

Read every Planner reply first, then the complete revised feature, PROJECT.md,
DECISIONS.md, STATUS.md, and combat.md. The player-facing goal, explicit exclusions,
class data model, and rejected options remain appropriate. The new aim/deadzone
rules are also reflected explicitly in combat.md. T9b now provides the previously
missing physics integration coverage; the original seven findings are not re-raised.

| Finding | Verified revision | Current status |
|---|---|---|
| PR-1 | C4/C18 distinguish intentions from lifecycle/synchronization writes. C5 specifies the between-ticks snapshot and per-tick command lifetime; C18 defines position authority and restore synchronization. | ✔ resolved |
| PR-2 | AC17 separates pure motor, pure mapper, and physics scene coverage. T7 includes the mapper tests; T9b covers walls and end-to-end reload. | ✔ resolved |
| PR-3 | C15 specifies ordering, movement integration, expiry/buffer rules, and physics displacement. §5 now gives numerical tolerances, a settled-speed AC1 oracle, common sample times, and repeated cycles. The correctness of the newly chosen policy is reviewed separately in PR-8/PR-9. | ✔ resolved — ambiguity addressed |
| PR-4 | C16 specifies initial mode/facing, qualifying physical events, event ordering, device selection, and zero-aim fallback; AC4–AC6 and mapper coverage refer to it. | ✔ resolved |
| PR-5 | C14 defines the radial formula, equality boundary, digital fallback, and single resource-owned deadzone; AC2 and AC17 cover raw samples/reload. Only F5 adds an action. | ✔ resolved |
| PR-6 | C17 defines validation, atomic rejection, active-dash latching, and live-update rules; AC16/AC17 cover valid/invalid reload and state preservation. Short-window observability under the new C8/C15 policy is a separate defect in PR-9. | ✔ resolved |
| PR-7 | T7 explicitly extends the exact action set by F5 while retaining every original F-000 binding/deadzone assertion. | ✔ resolved |

### PR-8 — 🔴 C15 accumulates cooldown-to-dash rounding beyond AC13's tolerance — ✔ resolved (round 3)
- **Location:** §4 C1/C15 (eligibility step c and phase advance step d); §5 timing
  tolerance and AC13; §6 T5/T6.
- **Problem:** Eligibility is checked only at tick start. C15 carries the fractional
  remainder of a dash-ending tick into cooldown, but does not carry cooldown expiry
  within a later tick into the next buffered dash. Each new dash therefore restarts
  on a rounded-up tick boundary. Repeated cycles accumulate that delay.
- **Evidence:** With valid `dash_duration = 0.141 s`, `dash_cooldown = 0.329 s`,
  `input_buffer_window = 0.12 s`, and identical DashCommands at absolute times
  0.0, 0.1, 0.2, … seconds, the proposed timeline gives these starts (all requests
  needed at eligibility remain fresh):

  | Rate | Dash 1 | Dash 2 | Dash 3 | Dash 4 | Dash 5 |
  |---|---|---|---|---|---|
  | 30 Hz | 0.000000 | 0.500000 | 1.000000 | 1.500000 | 2.000000 |
  | 60 Hz | 0.000000 | 0.483333 | 0.966667 | 1.450000 | 1.933333 |
  | 120 Hz | 0.000000 | 0.475000 | 0.950000 | 1.425000 | 1.900000 |

  These values were checked with a standalone rational-arithmetic model of C15,
  including normal cooldown decrementing and its stated dash-end overshoot credit.
- **Why it matters:** The fifth dash/i-frame window differs by 0.1 s between 30 and
  120 Hz, exceeding AC13's 1/30 s timing tolerance. Common 1/30 s observation points
  do not remove a delay spanning three such intervals. A Builder obeying C15 cannot
  satisfy the required repeated-cycle behavior for this valid sequence.
- **Suggested fix:** Preserve phase-time overshoot through cooldown-to-dash transitions
  as well as dash-to-cooldown transitions, and define when buffered eligibility is
  re-evaluated within the remaining interval. Specify the corresponding displacement
  passed to physics. Add this concrete command sequence/data combination to T6 at
  all three rates; do not rely only on defaults whose cycle total is exactly 0.5 s.

> **Planner reply (Direction):** Accepted. C15 step c is now a phase loop that consumes
> `delta` in segments: a buffered dash fires at the exact instant cooldown expires inside
> a tick, and a dash's end, cooldown and next dash can all happen within one tick. Fixing
> this exposed two more rate-dependent drifts the old text had, both fixed: (1) the rest of
> a dash-ending tick used to produce no movement — it now integrates normal movement from
> velocity 0; (2) normal movement used per-tick Euler steps — step d now integrates
> constant acceleration exactly. Motor clock `time` added to the snapshot. AC13 now
> requires your exact data set with expected fire times 0, 0.47, 0.94, 1.41, 1.88 s at
> every rate (±1 µs), plus the default-data run; T6 must include it.

### PR-9 — 🔴 Valid short i-frame windows make C8's post-tick rule contradictory — ✔ resolved (round 3)
- **Location:** §4 C8/C15/C17; §5 AC9/AC16/AC17.
- **Problem:** C17 accepts `dash_duration = 0.1 s` and `dash_iframe_duration = 0.01 s`.
  At 30 Hz, the firing tick advances dash elapsed to 1/30 s. C8 requires
  `is_invulnerable()` to be true after the firing tick, but also requires expiry at
  that same end-of-tick check because elapsed ≥ 0.01 s. The dash is still active,
  so this is not just an already-ended dash case.
- **Why it matters:** No post-tick boolean can satisfy both clauses for these valid,
  reloadable values. Keeping it true breaks the expiry predicate; making it false
  breaks the first-tick guarantee and leaves no sampled invulnerable phase. The
  timing tolerance does not resolve two opposite requirements at the same observation.
- **Suggested fix:** Define whether invulnerability describes a sampled instant or
  intervals within a tick, and make the first-tick/expiry rules consistent with that
  choice. Alternatively, add validation bounds tied to supported tick intervals that
  guarantee the promised observable phases. Explicitly cover sub-tick i-frames,
  a sub-tick whole dash, and a sub-tick vulnerable tail in AC9/C17 tests. Keep the
  combat design's invulnerable start and vulnerable tail aligned with the chosen rule.

> **Planner reply (Direction):** Accepted — chose intervals, not sampled instants. C8: i-frames
> are an exact window on the motor clock; `is_invulnerable()` after a tick = the window
> overlaps that tick's `[start, end)`. The fire tick is therefore always true (even for
> 0.01 s windows), a tail-only tick is false, and `get_iframe_window()` gives the exact
> window for the future hit system. No tick-tied validation bounds, so C17 is unchanged.
> AC9 now names the three sub-tick cases (short window, whole dash in one tick, short tail).
> design/combat.md updated to the same rule.

**Round 2 verdict (historical):** `CHANGES_REQUESTED`. Keep `owner_now: Planner` and
`status: PLAN_CHANGES`. Verification here checks the proposed contract mathematically;
it does not claim that F-001 code or implementation tests have been run.

### Round 3 — PR-8/PR-9 reply and resolution check

Checked the replies under PR-8 and PR-9 first, then re-read the revised plan and
combat.md against PROJECT.md and the accepted decisions. PR-1–PR-7 remain resolved.

| Finding | Verified revision | Current status |
|---|---|---|
| PR-8 | C15 now consumes the tick in phase segments and re-evaluates buffered eligibility at cooldown expiry. Remaining time also integrates normal movement after dash end, and normal acceleration uses its exact integral. AC13/T6 require the concrete regression data and the default-data run. | ✔ resolved |
| PR-9 | C8 defines an exact half-open i-frame window separately from the tick-overlap flag. AC9/T6 cover a sub-tick window, a whole sub-tick dash, and a sub-tick tail. combat.md explicitly matches the exact-time rule. | ✔ resolved |

**Contract verification:** A standalone rational-arithmetic model of the new phase
loop produced fire times `0, 0.47, 0.94, 1.41, 1.88 s` at 30/60/120 Hz for the PR-8
data and identical DashCommands every 0.1 s. The default-data sequence likewise
produced `0, 0.5, 1, 1.5, 2 s` at all three rates. Half-open interval overlap checks
at 30 Hz confirmed that a 0.01 s i-frame window reports true for its firing tick
and false for the following tick, including a whole dash shorter than one tick.
A short-tail case also followed the explicit overlap rule without extending the
underlying exact window. These checks validate the proposed contract, not an
implementation of F-001. Implementation still must satisfy AC9/AC13/AC14.

The goal, scope, pillar alignment, class/resources/commands architecture, rejected
options, and coverage map remain coherent. The revised timing model leaves no
blocking conflict with the department design doc or project constraints. T1–T10
(including T9b) still provide an ordered implementation path; the new interval
getter should be included in its API inventory as noted below.

### PR-10 — 🟡 T5's exact API inventory omits the new required interval getter
- **Location:** §4 C8; §5 AC9; §6 T5.
- **Problem:** C8 and AC9 now require `get_iframe_window()`, but T5 still describes
  the API as “exactly C4/C18 + getters” followed by the old list, which omits it.
- **Why it matters:** The Builder's implementation checklist disagrees with the
  acceptance contract about a public method needed by the new tests. The required
  behavior itself is clear in C8, so this is a documentation note, not a blocker.
- **Suggested fix:** Add `get_iframe_window()` to T5's getter inventory and reference
  C8 for its motor-clock interval/empty-result semantics.

**Round 3 verdict:** `APPROVE_WITH_NOTES`. Leave `status: PLAN_REVIEW`, set
`owner_now: Lucas`; only Lucas sets APPROVED at Gate A. No source code or protected
plan sections were edited by this review.

---

## 8. Implementation Log  ·  _Builder_

**Started:** 2026-10-31  ·  **Branch:** `feature/F-001-warrior-movement-dash`

### Progress
- [x] T1 — 4adf703
- [x] T2 — 5087308
- [x] T3 — 83eda0d
- [x] T4 — 7e2191e
- [x] T5 — a47fd0b
- [x] T6 — ed066b6, 5025106
- [x] T7 — f7d0e70
- [x] T8 — bf030b5
- [x] T9 — 7f00923
- [x] T9b — 9228dac, 6b691cc, 67f23f7
- [x] T10 — 6915cce

### Deviations from plan
- **DEV-1:** T6's single `tests/core/player/test_player_motor.gd` became six files
  (`test_player_motor_{movement,dash,iframes,buffer,timing,lifecycle}.gd`), plus
  `test_data_validation.gd` and the helper `motor_harness.gd`. **Why:** gdlint's
  `max-public-methods` is 20, and each test counts. **Impact:** tests only, AC17's folder holds.
- **DEV-2:** T9b is two files: `test_f001_walls.gd` as planned, plus `test_f001_reload.gd`.
  **Why:** same limit, and reload needs its own `user://` fixture. **Impact:** tests only.
- **DEV-3:** The snapshot has three keys beyond C5's list: `has_iframe_window`, `iframe_start`,
  `iframe_end` (`time` is required by C15). **Why:** `get_iframe_window()` must survive a restore,
  and a snapshot can be taken after the dash ended while the window still overlaps the last tick
  (sub-tick dash). **Impact:** C5's "round-trip loses nothing" holds; the snapshot is a superset.
- **DEV-4:** T1 gained `vector_tiles_to_px()` and `vector_px_to_tiles()`. **Why:** the motor and
  glue convert vectors, and C7 wants one conversion place. **Impact:** none.
- **DEV-5:** `Player` has public members T8 doesn't list: `motor`, `input_enabled`, `tunables_path`,
  `get_aim_mode()`, `reload_data()`, `restore_snapshot()`. **Why:** the overlay needs them, T9b's
  scripted commands need input off, and C18 needs the glue's half of a restore. **Impact:** none on C4:
  `input_enabled` only stops `PlayerInput`, and commands still arrive only through `submit()`.
- **DEV-6:** `project.godot` also names physics layers 1 `world` and 2 `player`. **Why:** readable
  in the inspector. **Impact:** none; C12 concerns input actions only.

### Assumptions made (small, reversible)
- **ASSUMPTION-1:** C8 leaves the return type open → `get_iframe_window()` returns
  `PackedFloat64Array([start, end])`, empty before any dash and once the last tick no longer
  overlaps it. **Why:** 64-bit (`Vector2` is 32-bit), and "empty" stays meaningful. If a tick holds
  an expiring window and a new dash, the getter returns the newest one.
- **ASSUMPTION-2:** Float noise at exact boundaries → `PlayerMotor.TIME_EPSILON` (1e-9 s) on the
  inclusive buffer check, dash end and window end. **Why:** without it a dash ending exactly on a
  tick boundary reported `DASHING` one tick late (a test caught this). Far below AC13's 1 µs; a
  float guard, not a tunable (C2).
- **ASSUMPTION-3:** C14's boundary "0.2 → 0" fails on 32-bit `Vector2` (raw 0.2 reads 0.200000003) →
  `PlayerInputMapper.STICK_TOLERANCE` (1e-6). **Why:** AC2 needs that boundary exact.
- **ASSUMPTION-4:** C15 doesn't define "slowing" → `|target| < |velocity|`, and a reversal switches
  from the decel rate to the accel rate at the exact instant speed reaches `|target|`, even inside a
  tick. **Why:** deciding the rate per tick would make reversals depend on the tick rate (C1).
- **ASSUMPTION-5:** C16's 0.25 tiles and 2 px are `const`s in the mapper with a `# F-001/C16` comment.
  **Why:** they are device-detection rules stated by C16, and T2's field list has no place for them.
- **ASSUMPTION-6:** C16 "stick with raw |r| > dz" is event-based (`InputEventJoypadMotion`), so a stick
  held perfectly still doesn't re-claim the mode from a moving mouse. **Why:** C16 calls them
  "qualifying events" and orders them by arrival.
- **ASSUMPTION-7:** Mouse motion is measured with `screen_relative`. **Why:** C16 says physical
  pixels, and `relative` shrinks with the 2x stretch.
- **ASSUMPTION-8:** C14 forbids reading stick strength through actions, but `move_*` also binds the
  left stick → digital input reads only the key and button bindings of those actions, from `InputMap`.
  **Why:** F-000's bindings stay the single source and nothing is filtered twice.
- **ASSUMPTION-9:** `setup()` and `apply_data()` return `bool`; `setup()` with zero facing keeps
  `Vector2.DOWN` (C16: never zero); `from_dict()` refuses a snapshot with missing keys; `tick()` before
  a valid `setup()` is a no-op. **Why:** simplest behavior that keeps C17's "refused" observable.
- **ASSUMPTION-10:** `to_dict()["velocity"]` holds the dash velocity during a dash. **Why:** it is the
  motor's real velocity, and it is 0 at dash end (AC10).
- **ASSUMPTION-11:** F5 is handled by `MotorDebugOverlay`, and `Player.reload_data()` also replaces
  `Tunables.player_combat`. **Why:** a stale autoload would mislead the next reader.
- **ASSUMPTION-12:** Player body is a 6 px radius circle, `collision_layer = 2`, `collision_mask = 1`,
  `motion_mode = FLOATING`. **Why:** T8 says world layer only; floating is Godot's top-down mode.
- **ASSUMPTION-13:** Debug room geometry is in pixels at 16 px per tile, in the scene file. **Why:**
  placeholder; it moves with CX1 if the tile size changes.

### Things the Auditor should look at closely
- **45° wall slide keeps full speed.** `MOTION_MODE_FLOATING` rescales slide motion, so a 45° dash
  into a wall travels about the full `dash_distance` along it, not `distance × cos 45°`. AC8 only
  requires a slide, so this stays; it is pinned by a test and raised as Q4 for Combat.
- **C15 phase loop:** `PlayerMotor._run_phases()`, `_slowdown_end()`, `_ramp_toward()`.
- **C8 overlap:** `_update_invulnerability()`. `_fired_this_tick` forces the fire tick to true for
  windows shorter than `TIME_EPSILON`.
- **`tests/scenes/` timing:** `_run_ticks` uses `get_tree().physics_frame`, because GUT's
  `wait_physics_frames(1)` spanned two Player ticks when measured. `_spawn*` ends on a physics frame
  so the first `submit()` isn't overwritten before the first tick.
- **Mutation check (not in the repo):** 34 deliberate breaks across motor, mapper, input node, glue
  and reload. 32 fail the suite. The remaining 2 are equivalent at fire time (`_velocity` and
  `_iframe_end` are computed once, from values equal to the latched ones).
- **T5/T6 order:** the spec puts code before tests, so tests were written after the code. The
  mutation check is what shows they can fail.
- **Not tested:** Linux (C7). Physical joypad and real mouse: covered through `InputSample`s and
  synthesized Godot events, including the node's path; left stick via a real device is only
  covered by the mapper because no joypad connects in headless.
- **The manual feel test in §5 belongs to Lucas (Gate B).** The Builder has not played it.

### How to test
```sh
tools/setup                                 # idempotent
tools/test                                  # expect 130/130, exit 0
tools/lint                                  # expect exit 0
tools/check_core_purity                     # expect "core purity ok"
tools/check_core_purity --self-test         # expect 19 rules tripped
godot --headless --path . scenes/debug/f001_movement.tscn --quit-after 60   # expect exit 0, no errors
```

Feel test scene: `scenes/debug/f001_movement.tscn` (editor: open it, F6; or
`godot --path . scenes/debug/f001_movement.tscn`). F5 in the running scene reloads both data files.

---

## 9. Code Review  ·  _Auditor_

**Verdict:** `APPROVE_WITH_NOTES`
**Reviewed commit:** `588372e2f963f369f6a102f36a9ddc7b96533302` · **Round:** 1
**Reviewed:** 2026-10-31
**Comparison:** `main` (`f4f46470fa0d6d7627f00d32b8ce6ef036688a5e`)
to `feature/F-001-warrior-movement-dash`, using the merge-base diff.

No blocking findings. One reproducible presentation bug is recorded as CR-1.

### Checklist
- [x] AC1–AC17 supported by the implementation and checks below; verification limits stated
- [x] No Rejected option from §3 implemented
- [x] No blocking constraint violation found in §4 or PROJECT.md
- [x] DEV-1–DEV-6 justified; no undocumented implementation deviation found
- [x] ASSUMPTION-1–ASSUMPTION-13 reviewed as reasonable, reversible choices for this feature

### AC evidence

✅ indicates code/test evidence for the specified behavior; it does not claim the
manual feel test or physical-controller testing was performed.

| AC | Result | Evidence |
|---|---|---|
| AC1 | ✅ | `PlayerMotor._integrate_movement()` / `_ramp_toward()` integrate target speed and displacement; submit clamps movement length. `tests/core/player/test_player_motor_movement.gd` checks all eight directions at 30/60/120 Hz, oversized input, and settled travel within 0.01 tiles. |
| AC2 | ✅ | `PlayerInputMapper.apply_deadzone()` implements C14's radial remap once; PlayerInput reads raw axes. Mapper tests cover 0.1/0.2/0.5/1.0 raw magnitudes, radial direction, digital fallback, and the resulting settled motor speed at every rate. |
| AC3 | ✅ | `_ramp_toward()` uses exact constant-acceleration displacement until the target, then constant velocity; zero times change velocity immediately. Movement tests verify accel/decel limits, the displacement oracle, zero times, and a reversal across rates. |
| AC4 | ✅ | `Player._physics_process()` computes mouse world offset each physics tick; the mapper converts it to unit aim or zero inside the C16 radius; `_update_facing()` applies aim even during a dash. Mapper aim tests and motor movement tests cover these branches. |
| AC5 | ✅ | `_apply_device_events()` preserves event order, noise thresholds, last qualifying joypad, and mouse/gamepad switching. Right-stick aim, move/last-facing fallback, keyboard non-switching, and camera-only changes are tested. Scene tests also route synthetic mouse/joypad-button events through PlayerInput. Physical sticks were not exercised. |
| AC6 | ✅ | `_fire_dash()` selects and normalizes the current move input, else facing. Dash tests cover partial analog movement, facing-only dash, immediate DOWN dash after setup, and the buffer test checks direction at fire time. |
| AC7 | ✅ | `_advance_dash()` clips each segment to the remaining duration and uses latched constant velocity. Dash tests check exact travel, intermediate speed and duration at all three rates. Wall-scene tests additionally confirm open-space displacement through actual physics, including 30/60/120 ticks/s. |
| AC8 | ✅ | Player's circle body uses world-only collision and floating motion; `_physics_process()` calls move_and_slide and synchronizes its result. `tests/scenes/test_f001_walls.gd` checks straight/diagonal/angled-wall slides, zero overlap on each physics frame, and no wall jitter. The full-speed slide choice is disclosed in §8/Q4. |
| AC9 | ✅ | `_fire_dash()` stores the exact 64-bit window; `_update_invulnerability()` implements tick overlap with the disclosed numerical guard. I-frame tests cover ordinary/tail ticks, exact window values, sub-tick windows/dashes/tails, very short windows, and change signals. |
| AC10 | ✅ | `_end_dash()` resets velocity to zero before emitting dash_ended. Remaining time in the tick then uses normal acceleration. Tests record velocity at the end signal and verify post-dash displacement from rest, including a fractional end tick at every rate. |
| AC11 | ✅ | `_end_dash()` starts cooldown at dash end; `_advance_normal()` consumes it exactly, allowing eligibility within the same tick. Buffer tests verify start timing, expiry, zero cooldown, and the full value on an exact boundary. |
| AC12 | ✅ | submit records a press; `_run_phases()` tracks age through each segment, replaces the previous buffer, and re-checks eligibility. Buffer tests cover expiry, inclusive boundaries, replacement, presses during dash/cooldown, zero window, and direction at fire time. |
| AC13 | ✅ | `tests/core/player/test_player_motor_timing.gd:12` and line 18 run the default and PR-8 data with the same mixed commands at 30/60/120 Hz. They check all five expected fire times and i-frame ends to 1 µs, and final positions within 0.2 tiles. Both passed. |
| AC14 | ✅ | `to_dict()` / `from_dict()` preserve motor clock, velocity/position/facing, phase timers, buffer state and exact i-frame metadata. Timing tests compare every next-tick snapshot for 30 ticks after restoration mid-dash/i-frames/tail/cooldown/buffer. A scene test also checks body-position synchronization. Presentation resynchronization has the separate non-blocking defect CR-1. |
| AC15 | ✅ | Motor, mapper and glue hold per-instance state. Timing tests compare a motor beside another independently driven motor against an isolated run; mapper tests verify mode independence between instances. |
| AC16 | ✅ | `Player.reload_data():58–77` loads both resource files with cache ignored, validates both before mutation, and applies accepted data while preserving motor state. Lifecycle tests verify latching, live movement values, remaining cooldown and buffer age. Scene tests exercise F5, valid reload during dash/i-frames/cooldown/buffer, invalid and missing files, rejection during a dash, and atomic rejection when only one file is valid. |
| AC17 | ✅ | Core, mapper, physics/reload scene and migrated F-000 input-map tests are present in the planned locations (with logged splits). Full `tools/test`: 130/130 tests, 698 assertions, exit 0. `tools/lint`: zero issues, 54 files formatted. Core purity and its 19-rule self-test both pass. |

### Constraint, rejected-option, deviation and assumption audit

- **Rejected options:** No all-in-body movement logic, custom core collision, decaying
  dash impulse, roll/stamina/auto-aim system, or forbidden aiming/i-frame replacement
  was introduced. The interval-overlap flag is the approved C8 rule, not full-dash i-frames.
- **C1–C5/G1/G6–G8:** Physics uses delta; the motor is RefCounted with no Input/scene
  dependencies; intents use plain-data commands; lifecycle writes match C18; snapshot
  continuation is tested. The complete public mutating motor API remains the six
  allowed methods. `get_iframe_window()` implements the §11 PR-10 clarification.
- **C2/C7/G2/G9/D-005:** Movement/dash values reside in the Warrior resource and shared
  combat Resource; Units is the conversion point. Scene geometry/collider dimensions
  remain authored in pixels, as disclosed in ASSUMPTION-12/13. The two C16 thresholds
  are the explicitly specified input rules and are logged in ASSUMPTION-5.
- **C6/C8–C18/G3–G5:** Independence, timing/interval/buffer semantics, preserved bindings,
  and validated reload are supported by the checks above. Resources use centralized
  paths; the debug scene supplies isolation. No dependency/addon was added.
- **DEV-1/2:** Test-file splits preserve the coverage map and are justified by the
  public-method limit. **DEV-3:** Extra interval snapshot fields are needed for
  lossless restoration. **DEV-4:** Vector conversion helpers preserve C7. **DEV-5:**
  Glue inspection/restore/reload hooks support the overlay and tests without widening
  the motor's mutation API. **DEV-6:** Named layers leave input mappings unchanged.
- **Assumptions:** PackedFloat64Array windows, numerical guards, the rate-independent
  slowdown rule, physical mouse motion, event-based device arbitration, raw stick
  reads plus binding-derived digital input, lifecycle failure returns, and the
  placeholder body/geometry are documented and locally reversible. The newest-window
  return policy is accepted for this feature; hit processing remains out of scope.

For the raw-stick event path, Godot 4.7.2 updates axis state before dispatching the
event to scripts, consistent with PlayerInput's polling inside `_to_stick_event()`.
[Godot 4.7.2 input dispatch source](https://github.com/godotengine/godot/blob/4.7.2-stable/core/input/input.cpp#L923).

### Findings

### CR-1 — 🟡 Restoring a snapshot leaves the player's i-frame tint stale
- **Location:** `src/entities/player/player.gd:80–83` (`restore_snapshot`) and
  lines 92–93; `src/core/player/player_motor.gd:176` (`from_dict`).
- **Problem:** restore_snapshot updates motor state and body position, while modulate
  is updated only by invulnerability_changed. from_dict assigns the flag silently.
  The next tick compares overlap with that restored flag, so it need not emit a
  signal that would correct the old tint.
- **Reproduction:** In the debug scene, save a vulnerable snapshot; submit DashCommand
  and tick once at 60 Hz (cyan tint); restore the saved snapshot; tick again. A temporary
  harness reproduced `is_invulnerable() == false` with `modulate == (0.4, 0.9, 1, 1)`
  both immediately after restore and after the next tick, instead of Color.WHITE.
- **Why it matters:** The player's tint can advertise invulnerability indefinitely
  after restoring a vulnerable state, undermining the T9 visual indicator used to
  assess dash timing. Motor gameplay state itself restores correctly.
- **Suggested fix:** In the glue's restore path, synchronize the presentation from
  the restored motor flag as well as the position. Add a scene regression covering
  restoration from invulnerable to vulnerable and the reverse, including the next
  tick, without changing the motor's approved signal/timing contract.

### Verification scope

Executed the full suite, lint/format checks, core purity/self-test, and the debug
scene headless for 60 frames (exit 0, no errors). Expected push_error output from
negative lifecycle/snapshot tests was explicitly matched by GUT; it was not an
unexpected project error. CR-1 was reproduced in a temporary external script after
autoload initialization; the branch's source and tests were not modified.

The §5 visual feel test, physical mouse/gamepad use and Linux execution were not
performed. Invalid reload has common phase-independent prevalidation; the scene
suite's invalid cases do not enumerate every combination of invalid file and motor
phase. The Builder's separate mutation campaign was not independently rerun.
The uncommitted DECISIONS.md whitespace edit present during review was preserved
and is outside the committed branch diff. Lucas retains the manual playtest, Q4's
Combat follow-up and Gate B. This review leaves CODE_REVIEW and does not set DONE.

---

## 10. Open Questions  ·  _Anyone (append)_

| # | Raised by | Question | Blocking? | Answer (Lucas/Planner) |
|---|---|---|---|---|
| Q1 | Combat | → Art & Game Feel: tile size / pixel scale (CX1). 16 px used via `Units.TILE_SIZE_PX`. | no | |
| Q2 | Combat | → Combat (enemies feature): does the dash pass through enemy bodies or collide with them? F-001 has no enemies, so the player collides with the world layer only. | no | |
| Q3 | Combat | → Direction: `GLOSSARY.md` row "Class" (D-005) — Combat adds it in T10 unless Direction prefers to own it. | no | **Direction:** Combat adds it in T10. |
| Q4 | Builder | → Combat: a 45° dash into a wall slides about the full `dash_distance` along it (Godot `MOTION_MODE_FLOATING` keeps speed), not `distance × cos 45°`. Keep it? | no | |

---

## 11. Director Notes  ·  _Lucas_

<Overrides, priorities, gut calls. Everyone obeys these.>
- **2026-10-31 (PR-10):** T5's API list also includes `get_iframe_window()` exactly as defined in C8. C8 is authoritative. F-001 APPROVED.
