---
id: F-003
title: Warrior sword chain + hit/hurt + hitstop + training dummy
status: PLAN_CHANGES     # DRAFT | PLAN_REVIEW | PLAN_CHANGES | APPROVED | IN_PROGRESS | CODE_REVIEW | CODE_CHANGES | DONE | PARKED
owner_now: Planner       # who must act next: Planner | Auditor | Builder | Lucas
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
  - Per-tick ownership today: `Player._physics_process` runs its own commands → motor → `move_and_slide`. T9 moves this into one scene-level runner; F-001's scene and its tests (incl. `tests/scenes/test_f001_*`) must keep passing.
  - F-001's debug overlay and the F5 tunable hot-reload.
- **Relevant prior decisions:**
  - D-002 — online-ready architecture. Hitstop must never freeze other entities. Shake must be a per-player presentation effect.
  - D-005 — the chain is class data: `ClassData` holds an ordered list of attack resources.
- **Carry-over from the F-001 code review:** the invulnerability tint can stay stuck after restoring a snapshot, in `src/entities/player/player.gd`. The tint follows the `invulnerability_changed` signal, and `from_dict()` restores state without the visuals re-syncing. Fixed in T1, with a general rule (C12).
- **Relevant prior features:** F-000 (tooling), F-001 (movement + dash).

---

## 3. Options Considered  ·  _Planner_

> This section is what stops context loss. Be honest about trade-offs.
> The Builder MUST NOT implement anything listed under Rejected.

### ✅ Chosen: Geometric hit detection in core + per-scene `HitResolver`
- **How it works:**
  - Hurtboxes are circles: position, radius, team and owner id. Hitboxes are sectors: origin, locked direction, arc angle and range. A full circle is a sector with a 360° arc.
  - `HitResolver` (`RefCounted`, `src/core/combat/`) is created once per scene by glue, never as an autoload. Every physics tick, after all entities have ticked their logic, it tests each active hitbox against every hurtbox of another team, using an exact circle–sector intersection. It produces hit events in a deterministic order (registration order).
  - Hits are applied in this order:
    1. damage
    2. knockback
    3. per-entity hitstop on attacker and target
    4. hurt i-frames on the target (player only)
  - Logic emits signals (`hit_landed`, `damaged`, `died`). Presentation listens and draws the number, the flash and the shake.
- **Why chosen:**
  - The design doc says hits come from shapes and timers, not animation (G6).
  - Pure geometry is unit-testable without a scene, serializable (G7) and deterministic. That last point matters for co-op later.
  - A resolver per scene, with no global, keeps C6 from F-001.
- **Costs we're accepting:**
  - Hitboxes don't use Godot physics, so walls don't block sword arcs. That's acceptable at sword range.
  - Collision shapes are limited to circles and sectors.
  - The test is O(hitboxes × hurtboxes) per tick, which is fine for phase 1 counts.
- **Would revisit if:** bosses need shapes that aren't circles or sectors (lines, rectangles), or entity counts make per-tick testing slow. Either way, add the new shape types to the resolver; don't switch to Area2D.

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
| C1 | All new timers run on `delta` in `_physics_process`. Same commands at 30, 60 and 120 ticks/s give the same hits, the same damage and the same positions (± tolerance). | G1 |
| C2 | Every number comes from `data/`: per-hit values from `data/attacks/sword_hit_{1,2,3}.tres`; class values from `warrior.tres`; shared rules from `player_combat.tres`; dummy values from `data/enemies/training_dummy.tres`; placeholder shake look from `data/tunables/screen_shake.tres`. | G2, G9, D-005 |
| C3 | Hit detection, damage, knockback, hitstop and HP live in `src/core/`. They never read animations, sprites, `Area2D` or physics overlaps. | G6 |
| C4 | Attacking goes through an `AttackCommand`, the same way as F-001's commands. | G8 |
| C5 | All new state is serializable via `to_dict()`/`from_dict()`. That includes chain index, attack phase and its timer, chain window, locked aim, hit set, buffered attack, HP, hitstop, hurt i-frames, knockback, dummy HP and dummy respawn timer. | G7 |
| C6 | No autoload or static holds combat state. `HitResolver` is created per scene. | F-001 C6, D-002 |
| C7 | Hitstop is per entity. While an entity is in hitstop, **all** of its logic timers pause (attack phase, chain window, dash, cooldown, i-frames, knockback, input buffer ages) and its logic velocity is zero. Other entities are unaffected. A new hitstop takes the larger of the remaining and the new duration; it never adds them. | CQ8, D-002 |
| C8 | One attack instance (one hit's active phase) hits each hurtbox at most once. A hurtbox that was skipped because of i-frames is **not** marked as hit. | design doc, §3 |
| C9 | Teams: a hitbox never hits a hurtbox of its own team. No friendly fire, and no PvP (anti-goal). | PROJECT.md |
| C10 | Shake is never emitted by core. Presentation maps `hit_landed`/`damaged` to intensities from `player_combat.tres`, and only for hits where a **local player** is the attacker or the target. Shake is skipped entirely when `screen_shake_enabled` is false. | CQ8, D-002 |
| C11 | Dash rules from F-001 are unchanged, except: a dash cancels attack **recovery** only; a dash pressed during windup, active or knockback is buffered (F-001 buffer rules). | design doc |
| C12 | Presentation that mirrors logic state (i-frame tint, HP displays, debug arcs) must be **derivable from current state**. Signals may trigger a refresh, but after `from_dict()` every view re-syncs from state. | F-001 code review |
| C13 | No new addons or dependencies. | G4 |
| C14 | Existing input actions keep their names and bindings; only the three debug actions in §2 are added. | F-000/F-001 must-not-break |

**Must not break:** all F-001 behavior and tests (AC1–AC17 of F-001), F-001's debug scene, existing input bindings, `tools/test`, `tools/lint`, the core purity check, and `tools/test_studio`.

---

## 5. Acceptance Criteria  ·  _Planner_

Testable, observable. The Auditor checks each one. "Tolerance" = one tick.

**F-001 carry-over**
- [ ] AC1 — **Tint re-sync:** Snapshot the player mid-dash during i-frames, let the i-frames end, then restore. The tint must be on. Snapshot outside i-frames, enter i-frames, then restore. The tint must be off. The same check applies to the HP display and the debug arc.

**Attack chain**
- [ ] AC2 — **Phases:** Each hit runs windup → active → recovery with the durations in its attack file. The hitbox exists only during active.
- [ ] AC3 — **Locked aim:** The hit's direction = facing at the first tick of windup. Facing keeps updating afterwards, but that hit's direction does not.
- [ ] AC4 — **Chaining:**
  - The chain window opens at the first tick of recovery and lasts `attack_chain_window`.
  - An attack pressed during hit N's recovery starts hit N+1 immediately, cancelling the rest of the recovery.
  - An attack pressed after recovery but still inside the window also starts hit N+1.
  - An attack pressed after the window starts hit 1.
- [ ] AC5 — **Attack buffer:**
  - An attack pressed during windup or active is buffered. It fires at the first tick of recovery, as hit N+1, if pressed within `input_buffer_window`; otherwise it is discarded.
  - An attack pressed during a dash or knockback is buffered, and fires as hit 1 when that state ends, if within the window.
  - Only one attack is buffered at a time; the newest press replaces it.
- [ ] AC6 — **Finisher:** Hit 3 uses its own file's values. Its recovery **cannot** be cancelled by attack; a press during it is buffered and starts hit 1 once recovery ends, if within the window. A dash **can** cancel it.
- [ ] AC7 — **Rooted:** During windup, active and recovery, movement input is ignored and velocity decelerates to 0 using `move_decel_time`. Once recovery ends, movement resumes immediately (while still inside the chain window).
- [ ] AC8 — **Dash cancel:**
  - A dash pressed during recovery fires immediately and resets the chain.
  - A dash pressed during windup or active is buffered and fires at the first tick of recovery, if within the window.

**Hit / hurt**
- [ ] AC9 — **Geometry:** Circle–sector intersection is exact. Unit tests cover:
  - a circle fully inside the sector;
  - a circle whose center is outside the arc but whose edge crosses the arc boundary (hit);
  - a circle just beyond range + radius (miss);
  - a circle behind the attacker (miss);
  - the 360° case.
- [ ] AC10 — **Once per instance:** A hurtbox inside the hitbox for the whole active phase takes damage once per hit. Hits 1, 2 and 3 are separate instances.
- [ ] AC11 — **Hit order:** On hit: damage → knockback → hitstop (attacker and target) → hurt i-frames (player target only). Integer damage is subtracted from HP. `hit_landed` (on the attacker) and `damaged` (on the target) are emitted with: attacker id, target id, damage, `is_finisher`, and direction.
- [ ] AC12 — **Knockback:**
  - Distance is the attack's knockback × the target's `knockback_scale`.
  - It is applied over `knockback_duration` at constant speed, starting after the target's hitstop ends.
  - Direction = attacker → target center; if that is zero, the attack direction.
  - Walls stop it.
- [ ] AC13 — **Hitstop:**
  - Normal hits apply `hitstop_normal` to attacker and target; the finisher applies `hitstop_finisher`.
  - During hitstop all of that entity's timers pause (C7), and other entities keep moving and ticking.
  - When one attack hits several targets in the same tick, the attacker gets one hitstop, not one per target.
- [ ] AC14 — **I-frames:**
  - A player inside a hitbox during dash i-frames or hurt i-frames takes no damage, no knockback and no hitstop.
  - If they are still inside when the i-frames end, and the active phase is still running, they are hit (C8).
- [ ] AC15 — **Player hurt:** A hit on the player interrupts any attack and resets the chain. Knockback puts the player in a `KNOCKBACK` state: movement is ignored and dash/attack presses are buffered. Afterwards, `player_hurt_iframes` apply.
- [ ] AC16 — **Player HP:** The player starts at `max_hp`. At 0, the player emits `died`. In the debug scene, HP refills to max and nothing else happens.
- [ ] AC17 — **Teams:** The player's sword never hits the player. The dummy's pulse never hits the dummies.

**Dummy and presentation**
- [ ] AC18 — **Dummy:**
  - It has `max_hp`, a hurtbox radius and a `knockback_scale`.
  - At 0 HP it emits `died`, shows "KO", ignores hits, and refills to max after `respawn_delay`.
  - The anchored dummy (`knockback_scale` 0) never moves. The loose dummy (scale 1) is pushed back and stays where it lands until the reset key.
- [ ] AC19 — **Debug pulse:**
  - Toggled by a debug key, off by default.
  - Each `pulse_interval`, the anchored dummy shows a ring outline for `pulse_telegraph`, then a 360° hitbox of `pulse_radius` is active for `pulse_active` and deals `pulse_damage` and `pulse_knockback`, through the same `HitResolver`.
  - It is a debug tool, not AI.
- [ ] AC20 — **Damage numbers:** Every `damaged` on a dummy spawns a floating number above it; finisher numbers are visibly larger. Each dummy shows HP as a number and a bar. The player's HP is shown in the overlay.
- [ ] AC21 — **Shake:**
  - `hit_landed` by the local player shakes at `shake_intensity_hit`, or `shake_intensity_finisher` if `is_finisher`.
  - `damaged` on the local player shakes at `shake_intensity_player_hurt`.
  - With `screen_shake_enabled = false` (data flag, toggled by a debug key at runtime), there is no shake at all.
- [ ] AC22 — **Frame-rate independence:** A scripted sequence (a full 3-hit chain on a dummy, with dash cancels) at 30, 60 and 120 ticks/s gives the same total damage, the same number of hits and the same final positions (± tolerance).
- [ ] AC23 — **Serialization:** Snapshot and restore mid-windup, mid-active with a partial hit set, mid-hitstop, mid-knockback, and with buffered attack and dash. The next 60 ticks behave identically to an unbroken run. The dummy round-trips too.
- [ ] AC24 — **Hot-reload:** F5 reloads the three attack files, `warrior.tres`, `player_combat.tres`, `training_dummy.tres` and `screen_shake.tres`.
- [ ] AC25 — **Tooling:** GUT tests cover AC2–AC17 and AC22–AC23 at core level; F-001's tests still pass; `tools/test`, `tools/lint` and the core purity check pass.

**How to verify manually (feel test):**
Open `scenes/debug/f003_sword.tscn` and play about 5 minutes with KB/M, then with a gamepad.
- **Mash attack on the anchored dummy.** The 3 hits should flow without dropped inputs. Hit 3 should feel heavier: longer pause, bigger number, stronger shake. The gap after it should feel risky.
- **Swing, then dash out of the recovery.** It should come out instantly, every time.
- **Hit the loose dummy.** The finisher should visibly send it flying.
- **Turn the pulse on.** Dash *through* the ring at the right moment and take nothing. Dash too early and get caught by the tail. Getting hit should feel like a clear punishment, not a stun-lock.
- **Turn shake off.** Hits should still read clearly from hitstop and numbers alone.
- **Tune a value** (e.g. hit 3 windup), press F5, and feel the difference.

---

## 6. Task Breakdown  ·  _Planner_

Small, ordered, each independently committable.

| # | Task | Files likely touched | Notes |
|---|---|---|---|
| T1 | Fix the F-001 tint re-sync | `src/entities/player/player.gd`, `src/core/player/player_motor.gd` | `from_dict()` emits a `state_restored` signal at the end. Player presentation has one `_refresh_from_state()` that sets the tint from `is_invulnerable()`, called on `state_restored` and on `invulnerability_changed`. Add a regression test (AC1). Applies C12. |
| T2 | Data types | `src/core/combat/attack_data.gd` (`AttackData`), `src/core/combat/dummy_data.gd` (`DummyData`), extend `ClassData`, `PlayerCombatTunables`; `src/core/tunables/screen_shake_settings.gd` (`ScreenShakeSettings`) | `AttackData`: `id`, `windup`, `active`, `recovery`, `damage: int`, `arc_angle_deg`, `range_tiles`, `knockback_tiles`, `is_finisher: bool`. `ClassData` += `attack_chain: Array[AttackData]`, `attack_chain_window`, `max_hp: int`, `hurtbox_radius_tiles`. `PlayerCombatTunables` += `player_hurt_iframes`, `knockback_duration`, `hitstop_normal`, `hitstop_finisher`, `shake_intensity_hit`, `shake_intensity_finisher`, `shake_intensity_player_hurt`. `DummyData`: `max_hp`, `hurtbox_radius_tiles`, `knockback_scale`, `respawn_delay`, `pulse_interval`, `pulse_telegraph`, `pulse_active`, `pulse_radius_tiles`, `pulse_damage`, `pulse_knockback_tiles`. `ScreenShakeSettings`: `screen_shake_enabled`, `max_offset_px`, `decay_time` (placeholder look, → Art). |
| T3 | Data files | `data/attacks/sword_hit_{1,2,3}.tres`, `warrior.tres`, `player_combat.tres`, `data/enemies/training_dummy.tres`, `data/tunables/screen_shake.tres` | Values from the design-doc *Tunables index*, plus the new rows listed under Notes for Lucas below. `warrior.tres` gets `attack_chain` = [hit 1, hit 2, hit 3]. Paths as constants (G5). |
| T4 | Attack command + input | `src/commands/attack_command.gd`, player input reader, `project.godot`, `tests/test_input_map.gd`, mapper tests | `AttackCommand()` carries no data; the aim comes from the motor's facing. Produced from the existing `attack` action (bindings unchanged). Add only `debug_pulse_toggle` (P), `debug_shake_toggle` (K), `debug_reset` (R) and migrate the input-map test (§2). |
| T5 | Geometry + resolver | `src/core/combat/hurtbox.gd`, `hitbox.gd`, `geometry.gd`, `hit_resolver.gd`, `hit_event.gd` | Exact circle–sector intersection. `HitResolver`: `register_hurtbox`, `unregister`, `resolve(active_hitboxes) -> Array[HitEvent]`, in deterministic order. Teams as an enum (`PLAYER`, `ENEMY`). Each attacker owns the hit set for its attack instance. |
| T6 | Combat state component | `src/core/combat/combat_state.gd` (`CombatState`) | Shared by the player and the dummy: HP, hitstop timer, knockback (remaining distance, direction, speed), hurt i-frames, `apply_hit(event, tunables)`, signals `damaged`, `died`, `to_dict`/`from_dict`. Hitstop takes the max of remaining and new (C7). |
| T7 | Motor: attack chain + knockback | `src/core/player/player_motor.gd` (+ an `attack_chain.gd` helper if it grows) | New states: `ATTACKING` (with phase) and `KNOCKBACK`. Implements AC2–AC8 and AC15. Hitstop pauses every timer, including buffer ages (C7). Exposes the active hitbox (or none) for the resolver. Emits `hit_landed`. Extend serialization (C5). |
| T8 | Core tests | `tests/core/combat/test_geometry.gd`, `test_hit_resolver.gd`, `test_combat_state.gd`, `tests/core/player/test_player_attack.gd`, `test_player_snapshot.gd` | Cover AC2–AC17, AC22, AC23. No scenes. |
| T9 | Player glue | `src/entities/player/player.gd` | Per-tick order: commands → all entities tick logic → resolver resolves → apply hit events → `move_and_slide` → write positions back. The order is owned by one scene-level runner, not by each entity on its own. Player HP refill on `died` happens only in the debug scene. |
| T10 | Dummy | `src/core/combat/dummy_logic.gd`, `src/entities/dummy/training_dummy.gd`, `.tscn` | Logic: `CombatState` + respawn timer + debug pulse timer. Body: `CharacterBody2D`, with knockback applied via `move_and_slide`. Placeholder visuals: a circle, an HP bar with a number, a "KO" label, a telegraph ring. |
| T11 | Presentation listeners | `src/ui/debug/damage_numbers.gd`, `src/world/camera/placeholder_shake.gd` | Floating numbers on dummies. Placeholder shake: random camera offset ≤ `intensity × max_offset_px`, decaying over `decay_time`. Implements C10 and AC21. A placeholder white flash on the damaged entity is allowed. |
| T12 | Debug scene + overlay | `scenes/debug/f003_sword.tscn`, extend `src/ui/debug/motor_debug_overlay.gd` | Room with one anchored dummy and one loose dummy. Overlay shows: chain index, phase and remaining time, chain window, buffered attack/dash, hitstop remaining, player HP, hurt i-frames, shake on/off. Draws the active hitbox arc and the hurtbox circles. Keys: F5 `debug_reload_tunables`, P `debug_pulse_toggle`, K `debug_shake_toggle`, R `debug_reset` (actions from T4). F-001's debug scene keeps working unchanged. |
| T13 | Glossary | `studio/GLOSSARY.md` | Add: Hitbox, Hurtbox, Attack instance, Windup / Active / Recovery, Chain window, Hitstop, Knockback, Hurt i-frames, Punish window, Telegraph, Team. |

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

### PR-2 🔴 Hurt i-frames begin at two different points

**Location:** §3 hit application step 4; §5 AC11 versus AC15; `studio/design/combat.md` → Hit / hurt system.

**Problem:** AC11 and the design doc apply hurt i-frames on hit, after initializing knockback and hitstop. AC15 instead says they apply “Afterwards,” following the `KNOCKBACK` state. These produce different protection during knockback and different expiry times: with the defaults, starting the 0.6 s timer on hit leaves 0.48 s after the 0.12 s knockback, excluding paused hitstop; starting it afterwards leaves the full 0.6 s.

**Why it matters:** This is an unflagged conflict with the department design doc and changes whether the player can be hit repeatedly during knockback.

**Suggested fix:** Make AC15 agree with the on-hit rule and state explicitly whether the timer ages during knockback, preserving C7's pause during hitstop. If delayed i-frames are intended instead, explicitly reconcile the design doc and AC11 and define protection during knockback. Add boundary checks for the chosen rule.

### PR-3 🔴 Immediate recovery dash cancels contradict the retained cooldown

**Location:** §4 C11 and must-not-break; §5 AC8 and manual dash-cancel check. Related: F-001 AC11/AC12.

**Problem:** AC8 requires a dash pressed during recovery to fire immediately, including a buffered dash at recovery start, without a cooldown condition. C11 preserves F-001's rule that a new dash cannot fire until cooldown ends. This occurs with default data: dash at 0, end at 0.15, start a missed hit at 1/6 s, then press dash during its recovery at 1/3 s. Cooldown lasts until 0.50 s, so both requirements cannot hold.

**Why it matters:** The Builder must either bypass a required defensive cooldown or fail the new dash-cancel AC. The manual promise “instantly, every time” has the same conflict.

**Suggested fix:** State that recovery cancellation fires immediately only when dash cooldown permits it; otherwise apply the existing buffer eligibility/expiry rules, without cancelling recovery until a dash actually fires. Qualify AC8 and the feel test, and cover recovery presses with cooldown ready, cooldown expiring within the buffer and cooldown expiring too late.

### PR-4 🟡 Define arbitration between buffered actions and interrupted movement states

**Location:** §5 AC4–AC8/AC15; §6 T7.

**Problem:** An attack and a dash can both be buffered during active and both are required to fire at recovery start. After knockback, both may also be eligible. The spec gives neither priority nor a rule for clearing or retaining the losing buffer. A hit in a vulnerable dash tail enters `KNOCKBACK`, but it is also unspecified whether this interrupted dash starts its cooldown. Repeated hits on a dummy during knockback have no replacement-versus-accumulation rule for remaining knockback.

**Why it matters:** These choices affect whether an intended escape becomes another attack, whether a stale attack fires after the escape, and whether interrupted dashes evade cooldown. They also change loose-dummy travel under a chain.

**Suggested fix:** Add a transition/priority table for simultaneous eligible actions and incoming hits, including buffer disposal, dash interruption/cooldown and repeated knockback. Add focused tests for both buffers at recovery/knockback exit and for a hit during the vulnerable dash tail.

### PR-5 🟡 Define eligibility while applying a batch of hit events

**Location:** §3 chosen resolver; §4 C8; §5 AC10/AC11/AC14/AC18; §6 T5/T9.

**Problem:** `resolve()` returns an array before any event is applied. Registration order orders that array, but does not say whether later events recheck i-frames, death and attack interruption after earlier events mutate state. Two simultaneous incoming hitboxes can both pass an initial eligibility check before the first hit grants hurt i-frames; marking both in their hit sets would also prevent the skipped one from hitting later. A sword hit and the dummy's pulse in the same tick leave the trade/interruption policy undefined.

**Why it matters:** Ordered candidates alone do not establish deterministic damage semantics or C8's rule that an i-frame-skipped target remains hittable later.

**Suggested fix:** Distinguish geometric candidates from successfully applied hits. Specify when eligibility is rechecked and hit sets are updated, and whether simultaneous outgoing attacks trade or are cancelled by an earlier event. Test two hitboxes against one player and a player/dummy exchange in one tick.

### PR-6 🟡 Resolve geometry using an explicit authoritative position

**Location:** §6 T9; §5 AC12. Related: `src/core/player/player_motor.gd:122` and `src/entities/player/player.gd:33`.

**Problem:** The existing motor advances its predicted position inside `tick()`, then glue corrects it after `move_and_slide()`. T9 inserts hit resolution before that correction. Reading the ticked motor's position tests shapes at a position that may be inside or beyond a wall; reading the body instead tests the previous position. The spec does not choose either interpretation or another reconciliation step.

**Why it matters:** Hits can be added or missed around walls because the hurtbox and the actual body disagree. Accepting sword arcs through walls in §3 does not establish permission to move their origins or target centers through walls.

**Suggested fix:** Specify where shape positions come from and when collision-corrected positions become authoritative in the hit timeline from PR-1. Add a scene case where a dashing or knocked-back body reaches a wall while a hitbox is active, verifying the resolver uses the intended body position.

### PR-7 🟡 Complete the new data validation and hot-reload contract

**Location:** §4 C2; §5 AC4/AC12/AC24; §6 T2/T3. Related: F-001 §4 C17.

**Problem:** AC24 lists the files to reload but does not extend F-001's atomic validation/latching policy to them. It leaves bounds and zero-duration behavior undefined for phases, arcs, knockback and pulse timers; likewise empty/null chain entries and a chain window shorter than recovery. Reloading an in-progress hit leaves its duration, damage, geometry and chain identity unspecified, and lowering `max_hp` leaves current HP unspecified. AC12 also multiplies by the *target's* `knockback_scale`, but T2 defines that field only for dummies, with no player source or explicit fixed player rule.

**Why it matters:** Tuning is the purpose of the dummy scene. These gaps can produce partially updated combat, skipped phases or invalid state, and force the Builder to invent gameplay/data policy.

**Suggested fix:** Extend the validation table and define the atomic reload group, latched versus immediately updated fields, current-HP handling and permitted chain edits. Reconcile the chain-window/recovery relationship and specify the player's knockback scaling source. Cover invalid new data and a valid reload during an attack and knockback.

### PR-8 🟡 Define snapshot identity and the scene snapshot boundary

**Location:** §3 owner IDs/registration order; §4 C5; §5 AC23; §6 T5/T9/T10.

**Problem:** The hit set stores hurtbox identities, but the spec does not say how IDs and resolver registration order survive reconstruction in fresh objects. F-001's snapshot boundary is after an individual motor tick; T9 now performs hit application and collision correction afterwards, so that boundary can capture a partially processed scene. The dummy's pulse enable flag, phase, remaining interval/telegraph/active time and per-pulse hit set also need an explicit continuation check, beyond merely round-tripping its HP.

**Why it matters:** A snapshot can restore the same scalar values yet hit a target twice, skip a target or resume a different pulse. That fails C5/G7 and AC23's continuation promise.

**Suggested fix:** Define stable scene-supplied identities, registry restoration order and one snapshot boundary after the complete scene step with no pending events/commands. Include pulse state and reconstruct the player, both dummies and resolver as fresh objects in a partial-hit-set continuation test.

### PR-9 🟡 Separate core coverage from scene coverage and give position tolerance units

**Location:** §5 introduction/AC1/AC12/AC16/AC22/AC25; §6 T8/T9/T12.

**Problem:** AC25 and T8 require AC2–AC17 at core level, but AC12's wall collision and AC16's debug-scene refill depend on glue/physics. T1's tint/HP/arc re-sync also requires presentation assertions; a core signal test alone cannot verify it. No new scene-test task covers these behaviors or the new runner's once-per-tick ownership. Finally, “Tolerance = one tick” supplies no distance unit or numeric bound for AC22's final positions and does not identify a common input/sample schedule across rates.

**Why it matters:** Core tests can pass while the newly refactored scene moves twice, ignores collision or restores stale visuals. AC22 has no objective position pass/fail threshold.

**Suggested fix:** Add a coverage map and scene-test task for new collision behavior, debug refill, actual view restoration and one runner step per physics tick, while retaining pure core tests for combat. Give AC22 a shared physical-time input/sample schedule, expected hit/damage totals, a numeric position tolerance in tiles and a separate timing tolerance.

### PR-10 🟡 Specify the debug reset and pulse lifecycle

**Location:** §5 AC18/AC19; §6 T10/T12.

**Problem:** R is named and the loose dummy stays put “until the reset key,” but the reset operation has no defined state set. It could restore only positions or also HP, attacks, buffers, hitstop and pulse timers. Pulse interval could mean start-to-start or an idle delay plus telegraph/active time; toggling off during telegraph/active and killing/respawning the pulse dummy have no defined effect on its outgoing hitbox or next pulse.

**Why it matters:** These choices change the repeatable timing and clean starting state needed for the documented dodge-tail feel test.

**Suggested fix:** State the complete reset contract and pulse phase transitions, including toggle-off, KO and respawn, and define what `pulse_interval` measures. Add small core checks for the pulse lifecycle and a debug reset check.

---

## 8. Implementation Log  ·  _Builder_

**Started:** YYYY-MM-DD  ·  **Branch:** `feature/F-003-warrior-sword-chain`

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
| Q1 | Combat | → Art & Game Feel: final look of hit flash, damage numbers and screen shake (CX2). Placeholders in this feature only. | no | |
| Q2 | Combat | → Direction: `screen_shake_enabled` is a data flag for now. Where do player-facing settings live once a settings menu exists, and do they persist per player or per character? | no | |
| Q3 | Combat | → Combat (F-004): enemy hurt rules (i-frames, stagger, knockback resistance) are decided with the enemies. The dummy has no hurt i-frames. | no | |

---

## 11. Director Notes  ·  _Lucas_

<Overrides, priorities, gut calls. Everyone obeys these.>
