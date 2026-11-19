---
id: F-014
title: Waves — reinforcements arrive in a room until its kill target is reached (Gate B playtest, third fix)
status: PLAN_REVIEW      # DRAFT | PLAN_REVIEW | PLAN_CHANGES | APPROVED | IN_PROGRESS | CODE_REVIEW | CODE_CHANGES | DONE | PARKED
owner_now: Auditor       # who must act next: Planner | Auditor | Builder | Lucas
created: 2026-11-19
updated: 2026-11-19
depends_on: [F-004, F-011, F-012, F-013, D-007, D-010, D-012, D-014, D-015]
pillars: [1, 2]
department: Floors       # studio/design/floors.md; the enemy's waiting state belongs to Combat (studio/design/combat.md)
---

# F-014 — Waves

> **How to use this file.** This is the single source of truth for this feature.
> Every agent reads the WHOLE file before acting. Write only in the sections you own
> (see studio/README.md). Never delete another role's text — reply under it.
>
> **This feature runs under D-015:** the lead (Claude Code) wrote §1–§6 and gates the work;
> up to two implementer sub-agents write code; only the lead commits and writes §8. Reviews
> are run by the lead with fresh reviewer sub-agents (D-014). The branch is stacked on
> `feature/F-013-camera-rooms-dash`, which Lucas has not played yet.

---

## 1. Goal  ·  _Planner_

**Player-facing outcome (one sentence):**
A combat room keeps sending enemies, a few at a time and each announced by a marker on the
floor, until the player has killed the room's kill target, which the HUD counts; then the exit
opens.

**Why now:** Lucas's Gate B playtest of F-011 and F-012 (2026-11-18; F-012 §10 Q11), his point
3, and the last of the six. F-013 made the rooms three to five times larger with the old
handful of enemies, so they are sparse until this lands.

**Out of scope (explicitly):**
- Boss rooms. They keep exactly one enemy, the boss (adds in boss rooms: FX2).
- New enemy types, and any change to an enemy's attacks, numbers or brain.
- Random waves. The order of arrivals is written in the room's data.
- Rewards, score, a timer, a combo counter (Items & Economy; later).
- Tuning the heal for the longer rooms. The numbers in §4/C12 are starting values (§10 Q1).
- Art for the marker. It is a placeholder shape (Art & Game Feel).
- Enemies entering through doors or from outside the room.

---

## 2. Context  ·  _Planner_

What the Builder needs to know that isn't obvious from the code:

- **Lucas's words.** Playtest: "the enimies I belive they can be spaming them on the room I
  dont know the right amount but enough for the space on the room (we can always change later
  if necessary) so they would appear until the player reach a certain amount that he killed,
  what you think? develop something around that idea". The lead proposed: a kill target per
  room shown on the HUD, a cap on enemies alive at once, a warning marker before each spawn, a
  fixed order at first, boss rooms unchanged. On 2026-11-19 he answered: "I can't play test
  right now so yes go ahead and build waves".
- **A room today.** `RoomData` holds an ASCII grid; a digit tile `1`–`9` places one enemy of
  `enemies[digit − 1]` there at the start (`get_spawns()`, row-major, ids `<EnemyData.id>_<n>`).
  `Room` (glue) builds one `Enemy` node per spawn and a `CombatRunner` whose `combatant_paths`
  are the player and then the enemies in spawn order. `Room.is_cleared()` is "no enemy alive",
  read from the logic on every call (F-011/C11). `FloorScene` opens the exit, heals and
  advances on it.
- **The sim's roster is fixed.** `CombatSim.register()` is called once per combatant when the
  runner is built; registration order orders every contact (F-003/C19); `from_dict()` refuses
  a snapshot with other ids or another order. Nothing is ever added or removed during a fight:
  a dead enemy stays registered in state `DEAD`.
- **What "not alive" already means.** `CombatView.capture()` copies `is_alive()` for every
  combatant, and brains and the hit resolver ignore the ones that are not; `EnemyLogic`'s
  `_is_protected()` makes a dead enemy unhittable; its `step()` loop stops for `DEAD`. The glue
  (`src/entities/enemies/enemy.gd`) hides a dead enemy's body and turns its collision off.
- **Aggro.** An enemy stands still until a player comes inside `aggro_radius_tiles`, or until
  it is hit (`apply_hit()` sets `_aggroed`). Once aggroed it stays so.
- **The step grid.** The sim advances in fixed steps of `1 / combat_step_rate` (1/120 s, D-007)
  whatever the frame rate, so anything decided once per step is tick-rate independent (G1).
- **Tests that kill.** The scene-test helpers `kill()` and `kill_all()` put lethal damage
  straight on an enemy's combat state and loop over `room().get_enemies()`; F-012's scripted
  runs clear rooms that way.
- **Screen and reach.** Half a screen is 20 × 11.25 tiles. Aggro radii are 6 (chaser), 8
  (caster), 7 (brute). `min_spawn_distance_tiles` is 4.
- Relevant prior decisions: D-007 (step grid), D-012 (rooms are data), D-015 (how this is built).
- Relevant prior features: F-004 (enemy base), F-011 (rooms), F-012 (HUD, `Game`), F-013 (room
  sizes, the shipped-room rules of `design/floors.md`).

---

## 3. Options Considered  ·  _Planner_

> This section is what stops context loss. Be honest about trade-offs.
> The Builder MUST NOT implement anything listed under Rejected.

### ✅ Chosen: reinforcements written in the room's data, held in reserve in the sim, sent by a core director to arrival points

- **How it works:**
  - *Data.* A room lists its reinforcements in arrival order (`reinforcements`, each an entry
    of the room's `enemies`) and marks **arrival points** in its grid with a new tile `S`. The
    **kill target** is the enemies placed at the start plus the reinforcements.
  - *Reserve.* Every reinforcement is built and registered with the sim when the room is
    built, in a new enemy state `WAITING`: not alive to anyone, cannot be hit, does nothing,
    is not drawn. The roster never changes during a fight, so contact order and snapshots work
    as they do today.
  - *Director.* A core object, `RoomWaves`, is stepped by the sim once per step. Once the
    fight has started it sends the next reinforcement whenever fewer than the room's
    `max_alive` enemies are alive or on their way: it picks an arrival point near the player
    but not on top of them, counts down a warning, then the enemy **arrives** there, already
    aggroed.
  - *Glue.* `Room` draws a marker on each arrival point while its warning counts down, and
    reports kills and the kill target; the HUD shows them. A room is cleared when nobody is
    alive and nobody is waiting.
- **Why chosen:** it is what Lucas approved, the rules live in core where a server can run
  them (G6), the content is data (G9), and the sim's fixed roster and its snapshot (G7) stay
  as they are.
- **Costs we're accepting:**
  - Every reinforcement costs a hidden `Enemy` node and a sim entry for the whole room.
  - Reinforcements come for the player at once, wherever they arrive: the "fight in pieces"
    opening (enemies outside aggro) is only for the enemies placed at the start.
  - The rooms get much longer and harder with the same heal per room (§10 Q1).
  - A new tile in the room format, and a new enemy state every view must treat as "not there".
  - **Adds to `design/floors.md`** (room format legend and rules, the encounter table) and to
    `design/combat.md` (the waiting state). F-013's shipped-room rules still hold.
- **Would revisit if:** rooms need more reinforcements than is sensible to pre-build (hundreds),
  or Lucas wants enemies to walk in through doors, or random waves.

### ❌ Rejected: create and register enemies in the sim while the fight runs
- **How it would work:** the director instantiates an enemy and calls `CombatSim.register()`.
- **Why rejected:** registration order orders every contact and a snapshot refuses a changed
  roster; both would need new rules, and a restore would have to create and delete nodes.
- **Tempting because:** no hidden nodes, and no limit on how many can come.

### ❌ Rejected: respawn at the digit tiles the room already has
- **How it would work:** each spawn tile sends another enemy of its type when one dies.
- **Why rejected:** in rooms up to 64 tiles wide the tiles are often far off screen, so the
  player would kill, walk back, kill; and an enemy could appear on a tile the player stands on.
- **Tempting because:** no new tile and no new data.

### ❌ Rejected: reinforcements arrive dormant, like the enemies placed at the start
- **How it would work:** an arrival stands still until the player comes inside its aggro.
- **Why rejected:** the player would have to search a room three screens large for the last
  enemy before the exit opens.
- **Tempting because:** it needs no "aggroed on arrival" rule.

### ❌ Rejected: random arrival order or random arrival points
- **How it would work:** a seeded generator picks the type and the point.
- **Why rejected:** the lead proposed a fixed order and Lucas approved it; a room that plays
  the same every time is also what the scripted tests and the snapshot need.
- **Tempting because:** more variety for free.

### ❌ Rejected: timed waves that arrive whether or not the last one is dead
- **How it would work:** wave n arrives t seconds after wave n − 1.
- **Why rejected:** a slow player would be buried under enemies the room was not sized for
  (pillar 2: skill beats stats, not speed). The cap on enemies alive is the pace.
- **Tempting because:** it is what "waves" usually means.

### ❌ Rejected: reinforcements in boss rooms
- **How it would work:** the boss room lists reinforcements too.
- **Why rejected:** out of scope (FX2 is open), and F-011/C16 says a boss room has exactly one enemy.
- **Tempting because:** the data format would allow it with no extra code.

---

## 4. Constraints  ·  _Planner_

Hard rules for this feature. Violating any of these = automatic `CODE_CHANGES`.

| ID | Constraint | Reason |
|---|---|---|
| C1 | **Room data.** `RoomData` gains `reinforcements: PackedInt32Array` (each value is 1-based, like a spawn digit: `enemies[value − 1]`; in arrival order; empty by default) and `max_alive: int` (0 by default, which means `FloorTunables.wave_max_alive`). The legend gains `S`, an **arrival point**: a walkable floor tile like `.` for every existing rule, the nav grid and the walls. | G9 |
| C2 | **Derived values on `RoomData`.** `get_kill_target()` is the number of spawns plus the number of reinforcements. `get_reinforcement_spawns() -> Array[RoomSpawn]`: one per reinforcement, in order, with ids that continue the numbering of `get_spawns()` (`<EnemyData.id>_<n>`, n counting on from the last spawn), `position_tiles` the first arrival point's centre, and a new `RoomSpawn.is_reinforcement` true. `get_spawns()` is unchanged. `get_arrival_points_tiles() -> Array[Vector2]`: the centres of the `S` tiles, row-major. `get_max_alive(rules)` resolves the 0. | One place for the numbers |
| C3 | **Validation**, each a named error like the existing ones (`waves: …`): a reinforcement value outside 1..`enemies.size()`; reinforcements in a boss room or a safe room; an `S` in a boss room or a safe room; reinforcements with fewer than `wave_min_arrival_points` `S` tiles; `S` tiles without reinforcements; an `S` nearer than `min_spawn_distance_tiles` to `P`; two `S` tiles nearer than `wave_spawn_gap_tiles` to each other, or an `S` that near a spawn tile; `max_alive` negative; a kill target above `max_kill_target`. A room with no reinforcements and no `S` validates exactly as before. `max_enemies_per_room` still counts the spawn tiles only. | F-011/C16 style: all errors, with the tile |
| C4 | **Tunables** in `FloorTunables` / `data/tunables/floors.tres`, each checked by `validate()`: `wave_max_alive` (4, ≥ 1), `wave_spawn_warning_duration` (0.8 s, ≥ 0), `wave_spawn_interval` (1.5 s, ≥ 0), `wave_min_spawn_distance_tiles` (6.0, ≥ 0), `wave_spawn_gap_tiles` (1.5, ≥ 0), `wave_min_arrival_points` (2, ≥ 1), `max_kill_target` (30, ≥ 1). No wave number is hardcoded. | G2 |
| C5 | **Waiting.** `EnemyLogic.State.WAITING` is appended after `STAGE_SHIFT`. `hold_in_reserve()` (valid right after `setup()`) puts the enemy in it. While waiting: `is_alive()` is false, it cannot be hit, it senses nothing, decides nothing, moves nothing, has no hitbox and launches nothing; `is_waiting()` is true. `arrive(position_tiles)` (valid only while waiting) puts it at that position in state `IDLE`, aggroed, with full HP, and emits a new signal `arrived`; it senses for the first time at the next step start. The state is part of the snapshot. A waiting enemy that is killed anyway (only a test can do that, by putting damage straight on its combat state) is `DEAD` and counts as a kill. `setup()` (the debug reset) leaves an enemy not waiting; `Room` rebuilds a room instead of resetting it. | The sim's roster stays fixed |
| C6 | **Director.** `RoomWaves` (core, `RefCounted`, `src/core/floors/room_waves.gd`) holds the room's enemies in registration order (the ones placed at the start, then the reserve in arrival order), the arrival points, the resolved `max_alive` and the rules. `CombatSim.set_waves()` attaches it; the sim calls `step(duration, view)` once per step, after every combatant has stepped and before the step's contacts. With no director attached the sim behaves exactly as before. | G6; D-007 |
| C7 | **Director rules**, per step, in this order. (1) Every pending arrival's time goes down by the step; one that reaches 0 arrives (`arrive()` on its enemy, at its point). (2) The fight **starts** the first time any of the room's enemies is aggroed or dead; it never un-starts. (3) The time since the last arrival was started goes up by the step. (4) While the fight has started, a reserve enemy is left, a living player exists, the enemies alive plus the pending arrivals are fewer than `max_alive`, and at least `wave_spawn_interval` has passed since the last arrival was started: choose a point (C8); if there is none, stop for this step; otherwise the next reserve enemy becomes a pending arrival at that point with `wave_spawn_warning_duration` to go, and the time since the last start is 0. | The pace is the cap, not a clock |
| C8 | **Choosing a point.** Candidates are the arrival points with no pending arrival on them and no living enemy within `wave_spawn_gap_tiles`. A point's distance is to the nearest living player. Among candidates at least `wave_min_spawn_distance_tiles` away, the nearest wins; if none is that far, the farthest candidate wins; ties go to the first in row-major order. No candidate: no arrival this step. | Near the fight, never on the player |
| C9 | **Counts.** `RoomWaves.get_kill_target()` is the number of the room's enemies; `get_kill_count()` is how many of them are neither alive nor waiting. Both are computed from the enemies on every call, never stored. `get_pending()` lists the pending arrivals (point, time left, total warning, enemy id) for the glue to draw. `has_started()`. | F-011/C11: nothing that can go stale |
| C10 | **Snapshot.** With a director attached, `CombatSim.to_dict()` carries a `waves` entry (started, the index of the next reserve enemy, the time since the last start, the pending arrivals) and `from_dict()` refuses a snapshot without it or with values out of range, before anything changes. Without a director the snapshot is exactly today's. A room restored in the middle of a warning continues it to the same instant. | G7 |
| C11 | **Glue.** `Room` builds the reserve enemies after the placed ones (hidden, no collision, waiting), lists all of them in the runner's `combatant_paths` (player, placed enemies in spawn order, reserve in arrival order), and attaches a `RoomWaves` only when the room has reinforcements. `Room.get_enemies()` returns every enemy, the reserve included; `get_reserve_enemies()` only those. `is_cleared()` is "no enemy alive and none waiting". `get_kill_count()` and `get_kill_target()` work in every room (a room without waves: its dead enemies and its enemy count). The `Enemy` node treats `WAITING` as not there (no body collision, nothing drawn, no health bar or label) and on `arrived` puts its body on the logic's position and appears. | Views follow the logic |
| C12 | **Markers.** `Room` draws one marker per pending arrival at its point, from `RoomWaves.get_pending()`, read every frame: a ring of the arriving enemy's body radius that fills as the warning runs out. Colours and line width are exports on the marker node (placeholder, → Art & Game Feel). Presentation only: no collision, nothing in core reads it. | Pillar 2: readable; G6 |
| C13 | **HUD.** In a combat room of a floor the HUD shows `Kills <count> / <target>` under the location text; in the town and in a boss room it shows nothing there. `Game` feeds it from the shown room every physics frame; no rule moves into `Game` or the HUD. | Lucas approved "shown on the HUD" |
| C14 | **Shipped rooms.** The 12 combat rooms get arrival points, reinforcements and `max_alive` as the table below this one gives; reinforcements use only enemy types the room already lists. Each room has at least 4 arrival points, spread so that their bounding box covers at least half the room's width and half its height, each at least 2 tiles from any wall tile. The grids of F-013 do not change otherwise (an `S` replaces a `.`), and every F-013 shipped-room rule still holds. | The lead's starting values (§10 Q1) |
| C15 | **Nothing changes where there are no waves.** A room without reinforcements (every fixture, every boss room, the town) behaves exactly as before, and its sim snapshot is byte-for-byte what it was. | The old suite is the proof |
| C16 | **Pre-existing tests** change only where they assume that every enemy of a **shipped combat room** is present and acting from the start, or pin a shipped value this spec changes (a grid's tiles where an `S` now stands, the shipped `floors.tres` values). Each change is listed in §8 with its reason. Tests on fixtures do not change. `kill_all()` keeps clearing a room because `get_enemies()` includes the reserve (C5, C11). | As F-013/C16 |
| C17 | No new third-party dependency, no new autoload, no new input action. Core stays pure. | G4, G6 |

**Wave table for C14.** "Placed" is what the room has today and keeps. Reinforcements are in
arrival order; ch = chaser, ca = caster, br = brute.

| Room | Placed | Reinforcements | Kill target | `max_alive` |
|---|---|---|---|---|
| 1-1 | 2 ch | ch, ch, ch, ch | 6 | 2 |
| 1-2 | 3 ch | ch, ch, ch, ch, ch | 8 | 3 |
| 1-3 | 4 ch | ch, ch, ch, ch, ch, ch | 10 | 4 |
| 2-1 | 2 ch, 1 ca | ch, ch, ca, ch, ca | 8 | 3 |
| 2-2 | 2 ch, 2 ca | ch, ch, ca, ch, ca, ch | 10 | 4 |
| 2-3 | 1 ch, 3 ca | ch, ch, ca, ch, ch, ca | 10 | 4 |
| 2-4 | 3 ch, 2 ca | ch, ca, ch, ch, ca, ch, ch | 12 | 5 |
| 3-1 | 1 br | br, br | 3 | 1 |
| 3-2 | 1 br, 2 ch | ch, ch, br, ch, ch | 8 | 3 |
| 3-3 | 1 br, 2 ca | ca, br, ca, ca | 7 | 3 |
| 3-4 | 2 br | br, br | 4 | 2 |
| 3-5 | 1 br, 2 ch, 2 ca | ch, ca, ch, br, ch, ca, ch | 12 | 5 |

**Must not break:** every F-011, F-012 and F-013 behaviour: room clear opening the exit, the
heal and its message, death returning to town, the debug keys N and R (a rebuilt room starts
its waves again), the camera, the routes enemies take, snapshots, tick-rate independence; the
debug scenes; the boss fights.

---

## 5. Acceptance Criteria  ·  _Planner_

Testable, observable. The Auditor checks each one.

**Data**
- [ ] AC1: A room with reinforcements `[1, 2, 1]` on a grid with two spawns reports a kill target of 5, three reinforcement spawns of the right enemies with ids numbered on from the spawns', and its `S` tiles as arrival points in row-major order. `get_spawns()` returns what it returned before.
- [ ] AC2: Each rule of C3 is refused with its own error naming the tile or value, alone and together with others; a room with no reinforcements and no `S` gets no new error.
- [ ] AC3: The seven tunables of C4 exist with their shipped values, and `FloorTunables.validate()` refuses each bad value.

**Waiting and arriving**
- [ ] AC4: A waiting enemy is not alive in a `CombatView`, is not chosen as a target, is not hit by a sword arc that covers its position, does not aggro on a player standing on it, does not move or act for 5 s of sim time, and has no hitbox or projectile.
- [ ] AC5: `arrive()` puts it at the given position, `IDLE`, aggroed and at full HP, and emits `arrived` once; from the next step on it chases the player from any distance. `arrive()` on an enemy that is not waiting changes nothing and reports an error.
- [ ] AC6: A snapshot of a sim with a waiting enemy restores it waiting; one taken after it arrived restores it arrived.

**Director**
- [ ] AC7: Nothing arrives before the fight starts, however long the player waits outside every aggro radius. The fight starts in the step an enemy is first aggroed (by range or by a hit) or dies.
- [ ] AC8: With `max_alive` 2, two placed enemies and three in reserve: while both placed enemies live nothing arrives; when one dies a warning starts within one step (if the interval has passed) and the reinforcement arrives exactly `wave_spawn_warning_duration` later; at no step are more than 2 enemies alive or on their way.
- [ ] AC9: With `max_alive` 3 and one placed enemy, the reserve's warnings start at least `wave_spawn_interval` apart, in the order of `reinforcements`.
- [ ] AC10: The point chosen is the one C8 names, in each of its cases: the nearest far-enough point; the farthest when none is far enough; row-major on a tie; never a point with a pending arrival or a living enemy within the gap; no arrival when no point qualifies, and the arrival starts in the first later step in which one does.
- [ ] AC11: With no living player nothing new starts; pending arrivals still arrive.
- [ ] AC12: Kill count and kill target follow C9 through a whole room: 0 of n at the start, +1 at the step an enemy dies, n of n when the last dies, and `Room.is_cleared()` is true exactly then.
- [ ] AC13: A scripted room run gives the same arrival times, points and final positions at 30, 60 and 120 ticks per second.
- [ ] AC14: A snapshot taken in the middle of a warning, restored into a freshly built room, continues to the same arrival instant, point and kill count as the original; a snapshot without the `waves` entry is refused by a sim that has a director, with nothing changed.

**Room, markers, HUD**
- [ ] AC15: In a `Room` with reinforcements the reserve enemies exist, are registered after the placed ones in arrival order, are invisible and have no collision; a body walks through the place a waiting enemy's node stands.
- [ ] AC16: While a warning runs, one marker is drawn at its point and its fill follows the time left; it is gone in the frame after the arrival; with two pending arrivals there are two.
- [ ] AC17: On arrival the enemy's node is on the arrival point, visible, with collision, and it reaches attack range of a player standing 10 tiles away behind a pillar.
- [ ] AC18: The exit of a room with reinforcements stays locked after the placed enemies are dead and opens in the tick the kill target is reached; the room-clear heal and its `+N HP` message come then, once.
- [ ] AC19: The debug keys N and R, a death and a return from the town each give a room whose waves start from the beginning.
- [ ] AC20: The HUD shows `Kills 0 / n` on entering a combat room, counts up with each kill, shows nothing in the town and in a boss room, and follows a room change in the same tick as the location text.

**Shipped rooms**
- [ ] AC21: Every shipped combat room matches the wave table (reinforcement types in order, kill target, `max_alive`) and C14's arrival-point rules; the shipped tower validates; F-013's shipped-room tests pass on the new grids.
- [ ] AC22: In every shipped combat room, played by a script that kills each enemy as soon as it is alive, every reinforcement arrives and the room is cleared at its kill target; from every arrival point the nav grid gives a direction toward `P`.
- [ ] AC23: F-012's scripted runs of floors 1 to 3 pass.

**Whole feature**
- [ ] AC24: A room without reinforcements has a sim snapshot with exactly today's keys, and F-011's, F-012's and F-013's tests on fixtures pass unchanged.
- [ ] AC25: `tools/test` passes; `gdlint` and `gdformat --check` are clean; `tools/check_core_purity` passes; `scenes/main.tscn` starts headless with no error.

**How to verify manually:** Enter floor 1. The HUD says `Kills 0 / 6`. Walk at the two
chasers and kill one: a ring appears on the floor somewhere near you and fills, and a chaser
appears in it and comes for you. The count goes up with each kill; never more than two are
alive in that room. At 6 the exit opens and `+30 HP` shows. Later rooms send more at once.
The boss rooms are as they were.

---

## 6. Task Breakdown  ·  _Planner_

Small, ordered, each independently committable. "A" and "B" are the two implementers; their
file lists never overlap while both work.

| # | Task | Files likely touched | Notes |
|---|---|---|---|
| T1 | Room data and tunables: C1–C4, AC1–AC3. | `src/core/floors/room_data.gd`, `src/core/floors/room_spawn.gd`, `src/core/tunables/floor_tunables.gd`, `data/tunables/floors.tres`, `tests/core/floors/test_f014_wave_data.gd`, `tests/core/floors/wave_fixtures.gd`, `tests/core/floors/test_floor_tunables.gd` (the shipped-values test gains the new values) | A |
| T2 | The waiting state: C5, AC4–AC6, and the `Enemy` node's part of C11. | `src/core/enemies/enemy_logic.gd`, `src/entities/enemies/enemy.gd`, `tests/core/enemies/test_f014_waiting.gd`, `tests/entities/test_f014_enemy_waiting.gd` | B, in parallel with T1 |
| T3 | The director and the sim hook: C6–C10, AC7–AC14 in core (on fixture rooms, with bodies moved by the logic). | `src/core/floors/room_waves.gd`, `src/core/combat/combat_sim.gd`, `tests/core/floors/test_f014_room_waves.gd`, `tests/core/combat/test_f014_sim_waves.gd` | A, after T1 and T2 are committed |
| T4 | The room: reserve enemies, the director attached, `is_cleared()`, the counts, the markers; C11, C12, AC12 (room part), AC15–AC19. | `src/world/floors/room.gd`, `src/world/floors/wave_markers.gd`, `tests/scenes/test_f014_room.gd` | B, after T3 |
| T5 | The HUD line and `Game` feeding it: C13, AC20. | `src/ui/hud/hud.gd`, `src/ui/hud/hud.tscn`, `src/world/game.gd`, `tests/ui/test_f014_hud.gd`, `tests/scenes/test_f014_game.gd` | A, after T4 |
| T6 | The shipped rooms: C14, AC21–AC23, and the pre-existing tests C16 allows. | `data/floors/floor_*/room_*.tres`, `tests/core/floors/test_shipped_floors.gd`, `tests/scenes/test_f011_shipped_floors.gd`, other scene tests only where C16 applies | B, after T4, in parallel with T5. The lead looks at every grid before the pins are committed. |
| T7 | Design docs and glossary. | `studio/design/floors.md`, `studio/design/combat.md`, `studio/GLOSSARY.md` | Lead, as Planner |
| T8 | Final gate: full suite, lint, format, purity, headless boot; a rendered look at a room with a warning marker and the HUD count; frame cost of the largest room with its reserve. | — | Lead |

---

## 7. Plan Review  ·  _Auditor_

---

## 8. Implementation Log  ·  _Builder_

**Started:** —  ·  **Branch:** `feature/F-014-waves` (cut from `feature/F-013-camera-rooms-dash`, D-015)

### Progress
- [ ] T1
- [ ] T2
- [ ] T3
- [ ] T4
- [ ] T5
- [ ] T6
- [ ] T7
- [ ] T8

### Deviations from plan

### Assumptions made (small, reversible)

### Things the Auditor should look at closely

### How to test

---

## 9. Code Review  ·  _Auditor_

---

## 10. Open Questions  ·  _Anyone (append)_

| # | Raised by | Question | Blocking? | Answer (Lucas/Planner) |
|---|---|---|---|---|
| Q1 | Lead | → Lucas, at Gate B: the starting values. Kill targets and how many are alive at once per room (the wave table), the warning (0.8 s), the pause between arrivals (1.5 s), and whether the heal (30 % per cleared room) still fits rooms with two to four times the enemies. All are data. | no | |
| Q2 | Lead | → Lucas, at Gate B: three things the lead added to what you approved. Reinforcements arrive at marked points near you (never closer than 6 tiles), they come for you at once, and they only start once the fight has (the first enemy noticing you or dying). Right, or change? | no | |
| Q3 | Lead | → Lucas, at Gate B: room 3-1 sends its three brutes one at a time and 3-4 keeps two alive. Is one brute after another the lesson you want there? | no | |

---

## 11. Director Notes  ·  _Lucas_

