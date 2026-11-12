---
id: F-007
title: Boss base + floor 1 boss (Warden)
status: CODE_REVIEW      # DRAFT | PLAN_REVIEW | PLAN_CHANGES | APPROVED | IN_PROGRESS | CODE_REVIEW | CODE_CHANGES | DONE | PARKED
owner_now: Auditor     # who must act next: Planner | Auditor | Builder | Lucas
created: 2026-11-09
updated: 2026-11-12
depends_on: [F-003, F-004, F-005, F-006, D-005, D-007, D-008]
pillars: [2]
department: Combat
---

# F-007 — Boss base + floor 1 boss (Warden)

> **How to use this file.** This is the single source of truth for this feature.
> Every agent reads the WHOLE file before acting. Write only in the sections you own
> (see studio/README.md). Never delete another role's text — reply under it.

---

## 1. Goal  ·  _Planner_

**Player-facing outcome (one sentence):**
In a test room, the player fights the Warden: a two-stage boss whose attacks come in
sequences that must be dodged hit by hit and punished only at the real opening.

**Why now:** The three phase-1 enemies are DONE. Bosses are the other half of pillar 2 and
phase 1 needs three. This feature adds the two things every boss needs (stages, patterns) and
proves them with the simplest boss, which uses only melee sectors and lunges that already exist.

**Out of scope (explicitly):**
- Boss room door, floor gate, floor structure, town return and boss re-entry (D-006) → Direction.
- The floor 2 and floor 3 bosses (F-008, F-009) and several projectiles per attack.
- A new brain: the Warden uses the chaser brain unchanged.
- Loot, rewards, a victory screen, music, final art or VFX.
- Summoned enemies, enrage timers, any invulnerability.
- Changing any value or behavior of the chaser, caster or brute.

---

## 2. Context  ·  _Planner_

What the Builder needs to know that isn't obvious from the code:
- **Existing systems this touches (checked by Direction on `main` at `a799822`):**
  - `src/core/enemies/enemy_data.gd` (`EnemyData`): `id`, `brain` (`Brain { CHASER, CASTER, BRUTE }`,
    appended only), `max_hp: int`, `hurtbox_radius_tiles`, `knockback_scale`, `move_speed`,
    `aggro_radius_tiles`, `stop_distance_tiles`, `retreat_distance_tiles`, `attack_cooldown`,
    `attacks: Array[EnemyAttackData]`. `validate(step_rate, tunables)` checks the fields and calls
    `_attacks_errors()` (list not empty, no null, each `validate_enemy()`, and the brain kind rule
    `_attack_kind_errors()`). The speed rule is separate: `validate_against_class(class_data)`,
    called by `CombatRunner` at setup and on reload (`combat_runner.gd` ~173 and ~260).
  - `src/core/enemies/enemy_attack_data.gd` (`EnemyAttackData extends AttackData`): `aim_track_time`,
    `lunge_tiles`, projectile fields, `trigger_min_tiles`, `trigger_max_tiles`, `wall_stun_duration`;
    `validate_enemy()`, `ENEMY_SNAPSHOT_KEYS`, `to_dict()` / `from_snapshot()`. A running attack is
    snapshotted **by value**, never as a resource reference.
  - `src/core/enemies/enemy_logic.gd` (`EnemyLogic`): `State { IDLE, CHASE, WINDUP, ACTIVE, RECOVERY,
    KNOCKBACK, DEAD }`; `SNAPSHOT_KEYS`; `_is_free()` (IDLE/CHASE, not in hitstop), `_is_committed()`;
    `_decide()` asks the brain; `_start_attack(view, index)` latches `_data.attacks[index].duplicate()`
    (a **shallow** copy: its `follow_up` would still point at the pre-reload resource);
    `_finish_attack()` starts the cooldown from `_data.attack_cooldown`; `_advance_move()` walks at
    `_data.move_speed`. `setup()` **is** the debug reset (F-004/C15); `apply_data()` is the reload.
    **Naming:** `_phase_elapsed`, `_advance_phase()`, `_phase_time_left()`, `_cross_finished_phases()`
    already use *phase* for windup/active/recovery, as `GLOSSARY.md` does. Boss stages are therefore
    called **stages** everywhere in this feature.
  - `src/core/enemies/enemy_brain.gd`: `static pick_attack(data: EnemyData, distance)` reads
    `data.attacks`. It is called by the three brains and by `tests/core/enemies/test_attack_list.gd`
    with an `EnemyData`. Brains also read `data.aggro_radius_tiles`, `stop_distance_tiles`,
    `retreat_distance_tiles` (unchanged by stages).
  - `src/core/combat/combat_state.gd`: `get_hp() -> int`, `get_max_hp() -> int`.
  - `tests/core/enemies/test_brute_wall_stop.gd` checks a snapshot against
    `EnemyLogic.SNAPSHOT_KEYS.size()`, so appending keys keeps it green.
  - `src/entities/enemies/enemy.gd`: each enemy already draws a small HP bar (`get_hp_fraction()`)
    and its telegraph. There is **no** screen-space HUD bar yet; `src/ui/` has `debug_overlay` and
    `src/ui/debug/` (`combat_debug_draw`, `damage_numbers`, `motor_debug_overlay`).
  - Debug scenes are `scenes/debug/f00N_<name>.tscn` (F-004–F-006: walled room, `CombatRunner`
    last with `refill_player_on_died` on, R = reset, F5 = reload).
  - **Reload path (`src/world/combat_runner.gd`):** `reload_data()` loads the whole group, runs
    `_validation_errors()` (each candidate `EnemyData.validate()` + `validate_against_class()`),
    then a **live-state check** (`_sim.rate_change_errors(rate)`, which refuses a rate change a
    running hit would break), and only if every list is empty calls `_apply_reload()`, which ends
    in `Enemy.apply_reloaded_data()` → `EnemyLogic.apply_data()` (replaces `_data`). C19 adds a
    second live-state check in the same place. `restore_snapshot()` returns `false` when
    `_sim.from_dict()` refuses a snapshot.
  - **Projectiles (F-005, D-008):** an enemy owns its bolts in `_projectiles` (`ProjectileSet`).
    They advance on the sim clock in `step()` whatever the owner's state or hitstop, and
    `Combatant.get_live_hitboxes()` includes them. A bolt can outlive the attack that launched it
    (up to 10 / 6 s of flight vs 0.90 s of active + recovery after launch).
  - **Telegraph view:** `Enemy.get_body_color()` returns `open_color` for every `RECOVERY`
    (`enemy.gd` ~141); `get_debug_text()` shows the state name.
- A boss is **not a new system**. It is an `EnemyData` whose data uses two new, optional
  features. With both left empty, an enemy behaves exactly as before this feature.
- Terms used below (see `GLOSSARY.md`): free, planted, step start, contact instant, trigger
  band, attack instance, aim tracking / aim lock, lunge, wall stop.
- New terms:
  - **Stage:** one step of a boss fight, entered at an HP percent. Stage 0 is the `EnemyData` itself.
    (Not "stage": in code and `GLOSSARY.md`, *stage* already means windup / active / recovery.)
  - **Stage shift:** the planted pause when a stage is entered.
  - **Follow-up:** the attack that starts the instant another attack's recovery ends.
  - **Pattern:** an attack plus its chain of follow-ups.
  - **Gap:** the recovery of an attack that has a follow-up.
- Relevant prior decisions: D-007 (step grid), D-008 (wall stops, used by C12), D-005 (data-driven), D-002 (G6–G9).
  `design/combat.md` → *Bosses* and its *Rejected* list.
- Relevant prior features: F-003 (hit/hurt, snapshots), F-004 (enemy base, chaser brain),
  F-006 (attack list, trigger bands, wall stun, `end_step()`).

---

## 3. Options Considered  ·  _Planner_

> This section is what stops context loss. Be honest about trade-offs.
> The Builder MUST NOT implement anything listed under Rejected.

### ✅ Chosen: A boss is an enemy with stages and follow-ups, both as data
- **How it works:** `EnemyData` gets an ordered `stages` list (`EnemyStageData`: HP percent,
  shift duration, attack list, move speed, attack cooldown). `EnemyAttackData` gets an optional
  `follow_up`. `EnemyLogic` keeps a stage index and reads the current stage's values through
  getters. Attack choice stays F-006's: first attack in the current list whose band holds.
- **Why chosen:** Bosses inherit every enemy rule and test for free. Two small data fields give
  stages and sequences, which is what makes a pattern fight. Any enemy can use them later (elites).
- **Costs we're accepting:** A reused attack with a different follow-up needs its own `.tres`
  copy (the Warden has 8 attack files). With distance-only selection a player may find one
  distance that makes a boss repeat a single pattern.
- **Would revisit if:** In playtests the Warden is beaten by standing at one distance without
  reading anything, or copies of attack files start to drift apart by mistake.

### ❌ Rejected: A separate `BossLogic` class or boss scene type
- **How it would work:** Bosses get their own logic class with stages and scripted attacks.
- **Why rejected:** It would re-implement the step grid, planted rule, targeting, hitstop and
  snapshots, and every later enemy fix would have to be made twice.
- **Tempting because:** Bosses feel special, and a blank class looks faster than extending
  `EnemyLogic` carefully.

### ❌ Rejected: Scripted attack rotation (a fixed cycle that ignores distance)
- **How it would work:** The boss runs attack 1, 2, 3, 1, 2, 3… wherever the player stands.
- **Why rejected:** It needs a second selection rule and a counter outside the attack state,
  and the player can no longer read the next attack from position (F-006's rule).
- **Tempting because:** It's the classic boss script and guarantees variety.

### ❌ Rejected: A wrapper resource for patterns (`EnemyPatternData` holding a list of attacks)
- **How it would work:** Attack lists hold patterns; each pattern holds its band and its attacks.
- **Why rejected:** Trigger bands would move off `EnemyAttackData`, so the chaser, caster and
  brute data and F-006's tests would all change for a feature they don't use.
- **Tempting because:** No duplicated attack files; a cleaner model on paper.

### ❌ Rejected: The stage change interrupts the running attack
- **How it would work:** The instant HP crosses the line, the attack is cancelled and the shift starts.
- **Why rejected:** A hit would cancel a telegraphed attack, which is the flinch rejected in
  CQ10, and the player would learn to burst a threshold to escape a pattern.
- **Tempting because:** It's simpler (no pending state) and the change feels immediate.

### ❌ Rejected: Invulnerable stage shift
- **How it would work:** The boss can't be hit while it shifts.
- **Why rejected:** It adds an enemy invulnerability state (the design has none) and takes the
  player's opening away at the moment they earned it.
- **Tempting because:** Every boss in the genre does it, and it protects the animation.

### ❌ Rejected: A reload that removes an entered stage falls back or keeps the old stage
- **How it would work:** After F5 drops the stage the boss is in, it either returns to stage 0
  (or the deepest stage still listed), or keeps reading the pre-reload stage resource.
- **Why rejected:** Falling back breaks "stages only go forward" (C5) through a side door, and
  keeping old data means two versions of the boss live at once, which a snapshot can't name.
  C19 refuses such a reload instead, like a rate change a running hit would break.
- **Tempting because:** The reload "just works" and nothing is refused.

### ❌ Rejected: A stage shift removes or pauses the boss's projectiles in flight
- **How it would work:** Entering a stage clears (or freezes) bolts already launched.
- **Why rejected:** It changes F-005/D-008's projectile lifecycle (only death removes bolts) for
  one state, and a bolt the player is already dodging would vanish or hang, which is unreadable.
- **Tempting because:** It makes "no hitbox during the shift" literally true.

### ❌ Rejected: Calling boss stages "phases" in code and data
- **How it would work:** `EnemyPhaseData`, `phase_index`, `phase_changed`.
- **Why rejected:** `EnemyLogic` and `GLOSSARY.md` already use *phase* for windup / active /
  recovery (`_phase_elapsed`, `_advance_phase()`). Two meanings in one class is how bugs start.
- **Tempting because:** "boss phase" is the genre's word, and the design doc first used it.

### ❌ Rejected: Random or weighted choice between the boss's attacks
- **How it would work:** Roll among attacks whose band holds.
- **Why rejected:** Already rejected in `design/combat.md`: unreadable, and needs synced RNG in co-op.
- **Tempting because:** Makes the boss feel alive with no design work.

---

## 4. Constraints  ·  _Planner_

Hard rules for this feature. Violating any of these = automatic `CODE_CHANGES`.

| ID | Constraint | Reason |
|---|---|---|
| C1 | No boss class. Stages and follow-ups live in `EnemyLogic` / `EnemyData` / `EnemyAttackData`, in `src/core/`, with no node or visual dependency. | G6, §3 |
| C2 | An enemy with empty `stages` and no `follow_up` behaves exactly as before. No value, file or test of the chaser, caster, brute or dummy changes (Direction checked: no existing test asserts an exact field or key set that this feature breaks). | Must not break |
| C3 | **Stage data.** `EnemyStageData` (Resource): `enter_at_hp_percent: int`, `shift_duration: float`, `attacks: Array[EnemyAttackData]`, `move_speed: float`, `attack_cooldown: float`. `EnemyData.stages` lists stages 1..n in order. Stage 0 uses `EnemyData`'s own `attacks`, `move_speed`, `attack_cooldown`. Every other value (HP, radii, stop/retreat distance, knockback scale, brain) comes from `EnemyData` in all stages. | G9 |
| C4 | **Effective values.** `EnemyLogic` exposes `get_current_attacks()`, `get_current_move_speed()` and `get_current_attack_cooldown()` (stage 0 = the `EnemyData` fields). `_start_attack()`, `_advance_move()` and `_finish_attack()` read them. Add `EnemyBrain.pick_attack_in(attacks: Array[EnemyAttackData], distance)`; the three brains call it with `enemy.get_current_attacks()`. `pick_attack(data, distance)` stays and delegates with `data.attacks` (its existing callers and tests are unchanged). | One place decides the stage |
| C5 | **Stage condition.** Stage `i` holds when `hp * 100 <= max_hp * enter_at_hp_percent` (integers). The stage index never decreases, except on the debug reset (back to 0). | Exact, serializable |
| C6 | **When a stage is entered.** At a step start, after the view is sensed and before the brain decides: if the enemy is free and a deeper stage holds, it enters the **deepest** stage that holds (skipping any in between). Never mid-attack, mid-pattern, in knockback, in hitstop, or when dead. | No interrupt (CQ10) |
| C7 | **Stage shift.** On entering: the stage index changes, `stage_changed(stage_index: int)` (a new `EnemyLogic` signal) is emitted once, and the enemy is in *stage shift* (a new `State.STAGE_SHIFT`, **appended** after `DEAD` so saved state ints keep their meaning) for that stage's `shift_duration`. During it the enemy is not free, doesn't move, starts no attack (so it has **no attack sector** and **launches no projectile**), is planted (no knockback), and takes damage and hitstop normally; hitstop pauses the shift timer. **Projectiles already in flight are untouched** (F-005/D-008): they keep flying on the sim clock and can hit during the shift; only death removes them, as before. `shift_duration` 0 = no shift state: the enemy stays free and decides in that same step with the new values. | Free punish, not a pause |
| C8 | The attack cooldown is **not** reset, cleared or paused by a stage shift (hitstop still pauses it, as always). If it is still running after the change, it keeps its remaining time; the new `attack_cooldown` applies from the next time a cooldown starts. | Never erase a punish window |
| C9 | **Follow-up.** `EnemyAttackData.follow_up: EnemyAttackData` (null = none). When the recovery of an attack with a follow-up ends, the follow-up's windup starts at that exact instant (no time lost or added, as active follows windup). No free moment, no brain decision, no cooldown, and the follow-up's trigger band is not read. The enemy stays planted through the whole pattern. **Which follow-up:** read from the **current data by position**, never from the latched copy's `follow_up` reference: the pattern root is the attack index the brain chose in the current stage's list, and the n-th follow-up is reached by following `follow_up` n times from that root. Each follow-up latches at its own windup start, like any attack. A reload mid-pattern therefore applies from the next follow-up; if the new chain is shorter, the pattern ends there. If the root index no longer exists in the current stage's list (the list got shorter), there is no chain: the running attack finishes from its latched copy and the pattern ends with it. A root index that still exists but now holds a different attack is followed as it is now (position, not identity). | Patterns, F-004/C12 |
| C10 | **Follow-up target and aim.** At a follow-up's start the target is re-picked by the normal rule (nearest living player, ties by registration order) from the combat view sensed at the start of the current step. Aim then tracks and locks by the follow-up's own `aim_track_time`. If that view has no living player, the pattern ends there as if that recovery were the last one. | Co-op ready (D-002) |
| C11 | Each attack of a pattern is its own attack instance (may hit each hurtbox once). The attack cooldown starts when the pattern's last recovery (or wall stun) ends. | F-003 |
| C12 | A wall-stopped attack (F-006) drops its follow-up: its wall stun runs and the pattern ends. | Design: Bosses |
| C13 | **Validation**, at scene setup and on every data reload; bad data is rejected, never clamped. (a) Every attack reachable through `follow_up` passes all existing attack checks: `validate_enemy()` (telegraph floors, step rules, trigger band, wall stun rule) **and** the brain kind rule (`_attack_kind_errors()`). (b) A follow-up chain has no cycle. (c) `enter_at_hp_percent` is 1–99 and strictly decreasing along `stages`. (d) `shift_duration >= 0`. (e) Each stage's `attacks` passes the same checks as `EnemyData.attacks`. (f) Each stage's `move_speed` is below the class's: `validate_against_class()` checks every stage too, so `CombatRunner`'s setup and reload paths cover it unchanged. (g) No `stages` entry is null (`stages[i] must not be null`, the same form as `_attacks_errors()`). (h) Each stage's `move_speed >= 0` and `attack_cooldown >= 0`, the same bounds `EnemyData.validate()` sets on stage 0; exactly 0 passes. Every stage error names the list position and the stage resource (`stages[i] (<resource_path>): <rule>`); every follow-up error names the attack `id` and the rule. | Principle 1, G2 |
| C14 | **Serializable.** Snapshot/restore round-trips the stage index, the shift time left, and which attack of the pattern is running, identified by position (C9): new `SNAPSHOT_KEYS` `stage_index`, `stage_shift_left`, `pattern_root_index`, `pattern_depth`, appended. The running attack itself stays snapshotted by value (`attack`). A restore mid-pattern or mid-shift continues identically. A snapshot whose `stage_index` is greater than the current data's `stages.size()` is refused: `from_snapshot` changes nothing and the restore returns `false` (same rule as C19). `pattern_root_index` / `pattern_depth` that no longer resolve are not an error: they end the pattern as C9 says. | G7 |
| C15 | Same results at 30, 60 and 120 physics ticks/s for the stage entry step, the shift end and every follow-up start. | G1, D-007 |
| C16 | The Warden is data only: `data/enemies/warden.tres`, `data/enemies/warden_stage_2.tres`, eight files in `data/attacks/`, path constants in `src/autoload/tunables.gd` (G5). Brain = the chaser's. No Warden-specific code anywhere. | G9 |
| C17 | The boss bar (new, screen-space, placeholder: `src/ui/debug/boss_bar.gd`), the stage shift cue and the gap cue (C20) are presentation: they read getters and signals, and nothing in core reads them. Placeholder look. | G6 |
| C18 | No new input action, autoload or third-party dependency. | G4 |
| C19 | **Reload vs live stage.** New `EnemyLogic.reload_errors(candidate: EnemyData) -> PackedStringArray`: one error when the enemy's current stage index is greater than `candidate.stages.size()` (`"<id>: in stage <i>, but <path> lists only <n> stages"`). `CombatRunner.reload_data()` collects it for every enemy, next to `_sim.rate_change_errors()`, **before** `_apply_reload()`: any error refuses the whole group and nothing changes anywhere (player, dummies, every enemy, rate). `apply_data()` also returns `false` and changes nothing on that error, as a guard. An accepted reload keeps the stage index, the shift time left (a new `shift_duration` applies from the next shift), the latched running attack, the pattern position (resolved as C9 says) and the cooldown left (C8). A deeper stage that now holds after the reload is entered by the normal rule (C6). The debug reset (`setup()`) is not a reload: it goes to stage 0 with any data. | No regression (C5), atomic reload (F-003/C18) |
| C20 | **Gap vs punish cue.** New `EnemyLogic.has_pending_follow_up() -> bool`: true only in `RECOVERY` when the next attack of the pattern resolves by C9 from the current data (root index exists, chain long enough) and the attack was not wall-stopped. It reads only logic state and data, so it is right after a reload, a reset or a restore. `Enemy.get_body_color()` returns a new placeholder `gap_color` export when it is true, `open_color` otherwise; `get_debug_text()` appends ` (gap)` to the state. Unchanged for every enemy without follow-ups. Look → Art & Game Feel (§10 Q3). | Teach gap ≠ opening; G6 |

**Must not break:** all F-001–F-006 behavior and tests; the existing enemy debug scenes; the
debug reset; the speed check and data reload refusing bad data.

### Warden data (starting values — all tunables)

`data/enemies/warden.tres` — brain: chaser · `max_hp` 400 · `hurtbox_radius_tiles` 0.7 ·
`knockback_scale` 0 · `move_speed` 3.0 · `aggro_radius_tiles` 10.0 · `stop_distance_tiles` 1.2 ·
`retreat_distance_tiles` 0 · `attack_cooldown` 1.0 · `attacks` [warden_swipe_a, warden_dashing_cut] ·
`stages` [warden_stage_2]. Body collision radius = hurtbox radius.

`data/enemies/warden_stage_2.tres` — `enter_at_hp_percent` 50 · `shift_duration` 1.2 ·
`move_speed` 3.5 · `attack_cooldown` 0.7 · `attacks` [warden_p2_swipe_a, warden_p2_dashing_cut].

| File (`data/attacks/`) | windup | `aim_track_time` | active | recovery | damage | arc | range | knockback | `lunge_tiles` | trigger band | `follow_up` |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `warden_swipe_a` | 0.50 | 0.30 | 0.10 | 0.25 | 20 | 110° | 1.6 | 0.8 | 0.6 | 0–2.0 | `warden_swipe_b` |
| `warden_swipe_b` | 0.45 | 0.25 | 0.10 | 0.80 | 20 | 110° | 1.6 | 0.8 | 0.8 | 0–2.0 (unused) | — |
| `warden_dashing_cut` | 0.70 | 0.45 | 0.30 | 0.90 | 22 | 120° | 1.2 | 1.2 | 5.0 | 3.0–6.0 | — |
| `warden_p2_swipe_a` | 0.50 | 0.30 | 0.10 | 0.25 | 20 | 110° | 1.6 | 0.8 | 0.6 | 0–2.0 | `warden_p2_swipe_b` |
| `warden_p2_swipe_b` | 0.45 | 0.25 | 0.10 | 0.25 | 20 | 110° | 1.6 | 0.8 | 0.8 | 0–2.0 (unused) | `warden_overhead` |
| `warden_overhead` | 0.75 | 0.50 | 0.10 | 1.00 | 25 | 150° | 2.0 | 1.5 | 1.0 | 0–2.0 (unused) | — |
| `warden_p2_dashing_cut` | 0.70 | 0.45 | 0.30 | 0.30 | 22 | 120° | 1.2 | 1.2 | 5.0 | 3.0–6.0 | `warden_spin` |
| `warden_spin` | 0.45 | 0 | 0.10 | 0.90 | 20 | 360° | 1.8 | 1.2 | 0 | 0–2.0 (unused) | — |

Times in seconds, distances in tiles. Any attack field not listed here takes the value used in
`chaser_swipe.tres`. No Warden attack uses projectiles or wall stun.

---

## 5. Acceptance Criteria  ·  _Planner_

Testable, observable. The Auditor checks each one.

- [ ] AC1: Given the existing chaser, caster and brute data (no stages, no follow-ups), when
  the full test suite runs, then every pre-existing test passes **unedited**.
- [ ] AC2: Given an enemy with one stage at 50% with `shift_duration` 1.2 s, `max_hp` 400, a
  ready cooldown and a target inside a trigger band, when a player hit takes its HP from 201
  (or more) to 200 (or less) while it is free (the hit gives it hitstop `h` > 0), then at every step start inside
  that hitstop its stage index is still 0 and no signal fired; at the first step start after
  the hitstop ends its stage index is 1, `stage_changed(1)` was emitted exactly once, it is in
  `STAGE_SHIFT`, and it did not start an attack in that step. (Same with `h` = 0: entry at the
  next step start.)
- [ ] AC3: Given the same enemy in the windup of the first attack of a two-attack pattern,
  when a hit takes it to 200 HP or less, then both attacks run to the end unchanged and the
  stage is entered at the first step start after the last recovery ends.
- [ ] AC4: Given an enemy with stages at 60% and 30%, when one hit takes it from above 60% to
  below 30% while it is free, then it enters stage 2 directly, with one `stage_changed(2)` and
  one shift of stage 2's `shift_duration`.
- [ ] AC5: Given a **melee** enemy (no projectiles in flight) in a stage shift, when a player
  hit lands, then it takes the damage and the hitstop, is not knocked back, has no live hitbox,
  doesn't move, and the shift ends later by exactly the hitstop time.
- [ ] AC6: Given an enemy that entered a stage with 0.4 s of cooldown left and a 1.2 s shift,
  when the shift ends with a target inside a trigger band, then it starts that attack at the
  first step start after the shift. Given `shift_duration` 0 and 0.4 s of cooldown left, then it
  does not attack until those 0.4 s have passed.
- [ ] AC7: Given an attack with a follow-up, when its recovery ends, then the follow-up's
  windup starts at that instant, the enemy was never free in between, no cooldown started, and
  the follow-up started even with the target outside the follow-up's trigger band.
- [ ] AC8: Given two players and a pattern whose first attack targeted player A, when player B
  is the nearest living player in the view of the step where the follow-up starts, then the
  follow-up targets B and its aim tracks B until its `aim_track_time`, then stays locked.
- [ ] AC9: Given a pattern and no living player in the view when a follow-up would start, then
  the pattern ends, the cooldown starts, and no follow-up windup begins.
- [ ] AC10: Given a player standing inside both attacks of a two-attack pattern without
  dodging, then the player is hit by the first, protected from nothing but hurt i-frames, and
  the second attack can hit the same player (a separate attack instance) once those i-frames
  allow it.
- [ ] AC11: Given a wall-stun attack with a follow-up, when it is wall-stopped, then the stun
  runs, no follow-up starts, and the cooldown starts when the stun ends. When it is not
  wall-stopped, the follow-up starts normally.
- [ ] AC12: Data with any of these is rejected at setup and on reload, with a message naming
  the file and the rule: a follow-up cycle (A → B → A); a follow-up whose locked telegraph is
  under `min_locked_telegraph`; stage percents not strictly decreasing; a percent of 0 or 100;
  a negative `shift_duration`; a stage `move_speed` at or above the Warrior's; a stage
  `move_speed` of −1; a stage `attack_cooldown` of −0.1; a null entry in `stages` (the message
  names its position). A stage with `move_speed` 0, `attack_cooldown` 0 and `shift_duration` 0
  passes. Each case is checked both at setup and on reload.
- [ ] AC13: Given a snapshot taken (a) mid-gap of a pattern and (b) mid-shift, when it is
  restored and the same inputs are replayed, then the following states match the original run
  step by step (stage index, shift time left, running attack, target, aim).
- [ ] AC14: Given the same scripted fight against the Warden (fixed player commands, including
  crossing 50% HP mid-pattern), when it runs at 30, 60 and 120 physics ticks/s, then the stage
  entry instant, every follow-up start, every hit and the final HP values are identical.
- [ ] AC15: Given `warden.tres` loaded with the real tunables, then validation passes, and a
  test asserts: stage 1 at 1.5 tiles starts `warden_swipe_a`; at 4.5 tiles starts
  `warden_dashing_cut`; at 2.5 tiles starts nothing and walks in; stage 2 at 1.5 tiles runs
  swipe A → swipe B → overhead in order; stage 2 at 4.5 tiles runs dashing cut → spin.
- [ ] AC16: The debug reset returns the Warden to full HP, stage 0, no shift, no attack.
- [ ] AC17: `scenes/debug/f007_warden.tscn` runs on its own: a walled room of 20 × 12 tiles, one
  Warrior, one Warden, a boss bar showing HP with a mark at 50%, and a visible cue during the
  stage shift. No door, gate or floor logic.
- [ ] AC18: Given a **caster**-brain enemy with one stage and a bolt in flight when it enters
  the stage shift, then the bolt keeps moving at its speed during the shift and hits a player
  in its path (normal damage, knockback along its flight); the enemy launches no new bolt
  during the shift; the shift itself still has no sector hitbox.
- [ ] AC19: Given `shift_duration` 0, a ready cooldown and a target inside a band of stage 1's
  list, when the enemy becomes free with HP past the line, then in that same step start it
  emits `stage_changed(1)` once and starts the **stage 1** attack (not the stage 0 one).
- [ ] AC20: Reload vs live stage (C19), in a scene with the enemy plus a dummy:
  (a) the enemy is in stage 1 and the candidate data has `stages` = [] → `reload_data()`
  returns an error naming the enemy, the file and the stage; the player, dummy, every enemy's
  data, stage index, shift time left, running attack and the step rate are unchanged.
  (b) Same, mid-shift: refused, shift continues unchanged.
  (c) Mid-pattern, a reload that shortens the chain after the running attack → the running
  attack finishes as latched, no follow-up starts, the cooldown starts at its recovery end.
  (d) Mid-pattern, a reload that changes the follow-up's `windup` → the follow-up starts with
  the new windup. (e) Mid-pattern, a reload that removes the root index from the stage list →
  pattern ends after the running attack. (f) After (c) and (d), a snapshot taken right after
  the reload and restored replays identically. (g) A snapshot with `stage_index` 1 restored
  onto data with no stages returns `false` and changes nothing.
- [ ] AC21: Gap vs punish cue (C20): in `f007_warden.tscn`, in swipe A's recovery
  `has_pending_follow_up()` is true and the body shows `gap_color` with ` (gap)` in the debug
  text; in swipe B's recovery (stage 1) it is false and the body shows `open_color`. After a
  debug reset and after a snapshot restored mid-gap, the cue matches the restored state. A
  chaser's recovery still shows `open_color`.

**How to verify manually (Lucas, in `f007_warden.tscn`):**
1. Stand close: two swipes, then it's open. Dodge each swipe with its own dash; punish with a
   full chain after the second.
2. Hit it during the gap between the swipes: you land one hit, but the second swipe is coming.
   The body shows the gap colour there, and the "open" colour only after the last swipe.
3. Stand at 4–5 tiles: it winds up and cuts across the room. Walk sideways early or dash late;
   it's open after.
4. Stand at 2.5 tiles: it only walks toward you.
5. Take it to half HP in the middle of a combo: the combo finishes, then it stops for about a
   second (hit it freely), then stage 2.
6. Stage 2, close: after the second swipe a slow third one comes. Dash on the old rhythm and
   you get hit; wait and it's easy.
7. Stage 2, far: rush in after the cut and the spin hits you; wait for the spin, then punish.
8. **Feel test:** every time you're hit you can say which attack it was and what you did wrong.
   Stage 2 should feel like the same boss asking a harder question, not a new boss. The fight
   should end in 1–2 minutes when played well, and never feel like chipping at a wall.

---

## 6. Task Breakdown  ·  _Planner_

Small, ordered, each independently committable.

| # | Task | Files likely touched | Notes |
|---|---|---|---|
| T1 | Effective-value getters on `EnemyLogic` (attacks, move speed, cooldown) and `EnemyBrain.pick_attack_in()`; brains, `_start_attack()`, `_advance_move()` and `_finish_attack()` use them. No behavior change. | `src/core/enemies/` | C4. All existing tests stay green (AC1). |
| T2 | `follow_up` on `EnemyAttackData`; pattern logic in `EnemyLogic` (start, target re-pick, end without a living player, wall stop drops it, cooldown at pattern end, missing root ends it); `has_pending_follow_up()`. | `src/core/enemies/`, `tests/core/enemies/` | C9–C12, C20 (getter). AC7–AC11. |
| T3 | `EnemyStageData`, `EnemyData.stages`, stage index, entry rule, stage shift state (no attack, projectiles in flight untouched), `stage_changed`, debug reset. | `src/core/enemies/`, `tests/core/enemies/` | C3, C5–C8. AC2–AC6, AC16, AC18, AC19. |
| T4 | Validation for follow-up chains and stages (incl. null stages, speed/cooldown ≥ 0), at setup and reload; `reload_errors()` and its call in `CombatRunner.reload_data()` before `_apply_reload()`. | `src/core/enemies/`, `src/world/combat_runner.gd`, tests | C13, C19. AC12, AC20 (a)–(e). |
| T5 | Snapshot/restore of stage index, shift time left and pattern position; refuse an unresolvable stage index. | `src/core/enemies/`, tests | C14. AC13, AC20 (f)–(g). |
| T6 | Warden data: enemy, stage 2, eight attacks. Data test + tick-rate test. | `data/enemies/`, `data/attacks/`, tests | C16. AC14, AC15. |
| T7 | `f007_warden.tscn` (built like `f006_brute.tscn`): room, Warrior, Warden, `boss_bar.gd` with a 50% mark, stage shift cue, gap cue (`gap_color`, ` (gap)` label). Telegraphs otherwise use the existing enemy telegraph presentation. Scene tests `tests/scenes/test_f007_*.gd`. Glossary terms from the design doc. | `scenes/debug/`, `src/ui/debug/`, `src/entities/enemies/`, `tests/scenes/`, `studio/GLOSSARY.md` | C17, C20. AC17, AC21. |

---

## 7. Plan Review  ·  _Auditor_

<Each completed round starts with its machine line (format in AGENTS.md), then its findings.
Severity: 🔴 blocking · 🟡 should fix · 🔵 suggestion. Example finding:>

### PR-1 🔴 <title>
<What's wrong, where, why it matters, what you'd suggest.>
> **Planner reply:** <accepted / rejected + reason / changed §X>

<!-- review-round: 1 verdict: CHANGES_REQUESTED -->

**Round 1 — 2026-11-10 · Verdict: CHANGES_REQUESTED**

The goal is one clear, isolated fight serving pillar 2. Scope boundaries and rejection reasons
are specific, and the Warden's values and patterns match `studio/design/combat.md`. The ordered
tasks cover the main implementation and verification work. The remaining blockers concern
the generic boss base's reload and projectile contracts.

### PR-1 🔴 Removing an entered stage on reload has no legal state transition

**Location:** §4 C3–C5, C9, C13–C14; §5 AC12–AC13; §6 T3–T5.

**Problem:** C13 validates candidate resources in isolation, but does not define compatibility
with a live stage index. For example, after the Warden enters stage index 1, changing its
`stages` to `[]` passes the stated data rules. The effective-value getters can no longer resolve
index 1, while falling back to stage 0 would violate C5's rule that only reset can decrease
the index. This also occurs if a stage is removed during its shift or pattern. The existing
`EnemyLogic.apply_data()` simply replaces `_data` (`src/core/enemies/enemy_logic.gd:99`), and
`CombatRunner` validates the candidate group before applying it without checking stage state
(`src/world/combat_runner.gd:131`, `:247`). C9 defines shortened follow-up chains, but does not
resolve removal of the stage containing the root.

**Why it matters:** A valid F5 edit can leave the running boss with an invalid index. The
Builder must invent either a stage regression, retained old stage data, or a new reload
rejection rule; those choices affect combat state and atomic reload behavior.

**Suggested fix:** Define structural reload compatibility explicitly. A small policy is to
reject the whole candidate group before any mutation if an enemy's entered stage index no
longer exists; keep the current index, remaining shift time and latched attack on accepted
reloads. Specify what happens when the current pattern's root position disappears from a
retained stage's attack list. Add valid mid-pattern follow-up edits/shortening and incompatible
stage removal to the reload ACs/tasks, including unchanged state across the whole group on
rejection and snapshot continuation after an accepted edit.

> **Planner reply (Combat):** accepted, your policy. New C19: `EnemyLogic.reload_errors()`
> refuses a candidate whose `stages` no longer reach the live stage index; `CombatRunner`
> collects it next to `rate_change_errors()` before `_apply_reload()`, so the whole group is
> refused with nothing changed. Accepted reloads keep index, shift time left, latched attack,
> pattern position and cooldown. C9 now says a missing root index ends the pattern after the
> running attack. C14 refuses a snapshot whose stage index doesn't resolve. New §3 Rejected
> entry (fallback / keep old stage). New AC20 (a)–(g); §2 documents the reload path; T4/T5 updated.

✔ resolved (round 2): C19 specifies group-wide preflight and the direct-call guard; C9 defines
missing/replaced roots, and AC20 covers rejection, accepted edits and replay.

### PR-2 🔴 The shift's no-hitbox rule does not account for live projectiles

**Location:** §4 C3–C4, C7, C13; §5 AC5; `studio/design/combat.md:242`;
D-008 and F-005's projectile lifecycle.

**Problem:** Stages are available to every brain, including the caster, but C7 says a shifting
enemy has no hitbox and AC5 requires no live hitbox. A caster can finish recovery and become
free with its last bolt still flying: the shipped bolt travels for up to 10 / 6 seconds, while
active plus recovery uses only 0.90 seconds after launch. It can therefore enter a stage shift
while owning a live projectile. Existing `Combatant.get_live_hitboxes()` includes owned
projectiles (`src/core/combat/combatant.gd:49`), and those advance on the sim clock independently
of the owner's attack state (`src/core/enemies/enemy_logic.gd:142`). The plan does not say
whether a shift removes, pauses, suppresses, or preserves them.

**Why it matters:** The literal no-live-hitbox requirement conflicts with preserving the
inherited projectile behavior. It also makes the promised free punish ambiguous for the
caster-based boss that will reuse this base in F-008.

**Suggested fix:** Define the rule for already launched projectiles. If they keep F-005/D-008
behavior, narrow C7 and the shared design wording to no *own attack sector*, scope AC5's empty
hitbox assertion to a melee fixture, and add a caster-stage test showing a bolt continues
moving and hitting during the shift. If another outcome is intended, explicitly reconcile
that change with the shared design and projectile contract before implementation.

> **Planner reply (Combat):** accepted, first option. C7 now says the shift starts no attack
> (no attack sector, no new launch) and leaves projectiles in flight untouched (F-005/D-008).
> AC5 is scoped to a melee enemy; new AC18 covers a caster bolt flying and hitting during the
> shift. `design/combat.md` → *Stage shift* reworded to match. New §3 Rejected entry (shift
> clears/pauses bolts). §2 documents the projectile lifecycle.

✔ resolved (round 2): C7 and the shared combat design preserve bolts in flight; AC5 is melee-only
and AC18 verifies continued projectile movement and damage during the shift.

### PR-3 🟡 Stage validation omits the existing scalar bounds and null entries

**Location:** §4 C3/C13; §5 AC12; §6 T4.

**Problem:** C13 requires a stage's speed to be below the class's, but never requires
`move_speed >= 0` or `attack_cooldown >= 0`, and does not reject null entries in `stages`.
Those scalar lower bounds already apply to the corresponding stage-0 values
(`src/core/enemies/enemy_data.gd:39`, `:47`). A stage speed of -1 passes the stated upper bound;
a null stage has no percent to validate.

**Why it matters:** The new resource can accept values that the enemy base rejects, producing
backwards movement or an immediately ready cooldown, or failing while traversing a null stage.

**Suggested fix:** Require non-null stages and the same nonnegative speed/cooldown checks as
stage 0. Extend AC12 with negative values, exact zero passing, and a null stage at setup and
reload, with errors identifying the stage resource or list position.

> **Planner reply (Combat):** accepted. C13 (g) rejects null stages; (h) requires stage
> `move_speed >= 0` and `attack_cooldown >= 0` (0 passes), and fixes the error format
> `stages[i] (<path>): <rule>`. AC12 extended with −1 speed, −0.1 cooldown, a null stage, an
> all-zero stage that passes, at setup and on reload. T4 updated.

✔ resolved (round 2): C13(g)–(h), AC12 and T4 cover null stages, both scalar lower bounds,
zero passing and identifiable errors at setup and reload.

### PR-4 🟡 Reusing the existing recovery cue labels every gap as an opening

**Location:** §4 C17; §5 manual steps 1–2/6–8; §6 T7; §10 Q3.

**Problem:** T7 reuses the existing enemy telegraph presentation, which returns `open_color`
for every `RECOVERY` (`src/entities/enemies/enemy.gd:141`). Pattern gaps are also recoveries,
so an unchanged view advertises the 0.25-second gap with the same opening cue as the final
punish. Q3 acknowledges gap-versus-punish presentation, but C17/T7 require only the boss bar
and stage shift cue and do not assign a placeholder distinction.

**Why it matters:** The existing cue gives misleading feedback at precisely the distinction
this feature is meant to teach: when another attack is still coming.

**Suggested fix:** Require a minimal state-derived distinction between a gap and the final
punish, such as a debug label or separate tint. Define how presentation reads whether a
follow-up remains under C9's reload rules, and add scene coverage for both recoveries,
including reset/restore. Final art can remain with Art & Game Feel.

> **Planner reply (Combat):** accepted. New C20: `EnemyLogic.has_pending_follow_up()` (true in
> `RECOVERY` only when C9 resolves a next attack from the current data and no wall stop), so it
> follows reload, reset and restore. `Enemy` shows a placeholder `gap_color` and ` (gap)` in the
> debug text; enemies without follow-ups are unchanged. New AC21 (both recoveries, reset,
> restore, chaser unchanged); C17, T2, T7 and manual step 2 updated. Final look stays Q3.

✔ resolved (round 2): C20 defines a state-derived gap cue using current data, with reset,
restore and unchanged-chaser coverage in AC21 and implementation work in T2/T7.

### PR-5 🟡 AC2 needs a positive shift duration in its fixture

**Location:** §5 AC2 versus §4 C7.

**Problem:** AC2 gives the stage threshold and HP but no `shift_duration`, then requires no
attack decision in the entry step. C7 explicitly permits a same-step decision when that
duration is zero, which is not excluded by AC2's setup.

**Why it matters:** The Builder must supply an unstated fixture assumption to make the AC
agree with the zero-duration contract.

**Suggested fix:** Set AC2's shift duration explicitly to a positive value (for example,
1.2 seconds), and retain separate zero-duration coverage with a ready cooldown and a target
inside a trigger band to verify C7's same-step decision.

The HP-change fixture also needs to state whether hitstop is zero or already over. Ordinary
damage starts hitstop, so C6 enters the stage at the next *free* step start rather than
necessarily the next step start after that hit. Make AC2's timing agree with that condition.

> **Planner reply (Combat):** accepted. AC2 now sets `shift_duration` 1.2 s, a ready cooldown
> and a target in band, and says the stage is entered at the first step start after the hit's
> hitstop ends (index stays 0 during it; `h` = 0 → next step start). New AC19 covers
> `shift_duration` 0: same-step entry and a stage 1 attack decision.

✔ resolved (round 2): AC2 explicitly uses a positive shift and accounts for hitstop;
AC19 separately covers a zero-duration shift and same-step stage-1 attack selection.

<!-- review-round: 2 verdict: APPROVE_WITH_NOTES -->

**Round 2 — 2026-11-10 · Verdict: APPROVE_WITH_NOTES**

All five previous findings are resolved as noted above. The isolated Warden fight serves
pillar 2, keeps its exclusions explicit, considers concrete alternatives and matches the
department's current boss design. No blocking conflict with PROJECT.md or accepted D-###
decisions remains. The ACs cover the new state, follow-ups, reloads, presentation and tick-rate
independence. Two nonblocking clarifications would make the task and fixture contracts exact.

### PR-6 🟡 T5 understates the shared restore work needed for atomic rejection

**Location:** §4 C14; §5 AC20(g); §6 T5;
`src/core/combat/combat_sim.gd:101`, `src/core/enemies/enemy_logic.gd:276`,
`src/world/combat_runner.gd:120`.

**Problem:** C14 names `from_snapshot`, but the enemy's restore entry point is
`EnemyLogic.from_dict() -> void`. `CombatSim.from_dict()` sets its time, restores combatants in
order and returns `true` without receiving a per-enemy result. T5 lists only enemy code and
tests, although refusing an unresolvable stage through the public restore path also needs a
check in the shared sim before any restore mutation.

**Why it matters:** An enemy-local refusal can leave earlier players/dummies and sim time
restored, while the enemy keeps its old state and `CombatRunner.restore_snapshot()` reports
success. That fails AC20(g)'s explicit all-or-nothing outcome.

**Suggested fix:** Name the real restore entry point and include the shared sim/preflight work
in T5. Check every enemy's candidate stage before changing sim time or any combatant. Exercise
AC20(g) through `CombatRunner.restore_snapshot()` with the incompatible enemy registered after
a player and dummy; assert `false` and an unchanged whole-scene snapshot and body positions.
The required behavior is already clear; this note makes its implementation boundary explicit.

### PR-7 🟡 AC2's first-post-hitstop timing needs a no-knockback fixture

**Location:** §5 AC2 versus §4 C6;
`src/core/enemies/enemy_logic.gd:188`, `:367`.

**Problem:** AC2 specifies a generic enemy hit while free, then requires stage entry at the
first step start after hitstop. It does not set `knockback_scale` or the hit's knockback to
zero. A normal hit on a free enemy with positive knockback puts it in `KNOCKBACK`, which runs
after hitstop; C6 correctly forbids stage entry until that state ends.

**Why it matters:** A valid generic fixture can fail AC2 while obeying the stage-entry rule.
The Warden's zero scale supplies the intended behavior, but AC2 does not say to use it.

**Suggested fix:** Give AC2's enemy `knockback_scale = 0` (or use the Warden explicitly), or
state that entry occurs at the first free step start after both hitstop and knockback end.
Keep C6's prohibition on entry during knockback.

---

## 8. Implementation Log  ·  _Builder_

**Started:** 2026-11-12  ·  **Branch:** `feature/F-007-boss-base-warden`

### Progress
- [x] T1 — 49b8097 (effective-value getters, `pick_attack_in()`, brains use them)
- [x] T2 — 8ac45aa (`follow_up`, pattern logic, `has_pending_follow_up()`)
- [x] T3 — ba45113 (`EnemyStageData`, `stages`, entry rule, `STAGE_SHIFT`, `stage_changed`)
- [x] T4 — b326acd (stage/follow-up validation, `reload_errors()`, runner preflight)
- [x] T5 — fc11656 (snapshot keys, refusal of an unlisted stage before any restore)
- [x] T6 — 1b84be3 (Warden data: 2 enemy files + 8 attacks, data and tick-rate tests)
- [x] T7 — 424ca2f (`f007_warden.tscn`, `boss_bar.gd`, gap and shift cues, glossary)

### Deviations from plan
- DEV-1: **File cycles are caught before loading.** A `follow_up` cycle across `.tres` files
  never reaches validation: Godot 4.7.2's loader recurses forever and the process segfaults
  (checked headless). So `CombatRunner._load_group()` now walks each enemy file's
  dependencies first, with the new `Tunables.find_dependency_cycle()`
  (`ResourceLoader.get_dependencies()`, no load), and refuses the group with
  `<enemy path>: follow_up files form a cycle: a -> b -> a`. — **Why:** otherwise F5 after
  such an edit crashes the game instead of being refused (C13 b, AC12). — **Impact:** one more
  method on the `Tunables` autoload (not a new autoload, C18) and one more reload message. The
  in-memory cycle check in `EnemyData.validate()` is still the C13 rule (setup + reload). A
  scene whose *saved* data already has a file cycle still can't load at all; nothing in our
  code runs before Godot loads the scene.
- DEV-2: **Restore preflight in the shared sim (PR-6).** New virtual
  `Combatant.restore_errors(snapshot)`; `CombatSim.from_dict()` asks every combatant before it
  changes its time or any combatant, and returns `false` on any error. `EnemyLogic.from_dict()`
  (the real entry point; C14 says `from_snapshot`) also refuses and changes nothing on its own.
  — **Why:** T5 listed only enemy code, but an all-or-nothing restore (AC20 g) needs the sim.
  — **Impact:** `combatant.gd`, `combat_sim.gd`; no other combatant overrides it.

### Assumptions made (small, reversible)
- ASSUMPTION-1: Stage entry with the AI toggle off → still happens (and the shift runs). It is
  driven by HP, not a decision. — **Why:** C6 only names "free".
- ASSUMPTION-2: Target during a stage shift → kept as it was. — **Why:** C7 is silent; the
  next decision re-picks anyway.
- ASSUMPTION-3: `<id>` in C19's message → the enemy's combat id (`warden: in stage 1, but
  <path> lists only 0 stages`). — **Why:** names the live enemy; the path names the data.
- ASSUMPTION-4: A follow-up re-picks its target by distance from the enemy's step-start
  position, the same one the view was sensed with (C10), not from mid-step lunge progress.
- ASSUMPTION-5: `shift_duration` at or below `TIME_EPSILON` counts as 0 (no shift state).
- ASSUMPTION-6: AC14's scripted fight starts the real Warden at 205 HP (set through the
  snapshot path) so one sword hit crosses 50 % inside swipe A. The script then runs 6 s.
- ASSUMPTION-7: AC18 crosses the caster's line by setting HP mid-recovery (snapshot path), not
  with a player hit, so the bolt is still flying when the shift starts.
- ASSUMPTION-8: The boss bar numbers stages from 1 ("stage 1" = index 0), as the design doc does.
- ASSUMPTION-9: Follow-up errors are `<enemy path>: <attack id>: <rule>`; a stage error on an
  in-memory stage prints `stages[i] (built-in)` (empty `resource_path`).
- ASSUMPTION-10: Placeholder colours: `gap_color` pale blue, `shift_color` purple (Enemy and
  BossBar exports). Final look stays §10 Q3.

### Things the Auditor should look at closely
- `EnemyLogic._end_recovery()`: the follow-up starts inside `_cross_finished_phases()`'s loop,
  using `_step_view` (per-step only, set in every `sense()`, never snapshotted).
- `has_pending_follow_up()` reads data only (C20), so it is true in a gap even if no living
  player will be there for the follow-up (C10 then ends the pattern).
- `_is_planted()` (committed or `STAGE_SHIFT`) replaces `_is_committed()` in `apply_hit()` and
  `get_knockback_scale()`; `_is_committed()` still drives the phase loop.
- The latched copy's `follow_up` is set to `null` in `_latch()`, so nothing can follow a
  pre-reload chain (C9).
- DEV-1's dependency walk takes the last `::` part of each dependency string (plain path or
  `uid://…::Type::path`).
- AC2 uses `knockback_scale` 0 (PR-7). AC12 setup cases are in
  `tests/core/enemies/test_stage_validation.gd`, reload cases in
  `tests/scenes/test_f007_reload.gd`.
- `.claude/worktrees/agent-…` (an F-008 worktree of another session) is untracked in this
  checkout and was left alone.

### How to test
- `tools/test` (826 tests, all pass), `tools/lint`, `tools/check_core_purity`.
- F-007 tests: `tests/core/enemies/test_stage_getters.gd`, `test_patterns.gd`,
  `test_stages.gd`, `test_stage_validation.gd`, `test_boss_snapshot.gd`, `test_warden.gd`;
  `tests/scenes/test_f007_reload.gd`, `test_f007_restore.gd`, `test_f007_scene.gd`.
- Scene: open `scenes/debug/f007_warden.tscn` and run it (F6). R = reset, F5 = reload. Then
  §5 "How to verify manually".

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
| Q1 | Combat | → Direction: this spec was written from the docs, not from the code on `main`. Check the real names and shapes: `EnemyData` / `EnemyAttackData` fields, where enemy data validation lives, how the snapshot identifies the running attack, how the debug reset and the F-006 debug scene are built, and whether a HUD bar already exists to reuse. Replace every guess in §2, §4 and §6 with what exists. | yes (before the Auditor) | **Direction:** done. §2 rewritten from `main` at `a799822`; C4, C7, C9, C13, C14, C16, C17, AC1, AC17, T1, T7 made concrete; scene renamed `f007_warden.tscn`; boss *phases* renamed **stages** (collision with attack phases in code and GLOSSARY). |
| Q2 | Combat | → Direction: should the Warden's player death in `f007_warden.tscn` just use the existing debug reset? Assumed yes; D-006's town return is out of scope. | no | **Direction:** yes. Same as F-004–F-006 scenes: `refill_player_on_died` on, R resets. |
| Q3 | Combat | → Art & Game Feel: look and sound of the boss bar, the stage shift cue, and gap vs punish window (design/combat.md CX8). Placeholders ship in this feature. | no | |
| Q4 | Combat | → Lore: "Warden" is a working name (CX7). File names use it; renaming later is a data rename. | no | |
| Q5 | Combat | → Lucas: Warden HP 400 means about 10 full chains. Confirm at Gate B by feel, not here. | no | |


---

## 11. Director Notes  ·  _Lucas_

<Overrides, priorities, gut calls. Everyone obeys these.>
