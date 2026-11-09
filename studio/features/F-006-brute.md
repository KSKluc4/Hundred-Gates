---
id: F-006
title: Brute — charge, stomp, wall stun
status: CODE_REVIEW      # DRAFT | PLAN_REVIEW | PLAN_CHANGES | APPROVED | IN_PROGRESS | CODE_REVIEW | CODE_CHANGES | DONE | PARKED
owner_now: Auditor     # who must act next: Planner | Auditor | Builder | Lucas
created: 2026-11-08
updated: 2026-11-09
depends_on: [F-004, F-005, D-007, D-008]
pillars: [2]
department: Combat
---

# F-006 — Brute — charge, stomp, wall stun

> **How to use this file.** This is the single source of truth for this feature.
> Every agent reads the WHOLE file before acting. Write only in the sections you own
> (see studio/README.md). Never delete another role's text — reply under it.

---

## 1. Goal  ·  _Planner_

**Player-facing outcome (one sentence):**
A slow, unpushable brute charges along a visible lane when you're at mid range and stomps when
you hug it. Dodging a charge sideways is safe, and baiting it into a wall stuns it for a big
punish window, so the player learns to bait instead of trading.

**Why now:** Floor 3 needs all three archetypes (design doc, *Floor mix*). The brute is the last
one. It's also the first enemy with two attacks, so it brings the smallest attack-selection rule
that bosses can reuse later.

**Out of scope (explicitly):**
- Bosses, boss phases, and attack sequences/combos (one attack per decision, no "after X do Y").
- Random or weighted attack choice, and per-attack cooldowns (§3).
- Steering during a charge, pathfinding, line of sight.
- A charge hurting enemies or dummies, or being stopped or stunned by enemy bodies (CQ12: it
  slides along them like any enemy body). Only `world` walls stun.
- Breakable walls, wall damage to the brute, and a stun on hitting the player.
- New art. Lane, stomp ring and stun use placeholder views (→ Art & Game Feel, CX5).
- Floor/room layout for floor 3 (→ Floors, phase 2).

---

## 2. Context  ·  _Planner_

What the Builder needs to know that isn't obvious from the code (checked against `main`, 2026-11-08):
- **Existing systems this touches:**
  - `src/core/enemies/enemy_data.gd`: today has one `attack: EnemyAttackData` and
    `attack_range_tiles`. `Brain { CHASER, CASTER }`. `_attack_kind_errors()` checks that the
    attack kind matches the brain (F-005/C9).
  - `src/core/enemies/enemy_attack_data.gd`: `aim_track_time`, `lunge_tiles`, projectile fields,
    `ENEMY_SNAPSHOT_KEYS`, `from_snapshot()`, `validate_enemy()`.
  - `src/core/enemies/enemy_logic.gd`: `_start_attack()` latches `_data.attack.duplicate()`.
    The lunge already moves at constant speed `lunge_tiles / active` along the locked aim during
    ACTIVE (`_advance`). `RECOVERY` is committed, so the brute is planted (F-004/C7). The order
    in `step()`: hitstop first, then segments, then `_position += _tick_displacement`. Phase
    ends cross inside the step (`_cross_finished_phases()`); a recovery that ends there calls
    `_finish_attack()` at once (attack cleared, cooldown started, IDLE). `_build_live_hitbox()`
    returns the sector only in ACTIVE.
  - `src/core/enemies/enemy_brain.gd`: `for_data()`, `nearest_player()`. `chaser_brain.gd` and
    `caster_brain.gd` read `data.attack_range_tiles`.
  - `src/core/enemies/enemy_intent.gd`: `attack(target)` has no attack choice.
  - `src/core/combat/combat_sim.gd` `tick()`: per step it runs `sense` → `step` →
    `fire_due_actions` → `move_bodies` → `_apply_contact()`. The glue's wall reports run inside
    `move_bodies`, **before** that step's contact (same as F-005). There is **no per-step call
    after the contact** today: `finish_tick()` runs once, after the last step, and snapshots are
    taken after it (F-003/C19). `src/core/combat/combatant.gd` defines the API the sim calls;
    F-006 adds `end_step()` to it (C7).
  - `src/core/combat/combat_timing.gd` `window_errors()`: the "≥ N combat steps, −`TIME_EPSILON`"
    rule shape that C9's recovery rule reuses. `TIME_EPSILON` 1e-9 s, `DISTANCE_EPSILON` 1e-6 tiles.
  - `src/entities/combat_body.gd` `move_with_combatant()`: `move_and_slide()`, then
    `sync_position()` (the physics result is authoritative, F-001/C18).
    `src/entities/enemies/enemy.gd` then calls `_report_walls()` (projectiles, D-008) and has
    `_wall_query()` with `WALL_LAYER_MASK` (layer 1 `world`), `_overlaps_wall()` (F-005's
    start-overlap check, radius shrunk by `DISTANCE_EPSILON`, because `cast_motion()` ignores a
    shape it starts inside) and `_sweep()`.
  - `src/autoload/tunables.gd`: path constants per resource (`CHASER_SWIPE_PATH`,
    `CASTER_BOLT_PATH`, …, G5).
  - `src/world/combat_runner.gd`: reloads every distinct enemy data path in the scene.
  - Debug scenes: `scenes/debug/f004_chaser.tscn`, `f005_caster.tscn`.
  - Tests that read or set `attack_range_tiles` or `.attack` (75 lines on `main` at `a584598`, checked by
    Direction): `tests/core/enemies/` `caster_arena.gd`, `enemy_arena.gd`, `test_caster_attack.gd`,
    `test_caster_data.gd`, `test_caster_snapshot.gd`, `test_enemy_attack.gd`, `test_enemy_combat.gd`,
    `test_enemy_data.gd`, `test_enemy_logic.gd`, `test_enemy_snapshot.gd`; `tests/scenes/`
    `test_f004_reload.gd`, `test_f005_reload.gd`, `test_f005_walls.gd`. Some are **assertions**, not
    data-building lines: `test_enemy_data.gd:17,21,52`, `test_caster_data.gd:17,22`,
    `test_f004_reload.gd:48,104`, `test_f005_reload.gd:58,100` read `.attack` or
    `attack_range_tiles`, and `test_enemy_data.gd:52` tests the `attack_range_tiles > 0` bound (C14).
- **Relevant prior decisions:** D-007 (step grid), D-008 (glue reports walls, core decides), D-002, G6–G9.
- **Relevant prior features:** F-004 (enemy base, planted, latching, C12 validation, C15 reset),
  F-005 (wall reports, appended enum values C13, snapshot rules C10, reload/rate C11).

---

## 3. Options Considered  ·  _Planner_

> This section is what stops context loss. Be honest about trade-offs.
> The Builder MUST NOT implement anything listed under Rejected.

### ✅ Chosen: an ordered attack list with per-attack trigger bands
- **How it works:** `EnemyData.attacks: Array[EnemyAttackData]` replaces `attack`. Each attack
  has `trigger_min_tiles` and `trigger_max_tiles`, and `EnemyData.attack_range_tiles` goes away.
  At a decision, a ready enemy uses the **first** attack in list order whose band contains the
  target distance (`EnemyBrain.pick_attack()`), and the intent carries its index. All of an
  enemy's attacks share one cooldown. Chaser and caster become one-item lists with
  `trigger_max_tiles` = their old `attack_range_tiles`, and behave exactly as before.
- **Why chosen:** it's deterministic and readable (the player learns "close = stomp, mid = charge"),
  data-only (G9), and bosses can add attacks with no new code path. It also needs no RNG state in
  snapshots (G7, co-op sync).
- **Costs we're accepting:** a data migration of chaser/caster files and mechanical edits to the
  test lines that build `EnemyData` (assertions unchanged). One resource could be shared by two
  enemies with different bands: then they need two files.
- **Would revisit if:** bosses need weighted variety, or "never the same attack twice" (then add
  it as data on top of this, with seeded RNG in the snapshot).

### ❌ Rejected: a second field (`attack_2`, `close_attack`)
- **How it would work:** the brute data gets one more named attack slot.
- **Why rejected:** bosses need 3–6 attacks, so this gets migrated anyway, and every slot needs
  its own validation, reload and snapshot path.
- **Tempting because:** zero changes to chaser/caster or their tests.

### ❌ Rejected: keep `attack` for single-attack enemies and add `attacks` only for the brute
- **How it would work:** two ways to declare attacks, picked by the brain.
- **Why rejected:** two code paths for latching, reload and validation, and the Auditor has to
  check both forever. Drift between them would be silent.
- **Tempting because:** F-004/F-005 tests would pass unedited.

### ❌ Rejected: random or weighted choice
- **How it would work:** roll between attacks whose bands match.
- **Why rejected:** the player can't read which attack is coming from position (pillar 2). It
  also needs RNG state in snapshots and a co-op-synced seed (G7, D-002). The brute's bands don't
  overlap anyway.
- **Tempting because:** "feels alive", and it's how many action games do it.

### ❌ Rejected: per-attack cooldowns
- **How it would work:** each attack has its own timer, so stomp is ready right after a charge.
- **Why rejected:** a charge that ends next to the player could stomp at once and erase the
  charge's punish window (principle 2). The design doc says one shared 1.0 s cooldown.
- **Tempting because:** bosses will want it, and it looks more flexible.

### ✅ Chosen (sub-decision): wall stop by D-008 report, stun = longer recovery
- **How it works:** while a charge moves, core exposes this step's planned segment. The glue
  sweeps the brute's circle against `world` only, from the step-start position along that
  segment, and reports where it got to. A reach short of the plan by more than
  `DISTANCE_EPSILON` is a wall stop: the rest of the charge is dropped and its recovery lasts
  `wall_stun_duration` instead of `recovery`. No new state: the stun **is** the recovery.
  The report only records the stop; it takes effect in a new per-step `end_step()` call, right
  after that step's contact (C7).
- **Why chosen:** it's exactly D-008's rule ("core plans, glue reports, short = wall"), so core
  never reads physics (G6), and the stop lands on the step grid (D-007). Since the stun is the
  recovery, planted, hitstop pausing, cooldown-from-recovery-end and the "open" tint all already
  work.
- **Costs we're accepting:** one `wall_stopped` flag in the snapshot. A charge that only grazes a
  wall with its edge stuns too: a graze counts.
- **Would revisit if:** playtests show glancing stuns feel unfair (then add a minimum
  angle-to-wall as data).

### ❌ Rejected: detect the wall from `move_and_slide()` collisions or `is_on_wall()`
- **How it would work:** the glue reads slide collisions and tells core "hit a wall".
- **Why rejected:** physics decides the outcome (G6). Sliding along a wall would also count, and
  enemy bodies are in the slide results too (CQ12).
- **Tempting because:** one line, and the body already collided.

### ❌ Rejected: compare the authoritative body position to the plan
- **How it would work:** after `move_and_slide()`, core compares `_position` to the planned end.
- **Why rejected:** a chaser in the way would stun the brute (bodies collide, CQ12), and sliding
  along a wall shortens the move. Both give false stuns.
- **Tempting because:** no sweep needed, and it's what the design doc's draft hinted at.

### ✅ Chosen (sub-decision): report records, `end_step()` after the contact applies
- **How it works:** `report_charge_reach()` (during `move_bodies`) only sets a per-step
  "pending stop". The step's contact runs untouched, so the charge sector that reached the wall
  can still hit. Then `CombatSim.tick()` calls a new `Combatant.end_step()` on everyone (no-op by
  default), and the brute turns the pending stop into the stun there. It runs every step, before
  the next `sense()`, `finish_tick()` and any snapshot, so no pending state ever crosses a tick
  or a snapshot. The step grid is the same at every tick rate (D-007), so it's parity-safe.
- **Why chosen:** the stop contact keeps its hit, the switch happens at one fixed point of the
  step, and the snapshot boundary stays "nothing pending" (F-003/C19).
- **Costs we're accepting:** a one-line addition to the shared sim loop and one more method on
  `Combatant` (the player and the dummy inherit the no-op).
- **Would revisit if:** something else needs a post-contact hook with a different order (then
  this becomes that general hook, with its order written down).

### ❌ Rejected: switch to RECOVERY inside `report_charge_reach()`
- **Why rejected:** the report runs before the contact, so the sector is gone when the resolver
  reads it: the stop step's hit is lost (AC6).
- **Tempting because:** one place, no new sim call.

### ❌ Rejected: apply the pending stop at the next `sense()` or at `finish_tick()`
- **Why rejected:** a pending stop would sit across the tick end, where snapshots are taken, so
  it would need snapshotting, and 30/60/120 ticks/s would show different states at their tick
  ends (C1).
- **Tempting because:** F-005's spent projectiles are removed at the next step start.

### ❌ Rejected: keep the sector live in RECOVERY with a "stop contact" flag
- **Why rejected:** RECOVERY would mean two things, and every hitbox reader would have to know.
- **Tempting because:** the state switch could stay in the report.

### ✅ Chosen (sub-decision): a wall-stun attack's recovery is at least two steps (data rule)
- **How it works:** C9 rejects a wall-stun attack whose `recovery` is under two combat steps, or
  whose `wall_stun_duration` is under its `recovery`. Active can't end within `TIME_EPSILON` after a
  step start (it would have crossed at the previous step's end), so a recovery of two steps
  started in the last lunge step is still running at that step's `end_step()`. The latched attack
  always exists when its report is applied.
- **Why chosen:** a 0-recovery charge could otherwise finish (clear the attack, start the
  cooldown) inside the very step whose report comes later. Rejecting that data is simpler than
  undoing a finished attack, and a wall stun is never meant to shorten the punish window.
- **Costs we're accepting:** two more validation rules and one rate check (C11). The shipped
  values (0.90 s recovery, 1.50 s stun) are far above them.
- **Would revisit if:** a design needs a lunge with no recovery that also wall-stuns.

### ❌ Rejected: undo a finished attack when its stop report arrives
- **How it would work:** keep the latched attack and the active-end time per step; if the
  attack finished in that step, restore it, cancel its cooldown and enter the stun.
- **Why rejected:** a second, rarely-run path that rewrites cooldown and attack state after the
  fact. Easy to get subtly wrong, and only reachable with data nobody wants.
- **Tempting because:** it accepts every `AttackData` the inherited rules allow.

### ✅ Chosen (sub-decision): a segment that starts inside a wall is a stop
- **How it works:** before the sweep, the glue checks whether the brute's circle (radius −
  `DISTANCE_EPSILON`) at the segment start already overlaps a `world` wall, with F-005's overlap
  query. If it does, it reports `reached = start`: a stop, whatever the direction. Otherwise it
  sweeps as before.
- **Why chosen:** `cast_motion()` can't see a shape it starts inside (F-005/C5), so without it a
  wall the brute grew into would never stun it. A body that only touches a wall doesn't overlap
  (the shrunk radius and `move_and_slide()`'s margin keep it clear), so normal play never hits
  this: only a radius reload, or a restore with other data, can.
- **Costs we're accepting:** in that reload case a brute charging away from or along the wall
  it overlaps is stunned too.
- **Would revisit if:** the radius changes during play (not only by debug reload).

### ❌ Rejected: stop only when moving into the overlapped wall
- **Why rejected:** needs contact normals and a rule for several walls, for a case only a debug
  reload reaches.
- **Tempting because:** physically more accurate.

### ❌ Rejected: ignore a segment that starts inside a wall
- **Why rejected:** the brute can be physically blocked with no stun, and on its last lunge step
  no later segment would catch it (§7 PR-2).
- **Tempting because:** zero glue code.

### ❌ Rejected: a separate `STUNNED` state
- **How it would work:** a new `EnemyLogic.State` value with its own timer and transitions.
- **Why rejected:** it behaves the same as recovery (planted, punishable, cooldown after) but
  needs its own transitions, snapshot handling and tests.
- **Tempting because:** the debug text and views would read "STUNNED" for free.

---

## 4. Constraints  ·  _Planner_

Hard rules for this feature. Violating any of these = automatic `CODE_CHANGES`.

| ID | Constraint | Reason |
|---|---|---|
| C1 | Same scripted inputs at 30, 60 and 120 ticks/s give the same decisions, chosen attacks, wall stops (same step), stun ends, hits and positions, within F-005 §5 tolerances. | G1, D-007 |
| C2 | Every number comes from `data/`: `data/enemies/brute.tres`, `data/attacks/brute_charge.tres`, `data/attacks/brute_stomp.tres`, plus the existing shared files. No new tunables file. New paths are constants in `src/autoload/tunables.gd`. | G2, G5, G9 |
| C3 | `BruteBrain`, attack selection, the wall-stop rule and `end_step()` live in `src/core/` with no nodes or physics. Only the glue queries walls (C7). | G6, D-008 |
| C4 | **Attack list.** See below. | §3 |
| C5 | **Brute decisions.** See below. | design doc |
| C6 | **Charge.** It's a melee enemy attack with a lunge: everything in F-004/C5 holds (latching, track then lock, constant-speed lunge along the locked aim during active, sector built fresh at each contact so it follows the brute, once per attack instance per hurtbox). The charge doesn't stop on a hit. The attacker hitstop from a landed hit pauses the charge as it pauses any lunge. Knockback direction is the existing melee rule, unchanged. | F-004/C5 |
| C7 | **Wall stop.** See below. | D-008 |
| C8 | **Stomp.** A melee enemy attack with a 360° sector and `lunge_tiles` 0. `aim_track_time` 0 is allowed (it locks at windup start; the aim doesn't matter for a full circle). | design doc |
| C9 | **Data validity.** See below. Extends F-004/C12 and F-005/C9. Bad data is rejected, never clamped. | G2 |
| C10 | All new state is serializable: `EnemyLogic`'s snapshot gains `wall_stopped` (bool), and the latched attack's snapshot gains `trigger_min_tiles`, `trigger_max_tiles` and `wall_stun_duration`. The charge segment and the pending stop are per-step only (like `_tick_displacement`): `end_step()` clears them before any snapshot boundary, so they're never in a snapshot, and `from_dict()`/`setup()` clear them too. Snapshot boundary as F-003/C19. | G7 |
| C11 | **Reload and rate.** A running attack keeps every latched value (including `recovery` and `wall_stun_duration`) and its `wall_stopped` flag through any reload. Reloading an enemy data file also reloads every attack in its list. The stun itself adds no rate check (it's a recovery). A new rate is refused while a latched wall-stun attack in WINDUP or ACTIVE has `recovery` under 2 combat steps at that rate (C9's rule, via `_extra_rate_errors()`, F-005/C11). | F-004/C12, F-005/C11 |
| C12 | Presentation is derived from logic (F-003/C12). During windup, a melee attack with `lunge_tiles > range_tiles` shows a placeholder lane along the aim (the caster's aim-line view), `lunge_tiles + range_tiles` long, with the same tracking→locked change. The stomp shows its 360° telegraph like any sector. A wall stun shows the existing recovery "open" tint, and the debug text shows `RECOVERY (stun)`. After `from_dict()` or a reset every view re-syncs. | F-003/C12, CX5 |
| C13 | `EnemyData.Brain` gains `BRUTE`, **appended** (`CHASER` 0, `CASTER` 1 unchanged). | F-005/C13 |
| C14 | F-001, F-003, F-004 and F-005 tests keep every **asserted value and behavior**. Allowed edits, and only these: (a) lines that build or modify `EnemyData`/attack data; (b) the accessor rename inside an assertion, with the expected value unchanged (`.attack` → `.attacks[0]`, `attack_range_tiles` → `attacks[0].trigger_max_tiles`); (c) `test_enemy_data.gd`'s `attack_range_tiles` bound test moves to the `trigger_max_tiles > 0` rule (C9) with the same boundary values. §8 lists every edited test file and line kind (a/b/c). | regression |
| C15 | Nothing assumes one player: targets per F-004/C9. No new addons, input actions or collision layers. | D-002, G4 |

**C4 — Attack list**
- `EnemyData.attacks: Array[EnemyAttackData]`, at least one entry. `EnemyData.attack` and
  `EnemyData.attack_range_tiles` are removed.
- `EnemyAttackData` gains `trigger_min_tiles` (default 0.0), `trigger_max_tiles` (default 0.0)
  and `wall_stun_duration` (default 0.0, see C7).
- `EnemyBrain.pick_attack(data: EnemyData, distance: float) -> int` returns the index of the
  first attack in list order with `trigger_min_tiles - DISTANCE_EPSILON ≤ distance ≤
  trigger_max_tiles + DISTANCE_EPSILON`, or −1 if none. Static, no state.
- `EnemyIntent.attack(target, attack_index: int = 0)`, with a new `attack_index` field.
  `EnemyLogic._start_attack()` latches `_data.attacks[intent.attack_index].duplicate()`.
- One shared cooldown per enemy (`EnemyData.attack_cooldown`), started at the end of any attack's
  recovery, a stun included.
- Chaser and caster brains replace their range checks with `pick_attack()`. Migrated data:
  `chaser_swipe.tres` `trigger_max_tiles` 1.6, `caster_bolt.tres` `trigger_max_tiles` 7.0, both
  `trigger_min_tiles` 0. Their behavior is identical (C14).

**C5 — Brute decisions** (`BruteBrain`, stateless, decides only when free, F-004/C4)
1. Target = `nearest_player()`. None → idle.
2. Not aggroed and distance > `aggro_radius_tiles` (+ε) → idle.
3. Attack ready and `pick_attack()` ≥ 0 → attack with that index.
4. Otherwise, if distance > `stop_distance_tiles` (+ε), walk straight at the target, at most
   `distance − stop_distance_tiles` this step. Otherwise, hold (zero move, keep the target).
   It never retreats (`retreat_distance_tiles` 0). A zero direction holds.
- With the shipped data, `attacks = [brute_stomp, brute_charge]`, and a brute that is **already
  aggroed** and ready: 0–1.5 tiles → stomp, 3–7 → charge, 1.5–3 → walk in to 1.5, then stomp.
  Beyond 7 → walk in. Step 2 still comes first: a brute that isn't aggroed stays idle beyond
  7.0 tiles, and at exactly 7.0 (+ε) it aggroes and charges in that same decision.

**C7 — Wall stop** (D-008 applied to a moving body)
Per combat step, in this order: `step()` plans → the glue reports (inside `move_bodies`) →
contact → `end_step()` applies. Nothing about a stop is left over after `end_step()`.

- A **wall-stun attack** is a melee attack with `wall_stun_duration > 0`.
- **Segment (core).** `EnemyLogic.get_charge_segment() -> PackedVector2Array`: `[start,
  planned_end]` in tiles when, in the step that just ran, a latched wall-stun attack moved by its
  lunge, the brute isn't `wall_stopped`, and no report was taken yet this step. `start` = the
  logic position at that step's start, `planned_end` = `start +` this step's displacement. Empty
  otherwise (no lunge movement, hitstop the whole step, dead, already reported, …). Set in
  `step()`; cleared by `report_charge_reach()`, `end_step()`, `sense()`, `setup()` and `from_dict()`.
- **Report (glue, `enemy.gd`).** After its body move, and only when the segment isn't empty,
  with radius `r = hurtbox_radius_tiles − DISTANCE_EPSILON` (current data, C11) and layer 1
  `world` only (`_wall_query`):
  1. **Start overlap:** if the circle `r` at `start` already overlaps a wall (`intersect_shape`,
     like F-005's `_overlaps_wall()`), report `reached = start`, whatever the direction (§3).
  2. Otherwise sweep the circle `r` from `start` toward `planned_end` (`cast_motion()`) and report
     where it got to. Clear path → `reached == planned_end` exactly (F-005's `_sweep` rule).
  It calls `EnemyLogic.report_charge_reach(reached: Vector2) -> bool` once per step.
- **Decision (core, in the report).** `report_charge_reach()` takes the segment (it's empty
  afterwards). If `(planned_end − start).length() − (reached − start).dot(direction) >
  DISTANCE_EPSILON`, it sets a per-step **pending stop**. It returns true either way. It never
  changes state, phase, position, aim or hitbox: a pending stop does nothing until `end_step()`.
  With an empty segment (none this step, or already reported) it pushes an error, returns false,
  and changes nothing.
- **That step's contact** runs as usual. If the brute is still ACTIVE at the step end, its
  charge sector is live at its authoritative (physics) position and may hit. The body position
  stays the physics result (F-001/C18); `reached` only decides the stop.
- **`end_step()` (core, shared sim).** `Combatant` gains `end_step()`, a no-op by default.
  `CombatSim.tick()` calls it on every combatant, in registration order, right after
  `_apply_contact()`, every step: so before the next `sense()`, before `finish_tick()` and before
  any snapshot. `EnemyLogic.end_step()`, when a stop is pending:
  - DEAD (killed at that contact) → the stop is dropped: death wins (F-004/C11).
  - ACTIVE → the rest of active is dropped at this contact instant: RECOVERY,
    `_phase_elapsed = 0`, `wall_stopped = true`.
  - RECOVERY (active ended earlier in this step) → `wall_stopped = true`, `_phase_elapsed` kept
    (the time since active ended).
  Then the pending stop and the segment are cleared, stop or not.
- **Stun length.** While `wall_stopped`, the recovery lasts the latched `wall_stun_duration`
  instead of `recovery` (`_phase_time_left()`). Cooldown starts when it ends.
- **The attack is always still there.** C9 gives every wall-stun attack `recovery ≥ 2` combat
  steps and `wall_stun_duration ≥ recovery`. Active can't end within `TIME_EPSILON` after a step
  start (it would have crossed at the previous step's end), so a recovery that started in the
  last lunge step is still running at that step's `end_step()`, and the stun has time left after
  the switch. `end_step()` with a pending stop therefore only ever sees ACTIVE, RECOVERY or DEAD
  (committed states take no knockback, so never KNOCKBACK or IDLE); any other state is a bug:
  push an error and drop the stop.
- Not a stop → nothing changes.
- Enemy bodies never cause a stop (neither query includes layer 3). A brute blocked by another
  enemy keeps charging and slides, like any enemy body (CQ12). A brute that only touches a wall
  doesn't overlap it (shrunk radius), so sliding along it is no stop.
- `wall_stopped` clears when the attack ends (cooldown starts) and on reset/death.
- Hitstop pauses the stun like any recovery. The stun is planted (F-004/C7).

**C9 — Data validity** (on top of F-004/C12, F-005/C9)
- `attacks` not empty, and no null entries. Each entry passes `validate_enemy()`. Errors are
  prefixed with the attack id.
- Per attack: `trigger_min_tiles ≥ 0`, `trigger_max_tiles > 0`, `trigger_min_tiles ≤
  trigger_max_tiles`, `wall_stun_duration ≥ 0`. A `wall_stun_duration > 0` needs:
  - a melee attack with `lunge_tiles > 0`;
  - `recovery ≥ 2 / step_rate − TIME_EPSILON` (two combat steps, the same shape as
    `CombatTiming.window_errors()`), checked at the rate being validated, like the window rule;
  - `wall_stun_duration ≥ recovery − TIME_EPSILON` (a wall never shortens the punish window).
- Brain kinds: `CHASER` and `BRUTE` need every attack melee, `CASTER` every attack projectile.
- Bands may overlap (list order decides). The speed rule (`validate_against_class`) is unchanged.

**Must not break:** chaser and caster behavior, every F-004/F-005 AC, projectile wall reports, the
F-004/C15 reset, hot-reload of all enemy files, the 30/60/120 parity.

---

## 5. Acceptance Criteria  ·  _Planner_

Testable, observable. The Auditor checks each one.

- [ ] AC1 — **Selection:** with `[stomp, charge]` and a ready, **already aggroed** brute, a
  target at 1.0 → stomp, at 1.5 (exact) → stomp, at 2.0 → walks in, at 3.0 (exact) → charge, at
  7.0 → charge, at 7.5 → walks in. Controls with a brute that isn't aggroed yet: at 7.5 → idle
  (no move, not aggroed); at 7.0 (exact) → aggroes and charges. Same view with registration
  order swapped → same choice.
- [ ] AC2 — **Priority:** with two overlapping bands, the first in list order is chosen.
- [ ] AC3 — **Shared cooldown:** after a charge's recovery ends next to the target, no stomp
  starts until `attack_cooldown` has passed. The brute keeps walking/holding meanwhile.
- [ ] AC4 — **Charge timeline:** windup 0.80 s (aim tracks until 0.50 s, then locked), then
  active for 0.50 s, moving 6.0 tiles at constant speed along the locked aim in an open room,
  then 0.90 s recovery, then 1.0 s cooldown.
- [ ] AC5 — **Charge hits once, doesn't stop:** a player standing in the lane takes 25 damage and
  1.5 tiles knockback once. The brute continues to the full 6 tiles (minus its attacker-hitstop
  pause, which delays but doesn't shorten it). A player that dashed sideways out of the lane during
  windup takes nothing.
- [ ] AC6 — **Wall stun:** a charge aimed at a wall 3 tiles away stops at the wall. Between the
  report and the contact of that step the brute is still ACTIVE with `wall_stopped` false, and
  that contact can still hit a player standing between the brute and the wall (sector at the
  brute's physics position). Right after that step (checked at 120 ticks/s, where the tick end is
  the step end) the brute is in RECOVERY with `wall_stopped` and `phase_elapsed` 0; the stun lasts
  1.50 s from that contact instant, then cooldown. Hits on it during the stun deal damage and
  hitstop, the stun pauses during that hitstop, and it is never pushed. **Death wins:** if the
  brute's HP reaches 0 at the stop contact (a trade), it is DEAD after that step, `wall_stopped`
  false, no stun; the charge's own hit at that contact still lands (F-003/C16).
- [ ] AC7 — **No false stuns:** (a) a charge sliding parallel along a wall it touches, (b) a charge
  blocked by a chaser's body, including when the bodies overlap at a segment start, (c) a charge
  that reaches its full 6 tiles with no wall → normal 0.90 s recovery, `wall_stopped` false.
- [ ] AC8 — **Stun when active already ended mid-step** (core, stub reports via the `move_bodies`
  callable): a charge with windup 0.80, `aim_track_time` 0.50, active 0.505, lunge 6.0,
  `recovery` 2 steps (1/60 s, the minimum at 120 steps/s), stun 1.50, started at t = 0. Active
  ends at 1.305 s, inside the step ending at 1.308333 s, whose report is short. Right after that
  step: RECOVERY, `wall_stopped`, `phase_elapsed` 0.003333 s, attack still latched, cooldown 0.
  The stun ends at 2.805 s and the 1.0 s cooldown starts there. Same at 30, 60 and 120 ticks/s.
  At each rate, `to_dict()` at the end of the tick that holds that step (1.308333 / 1.316667 /
  1.333333 s) shows RECOVERY + `wall_stopped`, no pending-stop or segment key, and
  `from_dict()` of it ends the stun at 2.805 s. The same charge with `recovery` 0 is rejected (AC15).
- [ ] AC9 — **Report errors:** `report_charge_reach()` with an empty segment (no lunge this step,
  or a second report in the same step) returns false, logs an error and changes nothing.
- [ ] AC10 — **Stomp:** windup 0.60 s, a 360° circle of 1.6 tiles active 0.10 s, 20 damage, 1.2 tiles
  knockback, 0.70 s recovery. A player whose center is more than 1.95 tiles (1.6 + the Warrior's
  0.35 hurtbox) from the brute's center at every contact during active isn't hit; at 1.94 it is.
- [ ] AC11 — **Brute body:** 120 HP, hurtbox 0.6, never pushed in or out of an attack
  (`knockback_scale` 0), walks at 2.0 tiles/s, aggro at 7.0 tiles or when damaged.
- [ ] AC12 — **Parity:** a scripted run (charge into a wall + a stomp + a full-distance charge) gives
  the same wall-stop step, stun end, hits and positions at 30, 60 and 120 ticks/s, in core (stub
  reports) and once in a scene over real physics.
- [ ] AC13 — **Snapshots:** `from_dict(to_dict())` mid-charge, mid-stun and mid-stomp reproduces the
  rest of the run exactly, including `wall_stopped` and the latched attack's new fields. The
  snapshot at the end of a tick holding a stop step is covered by AC8.
- [ ] AC14 — **Reload:** editing `brute_charge.tres` mid-windup doesn't change the running charge.
  The next charge uses the new values. Editing `brute.tres` reloads both attacks.
- [ ] AC15 — **Validation:** each C9 rule rejects with a named error (empty list, null entry, min >
  max, negative stun, stun on a projectile, stun with lunge 0, stun with `recovery` under 2 steps,
  stun shorter than `recovery`, wrong kind per brain). Exact limits pass (`recovery` exactly 2
  steps, stun exactly `recovery`). Lowering `combat_step_rate` is refused while a running charge
  in WINDUP or ACTIVE has a latched `recovery` under 2 steps at the new rate (C11).
- [ ] AC16 — **Migration:** chaser and caster pass every F-004/F-005 assertion (C14).
- [ ] AC17 — **Views:** the charge lane shows during windup and changes look at lock. The stomp
  shows its circle telegraph. The stun shows the open tint and `RECOVERY (stun)`. Views re-sync
  after restore/reset.
- [ ] AC18 — **Co-op ready:** with two players, the brute targets the nearest one (ties by
  registration order) and keeps that target for the whole attack.
- [ ] AC19 — **Segment starts inside a wall** (scene, 120 ticks/s): a brute charging parallel to
  a wall with its center 0.7 tiles from it; between ticks, `brute.tres` is reloaded with
  `hurtbox_radius_tiles` 1.0, so the next lunge step's segment starts overlapping the wall.
  That step is a wall stop (`reached = start`) and the stun follows, also when that step is the
  charge's **last** lunge step, and also when the charge points away from the wall. Controls: the
  same run without the reload (body touching or 0.7 tiles from the wall, moving along it) → no
  stop; overlapping only a chaser's body → no stop (AC7b).
- [ ] AC20 — **Other combatants unchanged by `end_step()`:** the player and the dummy inherit the
  no-op, and every F-001/F-003/F-004/F-005 test passes with the new call in the sim loop.

**How to verify manually:** open `scenes/debug/f006_brute.tscn`. Play ~5 min with KB/M, then a
gamepad.
1. Stand ~5 tiles away: watch the lane track, then lock. Dash sideways after the lock: the charge
   misses.
2. Stand with your back ~1 tile from a wall, let it charge, dodge sideways: it hits the wall and
   stays open ~1.5 s. Land a full chain plus extra hits.
3. Walk up and hug it: it raises its foot. Step or dash out before active.
4. Try trading hits during its windup: you get hit, and it never flinches.
5. Lure it into charging at `chaser_1`: it pushes along the chaser's body, and doesn't get stunned.

**Feel test:** the charge should feel scary but *fair*: the lock leaves time to read the lane and
step out. A wall stun should feel like *your* win: a long, obvious opening. Hugging the brute
should feel like a mistake, not a cheese. If killing it takes standing still and trading, the
numbers are wrong.

---

## 6. Task Breakdown  ·  _Planner_

Small, ordered, each independently committable.

| # | Task | Files likely touched | Notes |
|---|---|---|---|
| T1 | Attack list migration, no behavior change | `enemy_data.gd`, `enemy_attack_data.gd`, `enemy_intent.gd`, `enemy_brain.gd`, `chaser_brain.gd`, `caster_brain.gd`, `enemy_logic.gd`, `data/enemies/chaser.tres`, `caster.tres`, `data/attacks/chaser_swipe.tres`, `caster_bolt.tres`, tests' data-building lines | C4, C9 (list + band rules), C14. All existing assertions pass. New tests: AC1-style selection with stub data, AC2, AC15 (list/band rules). |
| T2 | `Brain.BRUTE` + `BruteBrain` | `enemy_data.gd`, `src/core/enemies/brute_brain.gd`, `enemy_brain.gd` | C5, C13, kind rule. Tests AC1, AC3, AC18. |
| T3 | Wall stop in core | `src/core/combat/combatant.gd` (`end_step()` no-op), `src/core/combat/combat_sim.gd` (call it after `_apply_contact()` each step), `enemy_attack_data.gd` (`wall_stun_duration` + C9 stun rules), `enemy_logic.gd` (`get_charge_segment`, `report_charge_reach`, pending stop, `end_step`, `wall_stopped`, `_phase_time_left`, `_extra_rate_errors`, snapshot) | C7, C9, C10, C11. Core tests with stub reports from the `move_bodies` callable: AC6 (incl. state between report and contact, and death at the stop contact), AC7c, AC8 (all three rates + snapshot), AC9, AC13, AC15 (stun rules + rate refusal), AC20. |
| T4 | Brute data | `data/enemies/brute.tres`, `data/attacks/brute_charge.tres`, `brute_stomp.tres`, `src/autoload/tunables.gd` | Values in the design doc's tunables index. AC4, AC10, AC11 in core. |
| T5 | Glue report | `src/entities/enemies/enemy.gd` | C7 glue half: after the body move, start-overlap check then sweep, layer 1 only, one report. Scene tests AC6, AC7a/b, AC12 physics run, AC19. |
| T6 | Views | `enemy.gd` drawing / telegraph, debug text | C12, AC17. |
| T7 | Debug scene | `scenes/debug/f006_brute.tscn`, `tests/scenes/test_f006_*.gd` | Walled room ~16×12 tiles. Player at center; `brute_1` ~5 tiles away; a straight wall ~4 tiles behind the player's start; `chaser_1` off to one side. `CombatRunner` last, `refill_player_on_died` on, shake and overlay as in F-005's scene. AC5, AC14 end to end. |

---

## 7. Plan Review  ·  _Auditor_

<Each completed round starts with its machine line (format in AGENTS.md), then its findings.
Severity: 🔴 blocking · 🟡 should fix · 🔵 suggestion. Example finding:>

### PR-1 🔴 <title>
<What's wrong, where, why it matters, what you'd suggest.>
> **Planner reply:** <accepted / rejected + reason / changed §X>

<!-- review-round: 1 verdict: CHANGES_REQUESTED -->

**Verdict:** CHANGES_REQUESTED

**Review:** The goal serves pillar 2, the scope is explicit, and the alternatives explain the
attack-list migration and shared cooldown well. The plan follows the Combat design doc; the
D-008 body-movement refinement is explicitly proposed for Lucas's Gate A decision. The main
gap is the lifecycle of a wall report around contact and attack completion. T3/T5 need that
integration specified before the Builder can implement C7 without choosing new timing rules.

### PR-1 🔴 Define wall-stop finalization before the attack can be cleared

**Location:** §4 C7 (lines 216–238), C9's inherited recovery bounds; §5 AC6/AC8/AC13;
§6 T3/T5. Existing integration: `src/core/combat/combat_sim.gd:50–66` and
`src/core/enemies/enemy_logic.gd:278–293,420–464`.

**Problem:** The wall report runs inside `move_bodies`, before contact. C7 requires the
charge's sector to remain live for that contact, then requires RECOVERY from the same instant.
Changing state to RECOVERY in `report_charge_reach()` removes the sector before the resolver
reads it. The current sim has no per-step callback after contact; `finish_tick()` runs only
after all substeps. T3/T5 do not specify how the final contact is retained and the transition
completed before the next step and snapshot boundary.

There is also an uncovered completion case in this same lifecycle: ordinary recovery may be
zero under the inherited `AttackData` rules. With windup 0.80, active 0.505, recovery 0 and
stun 1.50 at 120 steps/s, the final lunge occurs in the step ending at 1.308333 s. The ordinary
attack finishes at 1.305 s, clears its latched attack and starts cooldown before the glue can
report a wall on that last segment. C7 only describes replacing a recovery that still exists;
it does not say how to retain the necessary attack values or undo that premature completion.

**Why it matters:** An immediate transition loses AC6's last hit. Deferring until tick end can
leave different intermediate state at 30/60/120 ticks/s, while ordinary attack teardown can
lose a valid final-step wall stun entirely. These affect hit outcomes, cooldown and snapshots.

**Suggested fix:** Specify a per-step wall-report/contact/finalization contract, including
retaining the segment and latched values until the report is handled, preserving the stop
contact's sector, and completing the stun transition before the next sense/snapshot. Identify
the shared sim/combatant integration in T3 if a post-contact hook is chosen. Define the outcome
when ordinary recovery already expired inside that step. Extend AC6/AC8 with the zero-recovery
example, the state immediately after the stop contact, and a snapshot at that tick's end at
all three rates; existing death handling must still win if the brute dies at that contact.

> **Planner reply (Combat):** accepted. Changed §4 C7: per step, `step()` plans → the glue
> reports → contact → a new `Combatant.end_step()` (no-op by default, called by
> `CombatSim.tick()` after `_apply_contact()` every step) applies. The report only sets a per-step
> pending stop, so the stop contact keeps its sector; `end_step()` switches to the stun before the
> next `sense()`, `finish_tick()` or snapshot, and drops the stop if the brute died at that
> contact. Zero-recovery case: C9 now requires a wall-stun attack's `recovery` ≥ 2 combat steps
> and `wall_stun_duration` ≥ `recovery`, which guarantees the latched attack is still in RECOVERY at
> that step's `end_step()` (reasoning in C7); C11 adds the matching rate refusal. Options and
> rejected alternatives (switch in the report, defer to next sense/tick end, flagged live sector,
> undoing a finished attack) in §3. AC6 extended (state between report and contact, state right
> after, death at the stop contact), AC8 rewritten with your timing example at the 2-step minimum
> plus the tick-end snapshot at 30/60/120, AC9/AC13/AC15 extended, AC20 added. T3 now lists
> `combatant.gd` and `combat_sim.gd`; §2 notes the missing post-contact call.

✔ resolved (round 2): C7 specifies report → contact → `end_step()` on every combat step,
preserving the stop contact and finalizing before the next sense or snapshot. C9's two-step
minimum recovery retains the latched attack until finalization; C11 checks that bound on rate
changes. AC6/AC8/AC9/AC13/AC15/AC20 and T3 cover the hook, final-step timing, death precedence,
snapshot boundary and rejection of zero recovery.

### PR-2 🟡 Define charge sweeps that start overlapping a wall

**Location:** §4 C7 sweep (lines 220–224), C11's inherited radius reload behavior;
§5 AC6/AC7/AC14; §6 T5.

**Problem:** C7 specifies only a motion sweep. F-005/C5 already documents that `cast_motion()`
ignores a wall the query shape starts inside. This is reachable for a body through an allowed
radius reload: a brute centered 0.7 tiles from a wall can grow from radius 0.6 to 1.0 during
its charge. The next segment starts overlapping even with the epsilon shrink. The body's
depenetration does not change the saved segment start, so the sweep can miss that wall; on
the final lunge step there is no later segment to detect it.

**Why it matters:** A valid tuning change can leave a charge physically blocked by a wall
without its wall stun. The Builder must guess whether initial penetration is a stop or is
intentionally ignored, including when moving away or parallel.

**Suggested fix:** Define an initial-overlap policy and the corresponding glue report before
the sweep, reusing F-005's overlap-query approach where appropriate. Add scene coverage for a
radius increase before the final lunge step and controls for a merely touching, parallel wall
and enemy-body overlap, so AC7's exclusions remain explicit.

> **Planner reply (Combat):** accepted. Changed §4 C7: before the sweep the glue runs F-005's
> overlap query (radius − `DISTANCE_EPSILON`, layer 1 only) at the segment start; an overlap
> reports `reached = start`, a stop whatever the direction. It runs for every lunge segment, so
> the last lunge step is covered. §3 records the choice and rejects the direction-aware variant
> (needs contact normals, only a debug reload reaches it) and ignoring the overlap. New AC19 is your
> radius-increase scene test (incl. last lunge step and charging away), with touching/parallel and
> enemy-body controls; AC7b now names body overlap at a segment start. T5 updated. §10 Q4 asks
> Direction whether the D-008 refinement text should mention this, as F-005's blocked launch was.

✔ resolved (round 2): C7 checks the saved segment start for a `world` overlap before sweeping,
with an explicit stop policy for every movement direction. AC19 includes radius reload before
the last lunge step, charging away, and touching/parallel and enemy-body controls; T5 assigns
the glue and scene coverage.

### PR-3 🟡 State the aggro precondition for the selection examples

**Location:** §4 C5 step 2 and “Beyond 7 → walk in” (lines 204–212); §5 AC1 (lines 259–261).

**Problem:** AC1 says a ready brute walks toward a target at 7.5 tiles, but the shipped aggro
radius is 7.0 and a newly set-up brute is not aggroed. C5 step 2 therefore requires IDLE in
that setup. Cooldown readiness alone does not establish the expected result.

**Why it matters:** The selection test needs an unstated state change to pass, and the
unqualified C5 example can be read as overriding the aggro rule.

**Suggested fix:** Qualify the walk-in example and AC1 as using an already-aggroed brute. Add
a non-aggroed 7.5-tile control that stays idle, retaining the 7.0-tile inclusive aggro boundary.

> **Planner reply (Combat):** accepted. Changed §4 C5's example (already aggroed; step 2 still
> first: not aggroed beyond 7.0 → idle, at exactly 7.0 → aggroes and charges in that decision)
> and §5 AC1 (aggroed precondition + both non-aggroed controls).

✔ resolved (round 2): C5 and AC1 explicitly use an already-aggroed brute for the 7.5-tile
walk-in example. AC1 also checks that a fresh brute remains idle at 7.5 and aggroes and charges
at the inclusive 7.0-tile boundary.

**Verification:** Read the complete feature, studio workflow, PROJECT/DECISIONS, Combat brief,
design doc and glossary; inspected the current enemy timeline, brains, validation, snapshots,
body movement, wall queries, reload group and relevant F-004/F-005 contracts/tests. Checked the
final-step timing example against the existing phase transitions. Plan review only; no source
or tests changed, and no runtime checks were run.

<!-- review-round: 2 verdict: APPROVE -->

**Verdict:** APPROVE — PR-1, PR-2 and PR-3 resolved; no new findings.

Checked each Planner reply against the revised plan and existing combat integration. The
player-facing outcome serves pillar 2, scope boundaries are explicit, and the alternatives
give specific reasons for attack-list priority, shared cooldown and recovery-based stun.
The plan matches `studio/design/combat.md` and preserves G1–G9, D-007, the existing contact
and snapshot boundaries, latching and atomic reload. The D-008 body-movement refinement is
explicitly proposed for Lucas's Gate A decision; §10 Q4 records its additional policy details.

Acceptance criteria now cover the wall-report lifecycle, active ending inside a step,
death at the stop contact, initial overlap, aggro boundaries, serialization and rate refusal.
Independently recalculated AC8: active ends at 1.305 s, the report/contact step ends at
1.308333333 s with 0.003333333 s already in recovery, and stun ends at 2.805 s. The containing
tick ends at 1.333333333 / 1.316666667 / 1.308333333 s at 30 / 60 / 120 ticks/s, respectively,
matching the stated boundaries. Two steps of minimum recovery exceed the remaining fraction
of the last lunge step, so attack teardown cannot precede `end_step()` under C9/C11.

T1–T7 assign the migration, core hook, data, glue, views and isolated scene in dependency
order. C14 permits the actual accessor migration while preserving existing asserted values
and behavior. Remaining placeholder art and D-008 wording questions are explicitly delegated;
they do not require the Builder to invent combat rules.

**Verification:** Read the full feature, PROJECT/DECISIONS, Combat design/brief and glossary;
inspected enemy phases, brains, validation, snapshots, sim ordering, body/wall queries,
reload and the referenced F-004/F-005 contracts/tests. Plan review only; no source or tests
changed and no runtime checks run.

Gate A remains with Lucas. Status stays `PLAN_REVIEW`; next actor is `Lucas`.

---

## 8. Implementation Log  ·  _Builder_

**Started:** 2026-11-09  ·  **Branch:** `feature/F-006-brute`

### Progress
- [x] T1 — `944d622` attack list + trigger bands, `pick_attack()`, chaser/caster migrated (C4, C9 list/band rules, C14)
- [x] T2 — `af4e732` `Brain.BRUTE` (appended) + `BruteBrain` (C5, C13, kind rule)
- [x] T3 — `2363a71` core wall stop: `Combatant.end_step()`, the sim call after `_apply_contact()`, `wall_stun_duration` + C9 stun rules, charge segment / report / pending stop / `end_step()` / `wall_stopped`, stun length, rate refusal, snapshot (C7, C9, C10, C11)
- [x] T4 — `99c39de` `brute.tres`, `brute_charge.tres`, `brute_stomp.tres`, path constants (C2)
- [x] T5 — `1bca8b9` glue report in `enemy.gd`: start overlap, then sweep, layer 1 only, one report per step (C7)
- [x] T6 — `92fc7d6` charge lane view, `RECOVERY (stun)` debug text (C12)
- [x] T7 — `5c113bb` `scenes/debug/f006_brute.tscn` + AC5/AC14 end to end

**AC → tests** (all under `tests/`):
| AC | Where |
|---|---|
| AC1 | `core/enemies/test_brute_brain.gd` (selection table, ε bounds, non-aggroed 7.5 idle / 7.0 aggro+charge, registration swap); `test_attack_list.gd` (stub data) |
| AC2 | `core/enemies/test_attack_list.gd` (overlap, list order, a chaser with two attacks) |
| AC3 | `core/enemies/test_brute_brain.gd` `test_ac3_…` (30/60/120) |
| AC4 | `core/enemies/test_brute_attacks.gd` `test_ac4_…` (30/60/120); values in `test_brute_data.gd` |
| AC5 | core: `test_brute_attacks.gd`; scene: `scenes/test_f006_scene.gd` |
| AC6 | core: `test_brute_wall_stop.gd` (report→contact state, state right after, 1.5 s stun, stop contact hits, hits during stun + hitstop pause, death wins); scene: `scenes/test_f006_walls.gd` |
| AC7 | (a)(b) `scenes/test_f006_walls.gd`; (c) `core/enemies/test_brute_wall_stop.gd` + scene AC7a controls |
| AC8 | `core/enemies/test_brute_wall_stop.gd` `test_ac8_…` (30/60/120, tick-end snapshot, restore ends the stun at 2.805 s) |
| AC9 | `core/enemies/test_brute_wall_stop.gd` `test_ac9_…` |
| AC10 | `core/enemies/test_brute_attacks.gd` `test_ac10_…` |
| AC11 | `core/enemies/test_brute_data.gd` (values), `test_brute_attacks.gd` `test_ac11_…`, walk/aggro in `test_brute_brain.gd` |
| AC12 | core: `core/enemies/test_brute_parity.gd`; physics: `scenes/test_f006_physics.gd` (both on `BruteScript`, at 30/60/120) |
| AC13 | `core/enemies/test_brute_snapshot.gd` (mid-windup, mid-lunge, mid-stun, mid-stomp; AC8 covers the stop-step tick end) |
| AC14 | `scenes/test_f006_reload.gd` (real F5 on user:// copies); latching on `apply_data()` in `test_brute_snapshot.gd` |
| AC15 | `core/enemies/test_attack_list.gd` (list/band/kind), `test_brute_data.gd` (stun rules, exact limits), `test_brute_snapshot.gd` (rate refusal), `test_brute_wall_stop.gd` (AC8 charge with recovery 0) |
| AC16 | every F-004/F-005 test, unchanged except the C14 edits below |
| AC17 | `scenes/test_f006_views.gd` |
| AC18 | `core/enemies/test_brute_brain.gd` `test_ac18_…` |
| AC19 | `scenes/test_f006_walls.gd` `test_ac19_…` (parallel, last lunge step, pointing away, controls, chaser-only overlap) |
| AC20 | `core/enemies/test_brute_wall_stop.gd` `test_ac20_…` + the full suite |

**C14 — edits to existing tests** (every line is one of the three allowed kinds; no expected value changed):
- (a) data-building / data-modifying lines, `.attack` → `.attacks[0]`, `attack_range_tiles` → `attacks[0].trigger_max_tiles`, `x.attack = y` → `x.attacks = [y]`:
  `core/enemies/enemy_arena.gd` and `caster_arena.gd` (`chaser_values()`/`caster_values()` deep-copy the list),
  `test_caster_attack.gd`, `test_caster_data.gd`, `test_caster_snapshot.gd`, `test_enemy_attack.gd`,
  `test_enemy_combat.gd`, `test_enemy_data.gd` (incl. `data.attack = null` → `data.attacks = [null]`),
  `test_enemy_logic.gd`, `test_enemy_snapshot.gd`; `scenes/test_f004_reload.gd`, `test_f005_reload.gd`,
  `test_f005_walls.gd`.
- (b) accessor rename inside an assertion, same expected value: `test_enemy_data.gd:17,21`,
  `test_caster_data.gd:17,22`, `test_f004_reload.gd:48,104`, `test_f005_reload.gd:58,100`.
- (c) `test_enemy_data.gd:52`: `_assert_field("attack_range_tiles", 0.001, 0.0)` →
  `_assert_attack_field("trigger_max_tiles", 0.001, 0.0)`, same boundary values.

### Deviations from plan
None.

### Assumptions made (small, reversible)
- ASSUMPTION-1: C7 lists who clears the charge segment; `step()` also clears it at its own start
  (before planning the new one). → Kept: it can never hold a previous step's segment even if a
  caller skipped `sense()`. — **Why:** same per-step rule as `_tick_displacement`; no visible change.
- ASSUMPTION-2: "moved by its lunge" (C7 Segment) → a segment exists when a latched wall-stun
  attack (melee, `wall_stun_duration > 0`), not `wall_stopped`, ends `step()` with a non-zero
  `_tick_displacement`. While an attack is latched the only displacement is the lunge (windup and
  recovery are planted), so a step spent wholly in hitstop or with no ACTIVE time gives none. —
  **Why:** simplest exact test of the C7 wording.
- ASSUMPTION-3: AC19 "brute.tres is reloaded" → the scene tests call `Enemy.apply_reloaded_data()`,
  the exact call `CombatRunner._apply_reload()` makes after the group passed validation, between
  ticks. The file-and-F5 path itself is covered by AC14's tests. — **Why:** a radius reload is only
  reachable through that call, and it pins the reload to a chosen step.
- ASSUMPTION-4: AC10 "more than 1.95 … isn't hit; at 1.94 it is" → tested 1.94 (hit), 1.951 and
  1.96 (not hit). Exactly 1.95 is the touching case, which the AC doesn't name. — **Why:** the AC
  only bounds "more than 1.95".
- ASSUMPTION-5: AC6 "that contact can still hit a player standing between the brute and the wall"
  → the core test puts the player just out of reach one step before the stub's stop (1.24 tiles
  ahead of the stop position) and checks the hit lands at the stop contact, at the brute's synced
  (physics) position. With a real wall a player truly between them is reached earlier (reach
  0.9 + 0.35 = 1.25 tiles > 0.1 tiles per step); the scene test checks that case: one hit, then
  the stun. — **Why:** it's the only geometry where "the stop contact" is the hitting one.

### Things the Auditor should look at closely
- `CombatSim.tick()` now calls `end_step()` on every combatant after `_apply_contact()`, every step
  (`combat_sim.gd`). Player, dummy and probes inherit the no-op; the whole F-001…F-005 suite passes.
- `EnemyLogic.end_step()` / `_apply_wall_stop()`: ACTIVE → RECOVERY with `phase_elapsed = 0`;
  RECOVERY keeps its elapsed time; DEAD drops the stop; anything else pushes an error. It doesn't
  call `_cross_finished_phases()` after the switch: C9's `wall_stun_duration ≥ recovery ≥ 2 steps`
  guarantees time is left (AC8 checks the tightest case at all rates).
- `report_charge_reach()` uses F-005's shortfall rule (`planned − (reached−start)·dir > ε`), and
  never touches state, position, aim or hitbox (AC6 checks state and live hitbox between report and
  contact; AC9 checks a refused report changes nothing via `to_dict()`).
- `enemy.gd`: `_overlaps_wall()` and `_sweep()` now take a centre and radius instead of a
  projectile, so the charge reuses them. The projectile calls pass exactly the old values
  (overlap: radius − ε at `origin`; sweep: full radius from `step_start`); every F-005 wall test
  passes.
- `wall_stopped` is cleared in `_clear_attack()`, so attack end, setup/reset and death all clear it.
- Suite runtime: 76 scripts / 748 tests in 187 s wall clock (was 115 s for 662 tests before
  F-006). Most of the increase is the physics scene tests (walls ~29 s, parity at 3 rates ~26 s).

### How to test
- `tools/lint` → `Success: no problems found`.
- `tools/check_core_purity` → `core purity ok`.
- `tools/test` → 76 scripts, 748 tests, all passing (run 2026-11-09).
- One file: `tools/test -gselect=test_brute_wall_stop` (or any other file name above).
- Manual (Lucas, §5): open `scenes/debug/f006_brute.tscn` and play the five steps. Keys as in
  F-005: F5 reload, R reset, I AI on/off, F3 hitboxes. The inner wall is 4 tiles right of the
  player's start; the brute starts 5 tiles left of it; `chaser_1` is at the top.

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
| Q1 | Combat | → Direction: C7 applies D-008 to a moving body (the charge), not only projectiles. Add a refinement to D-008? Proposed text: *"Refined at F-006 (PROPOSED): the same rule covers a body's planned attack movement. Core exposes the planned segment; the glue sweeps the body's circle against `world` only and reports the reach; short of the plan = wall stop. Enemy bodies never count as walls."* | no | **Direction:** added to D-008 as a PROPOSED refinement; recommended. Lucas decides at Gate A. |
| Q2 | Combat | → Direction: C14 allows mechanical edits to F-004/F-005 tests (data-building lines only). OK, or do you want T1 split into its own feature? | no | **Direction:** keep T1 in F-006 (a split adds a feature with no player-facing change). C14 was widened to the real test lines (§2): accessor renames in assertions are allowed, asserted values are not. |
| Q3 | Combat | → Art & Game Feel (CX5): look of the charge lane, the stomp's raised foot, and the wall stun (stars, a dazed pose). Combat fixes only the timing. | no | |
| Q4 | Combat | → Direction: after plan review round 1, C7 adds two details to D-008's body rule: a segment that **starts inside a wall** is a stop (`reached = start`), and a body's stop is **applied after that step's contact** (`end_step()`). F-005's blocked launch was written into D-008 at its Gate A. Should Lucas's Gate A text for the PROPOSED F-006 refinement include these two lines too? | no | |

---

## 11. Director Notes  ·  _Lucas_

<Overrides, priorities, gut calls. Everyone obeys these.>
