---
id: F-005
title: Ranged caster + minimal projectiles
status: PLAN_CHANGES      # DRAFT | PLAN_REVIEW | PLAN_CHANGES | APPROVED | IN_PROGRESS | CODE_REVIEW | CODE_CHANGES | DONE | PARKED
owner_now: Planner       # who must act next: Planner | Auditor | Builder | Lucas
created: 2026-11-07
updated: 2026-11-07
depends_on: [F-004, D-005, D-007]
pillars: [2]
department: Combat
---

# F-005 — Ranged caster + minimal projectiles

> **How to use this file.** This is the single source of truth for this feature.
> Every agent reads the WHOLE file before acting. Write only in the sections you own
> (see studio/README.md). Never delete another role's text — reply under it.

---

## 1. Goal  ·  _Planner_

**Player-facing outcome (one sentence):**
A caster keeps its distance, shows an aim line that locks before it fires a slow bolt, and
leaves a long recovery after it, so the player learns to dash through bolts, use walls as
cover and close in to punish.

**Why now:** F-004 built the enemy base and the chaser. Floor 2 needs chasers + casters
(F-004 §10 Q3). The caster is the first thing that hits from range, so it also brings the
smallest projectile system that can do that.

**Out of scope (explicitly):**
- The brute (F-006). Enemies with more than one attack, charges, wall stuns.
- Player projectiles (archer, phase 2). `ProjectileSet` is written so a player could own one
  later, but `PlayerMotor` doesn't get one here.
- Homing, piercing, bouncing, splitting, area-on-impact, projectiles with a lifetime instead
  of a distance.
- Anything that destroys or reflects a bolt: sword, dash, parry, other bolts (§3).
- Projectiles hitting enemies or dummies. No friendly fire (F-003/C9).
- Line of sight. The caster fires even when a wall is in the way; the wall eats the bolt.
- Leading the target (aiming where the player will be).
- Pathfinding, strafing, cover-seeking AI. The caster walks straight toward or away.
- Floor 2 encounters, spawners, group sizes (→ Direction, then Floors).
- Final art, aim-line look, bolt look, sound (→ Art & Game Feel). Placeholders only.
- New input actions.

---

## 2. Context  ·  _Planner_

What the Builder needs to know that isn't obvious from the code:
- **Source of truth:** `studio/design/combat.md` → *Enemies (phase 1)* → *Rules shared by every
  enemy* and *Caster* (updated together with this spec), *Hit / hurt system*, *Tunables index*.
- **Existing systems this touches (checked on `main` at `6aef1aa`):**
  - `src/core/combat/combatant.gd` (`Combatant`): `get_live_hitbox()` returns **one** hitbox,
    and `null` while the owner is in hitstop. `tests/scenes/sim_probe.gd` overrides it, so it
    must keep its name and meaning. T1 adds `get_live_hitboxes()` next to it.
  - `src/core/combat/hit_resolver.gd` (`HitResolver.find_candidates`): one hitbox per attacker,
    attackers in registration order, then targets in registration order.
  - `src/core/combat/combat_sim.gd` (`CombatSim._apply_contact`): rechecks only the target, marks
    the hitbox, applies the hit, then `attacker.get_combat_state().apply_landed(event)`, which
    gives the attacker hitstop and emits `hit_landed` (`PlaceholderShake` listens to it).
    `tick(delta, move_bodies)` calls `move_bodies` once per step, after `step()` and
    `fire_due_actions()`, before `_apply_contact()`. Core tests may pass their own callable.
  - `src/core/combat/hitbox.gd` (`Hitbox`): a sector; a 360° arc is a full circle.
    `knockback_from_center = false` pushes along `direction`. `hit_ids` is shared by reference
    with its owner.
  - `src/core/enemies/enemy_logic.gd` (`EnemyLogic`): states `IDLE, CHASE, WINDUP, ACTIVE,
    RECOVERY, KNOCKBACK, DEAD`. Latches the attack at windup start. `_build_live_hitbox()`
    builds the sector during `ACTIVE`. `step()` consumes hitstop first, then advances to exact
    phase ends. `_enter_dead()` runs first on `died`. `SNAPSHOT_KEYS` is a fixed list.
  - `src/core/enemies/enemy_brain.gd` (`EnemyBrain.for_data`, `nearest_player`),
    `chaser_brain.gd`, `enemy_intent.gd` (`move(target, direction, max_distance)`).
  - `src/core/enemies/enemy_data.gd` (`EnemyData.Brain { CHASER }`, validation,
    `validate_against_class`), `enemy_attack_data.gd` (`EnemyAttackData extends AttackData`,
    `ENEMY_SNAPSHOT_KEYS`, `validate_enemy`).
  - `src/entities/enemies/enemy.gd` / `enemy.tscn` (`Enemy extends CombatBody`): one generic
    scene for every enemy, picked by `data`. Static body mode + `_publish_transform()`
    (F-004 DEV-1). Draws the telegraph sector from logic.
  - `src/entities/combat_body.gd` (`move_with_combatant`): moves the body, then
    `sync_position()`. The physics result is authoritative (F-001/C18).
  - `src/world/combat_runner.gd`: reloads every distinct enemy data path found in the scene,
    validates it with `validate(rate, rules)` and `validate_against_class`. Works for a new
    archetype with no change, as long as validation lives in the data classes.
  - `src/ui/debug/combat_debug_draw.gd`: draws each combatant's `get_live_hitbox()`. It already has its own `get_live_hitboxes()` (one entry per combatant), asserted by `tests/scenes/test_f003_views.gd` and `test_f004_debug.gd`. T1 keeps that method's name and makes it concatenate each combatant's `Combatant.get_live_hitboxes()`; scenes without projectiles return the same counts.
  - Collision layers: 1 `world`, 2 `player`, 3 `enemy`. Walls in debug scenes are
    `StaticBody2D` on layer 1, 16 px (1 tile) thick or more.
- **Relevant prior decisions:** D-002 (co-op later), D-005 (classes are data), D-007 (shared step
  grid). D-008 is proposed by this spec (§10 Q1).
- **Relevant prior features:** F-003 (hit rules, contact instants, C16 trades, C19 snapshots),
  F-004 (enemy base, brains, intents, planted rule, C12 data checks). F-004 §3 said a later
  enemy might need brain state; the caster doesn't (§3).

---

## 3. Options Considered  ·  _Planner_

> This section is what stops context loss. Be honest about trade-offs.
> The Builder MUST NOT implement anything listed under Rejected.

### ✅ Chosen: projectiles owned by the combatant that launched them, walls reported by the glue
- **How it works:**
  - A new core class `ProjectileSet` (`RefCounted`, `src/core/combat/`) holds one owner's
    projectiles in launch order. It launches, advances, ends, serializes them and builds their
    hitboxes. `EnemyLogic` owns one. Nothing else in the sim knows projectiles exist, except
    two small `Hitbox` flags read by `CombatSim` (C6).
  - A projectile is a **360° hitbox with a radius**: the attack's own `range_tiles` is the
    bolt's radius and `arc_angle_deg` must be 360. Two new `EnemyAttackData` fields turn an
    attack into a projectile attack: `projectile_speed_tiles` and
    `projectile_max_distance_tiles`.
  - Identity is the owner's id plus a per-owner serial. Snapshots live inside the owner's
    snapshot. Order is the owner's registration order, then serial (C4, C6).
  - **Walls:** core plans each projectile's move for the step. The owner's glue sweeps the
    projectile's circle along that move against the `world` layer and reports where it got to.
    A reported position short of the plan is a wall stop (C5). Core never asks physics.
  - `CasterBrain` is stateless, like `ChaserBrain`. Retreating uses one new `EnemyData` field,
    `retreat_distance_tiles` (0 for the chaser, so it never retreats).
- **Why chosen:**
  - The sim's registration list and snapshot shape stay as they are (F-003/C19). Nothing is
    registered or freed mid-fight.
  - The owner already has every rule a projectile needs: team, latched attack values, death.
    "A dead caster's bolts vanish" is one line in `_enter_dead()`.
  - The wall rule is the same one F-006 needs for the brute's charge ("authoritative position
    falls short of the planned move"), so the project learns one rule, not two.
  - A future player archer can own a `ProjectileSet` without touching the sim.
- **Costs we're accepting:**
  - `Combatant` gets a second hitbox getter, and every hitbox reader must use the plural one.
  - Walls are only known where physics runs. Core tests stop projectiles only through their
    own `move_bodies` callable. A headless server (phase 3–4) must run Godot physics for
    walls, which Godot does anyway.
  - The sweep happens once per step, after logic advanced, so a wall stop is known at the
    step's end, not at its exact instant. A projectile is never more than one step past a wall
    in logic, and it never reaches the contact there (C5).
  - `range_tiles` means "radius" for a projectile attack. One doc comment carries that.
- **Would revisit if:** a projectile needs to outlive its owner (e.g. a boss summon that dies
  while its bolts fly), or one owner fires so many projectiles that per-step sweeps cost too much.

### ❌ Rejected: each projectile is its own `Combatant`, registered at launch
- **How it would work:** launch creates a combatant, registers it with `CombatSim`, and it
  unregisters when it ends.
- **Why rejected:** snapshots are refused when ids or order differ (F-003/C19), the debug
  reset re-runs setup on a fixed list (F-004/C15), and registering mid-tick changes who gets
  sensed and stepped in the current step. All three would need new rules.
- **Tempting because:** the hit resolver, views and debug draw would handle it for free.

### ❌ Rejected: a pool of projectile combatants placed in the scene
- **How it would work:** each scene pre-registers N idle projectile combatants that casters borrow.
- **Why rejected:** scene authors must size a pool per caster, a too-small pool silently drops
  shots, and who-owns-which-slot becomes state shared between combatants.
- **Tempting because:** it keeps the fixed registration list with no API change.

### ❌ Rejected: one sim-owned list of every projectile
- **How it would work:** `CombatSim` holds all projectiles and a new `projectiles` snapshot key.
- **Why rejected:** the sim would need to know about owners' deaths, teams and latched attack
  values. Those rules already live on the owner.
- **Tempting because:** one place for every projectile in the game, player arrows included.

### ❌ Rejected: projectiles as physics nodes (`Area2D`, `CharacterBody2D`) that decide hits
- **How it would work:** a bolt scene with a collision shape; `body_entered` deals damage.
- **Why rejected:** hits would come from physics overlaps, not core (G6, F-003), and their
  timing would follow the physics tick, not the step grid (D-007, C1).
- **Tempting because:** it's how most Godot tutorials make bullets.

### ❌ Rejected: wall geometry stored in core
- **How it would work:** the scene hands core a list of wall rectangles at setup, and core
  tests segments against them.
- **Why rejected:** every level would describe its walls twice, and the two copies drift.
  Floors doesn't exist yet to own that format.
- **Tempting because:** core tests could test walls, and a server wouldn't need physics.

### ❌ Rejected: bolts keep flying after their caster dies
- **How it would work:** a dead caster's bolts finish their flight.
- **Why rejected:** a `DEAD` combatant would still own live hitboxes, breaking F-004/C11
  ("no hitbox after death") and needing special cases in every dead-state rule.
- **Tempting because:** it looks physically right.

### ❌ Rejected: the sword (or anything else) destroys bolts
- **How it would work:** a sword hitbox touching a bolt removes it.
- **Why rejected:** it adds a hitbox-against-hitbox contact the sim doesn't have, and it lets
  the player walk in swinging instead of dashing through (the caster's lesson).
- **Tempting because:** cutting a bolt out of the air feels great. Could come back as a class
  skill in phase 2.

### ❌ Rejected: a bolt hits every player it overlaps (piercing)
- **How it would work:** the bolt's hit set grows like a sword swing's, and it keeps flying.
- **Why rejected:** the design says the bolt disappears on the hit that lands. In co-op one
  bolt could drop two players stacked in a corridor.
- **Tempting because:** it's what the existing hit set already does.

### ❌ Rejected: bolts pause while their caster is in hitstop
- **How it would work:** bolts advance on the caster's clock, so hitting the caster freezes them.
- **Why rejected:** a bolt next to the player would freeze because someone else hit a caster
  10 tiles away. In co-op one player's hit would change another player's dodge timing.
- **Tempting because:** it's what "all of that entity's timers stop" says literally.

### ❌ Rejected: the caster gets hitstop when its bolt lands
- **How it would work:** the existing `apply_landed()` runs on the caster as for melee.
- **Why rejected:** a caster far away pausing for 0.05 s shows nothing readable, and shifts its
  next telegraph for a hit it never felt.
- **Tempting because:** zero code: it's the current `_apply_contact()`.

### ❌ Rejected: a hysteresis band (retreat below 3 tiles, keep backing off until 4)
- **How it would work:** the brain remembers it's retreating until it's back at 4 tiles.
- **Why rejected:** it would be the first brain with state (snapshots, reset, reload), for one
  tile of difference nobody can feel. The design doc's "4–6" band is replaced by 3–6.
- **Tempting because:** it matches the old design-doc wording.

### ❌ Rejected: the caster flees instead of shooting when the player is close
- **How it would work:** below `retreat_distance_tiles`, moving away beats attacking.
- **Why rejected:** a cornered caster would never shoot, so cornering becomes a free kill.
  Shooting point-blank keeps the player honest: read, dodge, then punish.
- **Tempting because:** it looks like smart kiting.

### ❌ Rejected: leading the shot
- **How it would work:** the aim follows where the target will be, from its velocity.
- **Why rejected:** walking straight would always get hit, and the lock cue would point at
  empty floor, which can't be read (principle 1).
- **Tempting because:** it makes the caster look smart.

### ❌ Rejected: a separate `ProjectileData` resource
- **How it would work:** `EnemyAttackData.projectile` points to a resource with radius, speed and
  max distance.
- **Why rejected:** a third file per ranged attack for three numbers, and its own latching,
  validation and snapshot code. `damage`, `knockback_tiles` and `range_tiles` already exist.
- **Tempting because:** cleaner types, no field that means two things.

---

## 4. Constraints  ·  _Planner_

Hard rules for this feature. Violating any of these = automatic `CODE_CHANGES`.

| ID | Constraint | Reason |
|---|---|---|
| C1 | Same scripted inputs at 30, 60 and 120 ticks/s give the same decisions, launches, projectile positions, hits and positions (§5 tolerances). Projectiles advance only inside `step()` on the shared grid. | G1, D-007 |
| C2 | Every number comes from `data/`: `data/enemies/caster.tres`, `data/attacks/caster_bolt.tres`, `enemy_combat.tres`, and shared hit rules from `player_combat.tres` (as F-004). No new tunables file. | G2, G9 |
| C3 | `ProjectileSet`, `CasterBrain` and every rule below live in `src/core/`, with no nodes, physics queries, animation or sprites. Only the glue sweeps against walls (C5). | G6 |
| C4 | **Projectiles.** See below. | design doc |
| C5 | **Walls.** See below. | G6, D-007 |
| C6 | **Combat API.** See below. Every existing hitbox behaves exactly as before. | F-003/C16 |
| C7 | **Caster decisions.** See below. | design doc |
| C8 | **Caster attack.** Everything in F-004/C5 holds (latching, track then lock, rooted, hitstop pauses the timeline, cooldown from recovery end). Differences: the attack's own sector never exists (no hitbox on the caster's body), lunge is 0, and one projectile launches at the exact instant windup ends (C4). Planted (F-004/C7) and death (F-004/C11) hold unchanged. | design doc |
| C9 | **Data validity.** See below. Extends F-004/C12. Bad data is rejected, never clamped. | G2 |
| C10 | All new state is serializable via `to_dict()`/`from_dict()`: every projectile (C4 fields) and the owner's next serial. `EnemyLogic`'s snapshot gains `projectiles` and `next_projectile_serial`; a chaser carries an empty list and 0. Snapshot boundary as F-003/C19. | G7 |
| C11 | **Hot-reload and rate.** A projectile in flight keeps its latched values through any reload. A step-rate change is rejected if a projectile in flight would break C9's tunneling rule at the new rate; the error names the owner and the serial. | F-003/C18 |
| C12 | Presentation is derived from logic (F-003/C12): bolts, aim line, telegraph, open tint. After `from_dict()` or a reset every view re-syncs and no stale bolt is drawn. | F-003/C12 |
| C13 | `EnemyData.Brain` gains `CASTER` **appended** (`CHASER` stays 0). F-001, F-003 and F-004 tests pass unedited. | F-004 |
| C14 | Nothing assumes one player: targets per F-004/C9, and a bolt lands on at most one hurtbox (C4). | D-002 |
| C15 | No new addons, no new input actions, no new collision layers. | G4, F-004/C17 |

**C4 — Projectiles**

- **Launch.** At the exact instant the caster's windup ends (`ACTIVE` starts), on its own clock,
  one projectile appears at the caster's position. Direction = the locked aim. It latches from
  the running attack: `projectile_speed_tiles`, `projectile_max_distance_tiles`, radius
  (`range_tiles`), `damage`, `knockback_tiles`. Its serial is the owner's next serial (0, 1, 2…,
  reset by `setup()`).
- **Movement.** Straight along its direction at constant speed, on the **sim clock**: from the
  launch instant it moves `speed × time`, exactly, inside steps too. It is never paused by its
  owner's hitstop or state, or by anyone else's.
- **Hitbox.** Live at every contact instant while it exists, including the contact where it is
  spent: a 360° circle of its radius at its position, the owner's team, its damage and knockback,
  `is_finisher` false, its own hit set. **Knockback pushes along the flight direction**
  (`knockback_from_center = false`). Never subject to the owner's hitstop.
- **Hits.** Every F-003 rule applies to the target (damage, knockback, hitstop, hurt i-frames,
  dash i-frames, vulnerable dash tail, C16 rechecks). A target skipped by i-frames isn't marked,
  and the bolt flies on; if it still overlaps when the i-frames end, it hits (F-003/C8).
  **Single target:** once it lands on one hurtbox, it lands on no other at that contact.
  **The owner gets no hitstop** from it; its `hit_landed` signal still fires.
- **It passes through every body** (players, enemies, dummies, its owner). Only walls stop it.
- **Ends.**
  - *Max distance:* it stops exactly at `projectile_max_distance_tiles` from its launch point,
    even mid-step, and is **spent**.
  - *Wall:* it stops where C5 says, and is **spent**.
  - A spent projectile gets that step's contact at its final position, then is removed before
    its owner's next step advances. A projectile that **landed a hit** is removed the same way.
  - *Owner death:* removed at the contact instant the owner dies. Candidates were already found
    for that contact, so a hit it found there still lands (F-003/C16).
- **Order.** Projectiles are listed in serial order. Their hitboxes come after the owner's own
  hitbox, if any (C6).

**C5 — Walls**

- Each step, after logic advanced, the glue that owns the projectile's owner sweeps the
  projectile's circle along that step's planned segment (its position before the step, or its
  launch point if it launched during the step, to its planned position) against layer 1 `world`
  only, and reports the position reached (`PhysicsDirectSpaceState2D.cast_motion()` or
  equivalent). This runs inside `CombatSim`'s `move_bodies` call, after the owner's body moved.
- Core compares: a reported position whose distance travelled along the segment is short of the
  plan by more than `Geometry.DISTANCE_EPSILON` is a **wall stop**. The projectile moves to the
  reported position and is spent. Otherwise nothing changes.
- With no glue (core tests), projectiles are stopped only by what a test's `move_bodies`
  callable reports.
- Walls are the only physics a projectile meets. Bodies, other projectiles and hurtboxes never
  stop it.

**C6 — Combat API**

- `Combatant.get_live_hitboxes() -> Array[Hitbox]`: by default the result of `get_live_hitbox()`
  if not null, else empty. `get_live_hitbox()` keeps its meaning (one sector, null in hitstop).
  `EnemyLogic` returns its own sector (if any) followed by its projectiles' hitboxes.
- `HitResolver.find_candidates` reads `get_live_hitboxes()`: attackers in registration order,
  each attacker's hitboxes in its order, then targets in registration order.
- `Hitbox` gains `single_target: bool = false` and `attacker_hitstop: bool = true`. A projectile
  hitbox sets `single_target = true`, `attacker_hitstop = false`.
- `CombatSim._apply_contact`: a `single_target` hitbox that has already marked a hurtbox at this
  contact skips its remaining candidates. When `attacker_hitstop` is false, the attacker's
  `hit_landed` still fires but its hitstop doesn't change.
- `CombatDebugDraw` draws every `get_live_hitboxes()` entry.

**C7 — Caster decisions** (`CasterBrain`, at a free step start, in this order)

1. No living player in the view → `IDLE`.
2. Not aggroed and no living player within `aggro_radius_tiles` → `IDLE`. Aggro on damage and
   "stays aggroed" as F-004/C5.
3. Target per F-004/C9. Cooldown ready and target distance ≤ `attack_range_tiles` → start the
   attack. **Shooting beats retreating**, at any distance.
4. Distance < `retreat_distance_tiles` → move straight away from the target, at most
   `retreat_distance_tiles − distance` this step.
5. Distance > `stop_distance_tiles` → move straight toward it, at most
   `distance − stop_distance_tiles` this step.
6. Otherwise hold still (a move intent of 0 that keeps the target).

Moving or holding is state `CHASE` (no new state). Speed is `move_speed` both ways. Every
comparison uses `DISTANCE_EPSILON` as in F-004/C5 (≤ means `≤ value + ε`, < means
`< value − ε`, > means `> value + ε`; a remaining gap ≤ ε moves 0). A zero direction (same
position) holds still.

**C9 — Data validity** (on top of F-004/C12, at setup and on every reload)

- `EnemyData.retreat_distance_tiles`: `0 ≤ retreat_distance_tiles ≤ stop_distance_tiles`.
- `EnemyAttackData.projectile_speed_tiles ≥ 0`, `projectile_max_distance_tiles ≥ 0`.
- `projectile_speed_tiles = 0` (melee attack): `projectile_max_distance_tiles` must be 0.
- `projectile_speed_tiles > 0` (projectile attack): `arc_angle_deg` must be 360,
  `lunge_tiles` must be 0, `projectile_max_distance_tiles > 0`, and **no tunneling:**
  `projectile_speed_tiles / step_rate ≤ range_tiles` (a projectile moves at most its own radius
  per combat step, so it can't skip over any hurtbox between contacts).
- A brain may only use the attack kind it supports: `CHASER` needs a melee attack, `CASTER` a
  projectile attack.

---

## 5. Acceptance Criteria  ·  _Planner_

Testable, observable. The Auditor checks each one.

**Oracle and tolerances.** As F-004: scripted commands at 30, 60 and 120 ticks/s, changed and
sampled only at multiples of 1/30 s. Positions ± 0.01 tiles, combat times ± 1 µs. Default data
unless stated. Times in seconds.

**Data**
- [ ] AC1 — **Validation:** every C9 bound is tested on both sides, including the tunneling rule
  at 120 and 240 steps/s with the exact limit passing, and both brain/attack-kind mismatches.
  Invalid data fails `setup()` and changes nothing. `chaser.tres` and `chaser_swipe.tres` still
  pass with no edit.
- [ ] AC2 — **Speed rule:** the caster's `move_speed` 2.5 passes against the Warrior's 5.0 at
  scene setup and on reload (F-004/C12, unchanged code path).

**Caster decisions**
- [ ] AC3 — **Band (C7):** cooldown not ready. Target at 2.5 → the caster moves straight away at
  2.5 tiles/s and stops at exactly 3.0. Target at 6.5 → it approaches and stops at exactly 6.0.
  Target anywhere in [3.0, 6.0] → it holds. Boundaries hold at 30, 60 and 120 ticks/s;
  `value ± 1e-4` falls on the expected side.
- [ ] AC4 — **Shooting beats retreating:** cooldown ready, target at 1.0 → windup starts.
- [ ] AC5 — **Aggro and target:** as F-004 AC2–AC3, with two player motors, run for the caster.
- [ ] AC6 — **Caught on foot:** a player walking straight at a retreating caster in open space
  closes the distance (its distance shrinks every step).

**Projectiles**
- [ ] AC7 — **Launch (C4):** exactly one projectile per attack, at the windup-end instant, at the
  caster's position, along the locked aim, with serials 0, 1, 2… The caster's own body never has
  a hitbox.
- [ ] AC8 — **Clock (C4):** a projectile flies `max_distance / speed` = 10/6 s and ends exactly
  10.0 tiles from launch. Hitting its caster with the sword mid-flight (caster in hitstop) changes
  nothing about the projectile's positions.
- [ ] AC9 — **Single target (C4, C14):** two player motors overlapping one projectile at the same
  first contact: only the first registered is hit, and the projectile is gone at the next step.
  Swapping the players' order swaps who is hit.
- [ ] AC10 — **No attacker hitstop (C6):** when a projectile lands, the target gets hitstop and
  the caster's hitstop remaining doesn't change; the caster's `hit_landed` fires once.
- [ ] AC11 — **Knockback direction:** a projectile hitting a player off-center pushes along the
  flight direction, not from the projectile's center.
- [ ] AC12 — **I-frames:** contacts during dash i-frames don't hit and don't mark; a projectile
  still overlapping when the i-frames end hits at the first contact after.
- [ ] AC13 — **Teams and bodies:** a projectile passing over another enemy, a dummy or its own
  caster produces no candidate and keeps flying.
- [ ] AC14 — **Owner death (C4):** killing a caster removes its projectiles at that contact
  instant. A caster killed at a contact where its projectile also touched the player still lands
  that hit, in both registration orders.
- [ ] AC15 — **Wall rule in core (C5):** with a `move_bodies` callable that reports a projectile
  short of its plan by 0.03 tiles, it becomes spent at the reported position, gets that contact,
  and is gone at the next step. A report equal to the plan (or short by ≤ 1e-6) changes nothing.
- [ ] AC16 — **Existing behavior (C6):** every F-003 and F-004 test passes unedited, and a sword
  swing still hits several targets at one contact.

**Frame-rate oracle**
- [ ] AC17 — **Run A, standing still.** Player at (0, 0), never moves or attacks. One caster at
  (0, 6.52), AI on.

      | Time | Expected |
      |---|---|
      | 0 | Windup starts at (0, 6.52), aim (0, −1) |
      | 42/120 (0.35) | Aim locks |
      | 72/120 (0.6) | Active starts. Projectile 0 launches at (0, 6.52), direction (0, −1) |
      | 84/120 (0.7) | Recovery starts |
      | 180/120 (1.5) | Recovery ends, cooldown 1.2 starts. Caster walks toward the player |
      | 191/120 (1.5917) | Projectile at (0, 0.57) lands: player HP 82, player in 0.05 s hitstop, caster not. Player knocked along (0, −1) |
      | 192/120 (1.6) | Projectile 0 is gone |
      | 211.4/120 (1.7617) | Player's knockback ends at (0, −0.5) |
      | 229/120 (1.9083) | Caster reaches distance 6.0 at (0, 5.5) and holds |
      | 324/120 (2.7) | Cooldown ready → second windup at (0, 5.5), aim (0, −1) |

      At 2.75: player HP 82 at (0, −0.5); caster in windup at (0, 5.5); no projectile in flight;
      exactly one hit landed.
- [ ] AC18 — **Run B, dash through.** Same start. At 188/120 (1.5667): dash + move up (0, 1) for
  1/30 s. Contacts 189/120–194/120 overlap the projectile during the dash i-frames and are
  skipped. The dash ends at (0, 3) at 206/120 (1.7167). The caster stops approaching at
  (0, 6.3117) at 190/120 and holds (distance 3.31, inside the band). The projectile reaches max
  distance at (0, −3.48) at 272/120 (2.2667) and is gone at the next step. Second windup at
  324/120 at (0, 6.3117). At 2.75: player HP 100 at (0, 3), no hit landed.
- [ ] AC19 — **Run C, fake wall (core).** As run A, but `move_bodies` reports projectile 0 stopped
  at y = 3.0. It is spent at (0, 3.0) at 143/120, gone at 144/120. At 2.0: player HP 100.
- [ ] AC20 — Runs A and B hold in core at every rate, and once in a scene over real physics at
  every rate (no walls in the projectile's path).

**State and data**
- [ ] AC21 — **Serialization (C10):** snapshot at the C19 boundary with a caster mid-windup
  (before and after lock), in recovery with one projectile in flight, with a spent projectile not
  yet removed, with two projectiles in flight (test data with a short cooldown), after a
  projectile landed, and dead. Restore into fresh objects registered in the same order: the next
  60 ticks match an unbroken run, serials included.
- [ ] AC22 — **Hot-reload (C11):** a valid change to `caster_bolt.tres` while a projectile flies:
  it finishes on latched values, the next one uses the new ones. Invalid values in `caster.tres`
  or `caster_bolt.tres` reject the whole group. A rate change that a projectile in flight can't
  take is rejected and names the caster and serial (test data at 240 steps/s).

**Scene**
- [ ] AC23 — **Walls (C5):** in a scene, a projectile fired at the player standing behind the
  pillar stops at the pillar and never hits. A projectile fired into an outer wall stops there.
  At every contact, a stopped projectile's circle doesn't overlap the wall by more than 0.01 tiles.
- [ ] AC24 — **Views (C12):** during windup a line from the caster along its aim, length
  `projectile_max_distance_tiles`, drawn "tracking", then "locked" from the lock instant. Each
  projectile is drawn as a circle of its radius at its logic position. Recovery is tinted "open"
  (as F-004). The F3 overlay draws projectile hitboxes. After restore and reset, no stale line or
  bolt. Look → Art & Game Feel (§10 Q2).
- [ ] AC25 — **Debug:** I, R and F5 work on casters exactly as on chasers (F-004 AC22). R removes
  every projectile.
- [ ] AC26 — **Coverage map:**
  - **Core tests, no scene** (`tests/core/enemies/`, `tests/core/combat/`): AC1, AC3–AC19, AC21,
    AC22's validation, latching and rate check.
  - **Scene tests** (`tests/scenes/test_f005_*.gd`): AC2, AC20's physics runs, AC22 end to end,
    AC23–AC25.
  - F-001, F-003 and F-004 tests pass unedited.

**How to verify manually (feel test):**
Open `scenes/debug/f005_caster.tscn`. Play about 5 minutes with KB/M, then with a gamepad.
- **One caster.** The aim line should make every shot obvious. When it locks, a step sideways
  should be enough. That should feel calm, not twitchy.
- **Dash through.** Dash *into* a bolt on purpose. Passing through it should feel like a skill
  you just learned, not a lucky frame.
- **Close in.** Walk straight at it. It backs off, but you should always catch it, and its long
  recovery after a shot should feel like the moment to go.
- **Cover.** Stand behind the pillar. Bolts should break on it, and peeking out should feel like
  a choice.
- **Caster + chaser.** The chaser pushes you around while bolts come in. It should be busy but
  readable, and killing the caster first should feel like the smart call.
- Tune `projectile_speed_tiles`, `windup` or `aim_track_time`, press F5, and feel the difference.

---

## 6. Task Breakdown  ·  _Planner_

Small, ordered, each independently committable.

| # | Task | Files likely touched | Notes |
|---|---|---|---|
| T1 | Combat API, no behavior change | `src/core/combat/hitbox.gd`, `combatant.gd`, `hit_resolver.gd`, `combat_sim.gd`, `src/ui/debug/combat_debug_draw.gd` | C6. `get_live_hitboxes()`, the two `Hitbox` flags, single-target skip, optional attacker hitstop. All F-003/F-004 tests pass unedited. New tests for both flags with stub hitboxes. |
| T2 | `ProjectileSet` | `src/core/combat/projectile_set.gd` | C4. Launch, advance on the sim clock (exact within a step), max-distance end, `report_position()` for C5, spent/landed removal before the next advance, `clear()`, hitboxes, `to_dict()`/`from_dict()`, running-rate errors (C11). No `EnemyLogic` dependency, so a player could own one later. |
| T3 | Data types | `src/core/enemies/enemy_attack_data.gd`, `enemy_data.gd` | C9. `projectile_speed_tiles`, `projectile_max_distance_tiles` (added to `ENEMY_SNAPSHOT_KEYS`), `retreat_distance_tiles`, `Brain.CASTER` appended. Doc comment: `range_tiles` is the radius for a projectile attack. |
| T4 | Data files | `data/enemies/caster.tres`, `data/attacks/caster_bolt.tres` | Values from the design doc's *Tunables index*. |
| T5 | `EnemyLogic` integration | `src/core/enemies/enemy_logic.gd` | Owns a `ProjectileSet`. Launch at the windup→active crossing (C8). No own sector for a projectile attack. Projectiles advance by the full step duration, before the hitstop-consuming timeline. `get_live_hitboxes()` per C6. `_enter_dead()` clears them. Snapshot keys per C10. `get_running_window_errors()` adds C11. `setup()` resets the set and serial. |
| T6 | `CasterBrain` | `src/core/enemies/caster_brain.gd`, `enemy_brain.gd` | C7. Stateless. Factory maps `Brain.CASTER`. |
| T7 | Core tests | `tests/core/combat/test_projectile_set.gd`, `test_hit_flags.gd`, `tests/core/enemies/test_caster_brain.gd`, `test_caster_attack.gd`, `test_caster_snapshot.gd`, `test_caster_oracle.gd` | AC26's core row. Real `PlayerMotor`s as targets, two for AC5/AC9. |
| T8 | Glue + views | `src/entities/enemies/enemy.gd` (and `enemy.tscn` if a child view node is needed) | C5 sweep in `move_with_combatant()` after the body moves, against layer 1 only, one sweep per projectile in serial order, reporting each result to logic. Aim line, projectile circles (global positions, e.g. a top-level child), all from logic (C12). |
| T9 | Debug scene | `scenes/debug/f005_caster.tscn` | Walled room with one 2×2-tile pillar. Player; `caster_1` about 6 tiles away with a clear line; `caster_2` behind the pillar from the player's start; `chaser_1` further back. `CombatRunner` last, `refill_player_on_died` on. Shake and overlay as in F-004's scene. |
| T10 | Scene tests | `tests/scenes/test_f005_*.gd` | AC26's scene row. `user://` data copies for reload, like F-004. |
| T11 | Glossary | `studio/GLOSSARY.md` | Add: Projectile, Spent (projectile), Retreat distance. Update Hitbox (single target, attacker hitstop). |

---

## 7. Plan Review  ·  _Auditor_

<Each completed round starts with its machine line (format in AGENTS.md), then its findings.
Severity: 🔴 blocking · 🟡 should fix · 🔵 suggestion. Example finding:>

### PR-1 🔴 <title>
<What's wrong, where, why it matters, what you'd suggest.>
> **Planner reply:** <accepted / rejected + reason / changed §X>

<!-- review-round: 1 verdict: CHANGES_REQUESTED -->

**Verdict:** CHANGES_REQUESTED

The goal clearly serves pillar 2, scope exclusions are explicit, and the alternatives have
specific trade-offs. The caster rules and starting values match the updated combat design.
D-008 is explicitly proposed for Lucas at Gate A. Two edge cases in the new contracts need
decisions before implementation; two acceptance/wording issues also need clarification.

### PR-1 🔴 Rate changes must check bolts still waiting to launch

**Location:** §4 C8/C11, §5 AC22, §6 T5; existing
`src/core/enemies/enemy_logic.gd::_running_window()`.

**Problem:** C11 checks projectiles already in flight, but C8 also latches projectile values
at windup start. Start a windup at 240 steps/s with speed 60 and radius 0.25: the displacement
bound passes exactly. Before launch, reload to 120 steps/s and replace the authored speed
with 30. The candidate data passes, existing phase-duration checks pass, and no projectile
exists for C11 to reject. The pending attack nevertheless launches its latched speed-60 bolt,
which moves 0.5 tiles per step and violates C9's 0.25-tile limit.

**Why it matters:** A valid, atomic F5 reload can put the simulation outside its mandatory
projectile movement bound. Checking only the replacement resource or existing projectiles
does not protect a latched attack.

**Suggested fix:** Extend the running-rate check to the latched projectile attack in
`WINDUP`, as well as projectiles in flight. Reject the entire reload when either fails;
identify the owner and pending attack in the error. Add an AC22 core and end-to-end reload
case with valid replacement data, no projectile launched yet, and the 240→120 example above.

### PR-2 🔴 Wall feedback cannot represent a bolt born overlapping a wall

**Location:** §4 C4 launch/ends, C5 and C9; §5 AC23; §6 T8.

**Problem:** C9 permits a bolt radius larger than its owner's body. For example, radius 0.5
and the default caster hurtbox/body radius 0.35 are valid, so a caster beside a pillar can
launch a circle already overlapping it. Godot's [`cast_motion()` documentation](https://docs.godotengine.org/en/stable/classes/class_physicsdirectspacestate2d.html#class-physicsdirectspacestate2d-method-cast-motion)
states that initial overlaps are ignored. C5 specifies no initial-overlap handling, and its
shorter-position report cannot express a stop when launch falls exactly at the step end:
the planned segment then has length zero.

**Why it matters:** Valid tuning can let a bolt pass through cover or reach contact already
penetrating a wall, contrary to the goal and AC23. Merely adding a sweep does not close this
case, and the Builder would have to invent both the feedback and hit-contact policy.

**Suggested fix:** Define a blocked-launch outcome: the glue checks initial wall overlap,
including zero-length launch segments, and explicitly reports a blocked launch so core
suppresses that projectile before contact. Keep the specified final contact for bolts that
reach a wall during flight. Align C4/C5 and the D-008 proposal with that exception, and add
core/scene acceptance cases for the larger-radius caster beside a wall, with launch both on
and between contact instants.

### PR-3 🟡 The catchability test needs initial conditions and an observation interval

**Location:** §5 oracle defaults and AC6; `data/classes/warrior.tres`;
`src/core/player/player_motor.gd::_integrate_movement()`.

**Problem:** AC6 requires distance to shrink every step but does not say whether the Warrior
is already moving, how the caster is kept retreating rather than shooting, or when sampling
ends. With default data and the Warrior starting at rest, its 0.05 s acceleration ramp moves
it only 0.003472 tiles in the first 1/120 s; a retreating caster moves 0.020833 tiles. The gap
initially grows by 0.017361 tiles even though the player subsequently catches it.

**Why it matters:** A literal test fails unchanged F-001 movement, while a passing test needs
unstated setup choices. Continuing past the catch would also invalidate monotonic separation.

**Suggested fix:** Specify player initial velocity/full-strength input, caster cooldown, and
the interval ending at melee reach. Either pre-accelerate the player before requiring
per-step closure, or retain the normal ramp and assert a concrete catch time instead.

### PR-4 🟡 The displacement bound does not guarantee every intervening overlap is detected

**Location:** §4 C9 projectile bound and its rationale; §5 AC1;
`studio/design/combat.md` → Caster → Projectiles.

**Problem:** Moving at most one bolt radius per step cannot guarantee that a bolt never skips
any hurtbox between contacts. With bolt radius 0.25, speed 30 and rate 120, take successive
contact positions (-0.125, 0) and (0.125, 0), and a stationary Warrior at (0, 0.599) with its
default radius 0.35. Both endpoint separations are about 0.6119 (> 0.6), but the middle
separation is 0.599 (< 0.6). C9 passes exactly, yet the grazing overlap gets no candidate.

**Why it matters:** The numerical validation AC is achievable, but its stated continuous
collision guarantee exceeds the chosen contact-instant model. The Builder needs to know
whether such misses are accepted rather than silently adding a different hit model.

**Suggested fix:** Retain the explicit displacement bound, describe it as a sampling limit,
and explicitly accept overlaps that exist only between contact instants under D-007. Update
the matching design-doc wording and add a boundary example that distinguishes the bound from
a swept-hit guarantee.

**Verification:** Read the complete feature, studio workflow, PROJECT/DECISIONS, Combat brief,
design and glossary; checked the inherited F-003/F-004 contracts and relevant core, glue,
reload and snapshot code. Independently calculated the rate, acceleration and grazing
examples, and checked the official Godot wall-query contract. No source or tests changed.

---

## 8. Implementation Log  ·  _Builder_

**Started:** YYYY-MM-DD  ·  **Branch:** `feature/F-005-caster`

### Progress
- [ ] T1 — <commit hash when done>
- [ ] T2

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

<Each completed round starts with its machine line (format in AGENTS.md), then
`**Reviewed commit:** <hash>`, AC evidence and findings. Example finding:>

### CR-1 🔴 <title>  ·  `path/to/file:line`
<problem, why it matters, suggested fix>
> **Builder reply:** <fixed in abc123 / disagree because …>

---

## 10. Open Questions  ·  _Anyone (append)_

| # | Raised by | Question | Blocking? | Answer (Lucas/Planner) |
|---|---|---|---|---|
| Q1 | Combat | → Direction: projectile ownership and "a wall stop is the glue's reported position falling short of the plan" will also shape the brute (F-006), bosses and the phase-2 archer. Accept as D-008 (proposal delivered with this spec)? | no | **Direction:** D-008 added to `DECISIONS.md` as PROPOSED; recommended for acceptance. Lucas decides at Gate A. |
| Q2 | Combat | → Art & Game Feel: look and sound of the caster's aim line (tracking vs locked), the bolt, and the bolt breaking on a wall. Placeholders here (design doc CX5). | no | |

---

## 11. Director Notes  ·  _Lucas_

<Overrides, priorities, gut calls. Everyone obeys these.>
