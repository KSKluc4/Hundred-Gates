---
id: F-006
title: Brute — charge, stomp, wall stun
status: PLAN_REVIEW      # DRAFT | PLAN_REVIEW | PLAN_CHANGES | APPROVED | IN_PROGRESS | CODE_REVIEW | CODE_CHANGES | DONE | PARKED
owner_now: Auditor       # who must act next: Planner | Auditor | Builder | Lucas
created: 2026-11-08
updated: 2026-11-08
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
    in `step()`: hitstop first, then segments, then `_position += _tick_displacement`.
  - `src/core/enemies/enemy_brain.gd`: `for_data()`, `nearest_player()`. `chaser_brain.gd` and
    `caster_brain.gd` read `data.attack_range_tiles`.
  - `src/core/enemies/enemy_intent.gd`: `attack(target)` has no attack choice.
  - `src/core/combat/combat_sim.gd` `tick()`: per step it runs `sense` → `step` →
    `fire_due_actions` → `move_bodies` → `_apply_contact()`. The glue's wall reports run inside
    `move_bodies`, **before** that step's contact (same as F-005).
  - `src/entities/combat_body.gd` `move_with_combatant()`: `move_and_slide()`, then
    `sync_position()` (the physics result is authoritative, F-001/C18).
    `src/entities/enemies/enemy.gd` then calls `_report_walls()` (projectiles, D-008) and has
    `_wall_query()` with `WALL_LAYER_MASK` (layer 1 `world`).
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
| C3 | `BruteBrain`, attack selection and the wall-stop rule live in `src/core/` with no nodes or physics. Only the glue sweeps (C7). | G6, D-008 |
| C4 | **Attack list.** See below. | §3 |
| C5 | **Brute decisions.** See below. | design doc |
| C6 | **Charge.** It's a melee enemy attack with a lunge: everything in F-004/C5 holds (latching, track then lock, constant-speed lunge along the locked aim during active, sector built fresh at each contact so it follows the brute, once per attack instance per hurtbox). The charge doesn't stop on a hit. The attacker hitstop from a landed hit pauses the charge as it pauses any lunge. Knockback direction is the existing melee rule, unchanged. | F-004/C5 |
| C7 | **Wall stop.** See below. | D-008 |
| C8 | **Stomp.** A melee enemy attack with a 360° sector and `lunge_tiles` 0. `aim_track_time` 0 is allowed (it locks at windup start; the aim doesn't matter for a full circle). | design doc |
| C9 | **Data validity.** See below. Extends F-004/C12 and F-005/C9. Bad data is rejected, never clamped. | G2 |
| C10 | All new state is serializable: `EnemyLogic`'s snapshot gains `wall_stopped` (bool), and the latched attack's snapshot gains `trigger_min_tiles`, `trigger_max_tiles` and `wall_stun_duration`. Anything the wall check needs inside a step is per-step only (like `_tick_displacement`) and never in a snapshot. Snapshot boundary as F-003/C19. | G7 |
| C11 | **Reload and rate.** A running attack keeps every latched value (including `wall_stun_duration`) and its `wall_stopped` flag through any reload. Reloading an enemy data file also reloads every attack in its list. The stun adds no rate check: it's a recovery. | F-004/C12, F-005/C11 |
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
- With the shipped data, `attacks = [brute_stomp, brute_charge]`: 0–1.5 tiles → stomp,
  3–7 → charge, 1.5–3 → walk in to 1.5, then stomp. Beyond 7 → walk in.

**C7 — Wall stop** (D-008 applied to a moving body)
- A **wall-stun attack** is a melee attack with `wall_stun_duration > 0`.
- `EnemyLogic.get_charge_segment() -> PackedVector2Array`: `[start, planned_end]` in tiles when,
  in the step that just ran, a latched wall-stun attack moved by its lunge and the brute isn't
  `wall_stopped` yet. `start` = the logic position at that step's start, `planned_end` = `start +`
  this step's displacement. Empty otherwise (no lunge movement, hitstop the whole step, dead, …).
- The glue (`enemy.gd`), after its body move and only when the segment isn't empty, sweeps a
  circle of radius `hurtbox_radius_tiles − DISTANCE_EPSILON` from `start` toward `planned_end`
  against layer 1 `world` only (`_wall_query`), and calls
  `EnemyLogic.report_charge_reach(reached: Vector2) -> bool`. Clear path → `reached ==
  planned_end` exactly (same rule as F-005's `_sweep`).
- Core: if `(planned_end − start).length() − (reached − start).dot(direction) >
  DISTANCE_EPSILON`, it's a **wall stop**. Then:
  - That step's contact still happens with the charge's sector live (when the brute is still
    ACTIVE), at the brute's authoritative position. The body position stays the physics result
    (F-001/C18); `reached` only decides the stop.
  - From that contact instant, the rest of the active phase is dropped and the brute is in
    RECOVERY, with `wall_stopped = true` and a recovery length of `wall_stun_duration`, counted
    from that instant. If the active phase already ended earlier in that same step, the recovery
    that started then becomes the stun (elapsed time kept).
  - Not a stop → nothing changes.
- `report_charge_reach()` with an empty segment pushes an error, returns false, and changes nothing.
- Enemy bodies never cause a stop (the sweep ignores layer 3). A brute blocked by another enemy
  keeps charging and slides, like any enemy body (CQ12).
- `wall_stopped` clears when the attack ends (cooldown starts) and on reset/death.
- Hitstop pauses the stun like any recovery. The stun is planted (F-004/C7).

**C9 — Data validity** (on top of F-004/C12, F-005/C9)
- `attacks` not empty, and no null entries. Each entry passes `validate_enemy()`. Errors are
  prefixed with the attack id.
- Per attack: `trigger_min_tiles ≥ 0`, `trigger_max_tiles > 0`, `trigger_min_tiles ≤
  trigger_max_tiles`, `wall_stun_duration ≥ 0`. A `wall_stun_duration > 0` needs a melee attack
  with `lunge_tiles > 0`.
- Brain kinds: `CHASER` and `BRUTE` need every attack melee, `CASTER` every attack projectile.
- Bands may overlap (list order decides). The speed rule (`validate_against_class`) is unchanged.

**Must not break:** chaser and caster behavior, every F-004/F-005 AC, projectile wall reports, the
F-004/C15 reset, hot-reload of all enemy files, the 30/60/120 parity.

---

## 5. Acceptance Criteria  ·  _Planner_

Testable, observable. The Auditor checks each one.

- [ ] AC1 — **Selection:** with `[stomp, charge]` and a ready brute, a target at 1.0 → stomp, at
  1.5 (exact) → stomp, at 2.0 → walks in, at 3.0 (exact) → charge, at 7.0 → charge, at 7.5 →
  walks in. Same view with registration order swapped → same choice.
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
- [ ] AC6 — **Wall stun:** a charge aimed at a wall 3 tiles away stops at the wall. The contact of
  that step can still hit a player standing between the brute and the wall. From that instant the
  brute is in RECOVERY with `wall_stopped`, for 1.50 s, then cooldown. Hits on it during the stun
  deal damage and hitstop, the stun pauses during that hitstop, and it is never pushed.
- [ ] AC7 — **No false stuns:** (a) a charge sliding parallel along a wall it touches, (b) a charge
  blocked by a chaser's body, (c) a charge that reaches its full 6 tiles with no wall → normal
  0.90 s recovery, `wall_stopped` false.
- [ ] AC8 — **Stun when active already ended mid-step:** a scripted step where active ends and the
  sweep reports a stop in the same step → the recovery becomes the stun, elapsed time kept.
- [ ] AC9 — **Report errors:** `report_charge_reach()` with an empty segment returns false, logs an
  error and changes nothing.
- [ ] AC10 — **Stomp:** windup 0.60 s, a 360° circle of 1.6 tiles active 0.10 s, 20 damage, 1.2 tiles
  knockback, 0.70 s recovery. A player whose center is more than 1.95 tiles (1.6 + the Warrior's
  0.35 hurtbox) from the brute's center at every contact during active isn't hit; at 1.94 it is.
- [ ] AC11 — **Brute body:** 120 HP, hurtbox 0.6, never pushed in or out of an attack
  (`knockback_scale` 0), walks at 2.0 tiles/s, aggro at 7.0 tiles or when damaged.
- [ ] AC12 — **Parity:** a scripted run (charge into a wall + a stomp + a full-distance charge) gives
  the same wall-stop step, stun end, hits and positions at 30, 60 and 120 ticks/s, in core (stub
  reports) and once in a scene over real physics.
- [ ] AC13 — **Snapshots:** `from_dict(to_dict())` mid-charge, mid-stun and mid-stomp reproduces the
  rest of the run exactly, including `wall_stopped` and the latched attack's new fields.
- [ ] AC14 — **Reload:** editing `brute_charge.tres` mid-windup doesn't change the running charge.
  The next charge uses the new values. Editing `brute.tres` reloads both attacks.
- [ ] AC15 — **Validation:** each C9 rule rejects with a named error (empty list, null entry, min >
  max, negative stun, stun on a projectile, stun with lunge 0, wrong kind per brain). Exact limits pass.
- [ ] AC16 — **Migration:** chaser and caster pass every F-004/F-005 assertion (C14).
- [ ] AC17 — **Views:** the charge lane shows during windup and changes look at lock. The stomp
  shows its circle telegraph. The stun shows the open tint and `RECOVERY (stun)`. Views re-sync
  after restore/reset.
- [ ] AC18 — **Co-op ready:** with two players, the brute targets the nearest one (ties by
  registration order) and keeps that target for the whole attack.

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
| T3 | Wall stop in core | `enemy_attack_data.gd` (`wall_stun_duration` + validation), `enemy_logic.gd` (`get_charge_segment`, `report_charge_reach`, `wall_stopped`, snapshot) | C7, C10, C11. Core tests with stub reports: AC6, AC7c, AC8, AC9, AC13, AC15 (stun rules). |
| T4 | Brute data | `data/enemies/brute.tres`, `data/attacks/brute_charge.tres`, `brute_stomp.tres`, `src/autoload/tunables.gd` | Values in the design doc's tunables index. AC4, AC10, AC11 in core. |
| T5 | Glue sweep | `src/entities/enemies/enemy.gd` | C7 glue half: sweep on layer 1 after the body move, report. Scene tests AC6, AC7a/b, AC12 physics run. |
| T6 | Views | `enemy.gd` drawing / telegraph, debug text | C12, AC17. |
| T7 | Debug scene | `scenes/debug/f006_brute.tscn`, `tests/scenes/test_f006_*.gd` | Walled room ~16×12 tiles. Player at center; `brute_1` ~5 tiles away; a straight wall ~4 tiles behind the player's start; `chaser_1` off to one side. `CombatRunner` last, `refill_player_on_died` on, shake and overlay as in F-005's scene. AC5, AC14 end to end. |

---

## 7. Plan Review  ·  _Auditor_

<Each completed round starts with its machine line (format in AGENTS.md), then its findings.
Severity: 🔴 blocking · 🟡 should fix · 🔵 suggestion. Example finding:>

### PR-1 🔴 <title>
<What's wrong, where, why it matters, what you'd suggest.>
> **Planner reply:** <accepted / rejected + reason / changed §X>

---

## 8. Implementation Log  ·  _Builder_

**Started:** YYYY-MM-DD  ·  **Branch:** `feature/F-006-brute`

### Progress
- [ ] T1 — <commit hash when done>
- [ ] T2
- [ ] T3
- [ ] T4
- [ ] T5
- [ ] T6
- [ ] T7

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
| Q1 | Combat | → Direction: C7 applies D-008 to a moving body (the charge), not only projectiles. Add a refinement to D-008? Proposed text: *"Refined at F-006 (PROPOSED): the same rule covers a body's planned attack movement. Core exposes the planned segment; the glue sweeps the body's circle against `world` only and reports the reach; short of the plan = wall stop. Enemy bodies never count as walls."* | no | **Direction:** added to D-008 as a PROPOSED refinement; recommended. Lucas decides at Gate A. |
| Q2 | Combat | → Direction: C14 allows mechanical edits to F-004/F-005 tests (data-building lines only). OK, or do you want T1 split into its own feature? | no | **Direction:** keep T1 in F-006 (a split adds a feature with no player-facing change). C14 was widened to the real test lines (§2): accessor renames in assertions are allowed, asserted values are not. |
| Q3 | Combat | → Art & Game Feel (CX5): look of the charge lane, the stomp's raised foot, and the wall stun (stars, a dazed pose). Combat fixes only the timing. | no | |

---

## 11. Director Notes  ·  _Lucas_

<Overrides, priorities, gut calls. Everyone obeys these.>
