---
id: F-009
title: Floor 3 boss (Juggernaut)
status: IN_PROGRESS      # DRAFT | PLAN_REVIEW | PLAN_CHANGES | APPROVED | IN_PROGRESS | CODE_REVIEW | CODE_CHANGES | DONE | PARKED
owner_now: Builder       # who must act next: Planner | Auditor | Builder | Lucas
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
- [ ] T1
- [ ] T2
- [ ] T3
- [ ] T4

### Deviations from plan
None.

### Assumptions made (small, reversible)

### Things the Auditor should look at closely

### How to test

---

## 9. Code Review  ·  _Auditor_

<Each completed round starts with its machine line (format in AGENTS.md), then
`**Reviewed commit:** <hash>`, AC evidence and findings.>

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
