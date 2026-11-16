---
id: F-009
title: Floor 3 boss (Juggernaut)
status: CODE_REVIEW      # DRAFT | PLAN_REVIEW | PLAN_CHANGES | APPROVED | IN_PROGRESS | CODE_REVIEW | CODE_CHANGES | DONE | PARKED
owner_now: Auditor       # who must act next: Planner | Auditor | Builder | Lucas
created: 2026-11-16
updated: 2026-11-16
depends_on: [F-006, F-007, F-008]
pillars: [2]
department: Combat
---

# F-009 — Floor 3 boss (Juggernaut)

> **How to use this file.** This is the single source of truth for this feature.
> Every agent reads the WHOLE file before acting. Write only in the sections you own
> (see studio/README.md). Never delete another role's text — reply under it.

---

## 1. Goal  ·  _Planner_

**Player-facing outcome (one sentence):**
In a test room, the player fights the Juggernaut: a two-stage brute boss whose charges come in
twos and threes and can only be truly punished when the player makes one end in a wall.

**Why now:** It is the last of phase 1's three bosses (design/combat.md, Build order: F-007 →
F-008 → F-009). Everything it needs exists after F-008: stages and patterns (F-007), the charge
and wall stun (F-006), volleys and mixed attack kinds on one brain (F-008). So it should be
data only, and it closes the combat side of phase 1.

**Out of scope (explicitly):**
- Boss room layout, interior walls, pillars, cover, room size (design/combat.md CX9) → Direction.
  The test room has only its four outer walls.
- Floor gate, door, town return, boss re-entry (D-006), loot, a victory screen.
- Final art, VFX, sound, music. Every look here is the existing placeholder.
- A new brain or any change to brain code: the Juggernaut uses `BruteBrain` as it is.
- Any change to `src/core/`, `src/entities/`, `src/world/` or `src/ui/` (see C1).
- Changing any value of the chaser, caster, brute, Warden or Hexer.
- Pre-placed adds or anything spawned mid-fight.

---

## 2. Context  ·  _Planner_

Written against `main` at `f9c6f4e`; the F-008 names were re-checked by Direction on `main` at
`3ac7fb2` (F-008 DONE and merged). Names below are the real ones on `main`.

- **F-008 names (confirmed on `main`).** Only the Debris attack depends on them:
  - `EnemyAttackData.volley_angles_deg: PackedFloat64Array`, angles in degrees from the locked
    aim, one projectile per entry, in list order (F-008/C3, C4).
  - `EnemyCombatTunables.max_volley_size` = 16, with validation in `validate_enemy()`
    (F-008/C7).
  - `EnemyData._attack_kind_errors()` is gone, so a `BRUTE` brain may use a projectile attack
    and a pattern may mix melee and projectile (F-008/C6).
  - `Enemy.get_aim_lines()`: one aim line per bolt during a volley's windup (F-008/C11).
  - **Re-check (Direction, 2026-11-16):** all four exist on `main` as named, and F-008's §8
    lists no deviation. F-008 also added `EnemyAttackData.volley_directions(aim)`, which this
    feature does not need to call.
- **Brute brain (F-006, real code).** `src/core/enemies/brute_brain.gd`: chases to
  `stop_distance_tiles`, never retreats, and at `is_attack_ready()` picks
  `EnemyBrain.pick_attack_in(enemy.get_current_attacks(), distance)`, so stage lists already work.
- **Charge and wall stun (F-006, D-008).** An attack with `wall_stun_duration > 0`, `lunge_tiles > 0`
  and no projectile is a wall-stun attack (`is_wall_stun()`). `EnemyLogic._plan_charge_segment()`
  exposes the step's segment; `Enemy._report_charge()` sweeps the body circle
  (`hurtbox_radius_tiles − DISTANCE_EPSILON`) against `world` walls and calls
  `report_charge_reach()`; `end_step()` applies the stop. Data rules (in `validate_enemy()`):
  `wall_stun_duration ≥ recovery`, and a wall-stun recovery is at least two combat steps.
- **Patterns (F-007, real code).** `EnemyAttackData.follow_up`; `EnemyLogic._end_recovery()`
  drops the follow-up when `_wall_stopped` (F-007/C12, tested in `test_patterns.gd`
  `test_ac11_a_wall_stopped_attack_drops_its_follow_up`). `has_pending_follow_up()` is false once
  wall-stopped, so a stopped gap reads as the punish window (`gap_color` vs `open_color`).
  Each follow-up re-picks its target and tracks again (F-007/C10).
- **Stages (F-007).** `EnemyStageData` (`enter_at_hp_percent`, `shift_duration`, `attacks`,
  `move_speed`, `attack_cooldown`) and `EnemyData.stages`. The stage shift waits for a free step
  start, so a running double charge always finishes (or stuns) first.
- **Presentation.** A charge already shows its lane (`Enemy._lane_length()`: lunge + range) and
  its sector. `src/ui/debug/boss_bar.gd` (`BossBar`) is reused as it is, with a mark at 50%.
- **Test scene pattern.** `scenes/debug/f007_warden.tscn`: a 20 × 12 tile room with four outer
  walls, Player, one `enemy.tscn` with `data`, `CombatDebugDraw`, `MotorDebugOverlay`, `BossBar`,
  `CombatRunner` last with `refill_player_on_died` on. Core wall tests use
  `tests/core/enemies/brute_wall_stub.gd` (F-006).
- **Path constants** live in `src/autoload/tunables.gd` (G5), as the Brute's and Warden's do.
- Relevant decisions: D-007 (step grid), D-008 (projectiles, wall reports), D-005 / G9 (data).
- No new glossary term.

---

## 3. Options Considered  ·  _Planner_

> This section is what stops context loss. Be honest about trade-offs.
> The Builder MUST NOT implement anything listed under Rejected.

### ✅ Chosen: The Juggernaut is data only, on the brute brain
- **How it works:** `juggernaut.tres` (brain `BRUTE`) plus a stage file and eight attack files.
  Double and triple charges are F-006 charges linked by `follow_up`. Debris is an F-008 volley
  of 8 bolts, the follow-up of a stage-2 stomp. A wall stop on any charge stuns it and ends the
  pattern through the existing F-007/C12 rule.
- **Why chosen:** Every behavior in the design already exists and is tested on its own. A third
  boss with no new code shows the boss base works (F-007's goal), and the risk sits in data the
  Auditor can read line by line.
- **Costs we're accepting:** It depends on F-008 landing as specified. Ten new data files.
  Two charge files differ only in `follow_up`, because `follow_up` lives on the attack (F-007/C9).
- **Would revisit if:** F-008 merges with different names or rules, or a playtest needs a
  behavior the data can't express (for example, a charge that keeps going after a stun).

### ❌ Rejected: A `JUGGERNAUT` brain or Juggernaut-specific code
- **How it would work:** A brain that, say, prefers charging toward walls or chains charges itself.
- **Why rejected:** The brute brain already moves and picks attacks exactly as the design says.
  Per-boss code is what F-007/C1 ruled out, and a brain that seeks walls would decide the
  player's punish for them (pillar 2: the player makes the wall do the work).
- **Tempting because:** "A brute that owns the room" sounds like it needs smarter movement.

### ❌ Rejected: Debris with the gap on the aim
- **How it would work:** Angles 22.5, 67.5, … so the player's line is between two bolts.
- **Why rejected:** The player who dodged the stomp walks straight back in along the aim to
  punish, and with a gap on the aim that walk is safe. That erases the floor's lesson ("a boss
  that looks open isn't always open"). With a bolt on the aim, that walk gets hit: step to the
  side, or dash through it.
- **Tempting because:** It mirrors the Hexer's Fan B and feels "fair".

### ❌ Rejected: Debris as an expanding melee shockwave
- **How it would work:** A 360° sector whose range grows over the active phase.
- **Why rejected:** A growing hitbox is a new hitbox kind (sector range changing over time) that
  the resolver, snapshots and the rate check don't have. Bolts already exist (F-005, F-008),
  and a ring with gaps can be read and passed between, which a solid wave can't.
- **Tempting because:** "Debris after a stomp" looks like a shockwave.

### ❌ Rejected: One attack that both stomps and launches the debris
- **How it would work:** The stomp's sector and the 8 bolts come from the same attack instance.
- **Why rejected:** An attack is melee or projectile, never both (F-005/C8). It would also drop
  the 0.30 s gap and the 0.50 s Debris telegraph, so the bolts would have no telegraph of their
  own (principle 1).
- **Tempting because:** One file instead of two, and it looks like one move.

### ❌ Rejected: The pattern continues after a wall stun
- **How it would work:** Charge A wall-stops, stuns 1.5 s, then Charge B starts.
- **Why rejected:** It breaks F-007/C12 and turns the only real punish into a trap. The design
  says the stun ends the pattern.
- **Tempting because:** It sounds harder and more "juggernaut".

### ❌ Rejected: Building a boss room with interior walls or pillars to test wall play
- **How it would work:** f009's room gets pillars so charges stop more often.
- **Why rejected:** Room layout is Direction's (CX9), and a room designed here would set floor 3's
  layout by accident. The four outer walls of the 20 × 12 room are enough for every wall case.
- **Tempting because:** The wall is the point of the fight.

---

## 4. Constraints  ·  _Planner_

Hard rules for this feature. Violating any of these = automatic `CODE_CHANGES`.

| ID | Constraint | Reason |
|---|---|---|
| C1 | **Data only.** No change to any file in `src/`, except new path constants in `src/autoload/tunables.gd`. No change to brains, `EnemyLogic`, `EnemyData`, `EnemyAttackData`, `Enemy`, `CombatRunner` or `BossBar`. If the Builder finds a behavior the data can't express, it stops, logs it in §8 and asks in §10. It does not add code. | F-007/C1, G9 |
| C2 | Brain = `BRUTE`. No new `Brain` value. | §3 |
| C3 | **F-008 names.** Debris uses `volley_angles_deg` and is a projectile attack on a brute brain, allowed by F-008/C6. Re-checked against `main` after F-008 was DONE (§2, Q5). | F-008 |
| C4 | No existing data file changes. The new files are exactly: `data/enemies/juggernaut.tres`, `data/enemies/juggernaut_stage_2.tres`, and the eight attack files in the tables below. | Must not break |
| C5 | **Every charge is a wall-stun attack:** `wall_stun_duration` 1.5, `lunge_tiles` > 0, melee. A wall stop on any charge of a pattern (first, middle or last) turns that charge's recovery into the 1.5 s stun and ends the pattern (F-007/C12). The cooldown starts at the stun's end. | Design, F-006/C7 |
| C6 | **Gap vs punish read (F-007/C20).** The recoveries of Charge A, stage-2 Charge B and the stage-2 Stomp are gaps (`has_pending_follow_up()` true, `gap_color`). After a wall stop the stun is shown as open (`has_pending_follow_up()` false). | Principle 2 |
| C7 | Every attack passes `validate_enemy()` with the real `enemy_combat.tres` at 120 steps/s: telegraph floor, locked tail ≥ 0.15 s, wall-stun rules, projectile sampling (5.0 / 120 ≤ 0.25), volley ≤ `max_volley_size`. Both `move_speed` values are below the Warrior's (`validate_against_class()`). | Principle 1, F-004/C12 |
| C8 | Same scripted fight at 30, 60 and 120 physics ticks/s gives the same attack starts, wall stops, launch instants, serials, hits and final HP, and bolt positions within 1e-6 tiles at every shared contact. | G1, D-007 |
| C9 | **Serializable.** A snapshot taken during a charge gap, during a wall stun, mid Debris windup, and with Debris in flight restores and continues identically. | G7 |
| C10 | **Co-op.** Nothing assumes one player: each follow-up re-picks the nearest living player (F-007/C10); each Debris bolt may hit a different player. | D-002 |
| C11 | **Test room.** `scenes/debug/f009_juggernaut.tscn` uses the same 20 × 12 tile room as `f007_warden.tscn`: four outer walls, no interior wall, pillar or door. | CX9 |
| C12 | No new input action, autoload, addon, collision layer, `EnemyLogic` state, signal or snapshot key. | G4 |

**Must not break:** all F-001–F-008 behavior and tests (unedited); the existing debug scenes;
debug reset, F5 reload and snapshot restore; the Brute, Warden and Hexer.

### Juggernaut data (starting values — all tunables)

`data/enemies/juggernaut.tres` — brain: brute · `max_hp` 500 · `hurtbox_radius_tiles` 0.8 ·
`knockback_scale` 0 · `move_speed` 2.0 · `aggro_radius_tiles` 10.0 · `stop_distance_tiles` 1.5 ·
`retreat_distance_tiles` 0 · `attack_cooldown` 1.0 · `attacks` [juggernaut_stomp,
juggernaut_charge_a] · `stages` [juggernaut_stage_2].

`data/enemies/juggernaut_stage_2.tres` — `enter_at_hp_percent` 50 · `shift_duration` 1.2 ·
`move_speed` 2.5 · `attack_cooldown` 0.8 · `attacks` [juggernaut_p2_stomp, juggernaut_p2_charge_a].

Stomps (melee, no aim: arc 360°, `aim_track_time` 0, `lunge_tiles` 0, no wall stun):

| File (`data/attacks/`) | windup | active | recovery | damage | range | knockback | trigger band | `follow_up` |
|---|---|---|---|---|---|---|---|---|
| `juggernaut_stomp` | 0.60 | 0.10 | 0.70 | 22 | 2.0 | 1.5 | 0–1.8 | — |
| `juggernaut_p2_stomp` | 0.60 | 0.10 | 0.30 (gap) | 22 | 2.0 | 1.5 | 0–1.8 | `juggernaut_debris` |

Charges (melee, arc 120°, range 1.0, active 0.50, `lunge_tiles` 7.0, damage 25, knockback 1.5,
`wall_stun_duration` 1.5):

| File (`data/attacks/`) | windup | `aim_track_time` | recovery | trigger band | `follow_up` |
|---|---|---|---|---|---|
| `juggernaut_charge_a` | 0.80 | 0.50 | 0.35 (gap) | 3.0–9.0 | `juggernaut_charge_b` |
| `juggernaut_charge_b` | 0.60 | 0.35 | 0.60 | 3.0–9.0 (unused) | — |
| `juggernaut_p2_charge_a` | 0.80 | 0.50 | 0.35 (gap) | 3.0–9.0 | `juggernaut_p2_charge_b` |
| `juggernaut_p2_charge_b` | 0.60 | 0.35 | 0.35 (gap) | 3.0–9.0 (unused) | `juggernaut_charge_c` |
| `juggernaut_charge_c` | 0.50 | 0.30 | 0.60 | 3.0–9.0 (unused) | — |

Debris (projectile volley: arc 360°, `range_tiles` 0.25 = bolt radius, `lunge_tiles` 0):

| File (`data/attacks/`) | windup | `aim_track_time` | active | recovery | damage | knockback | speed | max distance | `volley_angles_deg` | trigger band |
|---|---|---|---|---|---|---|---|---|---|---|
| `juggernaut_debris` | 0.50 | 0.30 | 0.10 | 0.80 | 18 | 0.5 | 5.0 | 8.0 | 0, 45, 90, 135, 180, −135, −90, −45 | 0–1.8 (unused) |

Times in seconds, distances in tiles, speeds in tiles/s. `is_finisher` false everywhere. Between
1.8 and 3.0 tiles the Juggernaut walks in (no band holds). At exactly 1.8 the stomp's band holds.
Chain budget: 500 HP ÷ 42 (hits 1–3) ≈ 12 full chains, inside the 10–12 "not a sponge" range.

---

## 5. Acceptance Criteria  ·  _Planner_

Testable, observable. The Auditor checks each one.

- [ ] AC1: Given the full suite, then every pre-existing test passes unedited, and `git diff`
  against the branch base touches no file in `src/` except `src/autoload/tunables.gd` (C1).
- [ ] AC2: Given `juggernaut.tres` with the real tunables at 120 steps/s, then `validate()` and
  `validate_against_class()` (Warrior) return no error, for stage 0 and stage 2.
- [ ] AC3: Given stage 1 and a ready attack, then at 1.5 and at exactly 1.8 tiles it starts
  `juggernaut_stomp`; at 2.5 it walks in and starts nothing; at 3.0 and 9.0 it starts
  `juggernaut_charge_a`; at 9.5 (aggroed) it walks in and starts nothing.
- [ ] AC4: Given stage 1, a target at 5 tiles and no wall in reach, then Charge A runs (0.80 s
  windup, 0.50 s active lunging 7.0 tiles), then a 0.35 s gap during which
  `has_pending_follow_up()` is true, then Charge B starts at that exact instant, re-picks the
  target and re-tracks (0.35 s) before locking. Then 0.60 s recovery, then the 1.0 s cooldown.
- [ ] AC5: Given Charge A whose lunge meets a wall (through `brute_wall_stub.gd`), then its
  recovery is 1.5 s, `has_pending_follow_up()` is false, Charge B never starts, and the cooldown
  starts when the stun ends. The same holds for a wall stop on Charge B, and in stage 2 on
  Charge A, B and C.
- [ ] AC6: Given stage 2 and a target at 1.5 tiles, then the stomp runs, a 0.30 s gap, then
  Debris: a 0.50 s windup that tracks 0.30 s, then at its end exactly 8 bolts launch at one
  instant with consecutive serials, one along the locked aim and the others at ±45°, ±90°,
  ±135° and 180° (within 1e-6), each with speed 5.0, radius 0.25, max distance 8.0, damage 18.
  Then 0.80 s recovery (shown as open), then the 0.8 s cooldown.
- [ ] AC7: Given stage 2 and a target at 5 tiles and no wall, then Charge A → B → C run with
  windups 0.80 / 0.60 / 0.50, gaps 0.35 / 0.35, each re-aimed, then 0.60 s recovery and cooldown.
- [ ] AC8: Given the Juggernaut crossing 50% HP during Charge A's gap, then Charge B still runs,
  the stage shift (1.2 s, planted, takes damage) starts at the first free step start after it,
  and the next attack comes from the stage-2 list at 2.5 tiles/s. (Debris only exists in
  stage 2 and stages only advance, so no Juggernaut bolt can be in flight at the shift. Bolts
  flying through a shift are already covered generically by `test_stages.gd`
  `test_ac18_a_bolt_in_flight_keeps_flying_and_hits_during_the_shift`; this feature adds no
  fixture for it.)
- [ ] AC8b: Given stage 2 and Debris in flight, when the player hits the Juggernaut (it enters
  hitstop), then every live bolt's position, by serial, matches a run without that hit at every
  step until the bolts end (within 1e-6 tiles), and the Juggernaut is in hitstop at least one
  step while they fly (F-008: owner hitstop changes no bolt).
- [ ] AC9: Given a player overlapped by two Debris bolts at one contact, then one hit (18 damage)
  lands and the other bolt flies on unmarked (F-008/C5).
- [ ] AC10: Given the same scripted fight at 30, 60 and 120 physics ticks/s (fixed player
  commands; it includes a stage-1 Charge A stopped by a wall, an unstopped double charge, a
  stomp, crossing 50% mid-pattern, a stage-2 stomp → Debris and a triple charge), then attack
  starts, wall stops, launch instants, serials, every hit and the final HP are identical, and at
  every shared contact the live bolts (by serial) match, each position within 1e-6 tiles.
- [ ] AC11: Given snapshots taken (a) in Charge A's gap, (b) in a wall stun, (c) mid Debris
  windup, (d) with Debris in flight, when each is restored and the same inputs replayed, then
  state, serials, bolt positions, hits and HP match the original run.
- [ ] AC12: `scenes/debug/f009_juggernaut.tscn` runs on its own: the 20 × 12 tile room of
  `f007_warden.tscn` (outer walls only), one Warrior, one Juggernaut, `BossBar` with a mark at
  50%, the existing debug keys, `refill_player_on_died` on. A charge into a real outer wall
  stuns it (physics, not the stub). Debug reset returns full HP, stage 0, no attack, no bolts.
  F5 reload with unchanged data keeps the fight running.

**How to verify manually (Lucas, in `f009_juggernaut.tscn`):**
1. Stand at 5 tiles in the middle of the room: a lane, a charge, a short pause, a second lane
   re-aimed at you, a second charge. Sidestep both. After the second it's far away and already
   recovering: you can't reach it in time. That is on purpose.
2. Now stand with a wall about 2 tiles behind you and let it charge. Dash sideways late: it hits
   the wall, stops for 1.5 s and the second charge never comes. Run in and land full chains.
3. Make Charge B hit the wall instead (dodge A in the open, put your back to a wall for B): same stun.
4. Hug it: it stomps (big circle). Step out, then punish the 0.70 s recovery with hits 1 and 2.
5. Take it to half HP mid double charge: the pattern finishes, it stops for about a second (hit
   it freely), then stage 2. It walks faster.
6. Stage 2, close: dodge the stomp, then walk straight back in. A ring of 8 debris comes out and
   one bolt is aimed at you: you get hit. Next time step to the side or dash through it. The
   real opening is after the debris.
7. Stage 2, far: three charges in a row, the last one faster. Use the walls.
8. **Feel test:** you should feel that *where you stand before it charges* decides the fight,
   not your reactions during it. Every wall stun should feel earned ("I put my back to the wall
   on purpose"). If you win by standing in the open and only punishing stomps, the stomp is too
   generous or the charges too easy to avoid: say so at Gate B. If you can't find a reliable way
   to get stuns in this room, say so too: that is input for the room (CX9).

---

## 6. Task Breakdown  ·  _Planner_

Small, ordered, each independently committable. F-008 is DONE and §2 is re-checked.

| # | Task | Files likely touched | Notes |
|---|---|---|---|
| T1 | Juggernaut data: enemy, stage 2, eight attacks; path constants. | `data/enemies/`, `data/attacks/`, `src/autoload/tunables.gd` | C1–C5, C7. Values from §4 tables exactly. |
| T2 | Core tests: validation, band picks, double/triple charge, wall stops on every charge (wall stub), stomp → Debris volley, stage shift mid-pattern, Debris through owner hitstop, one hit from two bolts. | `tests/core/enemies/test_juggernaut.gd` | AC2–AC9 (incl. AC8b). |
| T3 | Tick-rate and snapshot tests on the real data. | `tests/core/enemies/test_juggernaut_rates.gd` | C8, C9. AC10, AC11. |
| T4 | `f009_juggernaut.tscn`, built like `f007_warden.tscn`; scene tests (startup, real-wall stun, reset, reload). | `scenes/debug/`, `tests/scenes/f009_scene_test.gd`, `tests/scenes/test_f009_*.gd` | C11. AC1 (diff check), AC12. |

---

## 7. Plan Review  ·  _Auditor_

<Each completed round starts with its machine line (format in AGENTS.md), then its findings.
Severity: 🔴 blocking · 🟡 should fix · 🔵 suggestion.>

<!-- review-round: 1 verdict: CHANGES_REQUESTED -->

**Date:** 2026-11-16 · **Verdict:** CHANGES_REQUESTED

The goal serves pillar 2, the exclusions and rejected alternatives are explicit, and T1–T4
are ordered and independently committable. The specified values and mechanics match
`studio/design/combat.md`. Inspection of the existing brute brain, mixed-attack validation,
follow-up cancellation on wall stops, stage handling and debug-scene reload supports the
data-only scope. One acceptance scenario cannot occur with the specified data.

### PR-1 — 🔴 blocking — AC8 requires Debris to exist before it becomes available

- **Location:** §5 AC8, final sentence (lines 241); §4 enemy/stage attack lists and stomp
  follow-up (lines 174–187).
- **Problem:** AC8 requires crossing 50% HP while Debris is in flight and having those bolts
  continue through the resulting stage shift. Stage 1 contains only the plain stomp and
  double charge. Debris is reachable only through `juggernaut_p2_stomp`, after the sole 50%
  shift has already occurred. Stages only advance: `EnemyLogic._enter_deepest_stage()`
  (`src/core/enemies/enemy_logic.gd:508`) cannot enter that stage again. No legal fight with
  this data can produce the required precondition and subsequent shift.
- **Why it matters:** The Builder cannot satisfy AC8 using the real Juggernaut. It would
  have to change the specified attack lists/stages, or silently substitute an artificial
  fixture for the acceptance scenario. That conflicts with C1/C4 or leaves the AC unmet.
- **Suggested fix:** Keep the reachable threshold-crossing test during Charge A's gap.
  Replace the Debris clause with a reachable stage-2 continuation check, such as Debris
  continuing during its owner's hitstop. If projectile flight through a stage shift still
  needs evidence, cite the existing generic coverage in
  `tests/core/enemies/test_stages.gd:test_ac18_a_bolt_in_flight_keeps_flying_and_hits_during_the_shift`
  and F-008, or explicitly request a separate test-only fixture. Do not change the shipping
  Juggernaut's attack lists or add a stage to manufacture this case.

> **Planner reply (Combat):** accepted. Changed §5 AC8: the Debris-through-shift clause is removed, with a note that it is unreachable and is covered generically by `test_stages.gd` `test_ac18_a_bolt_in_flight_keeps_flying_and_hits_during_the_shift` (no test-only fixture). Added AC8b, a reachable stage-2 check: Debris bolts are unchanged by the Juggernaut's own hitstop. §6 T2 updated. Attack lists and stages unchanged.

✔ resolved — PR-1 (round 2, 2026-11-16): AC8 now tests the reachable threshold crossing
during Charge A's gap. AC8b replaces the impossible Debris-through-shift scenario with
Debris continuing through owner hitstop, and T2 includes it. The cited generic
`test_stages.gd:test_ac18_a_bolt_in_flight_keeps_flying_and_hits_during_the_shift` exists
and covers flight and damage during a shift. No shipping attack list or stage was changed.

<!-- review-round: 2 verdict: APPROVE -->

**Date:** 2026-11-16 · **Verdict:** APPROVE

**Findings:** None. PR-1 is resolved; no new findings.

Re-checked the whole plan against `PROJECT.md`, `DECISIONS.md`, `design/combat.md` and
the existing implementation. The goal serves pillar 2, scope exclusions are explicit,
alternatives have specific rejection reasons, and the data tables match the combat design.
The brute brain, mixed attack validation, follow-up targeting, wall-stop cancellation,
stage entry, telegraphs and debug-scene support can express the specified behavior within C1.
The stated timings, volley angles and speeds satisfy the existing validation rules.

The revised ACs are observable and achievable. In particular, `EnemyLogic.step()` advances
projectiles before consuming owner hitstop, supporting AC8b; the existing F-008
`test_volleys.gd:test_ac8_owner_hitstop_changes_no_bolt` demonstrates the comparison pattern.
T1–T4 remain ordered and independently committable. Q5 is answered; the remaining questions
are explicitly non-blocking tuning or presentation decisions. No unresolved implementation
ambiguity requires a plan change. Ready for Lucas's Gate A decision.

---

## 8. Implementation Log  ·  _Builder_

**Started:** 2026-11-16  ·  **Branch:** `feature/F-009-juggernaut`

### Progress
- [x] T1 — `bb38988` Juggernaut data: `juggernaut.tres`, `juggernaut_stage_2.tres`, the eight attack files (values from the §4 tables), path constants in `src/autoload/tunables.gd`.
- [x] T2 — `7225106` `tests/core/enemies/test_juggernaut.gd` (18 tests): C4/C5 data tables, AC2 validation (both stages, every attack, speeds below the Warrior's), AC3 bands, AC4 double charge (+ C10 re-pick of the nearest player), AC5 wall stop on each of the five charges, AC6 stomp → Debris, AC7 triple charge, AC8 50 % in Charge A's gap, AC8b Debris through owner hitstop, AC9 two bolts → one hit, C10 two players each hit by their own bolt.
- [x] T3 — `66e5111` `tests/core/enemies/test_juggernaut_rates.gd` (AC10 at 30/60/120, AC11 a–d) and the test helper `tests/core/enemies/room_wall_stub.gd`.
- [x] T4 — `6fec7ce` `scenes/debug/f009_juggernaut.tscn` and `tests/scenes/f009_scene_test.gd` + `test_f009_scene.gd` (7 tests, AC12/C11).
- [x] CR-1 — `ed364db` `test_juggernaut_rates.gd`: new `test_ac10_crossing_50_percent_in_charge_a_gap_is_the_same_at_every_tick_rate`.

### Deviations from plan
None.

### Assumptions made (small, reversible)
- **ASSUMPTION-1 (AC1 diff check):** checked with a command instead of a GUT test, because a test can't rely on git refs being there. `git diff --name-only 0aebafe..HEAD -- src/` lists only `src/autoload/tunables.gd`. No existing test file was edited: every changed test file is new.
- **ASSUMPTION-2 (room walls in core):** `BruteWallStub` only stops +x charges, so the AC10/AC11 scripted fight uses a new test-only helper, `RoomWallStub`. It is the four outer walls of the 20 × 12 room in any direction, with the centre inset by the hurtbox radius. It works like `BruteWallStub`: it moves the body to where it got to and reports once per step, and bolts pass through it. Bolts against real walls are already covered by F-008's scene tests. The real-wall stun is tested in the scene (AC12).
- **ASSUMPTION-3 (AC10 50 % crossing):** in the scripted fight, sword hits 1 and 2 cross 50 % during the stage-1 stomp's 0.70 s recovery, so the crossing happens inside a running attack and the shift waits for it. The crossing during Charge A's gap is AC8's own test, which uses the F-004/C6 restore path (`BossValues.set_hp`), like `test_warden`/`test_stages`. A real sword hit is then checked to land during the shift.
  **Superseded after review (CR-1):** AC10's mid-pattern crossing is now covered by its own three-rate test (Auditor's alternative fix: keep the broad fight, add the charge-gap scenario). The Juggernaut starts at 255 HP; a real sword hit 1 (10 damage) lands in stage-1 Charge A's 0.35 s gap. At 30, 60 and 120 ticks/s it asserts, at the damage event: running attack `juggernaut_charge_a`, state RECOVERY, `has_pending_follow_up()` true; then Charge B runs (it wall-stops on the bottom wall), the stage shift starts after B's last step, and stage 2 goes stomp → Debris. Attacks, wall stops, crossing time, B's end, stage entries, windups, every hit and damage, and final HP are compared across rates. The broad fight is unchanged.
- **ASSUMPTION-4 (AC4/AC7 at 5 tiles):** at 5 tiles the charges hit the player, so each active phase lasts 0.50 s plus 0.05 s of attacker hitstop per landed hit. The tests add that from the recorded hits. Windups, track times, gaps, recoveries and cooldowns are checked exactly. The AC5 wall-stop tests keep the player out of every charge's reach, so their timing has no hitstop.
- **ASSUMPTION-5 (placeholder look):** the Juggernaut's `body_color` in the scene is `Color(0.6, 0.42, 0.3)`, a placeholder (Q4). The rest of the scene copies `f008_hexer.tscn`/`f007_warden.tscn` exactly: same room, walls, bar, overlay and runner.

### Things the Auditor should look at closely
- `test_juggernaut.gd` `_assert_wall_stop`: the charges all go +x, because `BruteWallStub` only stops +x. Between charges the player is moved 7 tiles further, so no charge reaches it, and the stub's `limit` is set 4 tiles ahead of the charge that should stop. The stun is checked as the recovery (1.5 s), shown as open, with no later charge and the cooldown starting at its end.
- AC9 places the player at the midpoint of where bolts 0 and 1 will be at the next contact, 1 tile out. Both overlap it there at 0.38 tiles, and every other bolt is over 1 tile away. I chose this because with a static placement, float noise picks which bolt overlaps first.
- AC8b compares every live bolt's snapshot by step, from launch until none is left, between a run with a sword hit 1 and a run without. The hit lands in Debris's recovery, while the bolts fly.
- `test_juggernaut_rates.gd`'s script (thirtieths 45–65, 75–120, 279–294, 395–405) is timed to the current §4 values. Retuning the Juggernaut (Q2, Q3) can change the attack sequence the test asserts, and the script would need re-timing. Rate parity and the snapshot comparisons don't depend on the values.
- Every test loads the real `juggernaut.tres` (the cached resource) and never changes it.

### How to test
- `tools/test` — full suite: 916 tests, all pass (885 before this feature, plus 31 new).
- `tools/test -gselect=test_juggernaut` (core, rates) · `tools/test -gselect=test_f009` (scene).
- `tools/lint` and `tools/check_core_purity` — both clean.
- Manual (Lucas, §5): open `scenes/debug/f009_juggernaut.tscn` and run it (F6).

---

## 9. Code Review  ·  _Auditor_

<Each completed round starts with its machine line (format in AGENTS.md), then
`**Reviewed commit:** <hash>`, AC evidence and findings.>

<!-- review-round: 1 verdict: CHANGES_REQUESTED -->

**Reviewed commit:** 749458100e7ae85db36ff5750aa687e0f159e23a

**Date:** 2026-11-16 · **Verdict:** CHANGES_REQUESTED

One blocking acceptance-coverage finding. No production data or scene defect found.
Reviewed the complete feature and branch diff against `main`, including the existing
logic and presentation that consume the new resources. Per the Mode B handoff,
`tools/test`, `tools/lint` and `tools/check_core_purity` passed on this exact HEAD;
those prerequisite checks were not rerun. `git diff --check` is clean.

### AC evidence

| AC | Result | Evidence |
|---|---|---|
| AC1 | ✅ | The prerequisite suite passed. The diff adds only new test files and data; its only `src/` change is the ten path constants in `src/autoload/tunables.gd:40`. |
| AC2 | ✅ | `test_juggernaut.gd:185` validates the real enemy, stage, all eight attacks and both speeds against the Warrior at 120 steps/s. Resource values match §4. |
| AC3 | ✅ | `test_juggernaut.gd:201` covers all six specified distances and checks CHASE when no band holds; the lists feed the unchanged `BruteBrain`. |
| AC4 | ✅ | `test_juggernaut.gd:210` checks the double charge, seven-tile lunge, timings, pending follow-up, fresh aim lock and cooldown, accounting for landed-hit hitstop. The test at line 245 verifies target re-selection with two players. |
| AC5 | ✅ | The five tests at `test_juggernaut.gd:262` use `_assert_wall_stop` (line 510) to stop every charge position, check the 1.5 s stun, cancellation, open read and cooldown at stun end. All five charge resources set `wall_stun_duration = 1.5`. |
| AC6 | ✅ | `test_juggernaut.gd:282` checks stomp/gap/Debris timings, one simultaneous eight-bolt launch, serials, angles relative to locked aim, bolt values, final recovery and cooldown. `juggernaut_p2_stomp.tres` links to `juggernaut_debris.tres`. |
| AC7 | ✅ | `test_juggernaut.gd:329` checks A → B → C, all windups and tracking times, both gaps, re-aiming, final recovery and stage-2 cooldown. The three resources form that chain. |
| AC8 | ✅ | `test_juggernaut.gd:371` crosses the threshold in Charge A's gap, checks B completes before the shift, then checks planted damage reception, shift duration including hitstop, 2.5 tiles/s movement and the next stage-2 attack. |
| AC8b | ✅ | `test_juggernaut.gd:416` compares live bolts by serial at every flight step between runs with and without a sword hit, requires owner hitstop during flight and checks simultaneous flight completion. |
| AC9 | ✅ | `test_juggernaut.gd:438` verifies two simultaneous overlaps, one 18-damage hit, one marked bolt and continued flight of the other. |
| AC10 | ❌ | `test_juggernaut_rates.gd:23` compares attack/wall/launch/hit times, serials, damage, final HP and bolt positions at shared contacts across 30/60/120. However, its threshold crossing occurs during the standalone stomp, so the required mid-pattern crossing is absent (CR-1). |
| AC11 | ✅ | The four tests at `test_juggernaut_rates.gd:65` verify the requested snapshot preconditions. `_assert_resumes` (line 166) restores into a fresh sim and compares complete snapshots after replay, subsequent hits and wall stops. |
| AC12 | ✅ | `f009_juggernaut.tscn` reuses the F-007 room and existing components. The seven tests in `test_f009_scene.gd:10` cover standalone setup, four outer walls, Warrior/Juggernaut, bar mark, debug keys, real-wall stun, reset and unchanged-data F5 continuation. |

### CR-1 — 🔴 blocking — AC10 substitutes a standalone attack for the required mid-pattern threshold crossing

- **Location:** `tests/core/enemies/test_juggernaut_rates.gd:47`, lines 104–115 and
  140–142; §8 ASSUMPTION-3.
- **Problem:** The scripted fight crosses 50% during `juggernaut_stomp`'s recovery,
  as ASSUMPTION-3 explicitly records. That attack has no follow-up. The
  `crossed_mid_attack` flag accepts any non-null running attack, so it does not
  require a charge pattern or an outstanding follow-up. AC10 explicitly requires
  crossing 50% mid-pattern. AC8 covers the charge-gap case only at 120 ticks/s.
- **Why it matters:** The parity test never exercises preserving the old stage's
  pending Charge B after the threshold crossing at 30 and 60 ticks/s. It would
  remain green if that interaction behaved differently at those rates. The
  passing suite therefore does not establish the complete approved AC10 scenario.
- **Suggested fix:** Retune the scripted fight so the threshold crosses while the
  stage-1 double charge still has a follow-up pending, while retaining AC10's other
  required events. Assert the crossing's attack id and pending follow-up, and that
  B finishes before the shift, in every rate run. Alternatively, preserve this
  broad fight and add the missing charge-gap threshold scenario at all three
  rates with the same event/state comparisons. Update §8 to describe the final
  coverage; do not change shipping data to manufacture the scenario.

> **Builder reply:** fixed in `ed364db`. Took the alternative: the broad fight stays, and a new test, `test_ac10_crossing_50_percent_in_charge_a_gap_is_the_same_at_every_tick_rate`, crosses 50 % with a real sword hit in stage-1 Charge A's gap at 30, 60 and 120 ticks/s. In every run it asserts the crossing's attack id (`juggernaut_charge_a`), RECOVERY state and pending follow-up at the damage event, that Charge B runs and its last step comes before the shift, then stage 2's stomp → Debris. Events, times, damage and final HP are compared across rates. No shipping data changed. §8 ASSUMPTION-3 updated.

### Rejected options, constraints, deviations and assumptions

- **Rejected-option check:** None reintroduced. The boss uses BRUTE with ordinary
  follow-ups; Debris is a separate projectile attack with a bolt on the aim;
  wall stops cancel patterns; the room has only four outer walls.
- **Constraints:** Production changes satisfy C1–C7 and C10–C12. Snapshot evidence
  supports C9. C8's rate comparisons cover the exercised fight, with the AC10
  scenario gap identified above; no actual frame-rate divergence was observed.
  G1–G9 remain supported by the existing step grid, resources, isolated scene,
  path constants, presentation separation, snapshots and command layer. No new
  dependency or public state/API was added, and existing content is untouched.
- **Deviation audit:** No DEV-n entries or unlogged production departures found.
  ASSUMPTION-3 documents a test-scenario substitution, but an explicit AC is not
  an ambiguity to resolve by assumption; CR-1 requires the missing coverage.
- **Assumptions:** ASSUMPTION-1 (git-based scope check), ASSUMPTION-2 (test-only
  four-wall reporter), ASSUMPTION-4 (attacker hitstop in elapsed timing) and
  ASSUMPTION-5 (placeholder colour) are justified and reversible. The new wall
  geometry lives only in tests, consistent with D-008. ASSUMPTION-3 is reversible
  but insufficient for AC10 as written.

The manual feel checks in §5 remain for Lucas at Gate B.

---

## 10. Open Questions  ·  _Anyone (append)_

| # | Raised by | Question | Blocking? | Answer (Lucas/Planner) |
|---|---|---|---|---|
| Q1 | Combat | → Lucas: Debris puts one bolt on the aim (rush in after the stomp = hit; §3). The design doc didn't say which; it's updated to say so. Veto at Gate A if you want the gap on the aim. | no | |
| Q2 | Combat | → Direction: the Juggernaut is tuned in an empty 20 × 12 room. How often charges hit walls depends on the real room (CX9). Re-tune `lunge_tiles` and the charge band when the floor 3 boss room exists. | no | **Direction (2026-11-16):** accepted. The floor structure spec (F-011) carries a re-tune task for the floor 3 boss room (CX9). |
| Q3 | Combat | → Lucas: a charge's 0.60 s recovery is unpunishable by distance, by design: the wall stun is the punish. Judge at Gate B whether a player who never gets a stun has enough openings (stomp only), and whether HP 500 makes that fight too long. | no | |
| Q4 | Combat | → Art & Game Feel: look and sound of consecutive charge lanes, the wall-stun state, and the Debris ring telegraph (8 aim lines). Placeholders ship here (CX5, CX8). | no | |
| Q5 | Combat | → Direction: re-check §2 against `main` once F-008 is DONE (field names, validation, aim lines, F-008 §8 deviations) before Gate A. | yes (before Gate A) | **Direction (2026-11-16):** done on `main` at `3ac7fb2`. `volley_angles_deg`, `max_volley_size` (16), `get_aim_lines()` and the removed kind rule are all as this spec names them; F-008 §8 has no deviation. §2 and C3 updated. |

---

## 11. Director Notes  ·  _Lucas_

<Overrides, priorities, gut calls. Everyone obeys these.>
