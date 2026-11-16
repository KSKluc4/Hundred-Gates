---
id: F-008
title: Volleys + floor 2 boss (Hexer)
status: PLAN_REVIEW      # DRAFT | PLAN_REVIEW | PLAN_CHANGES | APPROVED | IN_PROGRESS | CODE_REVIEW | CODE_CHANGES | DONE | PARKED
owner_now: Lucas       # who must act next: Planner | Auditor | Builder | Lucas
created: 2026-11-16
updated: 2026-11-16
depends_on: [F-005, F-007]
pillars: [2]
department: Combat
---

# F-008 — Volleys + floor 2 boss (Hexer)

> **How to use this file.** This is the single source of truth for this feature.
> Every agent reads the WHOLE file before acting. Write only in the sections you own
> (see studio/README.md). Never delete another role's text — reply under it.

---

## 1. Goal  ·  _Planner_

**Player-facing outcome (one sentence):**
In a test room, the player fights the Hexer: a two-stage ranged boss that fills the room with
fans and rings of bolts, to be closed on under fire, dashed through, and punished after its nova.

**Why now:** F-007 (boss base, Warden) is DONE. The Hexer is the second of phase 1's three
bosses and the only one that needs a new mechanic: several projectiles from one attack. F-009
(Juggernaut) reuses it for its Debris attack.

**Out of scope (explicitly):**
- Boss room layout, cover and pre-placed adds (design/combat.md CX9) → Direction.
- Floor gate, door, town return, boss re-entry (D-006), loot, a victory screen.
- Final art, VFX, sound, music. Every look here is a placeholder.
- A new brain or any change to brain code: the Hexer uses `CasterBrain` as it is.
- Bolts with delays inside one volley, homing, bouncing or piercing bolts.
- Changing any value of the chaser, caster, brute or Warden.
- The Juggernaut (F-009).

---

## 2. Context  ·  _Planner_

Written against `main` at `39acab8` (F-007 merged). Names below are the real ones.

- **Boss base (F-007, real code).** `EnemyStageData` (`enter_at_hp_percent`, `shift_duration`,
  `attacks`, `move_speed`, `attack_cooldown`), `EnemyData.stages`, `State.STAGE_SHIFT`,
  `EnemyAttackData.follow_up`, `EnemyLogic.get_current_attacks()` and
  `has_pending_follow_up()`. A pattern is read by position (`_pattern_root_index`,
  `_pattern_depth`). The docs call these *stages*, never *phases*. None of it changes here.
- **Projectiles (F-005, D-008).** `EnemyLogic._launch_projectile()` runs once when a projectile
  attack's windup ends and calls `ProjectileSet.launch()` once, with origin
  `_position + _tick_displacement`, direction `_aim`, and flight time `_step_time_left`.
  Each projectile has its own serial, hit set, wall report (`Enemy._report_walls()` loops over
  all of them) and a `single_target`, no-attacker-hitstop hitbox. A volley only needs
  `launch()` called several times: `ProjectileSet` itself does not change.
- **A rule on `main` blocks the Hexer.** `EnemyData._attack_kind_errors()` rejects a melee
  attack on `Brain.CASTER` and a projectile attack on `CHASER` / `BRUTE` (F-005/C9, extended to
  follow-ups by F-007/C13 a). The Hexer's Nova is a melee circle on a caster brain. Nothing in
  `EnemyLogic` depends on the brain's kind: the sector, the launch and the wall stun are all
  decided per attack (`is_projectile()`, `is_wall_stun()`). C6 removes the rule.
- **Follow-ups re-aim (F-007/C10).** Each follow-up re-picks its target and tracks again. So
  the Hexer's Fan B (bolts at ±10°) is centred on the player's *current* position: the gap is
  on the aim line. The design doc's "(the lanes that were safe)" is therefore wrong; the read
  is: Fan A has a bolt on the aim (move), Fan B has the gap on the aim (hold still, or dash
  through when close: under about 3.5 tiles the gap is narrower than the player).
- **Presentation.** `Enemy.get_aim_line()` returns one line and `_draw_aim_line()` draws it;
  `get_bolts_px()` and `_draw_bolts()` already handle any number of projectiles.
  `src/ui/debug/boss_bar.gd` (`BossBar`) is reused as it is.
- **Test scene pattern.** `scenes/debug/f007_warden.tscn`: a 20 × 12 tile walled room, Player,
  one `enemy.tscn` instance with `data`, `CombatDebugDraw`, `MotorDebugOverlay`, `BossBar`,
  and `CombatRunner` as the last child. Scene tests follow `tests/scenes/f007_scene_test.gd`.
- **Path constants** live in `src/autoload/tunables.gd` (G5), as the Warden's do.
- Relevant decisions: D-007 (step grid), D-008 (projectiles), D-005 / G9 (data-driven).
- New term: **Volley** — all the projectiles one attack launches at the same instant.

---

## 3. Options Considered  ·  _Planner_

> This section is what stops context loss. Be honest about trade-offs.
> The Builder MUST NOT implement anything listed under Rejected.

### ✅ Chosen: An explicit list of angles; each entry is an ordinary projectile
- **How it works:** `EnemyAttackData.volley_angles_deg` lists angles from the locked aim. At
  the launch instant the attack launches one F-005 projectile per entry, in list order. Empty
  means one projectile along the aim, as today. The brain kind rule is removed so one enemy can
  mix melee and projectile attacks.
- **Why chosen:** Every shape in the design (fan with a bolt on the aim, fan with a gap on the
  aim, full ring) is one list with no rule to misread. Hits, walls, snapshots and the rate
  check are F-005's, unchanged, because each bolt is a normal projectile.
- **Costs we're accepting:** A ring is 12 numbers typed by hand. More projectiles in flight
  means more wall sweeps per step (about 20 at the Hexer's worst). Removing the kind rule
  lets someone author a chaser with a bolt, which no design asks for.
- **Would revisit if:** Wall sweeps show up in a profile (D-008's signal), or volleys need
  shapes a flat angle list can't say (different speeds per bolt).

### ❌ Rejected: Count + spread (`projectile_count`, `projectile_spread_deg`)
- **How it would work:** N bolts spaced evenly, centred on the aim.
- **Why rejected:** Centring puts a bolt on the aim for odd counts and a gap for even ones, so
  "12-bolt ring with a bolt aimed at the player" needs a third offset field, and three fields
  plus a centring rule is more to get wrong than one list.
- **Tempting because:** Two numbers, and it's how most tutorials do a shotgun.

### ❌ Rejected: One volley object sharing a hit set between its bolts
- **How it would work:** The volley is one projectile with several circles; a player hit by
  one bolt is marked for all.
- **Why rejected:** It breaks D-008's identity (owner + serial per projectile), needs new
  rules for a part that hits a wall or lands, and solves nothing: a player's hurt i-frames
  already stop a second bolt of the same volley at the same contact. A bolt still touching
  the player after those i-frames end may hit, as any F-005 bolt or melee hitbox may
  (combat.md: a skipped hurtbox is not marked; leaving matters). The design doc's volley line
  is scoped to that (PR-1).
- **Tempting because:** It makes "a volley hits you once" true by construction.

### ❌ Rejected: A `HEXER` brain (or exempting enemies with stages from the kind rule)
- **How it would work:** Keep the kind rule; add a brain value or a boss exception that allows
  both kinds.
- **Why rejected:** A brain is a way of moving and deciding, and the Hexer moves exactly like
  a caster. A per-boss brain or a boss special case is boss code, which F-007/C1 ruled out.
- **Tempting because:** It touches no existing rule and no existing test.

### ❌ Rejected: A follow-up that keeps the previous attack's aim
- **How it would work:** Fan B would fire along Fan A's aim, into the lanes that were safe.
- **Why rejected:** It adds a second aim mode next to F-007/C10's re-pick and re-track, and in
  co-op the fan would ignore whoever is nearest now.
- **Tempting because:** It's what the design doc's sentence literally describes.

### ❌ Rejected: Delays between the bolts of one volley
- **How it would work:** Each entry also has a launch delay.
- **Why rejected:** Per-bolt timers inside the active phase are new timeline state to
  snapshot and to keep exact across tick rates. Rhythm already exists: follow-ups.
- **Tempting because:** Sweeping fans look great.

---

## 4. Constraints  ·  _Planner_

Hard rules for this feature. Violating any of these = automatic `CODE_CHANGES`.

| ID | Constraint | Reason |
|---|---|---|
| C1 | Volleys live in `EnemyAttackData` and `EnemyLogic` (`src/core/`), with no node, physics or visual dependency. No boss class, no Hexer-specific code anywhere. `ProjectileSet`'s public API and behavior do not change. | G6, F-007/C1 |
| C2 | An attack with an empty `volley_angles_deg` behaves exactly as before. No existing data file changes, except `data/tunables/enemy_combat.tres` gaining `max_volley_size`. Existing tests pass unedited, except the assertions of the brain kind rule (C6). | Must not break |
| C3 | **Volley data.** New `EnemyAttackData.volley_angles_deg: PackedFloat64Array` (default empty): degrees from the locked aim, one projectile per entry, in list order. Empty = one projectile along the aim. Appended to `ENEMY_SNAPSHOT_KEYS`, so the latched attack carries it in snapshots and `from_snapshot()` restores it. The latched copy (`_latch()`) owns its own copy of the list: a reload never changes a running attack. | G9, F-004/C5 |
| C4 | **Launch.** At the existing launch instant (windup end of a projectile attack), `EnemyLogic` calls `ProjectileSet.launch()` once per entry, in list order, all with the same origin, the same latched values and the same flight time as today's single launch. Direction of an entry = `_aim.rotated(deg_to_rad(angle))`. Serials are consecutive in list order. | D-008 |
| C5 | **After launch nothing is shared.** Each bolt is an independent F-005 projectile: own hit set, single target, no attacker hitstop, knockback along its own flight direction, own wall report and blocked-launch report, own max distance, removed with its owner. No new hit rule: a player overlapped by several bolts at one contact takes exactly one hit, because the first hit's hurt i-frames stop the rest (F-003 recheck); the stopped bolts are not marked and fly on. There is **no lifetime immunity per volley**: an unmarked bolt that still overlaps the player when the hurt i-frames end hits normally. | F-005/C4, F-003 |
| C6 | **The brain kind rule is removed.** Delete `EnemyData._attack_kind_errors()` and its call in `_chain_errors()`. Any brain may use melee and projectile attacks, and a pattern may mix them. Brain code does not change. This supersedes the last bullet of F-005/C9 and the kind part of F-007/C13 (a). The tests that assert the rule (in `test_attack_list.gd`, `test_brute_brain.gd`, `test_brute_data.gd`, `test_caster_data.gd`, `test_stage_validation.gd`) are replaced by tests that the mixed data is accepted. | §2 |
| C7 | **Validation**, in `EnemyAttackData.validate_enemy()`, so it covers setup, reload, stage lists and follow-ups; rejected, never clamped; messages in the existing `<attack id>: <rule>` form. (a) A melee attack must have an empty `volley_angles_deg`. (b) Every angle is finite and within −180..180. (c) No two entries point the same way: differing by less than `VOLLEY_ANGLE_EPSILON_DEG` (a new const, 0.01) modulo 360, so −180 with 180 is rejected. (d) The list has at most `max_volley_size` entries. New `EnemyCombatTunables.max_volley_size: int`, script default **16** (so a resource built with `new()`, as existing tests do, stays valid) and 16 in `enemy_combat.tres`; its own `validate()` requires ≥ 1, so an explicitly set 0 is rejected. | Principle 1, G2, D-008 cost |
| C8 | **Rate change and reload.** A volley pending in `WINDUP` keeps its latched angles, speed and radius through any reload. The existing rate-change check (`_extra_rate_errors()`) is unchanged: one speed and radius per attack covers every bolt. | F-005/C11 |
| C9 | **Serializable.** No new `EnemyLogic` snapshot key. A snapshot taken mid-windup of a volley, or with a volley in flight, restores and continues identically (same serials, positions, hits). | G7 |
| C10 | Same scripted fight at 30, 60 and 120 physics ticks/s gives the same launch instants, serials, bolt positions at each contact (within 1e-6 tiles), hits and final HP. | G1, D-007 |
| C11 | **Presentation.** New `Enemy.get_aim_lines() -> Array[PackedVector2Array]`: during a projectile attack's windup, one line per bolt to be launched, in list order, each built as `get_aim_line()` builds its line today (from the enemy along that bolt's direction, max distance long, global px). `get_aim_line()` keeps its signature and returns the first of them (unchanged for one bolt and for charge lanes). `_draw_aim_line()` draws all of them. Derived from logic every frame; nothing in core reads it. | G6, F-005 AC24 |
| C12 | **The Hexer is data only:** `data/enemies/hexer.tres`, `data/enemies/hexer_stage_2.tres`, eight files in `data/attacks/`, and their path constants in `src/autoload/tunables.gd`. Brain = `CASTER`. | G9, G5 |
| C13 | No new input action, autoload, addon, collision layer, `EnemyLogic` state or signal. | G4 |
| C14 | Nothing assumes one player: each bolt may land on a different player at the same contact. | D-002 |

**Must not break:** all F-001–F-007 behavior and tests (except C6's assertions); the six
existing debug scenes; debug reset, F5 reload and snapshot restore; the Warden.

### Hexer data (starting values — all tunables)

`data/enemies/hexer.tres` — brain: caster · `max_hp` 320 · `hurtbox_radius_tiles` 0.5 ·
`knockback_scale` 0 · `move_speed` 2.5 · `aggro_radius_tiles` 10.0 · `stop_distance_tiles` 7.0 ·
`retreat_distance_tiles` 4.0 · `attack_cooldown` 1.2 · `attacks` [hexer_nova, hexer_fan_a] ·
`stages` [hexer_stage_2].

`data/enemies/hexer_stage_2.tres` — `enter_at_hp_percent` 50 · `shift_duration` 1.2 ·
`move_speed` 3.0 · `attack_cooldown` 0.9 · `attacks` [hexer_p2_nova, hexer_p2_fan_a].

Melee (`projectile_speed_tiles` 0, `projectile_max_distance_tiles` 0, empty volley):

| File (`data/attacks/`) | windup | `aim_track_time` | active | recovery | damage | arc | range | knockback | trigger band | `follow_up` |
|---|---|---|---|---|---|---|---|---|---|---|
| `hexer_nova` | 0.60 | 0 | 0.10 | 1.00 | 18 | 360° | 2.5 | 3.0 | 0–2.5 | — |
| `hexer_p2_nova` | 0.60 | 0 | 0.10 | 0.30 | 18 | 360° | 2.5 | 3.0 | 0–2.5 | `hexer_ring` |

Projectile (arc 360°, `range_tiles` 0.25 = bolt radius, damage 18, knockback 0.5, active 0.10):

| File (`data/attacks/`) | windup | `aim_track_time` | recovery | speed | max distance | `volley_angles_deg` | trigger band | `follow_up` |
|---|---|---|---|---|---|---|---|---|
| `hexer_fan_a` | 0.70 | 0.45 | 0.30 | 6.0 | 10.0 | −20, 0, 20 | 2.5–9.0 | `hexer_fan_b` |
| `hexer_fan_b` | 0.45 | 0.25 | 0.90 | 6.0 | 10.0 | −10, 10 | 2.5–9.0 (unused) | — |
| `hexer_p2_fan_a` | 0.70 | 0.45 | 0.30 | 6.0 | 10.0 | −20, 0, 20 | 2.5–9.0 | `hexer_p2_fan_b` |
| `hexer_p2_fan_b` | 0.45 | 0.25 | 0.30 | 6.0 | 10.0 | −10, 10 | 2.5–9.0 (unused) | `hexer_fan_c` |
| `hexer_fan_c` | 0.45 | 0.25 | 0.90 | 6.0 | 10.0 | −20, 0, 20 | 2.5–9.0 (unused) | — |
| `hexer_ring` | 0.60 | 0.35 | 1.00 | 4.0 | 8.0 | 0, 30, 60, 90, 120, 150, 180, −150, −120, −90, −60, −30 | 0–2.5 (unused) | — |

Times in seconds, distances in tiles, speeds in tiles/s. `lunge_tiles` 0, `wall_stun_duration`
0 and `is_finisher` false everywhere. At exactly 2.5 tiles both stage-1 bands hold: list order
makes it the nova.

---

## 5. Acceptance Criteria  ·  _Planner_

Testable, observable. The Auditor checks each one.

- [ ] AC1: Given the existing chaser, caster, brute and Warden data, when the full suite runs,
  then every pre-existing test passes unedited, except the brain-kind assertions named in C6.
- [ ] AC2: Given a projectile attack with `volley_angles_deg` [−20, 0, 20] and a locked aim
  `a`, when its windup ends, then exactly three projectiles exist at that instant, with
  consecutive serials in list order, the same origin, speed, radius, damage, knockback and max
  distance, and directions `a` rotated by −20°, 0° and 20° (within 1e-6).
- [ ] AC3: Given the same attack with an empty list, then exactly one projectile launches
  along `a`, and a recorded run of `caster_bolt` (positions, hits, serials) is identical to the
  run before this feature.
- [ ] AC4: Given a windup that ends inside a step, then every bolt of the volley has flown the
  same distance at that step's contact (speed × the time left in the step).
- [ ] AC5: Given one player overlapped by all three bolts at the contact after launch, then
  the player takes exactly one hit (18 damage) from the lowest serial, the other two bolts are
  not marked, are not removed, and keep flying.
- [ ] AC5b: Given a test volley whose unmarked bolt still overlaps the player when that
  player's hurt i-frames from an earlier bolt of the same volley end (e.g. a slow bolt the
  player stands in), then that bolt hits at the first contact after the i-frames end. There is
  no per-volley immunity (C5).
- [ ] AC6: Given two players, each overlapped by a different bolt of one volley at the same
  contact, then both are hit at that contact, each by its own bolt.
- [ ] AC7: Given a volley where one bolt's path meets a wall and the others' don't, then only
  that bolt is spent at the wall; the others fly to their max distance. Given a volley
  launched with its origin overlapping a wall, then every bolt is reported as a blocked launch,
  none ever hits, and the serials stay used.
- [ ] AC8: Given a volley in flight, when its owner dies, then all its bolts are removed at
  that contact. When its owner enters a stage shift or hitstop, the bolts keep flying.
- [ ] AC9: Data with any of these is rejected at setup and on reload, the message naming the
  attack and the rule: a melee attack with a non-empty list; an angle of 181; an angle of NaN;
  the lists [10, 10], [−180, 180] and [0, 0.005]; a list of 17 entries with `max_volley_size`
  16; `max_volley_size` 0. A list of exactly 16 entries passes. The same holds when the bad
  attack is a follow-up or sits in a stage's list.
- [ ] AC10: Given `Brain.CASTER` with a melee attack, `Brain.CHASER` and `Brain.BRUTE` with a
  projectile attack, and a pattern melee → projectile, then validation passes and each attack
  runs by its own kind: the melee one has a sector and launches nothing, the projectile one
  launches and has no sector.
- [ ] AC11: Given a volley attack in `WINDUP`, when the data is reloaded with a different
  `volley_angles_deg`, then the running attack launches the old list and the next one the new.
- [ ] AC12: Given snapshots taken (a) mid-windup of a volley and (b) with a volley in flight,
  when each is restored and the same inputs replayed, then serials, bolt positions at every
  contact, hits and HP match the original run.
- [ ] AC13: Given the same scripted fight against the real Hexer (fixed player commands,
  crossing 50% HP mid-pattern, at least one nova, one fan pattern and one ring), when it runs
  at 30, 60 and 120 physics ticks/s, then launch instants, serials, every hit and the final HP
  values are identical, and at every contact instant shared by the three runs the set of live
  bolts (by serial) is the same and each bolt's position matches within 1e-6 tiles.
- [ ] AC14: Given `hexer.tres` loaded with the real tunables, then validation passes (including
  the speed rule against the Warrior), and a test asserts: stage 1 at 2.0 tiles starts
  `hexer_nova`; at exactly 2.5 starts `hexer_nova`; at 5.0 runs fan A (3 bolts) → fan B
  (2 bolts) and then the cooldown; at 9.5 starts nothing. Stage 2 at 2.0 runs nova → ring
  (12 bolts, one along the locked aim); at 5.0 runs fan A → fan B → fan C (3, 2, 3 bolts).
- [ ] AC15: Given the Hexer with its cooldown running and a player at 3.0 tiles, then it backs
  straight away; at 8.0 tiles it walks in; at 5.0 it holds (the caster brain, unchanged).
- [ ] AC16: Given a volley attack in windup, then `get_aim_lines()` has one line per bolt in
  list order, each from the enemy along that bolt's direction and max distance long,
  `get_aim_line()` equals the first, and outside a windup both are empty. After a reset, a
  reload or a restore no stale line or bolt is drawn.
- [ ] AC17: `scenes/debug/f008_hexer.tscn` runs on its own: the same 20 × 12 tile walled room
  as `f007_warden.tscn` (no pillar, no door), one Warrior, one Hexer, the `BossBar` with a
  mark at 50%, the existing debug keys, and `refill_player_on_died` on. The debug reset
  returns the Hexer to full HP, stage 0, no attack and no bolts.

**How to verify manually (Lucas, in `f008_hexer.tscn`):**
1. Stand at 5–6 tiles: three lines appear, three bolts come. Step out of the middle lane.
   Then two lines appear around you: stand still and both miss; strafe and you walk into one.
2. Do the same at 3 tiles: now the two-bolt fan is too tight to stand in. Dash through it.
3. Walk in. It backs off slower than you walk. Inside 2.5 tiles it raises the nova: step out
   or dash through, then it's open for a full chain.
4. Get hit by the nova on purpose: you're thrown back about 3 tiles and it starts shooting.
5. Stand point-blank on a fan: you take one hit, never two or three.
6. Take it to half HP mid-pattern: the pattern finishes, it stops for about a second (hit it
   freely; bolts already in the air still fly), then stage 2.
7. Stage 2, close: after the nova a ring of 12 comes out, one bolt straight at you. Dash
   through it toward the boss and punish.
8. Stage 2, far: three fans in a row — move, hold, move.
9. **Feel test:** you should feel pulled *toward* the boss, not pushed to the far wall. Every
   hit should be explainable ("I strafed during the two-bolt fan"). Reaching melee should feel
   like the start of a second, shorter exam (the nova), not the reward itself. If the room
   just feels like noise, the fans are too wide or too frequent: say so at Gate B.

---

## 6. Task Breakdown  ·  _Planner_

Small, ordered, each independently committable.

| # | Task | Files likely touched | Notes |
|---|---|---|---|
| T1 | Remove the brain kind rule; replace its tests with acceptance tests for mixed kinds. | `src/core/enemies/enemy_data.gd`, the five test files in C6 | C6. AC1, AC10. No other behavior change. |
| T2 | `volley_angles_deg` on `EnemyAttackData` (field, snapshot key, latch copy); `max_volley_size` on `EnemyCombatTunables` and in `enemy_combat.tres`; validation. | `src/core/enemies/enemy_attack_data.gd`, `src/core/tunables/enemy_combat_tunables.gd`, `data/tunables/enemy_combat.tres`, `tests/core/enemies/` | C3, C7 (script default 16). AC9, AC11. |
| T3 | Volley launch in `EnemyLogic._launch_projectile()`; core tests for launch, hits, walls (through a test `move_bodies`), owner death, snapshots. | `src/core/enemies/enemy_logic.gd`, `tests/core/enemies/test_volleys.gd` | C4, C5, C8, C9. AC2–AC8 (incl. AC5b), AC12. |
| T4 | Hexer data: enemy, stage 2, eight attacks, path constants. Data test, brain-movement test, tick-rate test. | `data/enemies/`, `data/attacks/`, `src/autoload/tunables.gd`, `tests/core/enemies/test_hexer.gd` | C12, C10. AC13–AC15. The tick-rate test records serial and position of every live bolt at each shared contact instant. |
| T5 | `Enemy.get_aim_lines()` and drawing every line. | `src/entities/enemies/enemy.gd`, `tests/scenes/` | C11. AC16. |
| T6 | `f008_hexer.tscn`, built like `f007_warden.tscn`; scene tests `tests/scenes/f008_scene_test.gd` and `test_f008_*.gd` (real walls: one bolt of a volley stopped, blocked launch, reset, reload, restore). | `scenes/debug/`, `tests/scenes/` | AC7 (physics), AC16, AC17. |

---

## 7. Plan Review  ·  _Auditor_

<Each completed round starts with its machine line (format in AGENTS.md), then its findings.
Severity: 🔴 blocking · 🟡 should fix · 🔵 suggestion.>

<!-- review-round: 1 verdict: CHANGES_REQUESTED -->

**Date:** 2026-11-16 · **Review basis:** `main` at `1dd09c6`.

The goal and exclusions are clear, the options have specific trade-offs, and the data matches
the Hexer design. C6 explicitly supersedes the old brain-kind restriction; D-007/D-008 and
the shared boss behavior are otherwise preserved. Resolve the combat contract below before build.

### PR-1 · 🔴 blocking — Per-contact protection contradicts the design's lifetime guarantee

- **Location:** §3 rejected shared hit set; §4 C5; §5 AC5; `studio/design/combat.md:322–325`.
- **Problem:** The design says a volley "never hits one player twice", but C5/AC5 only
  guarantee one hit at a single contact. Independent, unmarked bolts can hit that player
  after the 0.6 s hurt i-frames expire. For example, launch the specified ring from the origin
  along +X with the Warrior at (1, 0). The 0° bolt hits about 0.10 s after launch. After its
  hitstop and 0.5-tile push, the player can walk to radius 2.6 on the 30° ray and hold. Around
  0.75 s, protection expires with the unspent 30° bolt only 0.4 tiles away, inside the combined
  0.6-tile radii. That is a second hit from the same volley under the chosen rules.
- **Why it matters:** This is an unflagged contradiction with the department design doc.
  The Builder cannot satisfy lifetime immunity while preserving the specified independent
  hit sets and adding no new hit rule.
- **Suggested fix:** Explicitly scope the design guarantee to a contact instant and add an
  AC confirming that a later bolt may hit after protection expires. If lifetime immunity is
  intended instead, revise §3 and the state/hit contracts explicitly before implementation.

> **Planner reply (Combat):** accepted — scoped to the contact instant. Lifetime immunity would
> need the rejected shared hit set, and the per-contact rule matches every other hitbox
> ("a skipped hurtbox is not marked; leaving matters"). Changed: design/combat.md volley line,
> §3 (shared-hit-set rejection), §4 C5 (no per-volley immunity), new §5 AC5b, §6 T3.

✔ resolved (round 2): the shared combat design and C5 now scope protection to a contact
instant; AC5b explicitly verifies a later hit after hurt i-frames expire. Independent
projectile identities and hit sets remain consistent with D-008.

### PR-2 · 🟡 should fix — Specify the new tunable's resource default

- **Location:** §4 C2/C7; §6 T2; `tests/core/enemies/test_enemy_data.gd:36–38,163–167`.
- **Problem:** C7 specifies 16 in `enemy_combat.tres`, but leaves the script default for
  `EnemyCombatTunables.max_volley_size` unstated. Existing tests construct this resource with
  `new()`, set only the telegraph fields, and expect validation to pass. An implicit int
  default of 0 would fail those tests, which C2 forbids editing.
- **Why it matters:** The Builder must guess a compatibility-relevant default or violate
  the unedited-tests requirement.
- **Suggested fix:** Specify a valid script default (for example, 16), as well as the
  authored `.tres` value, while retaining rejection of an explicitly assigned 0.

> **Planner reply (Combat):** accepted — changed §4 C7: script default 16, `.tres` 16,
> explicit 0 still rejected; §6 T2 notes it.

✔ resolved (round 2): C7 and T2 specify a script default of 16 as well as the authored
resource value, preserving existing `new()` callers while rejecting an explicit 0.

### PR-3 · 🟡 should fix — Include projectile positions in the tick-rate acceptance test

- **Location:** §4 C10; §5 AC13; §6 T4.
- **Problem:** C10 requires matching bolt positions at every contact across 30/60/120 ticks/s,
  but AC13 checks only launch instants, serials, hits and final HP. AC12 compares positions
  across snapshot replay, which does not cover the cross-rate requirement.
- **Why it matters:** A bolt that misses the player could drift between rates while all
  AC13 assertions still pass.
- **Suggested fix:** Extend AC13/T4 to record and compare each live bolt's serial and
  position at every shared contact instant, using a stated position tolerance.

> **Planner reply (Combat):** accepted — changed §4 C10 (tolerance 1e-6 tiles), §5 AC13 (same
> live-bolt set by serial and positions within 1e-6 tiles at every shared contact), §6 T4.

✔ resolved (round 2): C10, AC13 and T4 now require matching live-bolt serial sets and
positions within 1e-6 tiles at every shared contact instant across 30/60/120 ticks/s.

<!-- review-round: 2 verdict: APPROVE -->

**Date:** 2026-11-16 · **Review basis:** `HEAD` at `63bae00`.

All three previous findings are resolved above. No new findings.

The player-facing goal serves pillar 2, exclusions are explicit, and the alternatives have
specific rejection reasons. The Hexer data matches the combat design; C6 explicitly
supersedes the brain-kind restriction with Direction's confirmation in Q1. The launch,
wall-report, hit-order and snapshot contracts fit the existing shared interfaces and
D-007/D-008. Acceptance criteria and ordered tasks cover the required behavior, including
reload isolation, later hits, co-op targets and cross-rate projectile positions.

**Handoff:** leave `PLAN_REVIEW`, set `owner_now: Lucas` for Gate A.

---

## 8. Implementation Log  ·  _Builder_

**Started:** YYYY-MM-DD  ·  **Branch:** `feature/F-008-volleys-hexer`

### Progress
- [ ] T1
- [ ] T2
- [ ] T3
- [ ] T4
- [ ] T5
- [ ] T6

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
| Q1 | Combat | → Direction: C6 removes the brain kind rule set by F-005/C9 and F-007/C13 (a). It is needed here (Nova on a caster brain) and by F-009 (Debris on a brute brain). Confirm no other department relies on it. | no | **Direction (2026-11-16):** confirmed. Combat is the only department with enemies; nothing outside `EnemyData` reads the rule (checked on `main` at `39acab8`). Recorded in design/combat.md, rules shared by every boss. |
| Q2 | Combat | → Direction: the Hexer is designed and tested in an empty room. Cover and adds (CX9) will change how hard the fans are; re-tune the fan angles when the real boss room exists. | no | **Direction (2026-11-16):** accepted. The floor structure spec will carry a re-tune task for the Hexer's room (CX9). |
| Q3 | Combat | → Lucas: Fan B (±10°) straddles the player instead of filling Fan A's safe lanes, because follow-ups re-aim (§2). Read: Fan A = move, Fan B = hold or dash through. The design doc is updated to say so. Veto at Gate A if you want the old idea (it needs a new aim mode, §3). | no | |
| Q4 | Combat | → Art & Game Feel: look and sound of volley telegraphs (many aim lines at once, the ring) and of the nova. Placeholders ship here (CX5, CX8). | no | |
| Q5 | Combat | → Lucas: Hexer HP 320 and nova knockback 3.0 are starting values. Judge both at Gate B by feel. | no | |

---

## 11. Director Notes  ·  _Lucas_

<Overrides, priorities, gut calls. Everyone obeys these.>
