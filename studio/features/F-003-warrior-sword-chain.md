---
id: F-003
title: Warrior sword chain + hit/hurt + hitstop + training dummy
status: DONE                 # DRAFT | PLAN_REVIEW | PLAN_CHANGES | APPROVED | IN_PROGRESS | CODE_REVIEW | CODE_CHANGES | DONE | PARKED
owner_now: Lucas     # who must act next: Planner | Auditor | Builder | Lucas
created: 2026-11-01
updated: 2026-11-01
depends_on: [F-000, F-001, D-002, D-005]
pillars: [2]
department: Combat
---

# F-003 — Warrior sword chain + hit/hurt + hitstop + training dummy

> **How to use this file.** This is the single source of truth for this feature.
> Every agent reads the WHOLE file before acting. Write only in the sections you own
> (see studio/README.md). Never delete another role's text — reply under it.

---

## 1. Goal  ·  _Planner_

**Player-facing outcome (one sentence):**
The Warrior swings a readable 3-hit sword chain at a training dummy. Every hit lands with
a short per-entity hitstop, a screen shake and a damage number, and a dash can cancel any
swing's recovery.

**Why now:** F-001 gave us the dodge. Attacking is the other half of pillar 2, and every
later feature (enemies F-004, bosses) plugs into the hit/hurt system built here. The dummy
lets Lucas tune the swings before any AI exists.

**Out of scope (explicitly):**
- Enemies with AI, movement or attack patterns (F-004). The dummy never moves on its own and never chooses to attack.
- Player death flow and return to town (D-006). In this feature, player HP at 0 only emits `died`, and the debug scene refills HP.
- Final art, animation, hit flash style, sound, VFX. Placeholders only (→ Art & Game Feel).
- Screen-shake *look*. Only a placeholder camera shake exists to verify the events.
- A settings menu. The shake on/off toggle is a debug key plus a data flag.
- Lunges or any forward movement during attacks.
- Body-to-body collision. Players and dummies pass through each other. F-001 left this to the enemy feature, so F-004 decides it.
- Hyper armor, parry, perfect-dodge rewards, crits, damage types, gear-modified damage (phase 2).
- Other classes and weapons.

---

## 2. Context  ·  _Planner_

What the Builder needs to know that isn't obvious from the code:
- **Source of truth:** `studio/design/combat.md` → *Sword attack chain*, *Hit / hurt system*, CQ7, CQ8, *Rejected*, *Tunables index*.
- **Existing systems this touches:**
  - `src/core/player/player_motor.gd` (`PlayerMotor`) from F-001: states, dash, input buffer, `to_dict`/`from_dict`.
  - `src/entities/player/player.gd`, `player.tscn`, the player input reader.
  - `data/classes/warrior.tres` (`ClassData`) and `data/tunables/player_combat.tres` (`PlayerCombatTunables`).
  - The input map (checked on `main` by Direction): `attack` already exists from F-000 (J + left mouse, gamepad X/west) — **reuse it, don't change its bindings**. Dash is `dodge`. F5 is `debug_reload_tunables` (F-001). New in this feature: only `debug_pulse_toggle` (P), `debug_shake_toggle` (K), `debug_reset` (R).
  - `tests/test_input_map.gd` asserts the exact action set: T4 extends it with the three new actions and keeps every existing assertion (same migration as F-001 PR-7).
  - Per-tick ownership today: `Player._physics_process` runs its own commands → motor → `move_and_slide`. T13 moves this into one scene-level runner; F-001's scene and its tests (incl. `tests/scenes/test_f001_*`) must keep passing without being edited.
  - F-001's debug overlay and the F5 tunable hot-reload.
- **F-001 code that constrains this plan (checked on `main`):**
  - `tests/core/player/test_data_validation.gd` builds `ClassData` and `PlayerCombatTunables` by hand with F-001 fields only, and asserts exact error counts. So `validate()` keeps its F-001 rules, and the new rules go in a separate `validate_combat()` (C18).
  - Tests call `motor.tick(delta)` directly, and submit commands once per physics tick. `tick()` keeps its exact F-001 behavior, and sub-steps use a new `step()` (T5).
  - `Player._load_ignoring_cache` uses `CACHE_MODE_IGNORE`, which still takes external dependencies from the cache. `warrior.tres` now references the attack files, so the reload must use `CACHE_MODE_IGNORE_DEEP`, or edits to attack files are silently ignored.
  - `MotorDebugOverlay` reads `player.velocity`. With several `move_and_slide()` calls per tick, that holds only the last step's share, so the overlay reads the motor's velocity instead (T16).
  - `MotorDebugOverlay` handles F5 by calling `player.reload_data()`, and F-001's scene keeps that path. It must never change the combat step rate behind the sim's back (C18, T16).
- **Relevant prior decisions:**
  - D-002 — online-ready architecture. Hitstop must never freeze other entities. Shake must be a per-player presentation effect.
  - D-005 — the chain is class data: `ClassData` holds an ordered list of attack resources.
  - D-007 — **PROPOSED by this plan.** Combat runs on a shared step grid (C15). Approving this plan at Gate A accepts it (§10 Q4).
- **Carry-over from the F-001 code review:** the invulnerability tint can stay stuck after restoring a snapshot, in `src/entities/player/player.gd`. The tint follows the `invulnerability_changed` signal, and `from_dict()` restores state without the visuals re-syncing. Fixed in T1, with a general rule (C12).
- **Relevant prior features:** F-000 (tooling), F-001 (movement + dash).

---

## 3. Options Considered  ·  _Planner_

> This section is what stops context loss. Be honest about trade-offs.
> The Builder MUST NOT implement anything listed under Rejected.

### ✅ Chosen: Geometric hit detection in core, stepped on a shared combat grid
- **How it works:**
  - Hurtboxes are circles: position, radius, team and owner id. Hitboxes are sectors: origin, locked direction, arc angle and range. A full circle is a sector with a 360° arc.
  - `CombatSim` (`RefCounted`, `src/core/combat/`) is created once per scene by glue, never as an autoload. It owns one `HitResolver` and the ordered list of combatants (player motors and dummy logic).
  - Every physics tick is split into equal **combat steps** of at most `1 / combat_step_rate` seconds. At the default rate of 120, 30/60/120 ticks/s run 4/2/1 steps, so all three rates sample the same instants (C15, D-007).
  - In each step, every combatant advances, the bodies move, and the end of the step becomes the **contact instant**. There, `HitResolver` tests each live hitbox against every hurtbox of another team, using an exact circle–sector intersection, and returns ordered **candidates**. `CombatSim` then applies them one at a time, rechecking the target (C16).
  - Hits are applied in this order:
    1. damage
    2. knockback
    3. per-entity hitstop on attacker and target
    4. hurt i-frames on the target (player only)
  - Logic emits signals (`hit_landed`, `damaged`, `died`). Presentation listens and draws the number, the flash and the shake.
- **Why chosen:**
  - The design doc says hits come from shapes and timers, not animation (G6).
  - Pure geometry is unit-testable without a scene, serializable (G7) and deterministic. That last point matters for co-op later.
  - A shared grid makes every rate see the same instants, so the hard timing problems go away. No rate can skip a phase, no intervals need mapping between entity clocks, and each query is simply "what is this entity's state now?"
  - A sim per scene, with no global, keeps C6 from F-001.
- **Costs we're accepting:**
  - Hitboxes don't use Godot physics, so walls don't block sword arcs. That's acceptable at sword range.
  - Collision shapes are limited to circles and sectors.
  - The test is O(hitboxes × hurtboxes) per step, which is fine for phase 1 counts.
  - Contact timing is quantized to 1/120 s. That's under one 60 Hz frame, and a dash covers about 0.17 tiles per step, which is much less than any hurtbox.
  - `move_and_slide()` runs several times per physics tick, and the motor gains a `step()` / `finish_tick()` pair.
  - A physics rate that doesn't divide `combat_step_rate` samples slightly different instants. The game runs at 60, and C1 only promises 30, 60 and 120.
  - A hit or pulse with no lead-in time needs two steps of active time, so 1/120 s with zero windup is rejected as data. The default values are far above that.
  - A reload that lowers `combat_step_rate` can be refused while a short hit or pulse is running. Pressing F5 again after it finishes works.
- **Would revisit if:** bosses need shapes that aren't circles or sectors (lines, rectangles), or entity counts make per-step testing slow. Either way, add the new shape types to the resolver; don't switch to Area2D.

### ❌ Rejected: Resolve once per physics tick, at the end of the tick
- **How it would work:** the F-001 flow stays as it is: tick every entity for the whole `delta`, then test hits once.
- **Why rejected:**
  - The result depends on the tick rate. A contact at 0.12 s in the vulnerable dash tail falls in the 30 Hz tick [0.10, 0.1333), which started inside the i-frames, so it could be rejected at 30 Hz and accepted at 120 Hz (G1).
  - An active phase shorter than a tick can vanish before the resolver sees it.
  - F-001/C8 and pillar 2 both depend on that tail being exact.
- **Tempting because:** it's the simplest loop, and it needs no change to the motor's API.

### ❌ Rejected: Solving exact contact times inside a tick
- **How it would work:** the motor records its active and vulnerable intervals, and the resolver computes the exact moment shapes first touch.
- **Why rejected:**
  - A hit at time `t` changes both entities after `t` (hitstop, knockback, interruption), and that part of the tick has already been simulated. It would need rollback.
  - Moving shapes need swept collision, and each entity's clock would have to be mapped to scene time.
  - All of that buys precision nobody can feel below 1/120 s.
- **Tempting because:** it matches the "exact time" wording of F-001/C8, and looks like the purest answer.

### ❌ Rejected: An extra contact check at the instant an action starts
- **How it would work:** right after a press or toggle starts an attack or pulse, run one more contact at that instant, so a window `[T, T + 1/120)` is sampled at T.
- **Why rejected:**
  - The timeline would have two kinds of contact, and "the end of the step" would stop being the only place hits are decided.
  - Presses fire inside the first step and toggles act between ticks, so each would need its own hook.
  - It only serves a window with no lead-in that lasts a single step, an 8 ms swing nobody would tune on purpose.
- **Tempting because:** every duration stays legal, and an instant attack lands on the exact press instant.
- **Instead:** C18 rejects durations with no guaranteed contact.

### ❌ Rejected: Deferring a step-rate change until nothing is running
- **How it would work:** a reload that lowers `combat_step_rate` applies everything else now, and keeps the new rate waiting until no hit or pulse is running.
- **Why rejected:**
  - It splits one atomic reload in two (C18).
  - The waiting rate becomes new state to serialize and show.
  - A pulse with no wait between cycles would keep it waiting forever.
- **Tempting because:** F5 would never be refused.
- **Instead:** the whole reload is rejected, the overlay says why, and F5 works again once that hit or pulse has finished.

### ❌ Rejected: Recovery dash cancel that bypasses the dash cooldown
- **How it would work:** a dash pressed during recovery always fires instantly.
- **Why rejected:** chaining swing → dash → swing → dash would make the player permanently safe, which removes both the cooldown (F-001 AC11) and the punish window of the player's own attacks (pillar 2).
- **Tempting because:** "instantly, every time" feels great, and it's one less condition.

### ❌ Rejected: Hurt i-frames that start after knockback ends
- **How it would work:** the 0.6 s timer starts when the `KNOCKBACK` state ends.
- **Why rejected:** it contradicts the design doc's hit order, and the player would need a second rule for protection during knockback.
- **Tempting because:** the player gets the full 0.6 s of free movement, which sounds generous.

### ❌ Rejected: Godot `Area2D` hitboxes/hurtboxes with `area_entered` signals
- **How it would work:** each hit/hurtbox is an `Area2D`, toggled on during active frames, and damage happens in the overlap callback.
- **Why rejected:**
  - Logic would live in the node tree (G6) and couldn't be unit-tested without a scene.
  - Overlap signals arrive a physics step late.
  - A box that's already overlapping when it's enabled may not fire `entered`.
  - Signal order isn't something we control, which breaks determinism for co-op.
- **Tempting because:** it's the standard Godot tutorial approach, and the editor shows the shapes for free.

### ❌ Rejected: Hitboxes driven by animation keyframes
- **How it would work:** an `AnimationPlayer` track enables the hitbox on specific frames.
- **Why rejected:** this is exactly what G6 forbids. Timing would live in animation files instead of `data/attacks/*.tres`, so Lucas couldn't tune it there (G2), and a headless server couldn't run it.
- **Tempting because:** it's how most action games built in an editor sync swings to visuals.

### ❌ Rejected: Global hitstop (`Engine.time_scale`)
- Already rejected in `design/combat.md`. In co-op, one player's hit would freeze everyone.
- **Tempting because:** it's one line of code.

### ❌ Rejected: Free (or slowed) movement during attacks
- **How it would work:** the movement input keeps moving the Warrior while a hit plays.
- **Why rejected:**
  - Swings stop being a commitment, so recovery stops being a risk.
  - Bosses' punish windows only matter if the player's own attacks can be punished too (pillar 2).
  - Dash-cancel already gives the player an escape.
- **Tempting because:** it feels more fluid in the first minute of play.
- **Instead:** the Warrior is rooted during each hit. If that feels stiff in the feel test, add a per-hit lunge as data in a later feature.

### ❌ Rejected: An i-frame-ignored hit still counts as "hit" for that attack
- **How it would work:** once an invulnerable target overlaps the hitbox, that attack instance can never hit it again.
- **Why rejected:**
  - A single early dash would dodge an entire long active window.
  - The vulnerable dash tail (F-001 C8) would mean nothing.
  - Positioning, i.e. actually leaving the hitbox, has to matter (pillar 2).
- **Tempting because:** it's simpler, it feels generous, and some games do it.

### ❌ Rejected: Training dummy built as a full enemy (`EnemyData`)
- **How it would work:** define the enemy data type now and make the dummy the first enemy.
- **Why rejected:** this would pre-design F-004 without its enemy decisions, and the dummy would carry fields it doesn't use.
- **Tempting because:** it looks like less code later.
- **Instead:** the dummy gets its own small `DummyData` type, and F-004 decides independently.

---

## 4. Constraints  ·  _Planner_

Hard rules for this feature. Violating any of these = automatic `CODE_CHANGES`.

| ID | Constraint | Reason |
|---|---|---|
| C1 | All new timers run on `delta` in `_physics_process`. Same commands at 30, 60 and 120 ticks/s give the same hits, the same damage and the same positions (§5 tolerances). C15 is how. | G1 |
| C2 | Every number comes from `data/`: per-hit values from `data/attacks/sword_hit_{1,2,3}.tres`; class values from `warrior.tres`; shared rules from `player_combat.tres`; dummy values from `data/enemies/training_dummy.tres`; placeholder shake look from `data/tunables/screen_shake.tres`. The one exception is a dummy's `knockback_scale`, a per-instance value in the scene (design doc). | G2, G9, D-005 |
| C3 | Hit detection, damage, knockback, hitstop and HP live in `src/core/`. They never read animations, sprites, `Area2D` or physics overlaps. | G6 |
| C4 | Attacking goes through an `AttackCommand`, the same way as F-001's commands. | G8 |
| C5 | All new state is serializable via `to_dict()`/`from_dict()`. That includes next hit index, attack phase and its timer, the latched attack values (C18), chain window, locked aim, hit set, buffered attack, HP, hitstop, hurt i-frames, knockback, dummy HP, dummy respawn timer, and the pulse state (C20). The snapshot boundary is C19. | G7 |
| C6 | No autoload or static holds combat state. `CombatSim` and its `HitResolver` are created per scene. | F-001 C6, D-002 |
| C7 | Hitstop is per entity. While an entity is in hitstop, its clock and **all** of its logic timers pause (attack phase, chain window, dash, cooldown, i-frames, knockback, input buffer ages, dummy pulse and respawn) and it produces zero displacement. Its stored velocity stays frozen, so a decel carries on afterwards. Facing still updates, and a press made during hitstop is stored with its age paused. Other entities are unaffected. A new hitstop takes the larger of the remaining and the new duration; it never adds them. | CQ8, D-002 |
| C8 | One attack instance (one hit's active phase) hits each hurtbox at most once. Only a hit that **lands** marks the hurtbox. A hurtbox skipped because of i-frames is **not** marked as hit (C16). | design doc, §3 |
| C9 | Teams: a hitbox never hits a hurtbox of its own team. No friendly fire, and no PvP (anti-goal). | PROJECT.md |
| C10 | Shake is never emitted by core. Presentation maps `hit_landed`/`damaged` to intensities from `player_combat.tres`, and only for hits where a **local player** is the attacker or the target. Shake is skipped entirely when `screen_shake_enabled` is false. | CQ8, D-002 |
| C11 | Dash rules from F-001 are unchanged, including the cooldown (F-001 AC11, AC12), except: a dash may cancel attack **recovery** only, and only once it can fire (cooldown ready). A dash pressed during windup, active or knockback is buffered (F-001 buffer rules). A dash buffered during recovery while the cooldown runs doesn't cancel anything until it fires. Cooldown keeps counting during attacks and knockback, and pauses in hitstop (C7). | design doc |
| C12 | Presentation that mirrors logic state (i-frame tint, HP displays, debug arcs) must be **derivable from current state**. Signals may trigger a refresh, but after `from_dict()` every view re-syncs from state. | F-001 code review |
| C13 | No new addons or dependencies. | G4 |
| C14 | Existing input actions keep their names and bindings; only the three debug actions in §2 are added. | F-000/F-001 must-not-break |
| C15 | **Combat timeline.** See below. | G1, D-007 |
| C16 | **Applying hits.** See below. | §3, C8 |
| C17 | **Action arbitration.** See below. | design doc, principle 3 |
| C18 | **Data validity and hot-reload.** See below. Extends F-001/C17. | G2, F-001/C17 |
| C19 | **Identity and snapshots.** See below. Extends F-001/C5. | G7, D-002 |
| C20 | **Pulse lifecycle and debug reset.** See below. | G3 |

**C15 — Combat timeline**

Splitting a tick. A physics tick of length `delta` runs `n = max(1, ceil(combat_step_rate × delta − TIME_EPSILON))` equal steps of `s = delta / n`. `combat_step_rate` must be a positive multiple of 120, so 30, 60 and 120 ticks/s share the same instants.

One tick, in this fixed order:
1. The runner collects each player's commands once and submits them. Held commands (move, aim) apply to every step of the tick. Press commands (dash, attack) are consumed by the first step, with press time = tick start (F-001/C15).
2. For each step:
   1. **Advance.** Every combatant advances by `s`, in registration order.
   2. **Move.** Each body moves through `move_and_slide()`, and its logic position syncs from the body. Core tests have no bodies, so the logic's own integration stands (F-001/C18).
   3. **Contact.** The end of the step is the **contact instant**. Every position, hitbox and protection state is read as it is at this instant. The collision-corrected position is the authoritative one, for hitbox origins and hurtbox centers alike.
   4. **Apply.** Candidates are applied per C16. All signals are emitted here, synchronously.
3. `finish_tick()` clears the held commands.

Advancing one combatant by `s`:
- Hitstop is consumed first. For `h = min(s, hitstop_remaining)`, the clock and timers stop.
- The rest of the step, `s − h`, runs the phase loop of F-001/C15, extended with attack and knockback phases. Phase boundaries fall at exact times inside a step and overshoot is carried, never rounded. This includes a hitstop that ends mid-step.

Rules at the contact instant:
- **No clock mapping.** Each entity's phases and windows are on its own clock, and a contact only asks each entity about its state now.
- **Live hitbox.** A hitbox is live iff its owner's clock is inside `[active_start, active_end)` and its owner is not in hitstop. Active time is measured on the owner's clock, so hitstop mustn't stretch its reach.
- **Dash protection.** A player is protected iff their clock is inside `get_iframe_window()`, half-open, checked by a new `is_dash_protected()`. `is_invulnerable()` stays a presentation flag and never decides a hit.
- **Hurt protection.** A player is protected while `hurt_iframes_remaining > 0`.
- **New timers.** Hitstop, knockback and hurt i-frames set by a hit start at the contact instant, so the next step is the first to consume them.
- **Boundaries.** A phase that reaches its end with no time left in the step crosses in that step, so the contact at that instant sees the new phase. Every comparison at a contact uses F-001's `TIME_EPSILON`: a clock within it of a boundary counts as having reached that boundary. So a half-open window includes a contact on its start and excludes one on its end, at every rate, despite float rounding.
- **No vanished phases.** An attack or pulse can start just after the contact at its own instant, because presses and toggles arrive after the previous tick's last contact. Its first contact can therefore come a whole step later. With `lead` = `windup` or `pulse_telegraph`, C18 requires `active ≥ min_active` and `lead + active ≥ 2 × min_active`. That guarantees a contact:
  - Worst case, contacts fall at `start + k × s` for k ≥ 1, with `s ≤ min_active`.
  - If `lead > 0`, the first contact at or after the window's start comes less than `s` later, which is inside the window because `active ≥ s`.
  - If `lead = 0`, then `active ≥ 2 × min_active > s`, so `start + s` is inside the window.
  - Hitstop only adds contacts. The first contact after it ends finds the clock less than `s` past where it stopped, so the argument still holds.
  - A running window always meets these rules at the sim's rate. Only a rate change could break that, and C18's rate check and C19's snapshot rule prevent it.

**C16 — Applying hits**

`HitResolver` returns **candidates**: (hitbox, hurtbox) pairs that pass the team check, the geometry and the attack instance's hit set, ordered by the hitbox owner's and then the hurtbox owner's registration order. Candidates are computed once per contact instant, before any of them is applied. `CombatSim` then takes them in order and rechecks the **target only**, as it is at that moment:

| Target at that moment | Result |
|---|---|
| Dash or hurt i-frames, including hurt i-frames granted by an earlier candidate in this batch | Skipped, **not marked** |
| KO'd dummy | Skipped, **not marked** |
| Anything else | **Lands:** marked in the attacker's hit set, then applied in the AC11 order |

- Two hitboxes on one player: the first lands, and its hurt i-frames skip the second. The second stays unmarked, so it can still land later (C8).
- Two hitboxes on one dummy: both land, unless the first KOs it.
- **Hits at the same instant trade.** The attacker isn't rechecked, so an attacker that was hit, interrupted or KO'd earlier in the batch still lands that hit. Registration order must never decide who wins an exchange.
- One attacker hitting several targets at one instant gets one hitstop, since `max(remaining, new)` changes nothing the second time (C7).

**C17 — Action arbitration**

What a press does, by state. Every press enters its buffer in the first step of the tick it arrives in, and fires from there at that same instant if the state allows, as in F-001/C15.

| State | Attack press | Dash press |
|---|---|---|
| Free, chain window closed | Starts hit 1 | Fires if cooldown ready, else buffered |
| Free, chain window open | Starts hit N+1 | Fires if cooldown ready, else buffered |
| Windup or active | Buffered | Buffered |
| Recovery, not finisher | Cancels recovery, starts hit N+1 | Fires if cooldown ready, cancelling recovery, else buffered |
| Recovery, finisher | Buffered | Fires if cooldown ready, cancelling recovery, else buffered |
| `DASHING` | Buffered | Buffered (F-001) |
| `KNOCKBACK` | Buffered | Buffered |
| Hitstop, in any state | Stored, age paused, resolved by the row above once hitstop ends | Same |

"Free" means `IDLE` or `MOVING`. A recovery press still chains when `attack_chain_window` is shorter than the recovery: the window can only add time after recovery, never remove it.

When buffers are checked, and what fires:
- A buffer is checked at every instant its row allows it to fire: the first instant of recovery (non-finisher attack, or dash), any instant during recovery (dash), the end of recovery, the end of a dash, the end of knockback, and the end of hitstop.
- **Priority:** if a buffered dash and a buffered attack can both fire at one instant, **the dash fires and the attack is discarded**. Press order doesn't matter. Dodge is the defensive verb (principle 3), and a stale attack must not root the player after an escape.
- A dash that can't fire yet doesn't block an attack that can. The attack fires and the dash stays buffered, aging as usual.
- A buffered attack fires as hit N+1 at the start of a non-finisher recovery. It fires as hit 1 at the end of a finisher's recovery, a dash or knockback.
- Each buffer holds one press, the newest. Ages expire by F-001's rule, inclusive.

Hits and resets:
- **Any dash that fires resets the chain**, including one fired from a free state inside the chain window.
- **A hit that lands on a player** interrupts any attack, clears its hit set and resets the chain. Stored velocity becomes 0 and buffers are left alone. The player enters `KNOCKBACK` at the contact instant, and the motion starts when hitstop ends.
- **A hit in the vulnerable dash tail** ends the dash at the contact instant: velocity 0, `dash_ended` emitted, and the full `dash_cooldown` starts there (F-001/C9). Being hit never refunds a cooldown.
- **Zero knockback** (distance 0 after scaling) skips the `KNOCKBACK` state, and control returns when hitstop ends. The hit still interrupts.
- **Repeated knockback replaces, never accumulates.** A new hit on a target still in knockback overwrites remaining distance, direction and speed, and the new knockback starts after the new hitstop.

**C18 — Data validity and hot-reload**

Valid ranges. `validate()` on `ClassData` and `PlayerCombatTunables` keeps its F-001 rules, and these go in a new `validate_combat()`, which `PlayerMotor._accepts` also calls. `ClassData.validate_combat()` and `DummyData.validate()` take the step rate to check against, and `ScreenShakeSettings` has a plain `validate()`. Bounds that need the step use `min_active = 1 / combat_step_rate`, with the rate from the `PlayerCombatTunables` validated alongside, so a reload is always checked against its own new rate. They compare with `TIME_EPSILON`, so an exact minimum passes.

| Resource | Rule |
|---|---|
| `AttackData` | `id` not empty; `windup` ≥ 0; `active` ≥ `min_active`; `windup + active` ≥ `2 × min_active`; `recovery` ≥ 0; `damage` ≥ 1; 0 < `arc_angle_deg` ≤ 360; `range_tiles` > 0; `knockback_tiles` ≥ 0 |
| `ClassData` | `attack_chain` has at least one entry, no nulls, each entry valid; `is_finisher` on the last entry only; `attack_chain_window` ≥ 0; `max_hp` ≥ 1; `hurtbox_radius_tiles` > 0; `knockback_scale` ≥ 0 |
| `PlayerCombatTunables` | `combat_step_rate` a positive multiple of 120; `player_hurt_iframes` ≥ 0; `knockback_duration` > 0; `hitstop_normal`, `hitstop_finisher` ≥ 0; each `shake_intensity_*` within 0–1 |
| `DummyData` | `max_hp` ≥ 1; `hurtbox_radius_tiles` > 0; `respawn_delay` ≥ 0; `pulse_interval` > 0; `pulse_telegraph` ≥ 0; `pulse_active` ≥ `min_active`; `pulse_telegraph + pulse_active` ≥ `2 × min_active`; `pulse_telegraph + pulse_active ≤ pulse_interval`; `pulse_radius_tiles` > 0; `pulse_damage` ≥ 1; `pulse_knockback_tiles` ≥ 0 |
| `ScreenShakeSettings` | `max_offset_px` ≥ 0; `decay_time` > 0 |

Reload. F5 reloads one atomic group: `warrior.tres` with its attack files, `player_combat.tres`, `training_dummy.tres` and `screen_shake.tres`, loaded with `CACHE_MODE_IGNORE_DEEP`. If any file fails to load or validate, nothing changes and the overlay shows "reload rejected: <errors>" (F-001/C17). Chains may change length; a chain whose rules pass is valid.

Rate check. Only this reload can change the sim's rate. If the group's `combat_step_rate` differs from the sim's, every attack in windup or active and every pulse in telegraph or active must also pass the two duration rules (`active`, `lead + active`) at the new rate, using its latched values. If one fails, the whole reload is rejected like an invalid file, and the overlay names the running hit or pulse. Nothing is deferred: F5 again once it has finished. A hit in recovery or a pulse in its wait is not checked, since it has no window left to lose. Raising the rate always passes.

`Player.reload_data()`, the F5 path of F-001's scene, never changes the rate: it rejects a file whose `combat_step_rate` differs from the sim's.

What happens to running state on a valid reload:

| Value | Rule |
|---|---|
| Hit in progress | Every `AttackData` field is latched at windup start, so the running hit finishes unchanged. The next hit reads the new data |
| Next hit index | Kept. If it's past the new chain's end, it becomes 0 |
| `attack_chain_window` | Latched at recovery start |
| `max_hp` | `hp = min(hp, max_hp)`. Raising it doesn't heal |
| Hitstop, knockback, hurt i-frames, respawn in progress | Kept as they are. New values apply to the next hit or KO |
| Pulse in progress | Latched at telegraph start. New values apply from the next pulse |
| `hurtbox_radius_tiles`, `knockback_scale` | From the next contact instant |
| `combat_step_rate` | From the next tick, once the rate check passes |
| `screen_shake_enabled` | Takes the file's value, replacing the K toggle. Other shake values apply to the next shake |

**C19 — Identity and snapshots**

- Every combatant has a stable `combat_id` (`StringName`), set in the scene: `player_1`, `dummy_anchored`, `dummy_loose`. Hit sets store these ids, never object references or indices.
- Registration order is the order of the runner's exported list.
- `HitResolver` holds no state that needs saving. A fresh scene rebuilds it by registering the same ids in the same order. `CombatSim.from_dict()` refuses a snapshot whose ids, order or `combat_step_rate` differ from the sim's (`push_error`, nothing changes). A snapshot holds latched durations, so restoring one on a slower grid could skip a window, just like a reload.
- There is **one** scene snapshot boundary: after `finish_tick()`, with no pending commands and no pending events. Mid-tick snapshots are invalid, as in F-001/C5.
- `CombatSim.to_dict()` holds the step rate, plus one entry per `combat_id` with that combatant's full state. The glue then sets each body from its logic position, and views re-sync (C12).
- Damage numbers and shake offsets are transient presentation. They aren't saved, and a restore clears them.

**C20 — Pulse lifecycle and debug reset**

- `pulse_interval` is **start to start**: from one telegraph's start to the next. The cycle is telegraph → active → wait, and wait = `pulse_interval − pulse_telegraph − pulse_active`.
- **Toggle on:** a new cycle starts at telegraph, with an empty hit set.
- **Toggle off:** the pulse stops at once. Any telegraph or active phase ends, the hitbox is gone and the hit set is cleared.
- **KO:** same effect as toggle off, while the toggle stays on. At respawn, if the toggle is on, a new cycle starts at telegraph.
- A pulse's hit set belongs to one active phase and clears at the next telegraph. Dummy hitstop pauses the pulse (C7).
- **Debug keys act between ticks.** The toggle and reset apply before the next tick's commands.
- **Reset (R)** re-runs `setup()` on every combatant, with the current data and its scene start position. That clears HP to max, attacks, chain, buffers, cooldown, hitstop, knockback, i-frames, KO, velocity and facing. Bodies move to those positions, views re-sync, and damage numbers and shake clear. Only the debug settings survive: pulse on/off and shake on/off. If the pulse is on, it restarts at telegraph.

**Must not break:** all F-001 behavior and tests (AC1–AC17 of F-001), with F-001's test files unedited, except the input-map migration in T4. Also F-001's debug scene behavior, existing input bindings, `tools/test`, `tools/lint`, the core purity check, and `tools/test_studio`.

---

## 5. Acceptance Criteria  ·  _Planner_

Testable, observable. The Auditor checks each one.

**Oracle and tolerances.** Tests run the same scripted commands at 30, 60 and 120 ticks/s. Commands change, and samples are taken, only at multiples of 1/30 s (the F-001 oracle). Position tolerance: **0.01 tiles**. Combat times (contact instants, phase ends, dash fire times): **± 1 µs**, because all three rates sample the same instants (C15). All times below are in seconds, on the shared schedule.

**F-001 carry-over**
- [ ] AC1 — **Tint re-sync:** Snapshot the player mid-dash during i-frames, let the i-frames end, then restore. The tint must be on. Snapshot outside i-frames, enter i-frames, then restore. The tint must be off. The same check applies to the HP display and the debug arc. Asserted on the real views in a scene.

**Attack chain**
- [ ] AC2 — **Phases:** Each hit runs windup → active → recovery with the durations in its attack file, on the attacker's own clock. The hitbox exists only during active.
- [ ] AC3 — **Locked aim:** The hit's direction = facing at the first instant of windup. Facing keeps updating afterwards, but that hit's direction does not.
- [ ] AC4 — **Chaining:**
  - The chain window opens at the first instant of recovery and lasts `attack_chain_window`.
  - An attack pressed during hit N's recovery starts hit N+1 immediately, cancelling the rest of the recovery, even if the window is shorter than the recovery (C17).
  - An attack pressed after recovery but still inside the window also starts hit N+1.
  - An attack pressed after the window starts hit 1.
- [ ] AC5 — **Attack buffer:**
  - An attack pressed during windup or active is buffered. It fires at the first instant of recovery, as hit N+1, if pressed within `input_buffer_window`; otherwise it is discarded.
  - An attack pressed during a dash or knockback is buffered, and fires as hit 1 when that state ends, if within the window.
  - Only one attack is buffered at a time; the newest press replaces it.
- [ ] AC6 — **Finisher:** Hit 3 uses its own file's values. Its recovery **cannot** be cancelled by attack; a press during it is buffered and starts hit 1 once recovery ends, if within the window. A dash **can** cancel it (AC8). The hit after a finisher is always hit 1.
- [ ] AC7 — **Rooted:** During windup, active and recovery, movement input is ignored and velocity decelerates to 0 using `move_decel_time`. Once recovery ends, movement resumes immediately (while still inside the chain window).
- [ ] AC8 — **Dash cancel:**
  - **Cooldown ready:** a dash pressed during recovery fires at once, cancels the rest of the recovery and resets the chain.
  - **Cooldown ends within the buffer window:** the dash stays buffered and the recovery keeps running. The dash fires at the instant the cooldown ends. If recovery is still running then, that's when it's cancelled and the chain resets.
  - **Cooldown ends too late:** the dash is dropped by F-001's rule, and the recovery and chain carry on untouched.
  - A dash pressed during windup or active is buffered. It fires at the first instant of recovery if eligible, and otherwise follows the two rules above.

**Hit / hurt**
- [ ] AC9 — **Geometry:** Circle–sector intersection is exact. Unit tests cover:
  - a circle fully inside the sector;
  - a circle whose center is outside the arc but whose edge crosses the arc boundary (hit);
  - a circle just beyond range + radius (miss);
  - a circle behind the attacker (miss);
  - the 360° case.
- [ ] AC10 — **Once per instance:** A hurtbox inside the hitbox for the whole active phase takes damage once per hit. Hits 1, 2 and 3 are separate instances.
- [ ] AC11 — **Hit order:** On a hit that lands: damage → knockback → hitstop (attacker and target) → hurt i-frames (player target only). Integer damage is subtracted from HP, which stops at 0. `hit_landed` (on the attacker) and `damaged` (on the target) are emitted by each one's `CombatState`, with: attacker id, target id, damage, `is_finisher`, and direction (the knockback direction).
- [ ] AC12 — **Knockback:**
  - Distance is the attack's knockback × the target's `knockback_scale`: `ClassData.knockback_scale` for a player, the instance value for a dummy.
  - It is applied over `knockback_duration` at constant speed, starting after the target's hitstop ends.
  - Direction = attacker → target center; if that is zero, the attack direction. A pulse's direction is `Vector2.DOWN`.
  - Walls stop it. The distance isn't recalculated, and the state ends on time.
  - A new knockback replaces the remaining one (C17).
- [ ] AC13 — **Hitstop:**
  - Normal hits apply `hitstop_normal` to attacker and target; the finisher applies `hitstop_finisher`. A pulse is a normal hit.
  - During hitstop all of that entity's timers pause (C7), and other entities keep moving and ticking.
  - When one attack hits several targets at the same contact instant, the attacker gets one hitstop, not one per target.
  - While its owner is in hitstop, a hitbox isn't live (C15).
- [ ] AC14 — **I-frames:**
  - A player inside a hitbox during dash i-frames or hurt i-frames takes no damage, no knockback and no hitstop.
  - If they are still inside at the first contact instant after the i-frames end, and the active phase is still running, they are hit (C8).
  - **Hurt i-frames boundary:** they start at the contact instant, count down during knockback and pause during hitstop. With default data and a hit at time T, the player is protected throughout knockback and at the last contact instant before T + 0.65, and can be hit from the first contact instant at or after T + 0.65.
- [ ] AC15 — **Player hurt:** A hit that lands on the player interrupts any attack and resets the chain. Knockback puts the player in a `KNOCKBACK` state: movement is ignored and dash/attack presses are buffered. `player_hurt_iframes` start on the hit (AC14), not after knockback. A hit in the dash tail ends the dash and starts its full cooldown (C17).
- [ ] AC16 — **Player HP:** The player starts at `max_hp`. At 0, the player emits `died`, once per drop to 0. In the debug scene, HP refills to max and nothing else happens.
- [ ] AC17 — **Teams:** The player's sword never hits the player. The dummy's pulse never hits the dummies.

**Dummy and presentation**
- [ ] AC18 — **Dummy:**
  - It has `max_hp`, a hurtbox radius and a `knockback_scale`.
  - At 0 HP it emits `died`, shows "KO", ignores hits, and refills to max after `respawn_delay`.
  - The anchored dummy (`knockback_scale` 0) never moves. The loose dummy (scale 1) is pushed back and stays where it lands until the reset key.
- [ ] AC19 — **Debug pulse:**
  - Toggled by a debug key, off by default.
  - Each `pulse_interval`, start to start, the anchored dummy shows a ring outline for `pulse_telegraph`, then a 360° hitbox of `pulse_radius` is active for `pulse_active` and deals `pulse_damage` and `pulse_knockback`, through the same `HitResolver`.
  - Toggle on, toggle off, KO and respawn follow C20. Core tests cover toggling off during telegraph and during active, KO during a pulse, and respawn with the toggle on.
  - It is a debug tool, not AI.
- [ ] AC20 — **Damage numbers:** Every `damaged` on a dummy spawns a floating number above it; finisher numbers are visibly larger. Each dummy shows HP as a number and a bar. The player's HP is shown in the overlay.
- [ ] AC21 — **Shake:**
  - `hit_landed` by the local player shakes at `shake_intensity_hit`, or `shake_intensity_finisher` if `is_finisher`.
  - `damaged` on the local player shakes at `shake_intensity_player_hurt`.
  - With `screen_shake_enabled = false` (data flag, toggled by a debug key at runtime), there is no shake at all.
- [ ] AC22 — **Frame-rate independence:** One scripted run at 30, 60 and 120 ticks/s, with default data. The player starts at (0, 0) with aim held `Vector2.DOWN`, and an anchored dummy stands at (0, 1) tiles. Move input is zero except for the 1/30 s after each dash press.

      | Time | Input | Expected |
      |---|---|---|
      | 0 | Attack | Hit 1 lands at 10/120 (0.0833) |
      | 0.2 | Attack, during recovery | Hit 2 lands at 34/120 (0.2833) |
      | 0.4 | Attack, during recovery | Hit 3 lands at 68/120 (0.5667) |
      | 0.8 | Dash + move right, during finisher recovery | Fires at 0.8, ends at (3, 0) |
      | 1.4 | Dash + move left | Fires at 1.4, ends at (0, 0) |
      | 1.6 | Attack | Hit 1 lands at 202/120 (1.6833) |
      | 29/15 (1.9333) | Dash + move right, during recovery, cooldown not ready | Fires at 1.95, cancelling the recovery that would end at 1.97 |

      The cooldown ends at 1.95, not 1.90, because the hitstop at 1.6833 paused it for 0.05. At 2.2: **4 hits, 52 total damage, dummy HP 148, player at (3, 0)**. The run holds in core at every rate, and once in a scene over real physics at every rate.
- [ ] AC23 — **Serialization:** Snapshot at the C19 boundary mid-windup, mid-active with a partial hit set (one dummy hit, the other not yet), mid-hitstop, mid-knockback, mid-pulse (telegraph and active, with its hit set), and with buffered attack and dash. Restore into **fresh** objects: player, both dummies and `CombatSim`, registered in the same order. The next 60 ticks behave identically to an unbroken run, with no target hit twice or skipped. A snapshot with different ids, order or `combat_step_rate` is refused.
- [ ] AC24 — **Hot-reload:** F5 reloads the three attack files, `warrior.tres`, `player_combat.tres`, `training_dummy.tres` and `screen_shake.tres`, atomically, per C18.
  - Every C18 bound is tested on both sides.
  - An invalid value in any one file rejects the whole group, shows on the overlay and changes nothing.
  - A valid edit to one attack file is really picked up (`CACHE_MODE_IGNORE_DEEP`).
  - A valid reload during an attack lets that hit finish on its latched values, and the next hit uses the new ones.
  - A valid reload during knockback keeps that knockback.
  - Lowering `max_hp` below current HP clamps HP.
  - **Rate change 240 → 120.** Two separate runs at rate 240, each with a stationary target inside: a hit with `windup` 0.036 and `active` 1/240, pressed at 0; and a pulse with `pulse_telegraph` 0.036 and `pulse_active` 1/240, toggled on at 0. At 1/30, a reload sets the rate to 120, with new attack and dummy files that are valid at 120. In both runs it is rejected: nothing changes, the rate stays 240, and the running hit or pulse lands at 9/240 (0.0375).
  - The same reload is accepted once the hit is in recovery and the pulse is in its wait, and the rate is 120 from the next tick.
  - Raising the rate from 120 to 240 during a hit is accepted, and that hit finishes on its latched values.
  - `Player.reload_data()` rejects a file with a different `combat_step_rate`, and the sim's rate is unchanged.
- [ ] AC25 — **Tooling and coverage map:**
  - **Core tests, no scene** (`tests/core/`): AC2–AC11; AC12 without walls; AC13–AC15; AC16 up to `died`; AC17; the logic of AC18 and AC19; AC22; AC23; AC24's validation, latching and rate check; AC26–AC28.
  - **Mapper tests:** `attack` press → one `AttackCommand`.
  - **Scene tests, real physics** (`tests/scenes/`): AC1; AC12 walls; AC16 refill; AC18 and AC19 visuals; AC20; AC21; AC22's physics run; AC24 end to end; AC29–AC31.
  - F-001's tests pass unedited, except the input-map migration in T4. `tools/test`, `tools/lint`, the core purity check and `tools/test_studio` pass.

**Timeline and arbitration**
- [ ] AC26 — **Timeline oracle (C15).** Same result at every rate:
  - **Contact after i-frames, inside one tick:** dash at 0 inside a pulse with `pulse_telegraph` 0 and `pulse_active` 0.2, staying inside it. The player is protected at 13/120 and hit at **14/120 (0.1167)**, once. That instant is inside the 30 Hz tick [0.1, 0.1333), which `is_invulnerable()` reports as true. It must not block the hit.
  - **Active phase inside one tick:** an attack with `windup` 0.045 and `active` 1/120 occupies [0.045, 0.0533), inside the 30 Hz tick [0.0333, 0.0667). It lands at **0.05**, exactly once.
  - **Hitstop overshoot:** with `hitstop_normal` 0.055, hit 1 lands at 10/120, the attacker resumes mid-step at 0.1383, and recovery starts at **0.195**.
  - **Bound:** `active` 0.008 is rejected at rate 120, and 1/120 is accepted, with `windup` ≥ 1/120.
  - **Zero lead, sword:** at rate 120, `windup` 0 with `active` 1/120 is rejected, and with `active` 1/60 it's accepted. Pressed at T on a stationary overlapping dummy, that minimum hit lands at **T + 1/120**, exactly once.
  - **Zero lead, pulse:** at rate 120, `pulse_telegraph` 0 with `pulse_active` 1/120 is rejected, and with `pulse_active` 1/60 it's accepted. Toggled on at T with a stationary player inside, that minimum pulse lands at **T + 1/120**, exactly once.
  - **Window starting on a contact:** `windup` 1/120 with `active` 1/120 is accepted, and the same for a pulse. The window `[T + 1/120, T + 2/120)` lands at **T + 1/120**, exactly once, because a contact on a window's start counts and one on its end doesn't (C15).
  - **Attacker hitstop and reach:** a hurtbox that enters the hitbox while its owner is in hitstop isn't hit until hitstop ends.
- [ ] AC27 — **Arbitration (C17):**
  - Attack and dash both buffered, at the start of recovery and again at the end of knockback: the dash fires and the attack is discarded, in either press order.
  - Same, with the cooldown not ready: the attack fires and the dash stays buffered.
  - A hit in the dash tail: `dash_ended` emitted, velocity 0, state `KNOCKBACK`, full cooldown starts at the contact instant.
  - A dash fired from the chain window resets the chain.
  - A hit with zero knockback on a player skips `KNOCKBACK`, and control returns when hitstop ends.
  - A second knockback on a loose dummy replaces the first, so total travel is less than the two distances added together.
- [ ] AC28 — **Batches (C16):**
  - Two hitboxes on one player at one instant: damage once, and the skipped hitbox isn't marked, so it can hit after the hurt i-frames if still active.
  - Two hitboxes on one dummy: both land. If the first KOs it, the second doesn't.
  - A sword hit and a pulse hit in one exchange at one instant: both land, in either registration order, with the same damage on both sides.
  - Each entity's hitstop is `max(remaining, new)`.
- [ ] AC29 — **Authoritative position (C15):** Scene test. A player dashes into a wall while a live hitbox on the far side reaches the point the motor alone would predict, but not the point where the wall stops the body. No hit lands, and `motor.get_position_px()` equals the body position at every contact instant. A knocked-back body against a wall gets the same check.
- [ ] AC30 — **Debug reset (C20):** After a sequence with damage, KO, a moved loose dummy, a running attack, a buffer, hitstop and an active pulse, R gives the same state as a fresh `setup()`, in positions, HP and timers. Pulse on/off and shake on/off stay as set.
- [ ] AC31 — **One runner:** `CombatRunner` is the only thing that steps logic. A scene test counts exactly 4/2/1 steps per physics tick at 30/60/120 ticks/s, and `Player` has no tick of its own. F-001's scene runs through the same runner.

**How to verify manually (feel test):**
Open `scenes/debug/f003_sword.tscn` and play about 5 minutes with KB/M, then with a gamepad.
- **Mash attack on the anchored dummy.** The 3 hits should flow without dropped inputs. Hit 3 should feel heavier: longer pause, bigger number, stronger shake. The gap after it should feel risky.
- **Swing, then dash out of the recovery.** With the cooldown ready, it should come out instantly, every time. If you just dashed, it should come out as soon as the cooldown ends, or not at all if that's too far away.
- **Hit the loose dummy.** The finisher should visibly send it flying.
- **Turn the pulse on.** Dash *through* the ring at the right moment and take nothing. Dash too early and get caught by the tail. Getting hit should feel like a clear punishment, not a stun-lock.
- **Turn shake off.** Hits should still read clearly from hitstop and numbers alone.
- **Tune a value** (e.g. hit 3 windup), press F5, and feel the difference.

---

## 6. Task Breakdown  ·  _Planner_

Small, ordered, each independently committable.

| # | Task | Files likely touched | Notes |
|---|---|---|---|
| T1 | Fix the F-001 tint re-sync | `src/entities/player/player.gd`, `src/core/player/player_motor.gd`, `tests/scenes/test_f003_restore.gd` | `from_dict()` emits a `state_restored` signal at the end. Player presentation has one `_refresh_from_state()` that sets the tint from `is_invulnerable()`, called on `state_restored` and on `invulnerability_changed`. Add a regression test on the real tint, in a scene (AC1). Applies C12. T17 adds the HP display and arc checks once they exist. |
| T2 | Data types | `src/core/combat/attack_data.gd` (`AttackData`), `src/core/combat/dummy_data.gd` (`DummyData`), `src/core/combat/combat_timing.gd` (`CombatTiming`), extend `ClassData`, `PlayerCombatTunables`; `src/core/tunables/screen_shake_settings.gd` (`ScreenShakeSettings`) | `AttackData`: `id`, `windup`, `active`, `recovery`, `damage: int`, `arc_angle_deg`, `range_tiles`, `knockback_tiles`, `is_finisher: bool`. `ClassData` += `attack_chain: Array[AttackData]`, `attack_chain_window`, `max_hp: int`, `hurtbox_radius_tiles`, `knockback_scale`. `PlayerCombatTunables` += `combat_step_rate: int`, `player_hurt_iframes`, `knockback_duration`, `hitstop_normal`, `hitstop_finisher`, `shake_intensity_hit`, `shake_intensity_finisher`, `shake_intensity_player_hurt`. `DummyData`: `max_hp`, `hurtbox_radius_tiles`, `respawn_delay`, `pulse_interval`, `pulse_telegraph`, `pulse_active`, `pulse_radius_tiles`, `pulse_damage`, `pulse_knockback_tiles`. `ScreenShakeSettings`: `screen_shake_enabled`, `max_offset_px`, `decay_time` (placeholder look, → Art). All C18 validation, with `validate()` on `ClassData` and `PlayerCombatTunables` left as it is (§2). `CombatTiming` has no state and holds the two duration rules once, as `window_errors(lead, active, step_rate)`, used by data validation and the rate check. It owns `TIME_EPSILON`, and `PlayerMotor.TIME_EPSILON` stays as an alias of it. |
| T3 | Data files | `data/attacks/sword_hit_{1,2,3}.tres`, `warrior.tres`, `player_combat.tres`, `data/enemies/training_dummy.tres`, `data/tunables/screen_shake.tres` | Values from the design-doc *Tunables index*. `warrior.tres` gets `attack_chain` = [hit 1, hit 2, hit 3]. Only hit 3 has `is_finisher`. Paths as constants (G5). |
| T4 | Attack command + input | `src/commands/attack_command.gd`, `input_sample.gd`, `player_input.gd`, `player_input_mapper.gd`, `project.godot`, `tests/test_input_map.gd`, mapper tests | `AttackCommand()` carries no data; the aim comes from the motor's facing. Produced from the existing `attack` action (bindings unchanged). Add only `debug_pulse_toggle` (P), `debug_shake_toggle` (K), `debug_reset` (R) and migrate the input-map test (§2). |
| T5 | Motor step API, no behavior change | `src/core/combat/combatant.gd` (`Combatant`), `src/core/player/player_motor.gd` | `Combatant` (`RefCounted`) is the base of `PlayerMotor` and `DummyLogic`: `get_combat_id()`, `get_team()`, `get_combat_state()`, `get_hurtbox()`, `get_live_hitbox()`, `get_running_window_errors(step_rate)`, `step(s)`, `finish_tick()`, `get_tick_displacement_px()`, `sync_position()`, `to_dict()`, `from_dict()`. Motor gets `step(s)`, which consumes presses but keeps move and aim, and `finish_tick()`, which clears them. `tick(delta)` becomes `step(delta)` + `finish_tick()`. Displacement and the `is_invulnerable()` overlap now cover the last `step()`. Also `get_velocity_tiles()`. F-001/C4's API list gains `step()` and `finish_tick()`, plus the `apply_hit()` of T9. All F-001 core tests pass unedited. |
| T6 | Geometry + resolver | `src/core/combat/hurtbox.gd`, `hitbox.gd`, `geometry.gd`, `hit_resolver.gd`, `hit_candidate.gd`, `hit_event.gd` | Exact circle–sector intersection. `HitResolver.find_candidates(combatants) -> Array[HitCandidate]`, in C16 order, with no state of its own. A `HitEvent` exists only for a hit that lands. Teams as an enum (`PLAYER`, `ENEMY`). Each attacker owns the hit set for its attack instance. |
| T7 | Combat state component | `src/core/combat/combat_state.gd` (`CombatState`) | Shared by the player and the dummy: HP, hitstop timer, knockback (remaining distance, direction, speed), hurt i-frames, `apply_hit(event, tunables)`, signals `hit_landed`, `damaged`, `died`, `to_dict`/`from_dict`. Hitstop takes the max of remaining and new (C7). Knockback replaces (C17). |
| T8 | Motor: attack chain | `src/core/player/player_motor.gd` (+ an `attack_chain.gd` helper if it grows) | New state `ATTACKING` (with phase). Attack phases join the C15 phase loop. Implements AC2–AC8 and C17's press table and priority. Latches per C18. Cooldown runs during attacks and stops exactly at expiry if a dash is waiting. Exposes `get_live_hitbox()` and `is_dash_protected()`. `get_running_window_errors()` checks the latched hit during windup and active. Phase boundaries per C15. Extend serialization (C5). |
| T9 | Motor: hit reaction | `src/core/player/player_motor.gd` | Hitstop is consumed first in `step()`, then the phase loop (C15). New state `KNOCKBACK`. `apply_hit()` handles interruption, the dash tail, zero knockback and hurt i-frames per C17 and AC14, AC15. |
| T10 | Dummy logic | `src/core/combat/dummy_logic.gd` | `Combatant` with `CombatState`, respawn timer and the pulse lifecycle (C20). Its `knockback_scale` arrives through `setup()` from the scene. `get_running_window_errors()` checks the latched pulse during telegraph and active. |
| T11 | `CombatSim` | `src/core/combat/combat_sim.gd` | One tick per C15: splits `delta` into steps, advances, calls a `move_bodies` `Callable` (empty in core tests), finds candidates, applies them per C16, and calls `finish_tick()`. Scene snapshot and identity checks per C19. The sim stores its own step rate, set in setup. `rate_change_errors(new_rate)` collects every combatant's `get_running_window_errors()`, and `set_step_rate()` applies from the next tick (C18). |
| T12 | Core tests | `tests/core/combat/test_geometry.gd`, `test_hit_resolver.gd`, `test_combat_state.gd`, `test_combat_sim.gd`, `test_dummy_logic.gd`, `tests/core/player/test_player_attack.gd`, `test_player_hit_reaction.gd`, `test_player_snapshot.gd`, `test_combat_data_validation.gd` | Everything in AC25's core row. No scenes. |
| T13 | Runner + player glue | `src/world/combat_runner.gd` (`CombatRunner`), `src/entities/player/player.gd`, `scenes/debug/f001_movement.tscn` | `CombatRunner` (`Node`) is the only `_physics_process` that steps logic. It creates the `CombatSim`, registers its exported ordered list of combatants, and passes `move_bodies`. `move_bodies` sets each body's `velocity = get_tick_displacement_px() / physics_delta`, calls `move_and_slide()`, then `sync_position()`. `Player` loses its `_physics_process`, and gets a method the runner calls to submit commands, plus the sim's step rate for `reload_data()` to compare against (C18). F-001's scene gains a `CombatRunner` as its last child and nothing else. Player HP refill on `died` happens only in the debug scene. |
| T14 | Dummy body | `src/entities/dummy/training_dummy.gd`, `.tscn` | Body: `CharacterBody2D`, `collision_layer` 0, `collision_mask` 1 (world), so nothing is blocked by it. Exports `combat_id`, `knockback_scale` (default 0) and whether it pulses. Placeholder visuals: a circle, an HP bar with a number, a "KO" label, a telegraph ring. All derived from state (C12). |
| T15 | Presentation listeners | `src/ui/debug/damage_numbers.gd`, `src/world/camera/placeholder_shake.gd` | Floating numbers on dummies. Placeholder shake: random camera offset ≤ `intensity × max_offset_px`, decaying over `decay_time`; a new shake takes the larger intensity, never the sum. Implements C10 and AC21. A placeholder white flash on the damaged entity is allowed. |
| T16 | Debug scene + overlay | `scenes/debug/f003_sword.tscn`, extend `src/ui/debug/motor_debug_overlay.gd`, `src/world/combat_runner.gd` | Room with one anchored dummy and one loose dummy, plus a wall usable for AC12. Overlay shows: chain index, phase and remaining time, chain window, buffered attack/dash, hitstop remaining, player HP, hurt i-frames, shake on/off, and speed from `get_velocity_tiles()`. Draws the active hitbox arc and the hurtbox circles. Keys: F5 `debug_reload_tunables`, P `debug_pulse_toggle`, K `debug_shake_toggle`, R `debug_reset` (actions from T4). The runner owns the atomic reload, including the rate check (C18), and the reset (C20). In this scene the overlay sends F5 to the runner. `Player.reload_data()` keeps working for F-001's tests and F-001's scene, switches to `CACHE_MODE_IGNORE_DEEP`, and rejects a different `combat_step_rate` once a runner has set the sim's rate. `test_f001_reload.gd` is unaffected, because its file copies keep the same rate. F-001's debug scene keeps working as it does today. |
| T17 | Scene tests | `tests/scenes/test_f003_*.gd` | Everything in AC25's scene row, including the rest of AC1 and AC22's physics run. Uses `user://` copies of data, like `test_f001_reload.gd`. |
| T18 | Glossary | `studio/GLOSSARY.md` | Add: Hitbox, Hurtbox, Attack instance, Windup / Active / Recovery, Chain window, Hitstop, Knockback, Hurt i-frames, Punish window, Telegraph, Team, Combat step, Contact instant, Hit candidate, Combatant. Extend Input buffer to cover attacks. |

---

## 7. Plan Review  ·  _Auditor_

<Each completed round starts with its machine line (format in AGENTS.md), then its findings.
Severity: 🔴 blocking · 🟡 should fix · 🔵 suggestion. Example finding:>

### PR-1 🔴 <title>
<What's wrong, where, why it matters, what you'd suggest.>
> **Planner reply:** <accepted / rejected + reason / changed §X>

<!-- review-round: 1 verdict: CHANGES_REQUESTED -->

**Verdict:** CHANGES_REQUESTED — three blocking findings (PR-1–PR-3).

The goal is one clear, isolated player outcome serving pillar 2, with explicit scope boundaries. The options explain real trade-offs and respect the project's offline-first architecture. The blocking issues are timing and action-rule conflicts; the remaining findings identify contracts the Builder would otherwise have to invent.

### PR-1 🔴 Specify the hit timeline, including partial-tick active and invulnerable windows

**Location:** §3 chosen resolver; §4 C1/C7/C11; §5 AC2/AC14/AC22; §6 T7/T9. Related: F-001 §4 C8/C15 and `src/core/player/player_motor.gd:199`.

**Problem:** T9 resolves once after every motor has consumed the whole tick, and T7 exposes only the current active hitbox. There is no rule for a phase that starts and ends inside that tick, or for the exact instant at which i-frames protect against a hit. F-001's `is_invulnerable()` deliberately reports whether *any* dash i-frame interval overlapped the tick; it is not immunity at the hit instant. With the default 0.11 s window, the 30 Hz tick [0.10, 0.1333) reports invulnerable even though its tail is vulnerable. A contact at 0.12 s can therefore be rejected at 30 Hz and accepted at 120 Hz. Short attack phases introduced by tuning can also disappear before the resolver sees them. Per-entity hitstop further requires a rule for mapping these intervals between independently paused clocks.

**Why it matters:** The described pipeline does not establish how to satisfy C1/G1, preserve F-001's exact dash contract, and still punish the vulnerable tail in AC14. Applying `delta` to timers alone does not resolve this conflict.

**Suggested fix:** Specify the authoritative contact time/interval, partial-tick phase handling, hitstop overshoot handling and the mapping to each entity's clock. Require exact i-frame checks through the interval API rather than the presentation overlap flag. Add a common-time 30/60/120 Hz oracle covering a contact after i-frame expiry within the same tick, and an active phase wholly inside one tick.

> **Planner reply (Combat):** accepted. Changed §3 (new chosen option, two rejected options), §4 C1 and new C15, §5 AC2, AC3, AC14 and new AC26, §6 T5, T8, T9, T11. Each tick now splits into combat steps on a shared 1/120 s grid (proposed as D-007), so 30/60/120 ticks/s sample the same contact instants. Each entity's state is read on its own clock at that instant, so nothing maps between clocks. `is_dash_protected()` checks the exact window and `is_invulnerable()` never decides a hit. Hitstop is consumed first in a step and overshoot is carried. `active` ≥ one step guarantees a contact instant. AC26 has the worked oracle with exact times.

✔ resolved (round 2) — C15 and AC26 replace the original once-per-tick pipeline with an explicit contact timeline and exact protection checks. Two remaining duration/grid boundary cases are recorded separately in PR-11 and PR-12 below.

### PR-2 🔴 Hurt i-frames begin at two different points

**Location:** §3 hit application step 4; §5 AC11 versus AC15; `studio/design/combat.md` → Hit / hurt system.

**Problem:** AC11 and the design doc apply hurt i-frames on hit, after initializing knockback and hitstop. AC15 instead says they apply “Afterwards,” following the `KNOCKBACK` state. These produce different protection during knockback and different expiry times: with the defaults, starting the 0.6 s timer on hit leaves 0.48 s after the 0.12 s knockback, excluding paused hitstop; starting it afterwards leaves the full 0.6 s.

**Why it matters:** This is an unflagged conflict with the department design doc and changes whether the player can be hit repeatedly during knockback.

**Suggested fix:** Make AC15 agree with the on-hit rule and state explicitly whether the timer ages during knockback, preserving C7's pause during hitstop. If delayed i-frames are intended instead, explicitly reconcile the design doc and AC11 and define protection during knockback. Add boundary checks for the chosen rule.

> **Planner reply (Combat):** accepted. Kept the on-hit rule from the design doc. Changed §5 AC14 and AC15: the timer starts at the contact instant, counts down during knockback and pauses in hitstop. AC14 has the boundary: with defaults, protected until T + 0.65. §3 rejects the delayed version, and `design/combat.md` now states the rule.

✔ resolved (round 2) — AC14/AC15 and the design doc consistently start hurt i-frames on contact, count them during knockback and pause them during hitstop.

### PR-3 🔴 Immediate recovery dash cancels contradict the retained cooldown

**Location:** §4 C11 and must-not-break; §5 AC8 and manual dash-cancel check. Related: F-001 AC11/AC12.

**Problem:** AC8 requires a dash pressed during recovery to fire immediately, including a buffered dash at recovery start, without a cooldown condition. C11 preserves F-001's rule that a new dash cannot fire until cooldown ends. This occurs with default data: dash at 0, end at 0.15, start a missed hit at 1/6 s, then press dash during its recovery at 1/3 s. Cooldown lasts until 0.50 s, so both requirements cannot hold.

**Why it matters:** The Builder must either bypass a required defensive cooldown or fail the new dash-cancel AC. The manual promise “instantly, every time” has the same conflict.

**Suggested fix:** State that recovery cancellation fires immediately only when dash cooldown permits it; otherwise apply the existing buffer eligibility/expiry rules, without cancelling recovery until a dash actually fires. Qualify AC8 and the feel test, and cover recovery presses with cooldown ready, cooldown expiring within the buffer and cooldown expiring too late.

> **Planner reply (Combat):** accepted. Changed §4 C11, §5 AC8 and the feel test, and §3 rejects the cooldown bypass. AC8 now has the three cases you listed, and AC22's last dash exercises the middle one (fires at 1.95). `design/combat.md` is updated.

✔ resolved (round 2) — C11, AC8 and the feel test preserve cooldown eligibility and cancel recovery only when the dash fires.

### PR-4 🟡 Define arbitration between buffered actions and interrupted movement states

**Location:** §5 AC4–AC8/AC15; §6 T7.

**Problem:** An attack and a dash can both be buffered during active and both are required to fire at recovery start. After knockback, both may also be eligible. The spec gives neither priority nor a rule for clearing or retaining the losing buffer. A hit in a vulnerable dash tail enters `KNOCKBACK`, but it is also unspecified whether this interrupted dash starts its cooldown. Repeated hits on a dummy during knockback have no replacement-versus-accumulation rule for remaining knockback.

**Why it matters:** These choices affect whether an intended escape becomes another attack, whether a stale attack fires after the escape, and whether interrupted dashes evade cooldown. They also change loose-dummy travel under a chain.

**Suggested fix:** Add a transition/priority table for simultaneous eligible actions and incoming hits, including buffer disposal, dash interruption/cooldown and repeated knockback. Add focused tests for both buffers at recovery/knockback exit and for a hit during the vulnerable dash tail.

> **Planner reply (Combat):** accepted. New §4 C17 and §5 AC27. The dash wins over the attack, and the losing attack is discarded. A dash that can't fire yet doesn't block an attack that can. A hit in the dash tail ends the dash and starts the full cooldown. Repeated knockback replaces, never accumulates. Also settled: any fired dash resets the chain, and zero knockback skips the `KNOCKBACK` state.

✔ resolved (round 2) — C17/AC27 define action priority, losing-buffer disposal, interrupted-dash cooldown and replacement knockback.

### PR-5 🟡 Define eligibility while applying a batch of hit events

**Location:** §3 chosen resolver; §4 C8; §5 AC10/AC11/AC14/AC18; §6 T5/T9.

**Problem:** `resolve()` returns an array before any event is applied. Registration order orders that array, but does not say whether later events recheck i-frames, death and attack interruption after earlier events mutate state. Two simultaneous incoming hitboxes can both pass an initial eligibility check before the first hit grants hurt i-frames; marking both in their hit sets would also prevent the skipped one from hitting later. A sword hit and the dummy's pulse in the same tick leave the trade/interruption policy undefined.

**Why it matters:** Ordered candidates alone do not establish deterministic damage semantics or C8's rule that an i-frame-skipped target remains hittable later.

**Suggested fix:** Distinguish geometric candidates from successfully applied hits. Specify when eligibility is rechecked and hit sets are updated, and whether simultaneous outgoing attacks trade or are cancelled by an earlier event. Test two hitboxes against one player and a player/dummy exchange in one tick.

> **Planner reply (Combat):** accepted. New §4 C16 and §5 AC28, and §4 C8 and §6 T6 changed. The resolver returns candidates, and a `HitEvent` exists only for a hit that lands. The target is rechecked per candidate at apply time, and only a landed hit marks the hit set. Simultaneous attacks trade: attackers aren't rechecked, so registration order never decides an exchange. Two hits on one player resolve by order, and the skipped one stays unmarked.

✔ resolved (round 2) — C16/AC28 distinguish candidates from landed hits, specify target rechecks and preserve simultaneous trades.

### PR-6 🟡 Resolve geometry using an explicit authoritative position

**Location:** §6 T9; §5 AC12. Related: `src/core/player/player_motor.gd:122` and `src/entities/player/player.gd:33`.

**Problem:** The existing motor advances its predicted position inside `tick()`, then glue corrects it after `move_and_slide()`. T9 inserts hit resolution before that correction. Reading the ticked motor's position tests shapes at a position that may be inside or beyond a wall; reading the body instead tests the previous position. The spec does not choose either interpretation or another reconciliation step.

**Why it matters:** Hits can be added or missed around walls because the hurtbox and the actual body disagree. Accepting sword arcs through walls in §3 does not establish permission to move their origins or target centers through walls.

**Suggested fix:** Specify where shape positions come from and when collision-corrected positions become authoritative in the hit timeline from PR-1. Add a scene case where a dashing or knocked-back body reaches a wall while a hitbox is active, verifying the resolver uses the intended body position.

> **Planner reply (Combat):** accepted. Changed §4 C15 and §6 T13, new §5 AC29. Bodies move and logic positions sync inside every step, before the contact instant, so the collision-corrected body position is the one read for hitbox origins and hurtbox centers. AC29 is the scene case, for a dash and for knockback.

✔ resolved (round 2) — C15/T13 resolve geometry after body movement and position synchronization; AC29 checks the wall cases.

### PR-7 🟡 Complete the new data validation and hot-reload contract

**Location:** §4 C2; §5 AC4/AC12/AC24; §6 T2/T3. Related: F-001 §4 C17.

**Problem:** AC24 lists the files to reload but does not extend F-001's atomic validation/latching policy to them. It leaves bounds and zero-duration behavior undefined for phases, arcs, knockback and pulse timers; likewise empty/null chain entries and a chain window shorter than recovery. Reloading an in-progress hit leaves its duration, damage, geometry and chain identity unspecified, and lowering `max_hp` leaves current HP unspecified. AC12 also multiplies by the *target's* `knockback_scale`, but T2 defines that field only for dummies, with no player source or explicit fixed player rule.

**Why it matters:** Tuning is the purpose of the dummy scene. These gaps can produce partially updated combat, skipped phases or invalid state, and force the Builder to invent gameplay/data policy.

**Suggested fix:** Extend the validation table and define the atomic reload group, latched versus immediately updated fields, current-HP handling and permitted chain edits. Reconcile the chain-window/recovery relationship and specify the player's knockback scaling source. Cover invalid new data and a valid reload during an attack and knockback.

> **Planner reply (Combat):** accepted. New §4 C18, and §5 AC4, AC12 and AC24 changed. Player scaling comes from a new `ClassData.knockback_scale` (1.0, D-005), and C17 settles chain window vs recovery: the window only adds time after recovery. Two things I found while checking `main`: `test_data_validation.gd` builds data by hand, so the new rules go in `validate_combat()`, and F-001's `CACHE_MODE_IGNORE` wouldn't reload external attack files, so reload uses `CACHE_MODE_IGNORE_DEEP` (§2). `knockback_scale` also moved out of `DummyData` to a scene instance value, matching the design doc (§4 C2, §6 T2, T14).

✔ resolved (round 2) — C18 supplies validation, atomic loading, latching and HP rules; C17 settles the chain window and AC12 specifies player scaling. The new step-rate reload interaction is PR-12 below.

### PR-8 🟡 Define snapshot identity and the scene snapshot boundary

**Location:** §3 owner IDs/registration order; §4 C5; §5 AC23; §6 T5/T9/T10.

**Problem:** The hit set stores hurtbox identities, but the spec does not say how IDs and resolver registration order survive reconstruction in fresh objects. F-001's snapshot boundary is after an individual motor tick; T9 now performs hit application and collision correction afterwards, so that boundary can capture a partially processed scene. The dummy's pulse enable flag, phase, remaining interval/telegraph/active time and per-pulse hit set also need an explicit continuation check, beyond merely round-tripping its HP.

**Why it matters:** A snapshot can restore the same scalar values yet hit a target twice, skip a target or resume a different pulse. That fails C5/G7 and AC23's continuation promise.

**Suggested fix:** Define stable scene-supplied identities, registry restoration order and one snapshot boundary after the complete scene step with no pending events/commands. Include pulse state and reconstruct the player, both dummies and resolver as fresh objects in a partial-hit-set continuation test.

> **Planner reply (Combat):** accepted. New §4 C19, and §4 C5, §5 AC23 and §6 T11 changed. Scene-set `combat_id`s go in hit sets, registration order is the runner's exported list, and the one boundary is after `finish_tick()`. `from_dict()` refuses mismatched ids or order. AC23 restores into fresh objects, with a partial hit set and pulse state.

✔ resolved (round 2) — C19/AC23 define stable identities, registry order, a completed-scene snapshot boundary and fresh-object continuation with pulse/hit-set state.

### PR-9 🟡 Separate core coverage from scene coverage and give position tolerance units

**Location:** §5 introduction/AC1/AC12/AC16/AC22/AC25; §6 T8/T9/T12.

**Problem:** AC25 and T8 require AC2–AC17 at core level, but AC12's wall collision and AC16's debug-scene refill depend on glue/physics. T1's tint/HP/arc re-sync also requires presentation assertions; a core signal test alone cannot verify it. No new scene-test task covers these behaviors or the new runner's once-per-tick ownership. Finally, “Tolerance = one tick” supplies no distance unit or numeric bound for AC22's final positions and does not identify a common input/sample schedule across rates.

**Why it matters:** Core tests can pass while the newly refactored scene moves twice, ignores collision or restores stale visuals. AC22 has no objective position pass/fail threshold.

**Suggested fix:** Add a coverage map and scene-test task for new collision behavior, debug refill, actual view restoration and one runner step per physics tick, while retaining pure core tests for combat. Give AC22 a shared physical-time input/sample schedule, expected hit/damage totals, a numeric position tolerance in tiles and a separate timing tolerance.

> **Planner reply (Combat):** accepted. §5 now opens with an oracle: 0.01 tiles and ± 1 µs. AC22 is a worked schedule ending in 4 hits, 52 damage, dummy HP 148, player at (3, 0). AC25 is a coverage map, AC31 checks the runner, and §6 T17 is the scene-test task. §6 was also renumbered to T1–T18 so the Builder gets a clean order. Old T7 split into T5, T8 and T9, old T9 into T11 and T13, and old T10 into T10 and T14. T5 and T11 are new work the plan was hiding.

✔ resolved (round 2) — AC25/T17 separate core and scene coverage, AC31 checks runner ownership, and the common-time oracle gives numeric distance and timing tolerances. AC22's stated default-data hit and cooldown times are consistent with C15.

### PR-10 🟡 Specify the debug reset and pulse lifecycle

**Location:** §5 AC18/AC19; §6 T10/T12.

**Problem:** R is named and the loose dummy stays put “until the reset key,” but the reset operation has no defined state set. It could restore only positions or also HP, attacks, buffers, hitstop and pulse timers. Pulse interval could mean start-to-start or an idle delay plus telegraph/active time; toggling off during telegraph/active and killing/respawning the pulse dummy have no defined effect on its outgoing hitbox or next pulse.

**Why it matters:** These choices change the repeatable timing and clean starting state needed for the documented dodge-tail feel test.

**Suggested fix:** State the complete reset contract and pulse phase transitions, including toggle-off, KO and respawn, and define what `pulse_interval` measures. Add small core checks for the pulse lifecycle and a debug reset check.

> **Planner reply (Combat):** accepted. New §4 C20, §5 AC19 changed and new AC30. `pulse_interval` is start to start. Toggle-off and KO end a pulse at once, and toggle-on and respawn start a new cycle at telegraph. R re-runs `setup()` on every combatant, and only pulse on/off and shake on/off survive.

✔ resolved (round 2) — C20/AC19/AC30 specify pulse transitions, interval meaning and the complete reset state.

<!-- review-round: 2 verdict: CHANGES_REQUESTED -->

**Verdict:** CHANGES_REQUESTED — two blocking findings (PR-11, PR-12).

The previous Planner replies were checked first; PR-1–PR-10 are resolved as annotated above. The goal, pillar alignment, explicit scope and alternatives remain sound. The task split and coverage map address the earlier integration gaps. The shared-step approach is coherent for the default oracle, but two configurations permitted by C18 still invalidate C15's guarantee that active phases cannot vanish.

### PR-11 🔴 A zero-windup attack can finish before its first contact check

**Location:** §4 C15, step order and “No vanished phases”; §4 C18 `AttackData`/`DummyData` bounds; §5 AC10/AC26.

**Problem:** At rate 120, C18 permits `windup = 0` and `active = 1/120`. An attack pressed at tick start T is active on `[T, T + 1/120)`. C15 advances before checking contact, so the first check is at `T + 1/120`, when the half-open active window has already ended. There was no contact check at T after the press started the attack. A stationary overlapping target is never hit. The same failure occurs when toggling on a pulse with `pulse_telegraph = 0`, `pulse_active = 1/120` and a longer interval. The interval arithmetic holds at all three required physics rates.

**Why it matters:** The one-step minimum does not guarantee a contact for an active phase beginning at the action-start boundary. Valid tuning can silently remove an entire sword hit or pulse, violating C15 and AC10. AC26 tests a positive windup, so it misses this case.

**Suggested fix:** Define how the action-start boundary is sampled, or explicitly reject the duration combination that has no sample. Reconcile that rule with the half-open window and C18 bounds. Add 30/60/120 Hz core oracles for both a zero-windup sword hit and a newly enabled zero-telegraph pulse at the minimum active duration, with a stationary overlapping target.

> **Planner reply (Combat):** accepted. Took the "reject the combination" path. Changed §4 C15 and C18, and §5 AC26. C18 adds `lead + active ≥ 2 × min_active` for attacks and pulses, so a window with no lead-in needs two steps (1/60 s at rate 120), and C15 now carries the full proof, including hitstop. C15 also states the boundary rule that reconciles the half-open window: a phase ending exactly at a step's end crosses in that step, and contact comparisons use `TIME_EPSILON`. AC26 adds the zero-lead oracles for sword and pulse at the new minimum, plus a window starting exactly on a contact. §3 rejects an extra contact at the action's start, and §6 T2 adds `CombatTiming`, so the rule lives in one place. `design/combat.md` is updated.

✔ resolved (round 3) — C18 rejects the unsampled one-step, zero-lead window for both swords and pulses. C15 defines contact-boundary comparisons, and AC26 checks the accepted two-step minimum and a one-step window whose lead ends on a contact. T2 centralizes the duration rules.

### PR-12 🔴 Lowering the combat step rate can skip a latched active phase

**Location:** §4 C15 minimum active duration; §4 C18 reload rules for running hits, pulses and `combat_step_rate`; §5 AC24.

**Problem:** C18 validates replacement resources against the new rate, preserves running attacks and pulses on their latched values, and applies the new rate next tick without checking those latched values. For example, start at rate 240 with `windup = 0.036` and `active = 1/240`. Reload at scene time `1/30` to rate 120, also changing the replacement attack's active duration to `1/120`, so the new data validates. The running hit retains its old active interval `[0.036, 0.0401667)`. At rate 240 it would be checked at 0.0375; after reload the next contact is 0.0416667 and the whole phase is skipped. A latched pulse has the same exposure.

**Why it matters:** A valid atomic reload can invalidate the minimum-duration assumption behind C15 and make an in-progress hit disappear despite the latching contract. Validating only the newly loaded resources cannot prevent this.

**Suggested fix:** Specify a rate-change policy that accounts for every running latched attack and pulse before changing the grid. For example, reject the entire reload when a retained active duration is below the new step minimum, or define when the rate change is deferred. Reconcile the policy with C18's atomicity and next-tick rule, and add a reload oracle for this 240 → 120 case covering both sword and pulse continuation.

> **Planner reply (Combat):** accepted. Changed §4 C18 and §5 AC24. New rate check: when a reload changes the rate, every running attack in windup or active and pulse in telegraph or active must pass the same duration rules at the new rate on its latched values, or the whole reload is rejected, which keeps C18 atomic. A rate that passes still applies from the next tick. §3 rejects deferral. AC24 has your 240 → 120 case for sword and pulse, its accepted counterpart, and a raised rate. Two more ways to reach the same failure, closed here too: a snapshot restored at a different rate is refused (§4 C19, §5 AC23), and F-001's scene calls `Player.reload_data()` directly on F5, so that path can't change the rate (§2, §4 C18, §6 T13, T16). The sim now stores its own rate (§6 T11).

✔ resolved (round 3) — C18 checks every running latched window before accepting an atomic rate change. AC24 covers rejection and later acceptance of the 240 → 120 example, plus raising the rate. C19/AC23 reject snapshots from a different grid, and the legacy reload path cannot change the sim's rate.

<!-- review-round: 3 verdict: APPROVE -->

**Verdict:** APPROVE — no new findings. PR-11 and PR-12 were checked against the Planner replies and revised contracts first; both are resolved above. PR-1–PR-10 remain resolved.

- **Goal and pillars:** one isolated player-facing outcome, explicit exclusions, and clear support for pillar 2. The dummy remains a tuning tool rather than pre-empting enemy design.
- **Options and constraints:** the chosen contact grid and rejected alternatives have specific trade-offs. The revised plan agrees with `studio/design/combat.md` and G1–G9. D-007 is explicitly proposed for Lucas's Gate A decision; it is not treated as already accepted.
- **Acceptance criteria and tasks:** AC24/AC26 cover both corrected boundary cases; AC25 separates core, mapper and scene evidence. T1–T18 expose the runner migration, compatibility work, validation and presentation checks in an ordered build sequence. No remaining blocking ambiguity identified.

**Verification:** An independent rational-arithmetic model checked 1,740 valid lead/active/rate/initial-hitstop combinations across combat rates 120/240/360/480 and physics rates 30/60/120. Every valid window received a contact. The PR-11 sword/pulse examples reject the one-step zero-lead window and sample the accepted minimum at T + 1/120; the PR-12 latched example remains valid at 240 and lands at 9/240, while its duration fails validation at 120. These are plan-contract checks; implementation and gameplay validation remain for the build and code review.

---

## 8. Implementation Log  ·  _Builder_

**Started:** 2026-11-01  ·  **Branch:** `feature/F-003-warrior-sword-chain`

### Progress
- [x] T1 — 1984b03
- [x] T2 — aea96da
- [x] T3 — 7fc967f
- [x] T4 — 21555bf
- [x] T5 — 9fcee7d
- [x] T6 — 639bac8
- [x] T7 — 575fc3d
- [x] T8 — 2a6bf21
- [x] T9 — d0b0c91
- [x] T10 — b77e491
- [x] T11 — d8f5dec
- [x] T12 — 8969597
- [x] T13 — f956c72
- [x] T14 — 16908c3
- [x] T15 — 73ea330
- [x] T16 — 7e3f1f1
- [x] T17 — 512bfa5
- [x] T18 — 6c2d25c
- [x] CR-1 — 50aa9ca
- [x] CR-2 — 87a26b7
- [x] CR-3 — 6a4d7ba

### Deviations from plan
- DEV-1: `PlayerMotor` doesn't implement all of T5's `Combatant` API itself. `Combatant` holds position, hurtbox, displacement, `sync_position()`, the "no hitbox in hitstop" rule, the target recheck and the rate-check wrapper, and subclasses fill in private hooks (`_build_live_hitbox()`, `_is_protected()`, `_running_window()`, `_hurtbox_radius()`). — **Why:** gdlint's `max-public-methods: 20` applies, and the motor alone would have reached about 29. It also keeps each of those rules in one place. — **Impact:** `PlayerMotor` sits exactly at 20, so a new public method there needs a helper. `Combatant` also gains `can_be_hit()`, `apply_hit()`, `get_knockback_scale()` and `get_position_px()`, which T5 didn't list.
- DEV-2: The hit set is marked through `Hitbox.mark_hit()`, not through a method on the attacker. The hitbox shares the attacker's own array, so the attacker still owns the set (T6). — **Why:** one less public method (DEV-1). A trade also stays clean: an interrupted attack replaces its array, so a late mark lands on the old one and can't leak into the next hit (C16). — **Impact:** none outside `AttackChain` and `PulseCycle`.
- DEV-3: `Combatant` grew over T5–T7 instead of arriving whole in T5. — **Why:** its full API returns `Hurtbox`, `Hitbox` and `CombatState`, which T6 and T7 create. — **Impact:** history only.
- DEV-4: New files the plan didn't name: `src/core/combat/pulse_cycle.gd` (`PulseCycle`, the pulse version of T8's optional `AttackChain` helper), `src/entities/combat_body.gd` (`CombatBody`, the typed base of `Player` and `TrainingDummy`, so the runner needs no duck typing) and `src/ui/debug/combat_debug_draw.gd`. — **Why:** T16 had the overlay draw arcs, but the overlay is a screen-space `CanvasLayer`, so world-space drawing needs its own `Node2D`. — **Impact:** `Player` now extends `CombatBody`, which is a `CharacterBody2D`, so nothing else changes.
- DEV-5: P, K and R are read by `MotorDebugOverlay`, which calls the runner. T16 didn't say which node reads them. — **Why:** F-001's overlay has no runner, so those keys do nothing there, and F-001's scene needs no change beyond its `CombatRunner`. — **Impact:** tested by `test_ac31_f001_scene_keeps_its_keys_to_itself`.
- DEV-6: `Tunables.load_fresh()` replaces `Player._load_ignoring_cache()`, and both reload paths use it. It checks `FileAccess.file_exists()` instead of `ResourceLoader.exists()`. — **Why:** `ResourceLoader.exists()` still returns true for a deleted file that's in the resource cache, so a missing file logged engine errors on its way to a correct rejection. — **Impact:** the autoload gains a stateless function, and C6 still holds.
- DEV-7: Tests live in more files than T12 and T17 name, and were committed with the task they cover, not all in T12/T17. — **Why:** `max-public-methods` also counts test functions, and tests were written alongside each task. — **Impact:** T12's commit holds only the remaining core coverage. Extra files: `test_combat_rules_validation.gd`, `test_combat_data_files.gd`, `test_player_motor_steps.gd`, `test_player_dash_cancel.gd`, `test_player_hitstop.gd`, `test_combat_batches.gd`, `test_rate_change.gd`, `test_player_input_mapper_attack.gd`, and the `test_f003_*` scene set.
- DEV-8: T15 was committed before T14, because the dummy's scene uses `DamageNumbers`. T15's commit (73ea330) doesn't compile on its own: `PlaceholderShake.enabled` clashes with `Camera2D.enabled`, and no scene loaded the script until T16 (7e3f1f1), which renames it `shake_enabled`. — **Why:** a mistake of mine, not a plan change. — **Impact:** don't bisect onto 73ea330 or 16908c3 expecting the shake to load. `f003_sword.tscn` doesn't exist in either, so nothing else is affected.

- DEV-9: T5 lists `tick()` as `step()` + `finish_tick()` and the `Combatant` API has no fire step, but CR-1 needs one between Advance and Contact. `Combatant` gains `fire_due_actions()`, which only `CombatSim` calls, once every combatant has stepped and `_time` has moved to the contact instant. — **Why:** §2 says `tick()` keeps its exact F-001 behavior, so the boundary fire can't live inside `step()`: that is what `tick()` is built from. Advancing `_time` first keeps `get_time()` true to its doc for anything listening to `dash_started`. — **Impact:** C15's Advance stage now ends with this call. `PlayerMotor` stays at 20 public methods, because the public method is on `Combatant` and the motor fills a private hook (DEV-1). `test_tick_leaves_a_dash_due_on_its_end_for_the_next_tick` pins the old `tick()` timeline.

### Assumptions made (small, reversible)
- ASSUMPTION-1: **Withdrawn after CR-1.** It let a contact fall between a buffered action coming due and firing, and that changes outcomes, so it wasn't a small choice. An action due on a step's end now fires before that contact (DEV-9). `tick()` alone keeps the old timeline, as §2 requires.
- ASSUMPTION-2: A remainder within `TIME_EPSILON` in `PlayerMotor._run_phases()` counts as no time left, and the clock absorbs it. — **Why:** without this, a dash due on a step's end fired in the step before or after depending on float rounding. AC22 caught it. The spec states the `TIME_EPSILON` rule for contact comparisons, and this extends it to the phase loop. `fire_due_actions()` then handles what comes due on that step's end.
- ASSUMPTION-3: On a landed hit the target is applied first, then the attacker's hitstop and `hit_landed`. AC11's order holds per entity. — **Why:** `hit_landed` should be able to read the target's new HP. Both happen at one instant, and only signal handlers could tell the difference.
- ASSUMPTION-4: A dash cancelling a finisher's recovery doesn't discard a buffered attack, because that attack couldn't have fired at that instant (C17 discards only when both can). It may fire as hit 1 at the end of the dash if still within the window. — **Why:** literal reading of C17. With default data it always expires first (0.12 < 0.15).
- ASSUMPTION-5: `get_velocity_tiles()` reports the knockback velocity while knockback moves, and 0 during its hitstop. — **Why:** C17 sets stored velocity to 0 on the hit, and the overlay should show real speed.
- ASSUMPTION-6: A hit on a player at 0 HP still lands normally, with no second `died`. The debug scene's refill runs inside the `died` signal. — **Why:** AC16 says once per drop to 0, and there's no death flow yet (D-006).
- ASSUMPTION-7: R doesn't reset the sim clock (`CombatSim.get_time()`). — **Why:** nothing reads it to decide logic. It's scene time for tests and is in the snapshot only for continuity. Every combatant's own clock does reset.
- ASSUMPTION-8: The telegraph ring shows during telegraph only, and the debug arc shows the live hitbox, so it disappears during its owner's hitstop. — **Why:** AC19 and C15, and it keeps both views truthful.
- ASSUMPTION-9: An action due on the last step's end of a tick uses that tick's held move and aim, and a press arriving at that same time joins after it. So an attack due at T fires before a dash pressed on the tick starting at T, and that dash is buffered in windup, per C17's table. — **Why:** C15 has presses arrive after the previous tick's last contact, so the commands for T don't exist yet at contact T. C17's priority covers buffers that can both fire, and that dash isn't in its buffer yet. The result is the same at 30/60/120 ticks/s, because commands change on 1/30 s multiples (`test_dash_pressed_as_a_due_attack_fires_stays_buffered_at_every_rate`). If Combat wants that dash to win, it needs a new rule: C11 forbids cancelling windup.
- ASSUMPTION-10: A cooldown within `TIME_EPSILON` of 0 counts as ended for a waiting dash. — **Why:** C15's boundary rule. A rounding leftover would otherwise move the fire past the contact on its expiry instant, at some rates only. `test_a_dash_due_on_a_steps_end_fires_there_and_is_flagged` fails without this. F-001's fire time moves by at most 1e-9 s, far below its tolerances.

### Things the Auditor should look at closely
- `PlayerMotor._fire_due_actions()`, `CombatSim.tick()`, DEV-9 and ASSUMPTION-2/9/10: this decides which side of a contact a boundary action falls on.
- ASSUMPTION-9 is the one behavior choice CR-1 leaves open: a dash pressed on the tick after an attack fires at that same time doesn't beat it.
- `CombatSim._apply_contact()`: the recheck order, and that hits still trade after the attacker was interrupted or KO'd. Replacing (not clearing) `_hit_ids` in `AttackChain` and `PulseCycle` is what keeps a stale mark out of the next hit.
- `CombatRunner.reload_data()`: validation is against the group's own rate, the rate check runs only if everything else passed, and nothing is applied before all checks finish.
- `CACHE_MODE_IGNORE_DEEP`: it works in 4.7.2 here, including for scripts referenced by the files. `test_ac24_a_valid_edit_to_one_attack_file_is_really_picked_up` proves the edit is picked up.
- `Player.reload_data()` and `apply_reloaded_data()`: the second is also called by the runner, with `data_reloaded` keeping the sim's tunables current.

**Honest gaps:**
- Mutation checks: closed in this round. Ten mutations were each run against the full suite, and every one failed at least one test: the four rules left open at T17 (`is_dash_protected`, marking order, hitstop max, per-step contact) and six covering the review fixes (cooldown `TIME_EPSILON`, the hitstop guard, the i-frame flag at a due fire, the sim's due-fire call, and both latched shake values). Rules outside that list and `CombatTiming`'s two-step rule weren't mutated.
- TDD: T2's code was written alongside its tests, so those never failed first, apart from that one mutation. Tests for T3 onward failed first, except the few added at the end of T17 to close coverage gaps, which were written after the code they cover.
- History: T9's first commit went in with one failing test, because a chained command ignored the result. It was a test sampling error, and the commit was amended to d0b0c91 before anything else built on it.
- The §5 manual feel test (KB/M and gamepad) hasn't been run: it belongs to Lucas. Nothing here tests a real gamepad.

### How to test
- All checks: `tools/test`, `tools/lint`, `tools/check_core_purity`, `tools/check_core_purity --self-test`, `tools/test_studio`.
- After the CR-1 to CR-3 fixes: 410 GUT tests pass in 41 scripts, with no leaks. Lint and purity are clean, and `tools/test_studio` passes 243 tests.
- Review regressions: `tests/core/combat/test_boundary_actions.gd` (CR-1, contact level at 30/60/120 ticks/s), `tests/scenes/test_f003_pulse_restore.gd` (CR-2), and `test_c18_a_reload_leaves_a_running_shake_alone_and_the_next_one_takes_the_new_look` in `test_f003_reload.gd` (CR-3).
- Debug scene: `scenes/debug/f003_sword.tscn`. J / left mouse attacks, Space dashes, P pulse, K shake, R reset, F5 reload. It also boots headless with no errors over 240 frames.

---

## 9. Code Review  ·  _Auditor_

<Each completed round starts with its machine line (format in AGENTS.md), then
`**Reviewed commit:** <hash>`, AC evidence and findings. Example finding:>

### CR-1 🔴 <title>  ·  `path/to/file:line`
<problem, why it matters, suggested fix>
> **Builder reply:** <fixed in abc123 / disagree because …>

<!-- review-round: 1 verdict: CHANGES_REQUESTED -->

**Reviewed commit:** 7fcda79e5fa00e77a1706e7a591699173930b599

**Verdict:** CHANGES_REQUESTED — three blocking contract violations, independently reproduced against the unchanged HEAD. This is the first code-review round; there are no earlier Builder replies to resolve.

### CR-1 🔴 Resolve eligible buffered actions before the contact at their fire instant

**Location:** `src/core/player/player_motor.gd:376–399`, especially the loop guard at line 380; `src/core/player/player_motor.gd:482–489`; `src/core/combat/combat_sim.gd:50–61`; §8 ASSUMPTION-1. Violates C17 and AC8.

**Problem:** When recovery starts, cooldown expires, or hitstop ends exactly at the end of a combat step, `_run_phases()` exits without another `_fire_buffered_actions()` call. The resolver then observes the player before an already-eligible dash fires. ASSUMPTION-1 calls the next step's start the same clock time, but a contact has intervened and can damage/interrupt the player and add hitstop before that dash.

**Reproduction:** At each of 30/60/120 ticks/s, use hit 1 with windup 0.05 and active 0.05, attack at 0, and buffer a ready dash at 1/30. Place the dummy at (0, 5) tiles, outside sword range, with a pulse enabled at 0: telegraph 0.1, active 0.2, radius 20, knockback 0. Recovery and the pulse both start at 0.1. The independent probe records player HP **80**, a hit at **0.1**, and the dash only at **0.15** after hitstop. C17/AC8 require the buffered dash to fire at recovery start, protecting against that contact.

**Why it matters:** An eligible defensive input loses to a hit at its promised fire instant. The existing tests record the motor's eventual dash timestamp or sample after the transition, so they miss the intervening damaging contact. This is an observable rule change, not a harmless boundary convention.

**Suggested fix:** Resolve actions that become eligible at an advance boundary before that instant's contact, including a hitstop ending with zero remainder, while preserving the legacy F-001 `tick()` contract where needed. Replace ASSUMPTION-1's contact ordering and add 30/60/120 Hz contact-level regressions for recovery start, cooldown expiry and hitstop end; assert HP/protection at the boundary as well as fire time and buffer priority.

> **Builder reply:** fixed in 50aa9ca. `CombatSim.tick()` now calls `Combatant.fire_due_actions()` after every combatant has stepped and before the bodies move, so the contact sees the dash or attack. It respects hitstop, and a waiting dash treats a cooldown within `TIME_EPSILON` as ended. `tick()` keeps F-001's timeline (DEV-9, ASSUMPTION-10), and ASSUMPTION-1 is withdrawn. Your reproduction now records HP 100 at 0.1 and the dash at 0.1, at all three rates. `test_boundary_actions.gd` covers recovery start, cooldown expiry, hitstop end, buffer priority and a zero-windup attack. ASSUMPTION-9 records the one related case this leaves as it is.

✔ resolved (round 2) — Verified 50aa9ca and the contact-level regressions for recovery start, cooldown expiry, hitstop end, buffer priority and zero-windup attacks. The original reproduction now records HP 100 and dash time 0.1 at all three required rates. DEV-9 preserves the legacy `tick()` contract while the sim resolves due actions before contact.

### CR-2 🔴 Re-sync the runner's pulse toggle when restoring a scene snapshot

**Location:** `src/world/combat_runner.gd:46–57` and `src/world/combat_runner.gd:77–83`; `src/ui/debug/motor_debug_overlay.gd:75`. Violates C12/C19.

**Problem:** A snapshot restores each dummy's `pulse_enabled`, but leaves the runner's duplicate `_pulse_on` flag unchanged. Reproduced in the real F-003 scene: toggle on, take a snapshot, toggle off, restore. `restore_snapshot()` returns true and the dummy is enabled again, while `is_pulse_on()` still returns false. The next toggle changes the runner to true and calls `set_pulse_enabled(true)` on an already-enabled dummy, so the pulse stays on.

**Why it matters:** The overlay reports an inactive pulse while it can attack, and the first P press after restore cannot turn it off. Restoring into a fresh scene has the same mismatch because the runner starts with `_pulse_on = false`. Core-only continuation tests cannot catch this scene-state inconsistency.

**Suggested fix:** Derive the runner's toggle/display from the restored pulsing combatant state, or explicitly reconcile it after a successful restore. Add scene tests restoring both on and off snapshots into opposite settings and into a fresh scene; assert the overlay and that one P press immediately toggles the actual pulse.

> **Builder reply:** fixed in 87a26b7. `_pulse_on` is gone: `is_pulse_on()` reads the dummies, and `toggle_pulse()` flips what it reads, so there's no second copy to go stale. `test_f003_pulse_restore.gd` restores on and off snapshots over the opposite setting and into a fresh scene, and asserts the overlay and that one P press acts on the real pulse.

✔ resolved (round 2) — Verified 87a26b7 and all four pulse-restore scene tests. The toggle and overlay derive from restored logic; the original reproduction now reports pulse on after restore and off after one toggle. The loose dummy remains excluded from the debug pulse.

### CR-3 🔴 Latch shake look values until the next shake

**Location:** `src/world/camera/placeholder_shake.gd:23–34`, `src/world/camera/placeholder_shake.gd:44–56`. Violates C18's “Other shake values apply to the next shake” rule.

**Problem:** `apply_settings()` replaces `_settings` immediately, while an existing shake retains its old `_time_left` and `_intensity`. Both the current amplitude and its decay denominator then read the replacement settings. Reproduced with a freshly started intensity-0.5 shake: changing valid `decay_time` from 0.2 to 0.01 changes `get_current_intensity()` immediately from **0.5 to 10.0**. With `max_offset_px = 6`, the next frame can use a 60 px radius instead of the running shake's 3 px limit. Editing `max_offset_px` also changes the running shake immediately.

**Why it matters:** Valid F5 tuning can amplify an existing shake far beyond its specified intensity and changes its look before the next shake, contrary to the explicit reload contract. Current reload tests inspect the replacement settings but never reload during an active shake.

**Suggested fix:** Keep the new settings for subsequent shakes and latch the active shake's decay/amplitude values when `shake()` starts or refreshes it. Continue applying `screen_shake_enabled` immediately and clearing when disabled. Add a scene reload regression changing both decay and maximum offset during a shake: its current envelope stays unchanged, then a new shake uses the replacement values.

> **Builder reply:** fixed in 6a4d7ba. `shake()` now latches `decay_time` and `max_offset_px`, and `_process()` and `get_current_intensity()` read those latched values, so F5 only reaches the next shake. `screen_shake_enabled` still applies at once. The new regression in `test_f003_reload.gd` goes through the real F5 key and changes both values mid-shake: intensity stays 0.5 (not 10.0), the limit stays 3 px, the old decay keeps running, and the next shake takes the new look.

✔ resolved (round 2) — Verified 6a4d7ba and the real-F5 regression changing both decay and maximum offset during a running shake. The current envelope and limit retain their latched values; the next shake uses the new settings, and disabling still clears immediately. The original reproduction now retains intensity 0.5 after the decay edit.

**AC evidence** (paths relative to the repository; ✅ means the named behavior has implementation/test evidence, with the scope of any exception stated):

| AC | Result | Evidence at the reviewed HEAD |
|---|---|---|
| AC1 | ✅ | `PlayerMotor.from_dict()` emits `state_restored`; `Player._refresh_from_state()`, dummy refresh and state-derived debug arcs re-sync. Real-view assertions in `tests/scenes/test_f003_restore.gd` and `test_f003_views.gd`. The additional pulse-toggle view defect is CR-2. |
| AC2 | ✅ | `AttackChain.start/advance/_cross_finished_phases/build_hitbox` latch and advance phases; `PlayerMotor._advance_attack` carries segment time. `tests/core/player/test_player_attack.gd` checks phases and hitbox lifetime. |
| AC3 | ✅ | `AttackChain.start` stores facing in `_direction`; later aim updates only the motor's facing. Locked-direction test in `test_player_attack.gd`. |
| AC4 | ✅ | `AttackChain.advance/advance_window/_finish_recovery` manage the window; `PlayerMotor._can_fire_buffered_attack` permits non-finisher recovery chaining regardless of window expiry. Recovery/post-recovery/expired/short-window cases in `test_player_attack.gd`. |
| AC5 | ❌ | Both buffers, replacement and expiry exist in `PlayerMotor`; `test_player_attack.gd` and `test_player_hit_reaction.gd` cover ordinary transitions. Exact end-of-step firing is deferred until after contact (CR-1). |
| AC6 | ✅ | `AttackChain.start` latches finisher values and wraps the next index; motor arbitration blocks attack cancellation of finisher recovery while permitting dash. Finisher tests in `test_player_attack.gd` and `test_player_dash_cancel.gd`. |
| AC7 | ✅ | `PlayerMotor._advance_attack` integrates toward zero with class deceleration; normal integration resumes after recovery. Rooting/deceleration tests in `test_player_attack.gd`. |
| AC8 | ❌ | Cooldown eligibility and cancellation are implemented and ordinary cases pass `test_player_dash_cancel.gd`; the ready buffered dash can lose to contact at recovery start (CR-1). |
| AC9 | ✅ | `Geometry.circle_hits_sector` tests the apex, radial bound, angular interior and finite boundary segments. `tests/core/combat/test_geometry.gd` covers every requested case, including 360° and wide arcs. |
| AC10 | ✅ | `Hitbox.hit_ids` shares the current attack instance's stable-id set; `HitResolver._touches` filters it, and `CombatSim._apply_contact` marks only landed hits. Once-per-hit/three-hit tests in `test_combat_sim.gd`. |
| AC11 | ✅ | `CombatState.apply_hit` clamps HP and applies target damage/knockback/hitstop/i-frames; `CombatSim._apply_contact` also applies attacker hitstop/events. `HitEvent.from_candidate` carries the required fields. `test_combat_state.gd`, `test_hit_resolver.gd` and `test_combat_sim.gd` verify payloads and reactions; signal ordering is logged in ASSUMPTION-3. |
| AC12 | ✅ | `HitEvent._direction_of`, target scaling and `CombatState`'s constant-speed remaining distance implement knockback. `CombatBody.move_with_combatant` collides and syncs authoritative positions. Core knockback tests and `tests/scenes/test_f003_physics.gd` cover direction, replacement and walls. |
| AC13 | ✅ | `CombatState.consume_hitstop/_extend_hitstop`, motor/dummy step loops and `Combatant.get_live_hitbox` implement per-entity pauses and max-extension. `test_player_hitstop.gd`, `test_dummy_logic.gd` and `test_combat_sim.gd` cover timer pauses, bystanders and multiple targets. |
| AC14 | ✅ | `PlayerMotor.is_dash_protected` uses the exact half-open window; `Combatant.can_be_hit` also checks hurt protection. Candidate marking happens after the recheck. Boundary/skip-then-hit tests in `test_combat_batches.gd` and `test_player_hit_reaction.gd`. |
| AC15 | ✅ | `PlayerMotor.apply_hit/_advance_knockback` interrupt attacks/dashes, preserve buffers, start full interrupted-dash cooldown and handle zero distance. Tests in `test_player_hit_reaction.gd`. |
| AC16 | ✅ | `CombatState.apply_hit` emits `died` only on a positive-to-zero transition; the F-003 runner explicitly connects debug refill. `test_combat_state.gd` and `test_f003_views.gd` assert both halves. |
| AC17 | ✅ | `HitResolver._touches` rejects same-team candidates. `test_hit_resolver.gd` and `test_combat_batches.gd` cover self/same-team sword and pulse cases. |
| AC18 | ✅ | `DummyLogic` owns KO/respawn and per-instance scaling; `TrainingDummy` derives HP/bar/KO views from state. `test_dummy_logic.gd`, `test_f003_presentation.gd` and `test_f003_debug_keys.gd` cover ignored hits, respawn and anchored/loose movement. |
| AC19 | ❌ | `PulseCycle` and `DummyLogic.set_pulse_enabled/_enter_ko/_respawn` implement the requested phases/lifecycle, tested in `test_dummy_logic.gd`; real-scene toggle behavior after restore fails (CR-2). |
| AC20 | ✅ | `DamageNumbers` listens to each dummy's `damaged`, with larger finisher fonts; `TrainingDummy` draws HP/bar and the overlay reads player HP. Assertions in `test_f003_presentation.gd` and `test_f003_views.gd`. |
| AC21 | ❌ | Local-player signal listeners and disabling work in `PlaceholderShake`, covered by `test_f003_views.gd`. Reloading an active shake can exceed the specified intensity (CR-3). |
| AC22 | ✅ | `CombatSim.tick` implements the shared grid. Exact four-hit/52-damage, dash-time and final-position oracles exist at all three rates in `test_combat_sim.gd` and over real physics in `test_f003_physics.gd`. |
| AC23 | ✅ | `CombatSim.to_dict/from_dict`, motor/chain/combat/dummy/pulse snapshots preserve the requested core continuation and reject different ids/order/rate. `test_player_snapshot.gd` rebuilds fresh objects and compares 60 following ticks. Runner toggle/view reconciliation is separately blocked by CR-2. |
| AC24 | ❌ | Runner validation, deep atomic loading, running-window rate checks, HP clamps and attack/pulse/knockback latching have core and scene coverage in validation tests, `test_rate_change.gd` and `test_f003_reload.gd`. Active shake settings violate the remaining C18 reload rule (CR-3). |
| AC25 | ✅ | Core/mapper/scene coverage exists in the specified directories; exact input-map migration adds only P/K/R. No pre-existing F-001 tests changed apart from `tests/test_input_map.gd`. Mode B supplied passing test/lint/purity gates; independently ran `tools/test_studio`: 243 tests passed. The three new regression cases above are missing. |
| AC26 | ✅ | `CombatTiming.window_errors` centralizes both minimum-duration bounds; the sim, exact dash check and hitstop remainder consumption implement the timeline. `test_combat_sim.gd` and validation tests cover the listed short/zero-lead/contact-boundary/overshoot/reach oracles at 30/60/120 Hz. |
| AC27 | ❌ | Priority, cooldown retention, chain reset, interrupted dash and replacement/zero knockback have tests in `test_player_dash_cancel.gd`, `test_player_hit_reaction.gd` and `test_combat_batches.gd`. Arbitration at an exact end-of-step eligibility boundary is still deferred past contact (CR-1). |
| AC28 | ✅ | `CombatSim._apply_contact` builds candidates once, rechecks only targets and uses max hitstop. Shared hit-set arrays survive interruption without contaminating a new instance. `test_combat_batches.gd` covers player/dummy batches, KO, unmarked skips and trades in both registration orders. |
| AC29 | ✅ | `CombatRunner._move_bodies` runs before resolution; `CombatBody.move_with_combatant` synchronizes the collided position. `test_f003_physics.gd` checks wall/no-wall controls and motor/body agreement at contacts for dash and knockback. |
| AC30 | ✅ | Runner/body reset methods rerun setup, restore start positions, retain debug toggles and clear transient views. `test_f003_debug_keys.gd` compares snapshots with fresh setup and checks pulse restart/shake retention. |
| AC31 | ✅ | `CombatRunner._physics_process` alone submits/steps logic; `Player` has no physics tick. Both debug scenes register through the runner. `test_f003_runner.gd` counts 4/2/1 steps and checks single command delivery. |

**Rejected options / constraints:** No rejected alternative from §3 was reintroduced: resolution remains per combat step, geometry stays in core, cooldown is retained, only landed hits mark targets, and no global hitstop, animation-driven hitboxes, Area2D combat or full-enemy dummy appears. G1/G3–G9 and the core architecture have supporting implementation/tests; the explicit constraint failures are C17 (CR-1), C12/C19 (CR-2) and C18 (CR-3). The default AC22 oracle passing does not establish C17 at other valid phase boundaries.

**Deviation audit:** DEV-1/DEV-2 are justified API factoring with shared hit-set ownership; DEV-3 is staged history. DEV-4's helpers preserve the core/glue split; DEV-5 keeps F-001's overlay key behavior; DEV-6 adds a stateless deep loader. DEV-7's test split preserves the intended coverage. DEV-8 accurately documents non-buildable intermediate commits and is not a current-HEAD compile defect. No further intentional scope/API deviation was identified. CR-2/CR-3's behavior is not authorized by any logged deviation.

**Assumptions:** ASSUMPTION-1 is not acceptable because it changes the outcome of a boundary contact (CR-1). ASSUMPTION-2's epsilon convention is small and reversible, but cannot authorize that ordering. ASSUMPTION-3's synchronous target-before-attacker signal sequencing is explicit and reversible; both reactions complete before the next candidate. ASSUMPTION-4 matches the stated “both can fire” condition. ASSUMPTION-5 is consistent with stored velocity being zeroed on an incoming hit; later hitstop must still preserve existing velocity under C7. ASSUMPTION-6 follows the deliberately deferred death flow. ASSUMPTION-7 keeps a diagnostic scene clock without affecting combatant resets. ASSUMPTION-8 follows the telegraph/live-hitbox contracts. No additional blocking assumption was found.

**Verification:** Reviewed the feature in full, the branch diff against `main`, project decisions/design/glossary, implementation and relevant test assertions. Relied on the supplied passing Mode B `tools/test`, `tools/lint` and `tools/check_core_purity` results for this exact HEAD. Independently ran `tools/test_studio` (243/243 passed) and a temporary headless scene outside the repository that reproduced CR-1 at all three required rates and CR-2/CR-3 on the real scene/presentation nodes. No source or test files were changed. The manual KB/M/gamepad feel test remains for Lucas as logged in §8.

<!-- review-round: 2 verdict: APPROVE -->

**Reviewed commit:** 981ebedd11f5859d17321bed01d1f373f95fae56

**Verdict:** APPROVE — no new findings. Checked each Builder reply first; CR-1–CR-3 are resolved as annotated above. The feature remains `CODE_REVIEW`, with Lucas next for Gate B.

**AC evidence** (repository-relative paths; current-HEAD evidence for every criterion):

| AC | Result | Evidence at the reviewed HEAD |
|---|---|---|
| AC1 | ✅ | `PlayerMotor.from_dict()` emits `state_restored`; `Player._refresh_from_state()`, `TrainingDummy.refresh_view()` and `CombatDebugDraw` derive their views from state. Real tint, HP and arc restoration assertions are in `tests/scenes/test_f003_restore.gd` and `test_f003_views.gd`. |
| AC2 | ✅ | `src/core/player/attack_chain.gd` latches and advances windup/active/recovery; `PlayerMotor._advance_attack()` carries exact segment time and exposes a hitbox only during active. Phase/lifetime assertions: `tests/core/player/test_player_attack.gd`. |
| AC3 | ✅ | `AttackChain.start()` locks `_direction` from facing; later aim updates only the motor's facing. Locked-aim assertions: `test_player_attack.gd`. |
| AC4 | ✅ | `AttackChain.advance/advance_window/_finish_recovery` manage the recovery-start window; motor arbitration allows chaining throughout non-finisher recovery. Recovery, short-window, post-recovery and expired-window cases: `test_player_attack.gd`. |
| AC5 | ✅ | `PlayerMotor._take_presses/_fire_buffered_actions` retain only the newest press, pause ages in hitstop and check eligibility/expiry at transitions. `CombatSim.tick()` now fires boundary-due actions before contact. Evidence: `test_player_attack.gd`, `test_player_hit_reaction.gd`, `test_player_hitstop.gd` and `tests/core/combat/test_boundary_actions.gd`. |
| AC6 | ✅ | The chain latches finisher values and wraps its next index; motor arbitration prevents attack cancellation of finisher recovery while allowing a ready dash. Evidence: `test_player_attack.gd` and `test_player_dash_cancel.gd`. |
| AC7 | ✅ | `PlayerMotor._advance_attack()` integrates velocity toward zero using class deceleration; normal movement resumes after recovery. Rooting and deceleration assertions: `test_player_attack.gd`. |
| AC8 | ✅ | Motor cooldown checks, segmented expiry and the new pre-contact due-action hook fire eligible recovery cancels at the required instant without refunding cooldown. Ordinary/expired cases: `test_player_dash_cancel.gd`; exact recovery/cooldown contacts at 30/60/120 Hz: `test_boundary_actions.gd`. |
| AC9 | ✅ | `src/core/combat/geometry.gd` checks sector interior, apex, finite radial edges and range. `tests/core/combat/test_geometry.gd` covers all requested cases, full circles and wide arcs. |
| AC10 | ✅ | `Hitbox.hit_ids` shares the attack instance's stable-id array; `HitResolver` filters it and `CombatSim._apply_contact()` marks only landed hits. Once-per-instance and separate-chain-hit evidence: `test_combat_sim.gd` and `test_combat_batches.gd`. |
| AC11 | ✅ | `CombatState.apply_hit()` clamps HP, initializes knockback/hitstop/hurt protection and emits damage/death; the sim applies attacker hitstop and `hit_landed`. `HitEvent.from_candidate()` supplies the payload. Assertions: `test_combat_state.gd`, `test_hit_resolver.gd` and `test_combat_sim.gd`. |
| AC12 | ✅ | `HitEvent._direction_of()`, target scale and `CombatState` implement fixed-speed, replaceable knockback after hitstop. `CombatBody.move_with_combatant()` collides and syncs position. Core reaction/dummy tests and `tests/scenes/test_f003_physics.gd` cover scaling, direction, replacement and walls. |
| AC13 | ✅ | `CombatState.consume_hitstop/_extend_hitstop`, motor/dummy phase loops and `Combatant.get_live_hitbox()` implement per-entity pauses, remainder carry and max-extension. Evidence: `test_player_hitstop.gd`, `test_dummy_logic.gd`, `test_combat_state.gd` and `test_combat_sim.gd`. |
| AC14 | ✅ | `PlayerMotor.is_dash_protected()` checks the exact half-open window; `Combatant.can_be_hit()` also checks hurt protection before marking. Protection expiry and skipped-target retry assertions: `test_player_hit_reaction.gd` and `test_combat_batches.gd`. |
| AC15 | ✅ | `PlayerMotor.apply_hit/_advance_knockback` interrupt attacks/dashes, reset the chain, retain buffers and start the full interrupted-dash cooldown. `test_player_hit_reaction.gd` covers these rules and zero knockback. |
| AC16 | ✅ | `CombatState.apply_hit()` emits `died` only on a positive-to-zero transition; the debug runner explicitly connects refill. Assertions: `test_combat_state.gd` and `test_f003_views.gd`. |
| AC17 | ✅ | `HitResolver._touches()` rejects same-team pairs. Self/sword/pulse cases: `test_hit_resolver.gd` and `test_combat_batches.gd`. |
| AC18 | ✅ | `DummyLogic` owns KO, protected respawn and instance-scaled knockback; `TrainingDummy` derives HP/bar/KO views from state. Evidence: `test_dummy_logic.gd`, `test_f003_presentation.gd` and `test_f003_debug_keys.gd`. |
| AC19 | ✅ | `PulseCycle` implements telegraph/active/wait with start-to-start timing and latched values; dummy lifecycle handles toggles/KO/respawn. `CombatRunner.is_pulse_on()` now derives from restored logic. Evidence: `test_dummy_logic.gd`, `test_f003_debug_keys.gd` and `test_f003_pulse_restore.gd`. |
| AC20 | ✅ | `DamageNumbers` listens to dummy damage and enlarges finishers; dummy views draw HP/bar and the overlay reads player HP. Real-view assertions: `test_f003_presentation.gd` and `test_f003_views.gd`. |
| AC21 | ✅ | `PlaceholderShake` listens to the local player's hit/damage signals, reads configured intensities and clears/skips while disabled. Active look values are now latched. Signal/toggle/envelope assertions: `test_f003_views.gd` and the new reload regression in `test_f003_reload.gd`. |
| AC22 | ✅ | `CombatSim.tick()` preserves the shared step schedule. The exact four-hit/52-damage oracle, dash times and final position are asserted at 30/60/120 Hz in `test_combat_sim.gd` and over real physics in `test_f003_physics.gd`. |
| AC23 | ✅ | Sim/motor/chain/combat/dummy/pulse snapshots preserve core continuation and reject mismatched ids/order/rate. `test_player_snapshot.gd` restores fresh objects and compares 60 subsequent ticks; scene restoration and transient clearing are covered by `test_f003_views.gd` and `test_f003_pulse_restore.gd`. |
| AC24 | ✅ | `CombatRunner.reload_data()` deep-loads and validates the atomic group, checks running latched windows and applies only after success. The legacy player reload rejects rate changes; active shake look now remains latched. Evidence: validation tests, `test_rate_change.gd`, `test_f003_runner.gd` and `test_f003_reload.gd`, including real F5 during an active shake. |
| AC25 | ✅ | Core, mapper and real-scene tests match the coverage map. The diff leaves all pre-existing F-001 tests unchanged except the three-action input-map migration. Supplied Mode B test/lint/purity gates passed; independently ran 34 focused GUT tests and all 243 studio tests successfully. |
| AC26 | ✅ | `CombatTiming.window_errors()` centralizes the two duration bounds; the sim, exact protection check and hitstop consumption implement the timeline. Short/zero-lead/start-boundary/overshoot/reach oracles at all three rates: `test_combat_sim.gd` and validation tests. |
| AC27 | ✅ | Motor arbitration preserves priority, cooldown, chain reset and interrupted-dash rules; knockback replaces and zero distance skips the state. Evidence: `test_player_dash_cancel.gd`, `test_player_hit_reaction.gd`, `test_combat_batches.gd` and the new contact-level `test_boundary_actions.gd`. |
| AC28 | ✅ | `CombatSim._apply_contact()` creates candidates once and rechecks targets only; shared instance hit sets survive interruption without contaminating a new attack. `test_combat_batches.gd` covers multi-target batches, KO skips, unmarked protection skips and trades in either registration order; hitstop remains a max. |
| AC29 | ✅ | The runner moves bodies and syncs logic before resolution through `CombatBody.move_with_combatant()`. `test_f003_physics.gd` checks wall/no-wall controls and motor/body agreement at contact during dash and knockback. |
| AC30 | ✅ | Runner/body reset methods rerun setup, restore scene starts, retain debug toggles and clear transient views. `test_f003_debug_keys.gd` compares snapshots with fresh setup and checks pulse restart/shake retention. |
| AC31 | ✅ | `CombatRunner._physics_process()` alone submits/steps logic; `Player` has no physics tick and both debug scenes register through a runner. Step-count and single-command-delivery assertions: `test_f003_runner.gd`. |

**Rejected-option / constraint check:** No rejected option from §3 appears in the implementation. The new due-action hook completes Advance before Move/Contact; it adds no contact and does not bypass cooldown or change the half-open active-window rule. The core/glue split, scene-owned combat state, serializable state, command input, data resources, unchanged input bindings and collision-corrected contacts remain consistent with C1–C20, G1–G9 and D-002/D-005/D-007. No new dependency or animation/physics-driven combat decision was introduced.

**Deviation audit:** DEV-1–DEV-7 remain justified factoring, loading and test-organization choices. DEV-8 documents intermediate-history defects, with no current-HEAD defect found. DEV-9 is justified: the sim's due-action hook enforces C17 before contact while `PlayerMotor.tick()` retains the required F-001 boundary behavior, pinned by `test_player_motor_steps.gd`. No additional undocumented deviation found.

**Assumptions:** ASSUMPTION-1 is explicitly withdrawn. ASSUMPTION-2/10 apply C15's epsilon boundary convention and have regression coverage. ASSUMPTION-3's synchronous target-before-attacker signals, ASSUMPTION-4's finisher-buffer interpretation, ASSUMPTION-5's knockback speed display, ASSUMPTION-6's deferred death behavior, ASSUMPTION-7's diagnostic scene clock and ASSUMPTION-8's state-derived pulse/arc visibility remain reasonable and reversible. ASSUMPTION-9 follows the existing C15 ordering: the prior tick's last contact precedes new-tick presses, so a new press cannot retroactively participate in that contact's arbitration. Its 30/60/120 Hz regression pins the behavior; no additional gameplay rule is needed.

**Verification:** Read the entire feature, project decisions/design/glossary, full branch diff against `main` and the fixes since round 1. Relied on the supplied passing Mode B `tools/test`, `tools/lint` and `tools/check_core_purity` gates for this exact HEAD. Independently reran the original temporary reproduction: CR-1 now yields HP 100 and dash time 0.1 at 30/60/120 Hz; CR-2 toggles correctly after restore; CR-3 retains intensity 0.5 after reload. Independently ran four focused GUT scripts (34/34 tests, 388 assertions) and `tools/test_studio` (243/243 passed). No source or test files changed. The manual KB/M/gamepad feel test remains for Lucas as recorded in §8.

---

## 10. Open Questions  ·  _Anyone (append)_

| # | Raised by | Question | Blocking? | Answer (Lucas/Planner) |
|---|---|---|---|---|
| Q1 | Combat | → Art & Game Feel: final look of hit flash, damage numbers and screen shake (CX2). Placeholders in this feature only. | no | |
| Q2 | Combat | → Direction: `screen_shake_enabled` is a data flag for now. Where do player-facing settings live once a settings menu exists, and do they persist per player or per character? | no | |
| Q3 | Combat | → Combat (F-004): enemy hurt rules (i-frames, stagger, knockback resistance) are decided with the enemies. The dummy has no hurt i-frames. | no | |
| Q4 | Combat | → Lucas: D-007 (combat runs on a 1/120 s step grid) is PROPOSED because it binds every later combat feature. Approving this plan at Gate A accepts it. | no | |

---

## 11. Director Notes  ·  _Lucas_

<Overrides, priorities, gut calls. Everyone obeys these.>
- **2026-11-01 (Gate A):** Gate A: plan approved after 3 autopilot rounds. D-007 (120 Hz combat step grid) ACCEPTED.
- **2026-11-01 (Gate B):** Gate B: playtested, feel approved.
