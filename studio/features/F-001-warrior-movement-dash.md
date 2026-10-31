---
id: F-001
title: Warrior movement + dash
status: PLAN_REVIEW            # DRAFT | PLAN_REVIEW | PLAN_CHANGES | APPROVED | IN_PROGRESS | CODE_REVIEW | CODE_CHANGES | DONE | PARKED
owner_now: Auditor       # who must act next: Planner | Auditor | Builder | Lucas
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
    the same verb; see GLOSSARY "Dash"). Only add `aim_left/right/up/down` (right stick)
    and `debug_reload_tunables` (F5).
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
  - `Player` (`CharacterBody2D`) is glue: each physics tick it feeds commands to the motor,
    calls `motor.tick(delta)`, sets `velocity` from the motor, calls `move_and_slide()`,
    then writes the resulting position back into the motor state.
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
| C1 | All timing and movement use `delta` and tick in `_physics_process`. Same inputs give the same result (within tolerance) at 30, 60 and 120 ticks/s. | G1 |
| C2 | No movement/dash number in code. Every value comes from `data/classes/warrior.tres` or `data/tunables/player_combat.tres`. Fixed rules (e.g. "i-frames start at dash start") are behavior, not numbers. | G2, D-005 |
| C3 | `src/core/` scripts extend only `RefCounted` or `Resource`. They never call `Input`, never reference `Node`, sprites, animation or the scene tree. The core purity check from F-000 passes. | G6 |
| C4 | The motor changes state **only** through commands and `tick(delta)`. Input handlers never call motor methods other than submitting commands. | G8 |
| C5 | Motor state (position, velocity, facing, motor state, all timers, buffered dash) round-trips through `to_dict()` / `from_dict()` with no loss. | G7 |
| C6 | No global or static mutable state in the motor. Two motors in the same scene must be fully independent. | D-002 (co-op) |
| C7 | Values are stored in tiles and seconds. Tile → pixel conversion happens in one place (`TILE_SIZE_PX` constant). | CX1 pending |
| C8 | I-frames start at the dash's first tick and last `dash_iframe_duration`. The dash tail (after i-frames end, before dash ends) is **vulnerable**. | CQ3 |
| C9 | Dash cooldown starts **when the dash ends**, not when it starts. | design/combat.md |
| C10 | During a dash, movement input is ignored and the dash direction is fixed. | Readability: committed dodge |
| C11 | No new addons or dependencies. | G4 |
| C12 | F-000 input actions keep their names and bindings. No `dash` action — the dash uses `dodge`. | F-000 must-not-break |
| C13 | Hot-reload swaps data without resetting motor state (position, timers, buffer survive). | AC16 |

**Must not break:** F-000 tooling. `tools/test`, `tools/lint` and the core purity check
all pass.

---

## 5. Acceptance Criteria  ·  _Planner_

Testable, observable. The Auditor checks each one. "Tolerance" = one tick of travel.

- [ ] AC1 — **Movement speed:** Given a full-magnitude input in any of the 8 directions,
      when held for 1 s in open space, then the Warrior travels `move_speed` tiles
      (± tolerance, accounting for accel). Diagonal is **not** faster than cardinal
      (input vector length is clamped to 1).
- [ ] AC2 — **Analog:** Given a stick input with magnitude m (deadzone < m ≤ 1), target
      speed = `move_speed × m`. Below `stick_deadzone`, input counts as zero.
- [ ] AC3 — **Accel/decel:** From standstill, the Warrior reaches full speed after
      `move_accel_time`. From full speed with no input, it stops after `move_decel_time`.
      With either value at 0, the change is instant on the next tick.
- [ ] AC4 — **Facing (KB/M):** When the mouse was the last used aim device, facing = unit
      vector from Warrior to mouse world position, updated every tick, also while moving
      and dashing.
- [ ] AC5 — **Facing (gamepad):** When a gamepad was the last used device: right stick above
      deadzone → facing = right stick direction; else movement input direction; else facing
      keeps its last value. Facing never changes on its own.
- [ ] AC6 — **Dash direction:** Dash goes in the current movement input direction. With no
      movement input, it goes in the facing direction.
- [ ] AC7 — **Dash travel:** In open space, a dash covers `dash_distance` tiles
      (± tolerance) in `dash_duration` seconds, at constant speed.
- [ ] AC8 — **Dash and walls:** A dash into a wall stops at the wall (slides along it if at
      an angle). The Warrior never ends up inside or through world geometry.
- [ ] AC9 — **I-frames:** `is_invulnerable()` is true from the dash's first tick until
      `dash_iframe_duration` has elapsed, then false for the rest of the dash and after.
- [ ] AC10 — **Dash end:** When the dash ends, no dash momentum carries over. Velocity
      continues from the current movement input using normal accel rules (from standstill
      if there is no input).
- [ ] AC11 — **Cooldown:** After a dash ends, another dash can't start until
      `dash_cooldown` has elapsed.
- [ ] AC12 — **Buffer:** A dash pressed during a dash or cooldown is stored. It fires on the
      first tick a dash is allowed **if** it was pressed no more than `input_buffer_window`
      seconds before that tick; otherwise it is discarded. Only one dash is buffered; a
      newer press replaces it. Direction is read when the dash **fires**, not when pressed.
- [ ] AC13 — **Frame-rate independence:** The same scripted command sequence ticked at 30,
      60 and 120 ticks/s ends at the same position (± tolerance), with the same
      invulnerability windows (± one tick).
- [ ] AC14 — **Serialization:** Serializing the motor mid-dash, mid-cooldown and with a
      buffered dash, then restoring into a fresh motor, gives identical behavior over the
      next 30 ticks.
- [ ] AC15 — **Independence:** Two motors ticked side by side with different commands don't
      affect each other.
- [ ] AC16 — **Hot-reload:** In the debug scene, the `debug_reload_tunables` action (F5)
      reloads `warrior.tres` and `player_combat.tres` from disk (cache ignored) and applies
      them through `PlayerMotor.apply_data()` immediately — no scene restart, and the motor's
      current state (position, timers, buffered dash) is kept.
- [ ] AC17 — **Tests and lint:** GUT tests cover AC1–AC15 at core level; `tools/test`,
      `tools/lint` and the core purity check pass.

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
| T1 | Unit conversion | `src/core/units.gd` (`Units`) | `TILE_SIZE_PX := 16` (CX1 pending) + `tiles_to_px()`, `px_to_tiles()`. Comment: `# CX1: tile size pending Art & Game Feel`. |
| T2 | Data resource types | `src/core/classes/class_data.gd` (`ClassData`), `src/core/tunables/player_combat_tunables.gd` (`PlayerCombatTunables`) | `ClassData`: `id: StringName`, `display_name: String`, `weapon_family: StringName`, `move_speed`, `move_accel_time`, `move_decel_time`, `dash_distance`, `dash_duration`, `dash_iframe_duration`, `dash_cooldown`. `PlayerCombatTunables`: `input_buffer_window`, `stick_deadzone`. All `@export`, typed. Later features add fields; don't add unused ones now. `# D-005` on `ClassData`. |
| T3 | Data files | `data/classes/warrior.tres`, `data/tunables/player_combat.tres` | Values from the *Tunables index* in design/combat.md. `warrior`: `id = &"warrior"`, `weapon_family = &"sword"`. `stick_deadzone = 0.2`. Paths as constants (G5). |
| T4 | Commands | `src/commands/command.gd` (base), `move_command.gd`, `aim_command.gd`, `dash_command.gd` | Plain data, all extend `Command` (`RefCounted`). `MoveCommand(direction: Vector2)` (already deadzoned, length ≤ 1). `AimCommand(direction: Vector2)` (unit vector or zero = "no aim input"). `DashCommand()`. `DashCommand` is produced from the `dodge` input action. |
| T5 | `PlayerMotor` core | `src/core/player/player_motor.gd` | States: `IDLE`, `MOVING`, `DASHING`. Holds position, velocity, facing, timers, buffered dash + its age. API: `setup(class_data, tunables)` (= `apply_data` + reset state), `apply_data(class_data, tunables)` (swap data, keep state — AC16), `submit(command)`, `tick(delta)`, `get_velocity_px()`, `set_position_px()`, `is_invulnerable()`, `get_state()`, `to_dict()`, `from_dict()`. Signals (past tense): `dash_started`, `dash_ended`, `invulnerability_changed(is_invulnerable)`. Accel/decel = linear `move_toward` on velocity; time 0 = instant. |
| T6 | Core tests | `tests/core/player/test_player_motor.gd` | One or more tests per AC1–AC3 and AC6–AC15, using scripted commands. No scene needed. Walls (AC8) are tested in T9 manually, not here. |
| T7 | Input reader | `src/entities/player/player_input.gd`, `project.godot` input map | Reuse F-000 actions `move_*` (all existing bindings, incl. D-pad) and `dodge` (Space + A) → `DashCommand`. Add only `aim_left/right/up/down` (right stick, deadzone 0.2) and `debug_reload_tunables` (F5) (C12). Tracks last used device for facing (AC4/AC5). Converts mouse position to an aim direction relative to the player. Outputs commands only. |
| T8 | Player glue | `src/entities/player/player.gd` (`Player`, `CharacterBody2D`), `player.tscn` | Per tick: commands → motor → `tick` → `velocity` → `move_and_slide()` → write position back. Placeholder: colored circle + facing line. Collides with world layer only. Logic never reads the visuals. |
| T9 | Debug scene + overlay (+ `Tunables.player_combat`) | `scenes/debug/f001_movement.tscn`, `src/ui/debug/motor_debug_overlay.gd` | Room ~30×20 tiles with walls and a few pillars (angled corner too). Simple follow camera. Overlay: state, velocity (tiles/s), facing, i-frame flag (+ tint on player while invulnerable), cooldown remaining, buffered dash yes/no, last device, ticks/s. F5 reloads both `.tres` with cache ignored (AC16). |
| T10 | Glossary | `studio/GLOSSARY.md` | Add rows: Dash, I-frames, Facing, Input buffer, Class (see §11 note if Direction objects). |

---

## 7. Plan Review  ·  _Auditor_

**Verdict:** `PENDING` <!-- APPROVE | APPROVE_WITH_NOTES | CHANGES_REQUESTED -->
**Reviewed:** YYYY-MM-DD

Findings (severity: 🔴 blocking · 🟡 should fix · 🔵 suggestion):

### PR-1 🔴 <title>
<What's wrong, where, why it matters, what you'd suggest.>
> **Planner reply:** <accepted / rejected + reason / changed §X>

---

## 8. Implementation Log  ·  _Builder_

**Started:** YYYY-MM-DD  ·  **Branch:** `feature/F-001-warrior-movement-dash`

### Progress
- [ ] T1 — 
- [ ] T2
- [ ] T3
- [ ] T4
- [ ] T5
- [ ] T6
- [ ] T7
- [ ] T8
- [ ] T9
- [ ] T10

### Deviations from plan
<Every place the code differs from §3–§6, with reason. "None" if none.>
- DEV-1: <what changed> — **Why:** <reason> — **Impact:** <what else this affects>

### Assumptions made (small, reversible)
- ASSUMPTION-1: <the gap in the spec> → <what I chose> — **Why:** <reason>

### Things the Auditor should look at closely
- <tricky spots, edge cases you're unsure about>

### How to test
<exact steps / commands / scene to run>

---

## 9. Code Review  ·  _Auditor_

**Verdict:** `PENDING` <!-- APPROVE | APPROVE_WITH_NOTES | CHANGES_REQUESTED -->
**Reviewed commit:** <hash>  ·  **Round:** 1

### Checklist
- [ ] Every AC in §5 met (state evidence per AC below)
- [ ] No Rejected option from §3 implemented, even partially
- [ ] All constraints in §4 and PROJECT.md respected
- [ ] Every deviation in §8 is justified; no undocumented deviations
- [ ] Assumptions in §8 are sane

### AC evidence
- AC1: ✅/❌ <where in the code / how verified>

### Findings
### CR-1 🔴 <title>  ·  `path/to/file:line`
<problem, why it matters, suggested fix>
> **Builder reply:** <fixed in abc123 / disagree because …>

---

## 10. Open Questions  ·  _Anyone (append)_

| # | Raised by | Question | Blocking? | Answer (Lucas/Planner) |
|---|---|---|---|---|
| Q1 | Combat | → Art & Game Feel: tile size / pixel scale (CX1). 16 px used via `Units.TILE_SIZE_PX`. | no | |
| Q2 | Combat | → Combat (enemies feature): does the dash pass through enemy bodies or collide with them? F-001 has no enemies, so the player collides with the world layer only. | no | |
| Q3 | Combat | → Direction: `GLOSSARY.md` row "Class" (D-005) — Combat adds it in T10 unless Direction prefers to own it. | no | **Direction:** Combat adds it in T10. |

---

## 11. Director Notes  ·  _Lucas_

<Overrides, priorities, gut calls. Everyone obeys these.>
