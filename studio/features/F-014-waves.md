---
id: F-014
title: Waves — reinforcements arrive in a room until its kill target is reached (Gate B playtest, third fix)
status: CODE_REVIEW      # DRAFT | PLAN_REVIEW | PLAN_CHANGES | APPROVED | IN_PROGRESS | CODE_REVIEW | CODE_CHANGES | DONE | PARKED
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
  combatant, and the brains ignore the ones that are not. The hit resolver does not read
  `is_alive()`: a dead enemy is unhittable because `can_be_hit()` asks `_is_protected()`.
  `EnemyLogic.step()`'s loop stops for `DEAD`. The glue (`src/entities/enemies/enemy.gd`)
  turns a dead enemy's collision off but still draws it, in `dead_color`, with its bar and
  label. `Room` always adds a `CombatDebugDraw`, which draws a ring for every registered
  combatant's hurtbox, in the game too.
- **Aggro.** An enemy stands still until a player comes inside `aggro_radius_tiles`, or until
  it is hit (`apply_hit()` sets `_aggroed`). Once aggroed it stays so, and no brain has a
  leash: an aggroed enemy walks to the player from any distance. F-013 placed the enemies so
  that walking up to one wakes only that one (room 1-3's pairs wake two).
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
    `max_engaged` enemies are **engaged** (alive and aggroed) or on their way: it picks an
    arrival point near the player but not on top of them, counts down a warning, then the
    enemy **arrives** there, already aggroed. Enemies placed at the start that have not
    noticed the player do not count, so the cap is "how many are on you at once".
  - *Release.* The reserve is not spent at the first fight: it is **released in shares**,
    one share each time another placed enemy notices the player (or dies). The reserve is
    split as evenly as it goes over the placed enemies, so every part of the room the
    player walks into brings its own reinforcements.
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
  - In a room with waves a dead enemy's node disappears at once (up to 12 corpses with bars
    and labels would pile up where the fight is). A death effect is Art & Game Feel's.
  - Walking on can wake placed enemies on top of a full cap: the cap limits arrivals, not
    how many the player chooses to pull.
  - **Adds to `design/floors.md`** (room format legend and rules, the encounter table) and to
    `design/combat.md` (the waiting state). F-013's shipped-room rules still hold.
- **Would revisit if:** rooms need more reinforcements than is sensible to pre-build (hundreds),
  or Lucas wants enemies to walk in through doors, or random waves.

### ❌ Rejected: create and register enemies in the sim while the fight runs
- **How it would work:** the director instantiates an enemy and calls `CombatSim.register()`.
- **Why rejected:** registration order orders every contact and a snapshot refuses a changed
  roster; both would need new rules, and a restore would have to create and delete nodes.
- **Tempting because:** no hidden nodes, and no limit on how many can come.

### ❌ Rejected: reuse dead enemies as the reinforcements
- **How it would work:** a fixed roster of `max_engaged` slots; a dead enemy is set up again
  with the next type and sent back in.
- **Why rejected:** `design/combat.md` says an enemy dies once and is then inert; a slot
  would change data in mid-fight, and the kill count would have to be stored instead of
  read from the enemies (C9).
- **Tempting because:** no hidden nodes and no limit on the kill target.

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

### ❌ Rejected: a cap that counts every living enemy, awake or not
- **How it would work:** a reinforcement comes only while fewer than the cap are alive in the
  whole room.
- **Why rejected:** the placed enemies mostly sleep until the player walks up to them, so the
  reserve would come one enemy at a time (plan review PR-1, measured in 11 of 12 rooms).
- **Tempting because:** "alive" needs no new notion.

### ❌ Rejected: the whole reserve is free as soon as the fight starts
- **How it would work:** the director sends reinforcements until none is left, wherever the
  player first fights.
- **Why rejected:** the reserve would be gone 4 to 16 s into the first fight, and the other
  two or three screens of the room would hold only the sleeping placed enemies, as sparse
  as today (plan review PR-17, measured in every room).
- **Tempting because:** it needs no release rule.

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
| C1 | **Room data.** `RoomData` gains `reinforcements: PackedInt32Array` (each value is 1-based, like a spawn digit: `enemies[value − 1]`; in arrival order; empty by default) and `max_engaged: int` (0 by default, which means `FloorTunables.wave_max_engaged`). The legend gains `S`, an **arrival point**: a walkable floor tile like `.` for every existing rule, the nav grid and the walls. | G9 |
| C2 | **Derived values on `RoomData`.** `get_kill_target()` is the number of spawns plus the number of reinforcements. `get_reinforcement_spawns() -> Array[RoomSpawn]`: one per reinforcement, in order, with ids that continue the numbering of `get_spawns()` (`<EnemyData.id>_<n>`, n counting on from the last spawn), `position_tiles` the first arrival point's centre, and a new `RoomSpawn.is_reinforcement` true. `get_spawns()` is unchanged. `get_arrival_points_tiles() -> Array[Vector2]`: the centres of the `S` tiles, row-major. `get_max_engaged(rules)` resolves the 0. | One place for the numbers |
| C3 | **Validation**, each a named error like the existing ones (`waves: …`): a reinforcement value outside 1..`enemies.size()`; reinforcements in a boss room or a safe room; an `S` in a boss room or a safe room; reinforcements with fewer than `wave_min_arrival_points` `S` tiles; `S` tiles without reinforcements; an `S` nearer than `min_spawn_distance_tiles` to `P`; two `S` tiles nearer than `wave_spawn_gap_tiles` to each other, or an `S` that near a spawn tile (centre to centre); `max_engaged` negative; a kill target above `max_kill_target`. A room with no reinforcements and no `S` validates exactly as before. `max_enemies_per_room` still counts the spawn tiles only (F-011/C16's "1–6 enemies per combat room" now reads "placed enemies"). | F-011/C16 style: all errors, with the tile |
| C4 | **Tunables** in `FloorTunables` / `data/tunables/floors.tres`, each checked by `validate()`: `wave_max_engaged` (3, ≥ 1), `wave_spawn_warning_duration` (0.8 s, ≥ 0), `wave_spawn_interval` (1.5 s, ≥ 0), `wave_min_spawn_distance_tiles` (6.0, ≥ 0), `wave_spawn_gap_tiles` (1.5, ≥ 0), `wave_min_arrival_points` (2, ≥ 1), `max_kill_target` (30, ≥ 1), `wave_arrival_box_tiles` (`Vector2(19, 10)`, both > 0), `wave_max_walk_tiles` (18.0, ≥ 0; added after code review round 1, CR-1). No wave number is hardcoded. | G2 |
| C5 | **Waiting.** `EnemyLogic.State.WAITING` is appended after `STAGE_SHIFT`. `hold_in_reserve()` puts a freshly set-up enemy in it (state `IDLE`, not aggroed, nothing running); called at any other moment it changes nothing and reports an error. While waiting: `is_alive()` is false; it cannot be hit; `apply_hit()` changes nothing (no damage, no aggro, no state change); `sense()` decides nothing and `step()` returns before advancing anything (no cooldown, no phase time, no movement, and its displacement for the step is zero, so the runner never moves its hidden body); it has no hitbox and launches nothing; `is_waiting()` is true. `arrive(position_tiles)` puts it at that position in state `IDLE`, aggroed, with a fresh combat state (full HP, no hitstop, no knockback), and emits a new signal `arrived`; it senses for the first time at the next step start. `arrive()` on an enemy that is not waiting changes nothing and reports an error. The state is part of the snapshot. A waiting enemy that is killed anyway (only a test can do that, by putting damage straight on its `CombatState`) is `DEAD` and counts as a kill. `setup()` (the debug reset) leaves an enemy not waiting, so `CombatRunner.reset()` refuses, with an error and no change, when its sim has a director; `Room` rebuilds a room instead of resetting it. | The sim's roster stays fixed; plan review PR-3, PR-5, PR-10 |
| C6 | **Director.** `RoomWaves` (core, `RefCounted`, `src/core/floors/room_waves.gd`) holds the room's enemies in registration order (the ones placed at the start, then the reserve in arrival order), the arrival points, the resolved `max_engaged` and the rules. `CombatSim.set_waves()` attaches it; in `tick()` the sim calls `step(duration, view)` once per step, after every combatant's `step()` and the sim clock's advance and before `fire_due_actions()`. The director reads players and the room's nav grid (`view.nav`, null when the sim has none) from that step's `view` and reads its enemies from their logic as it is at that moment (the view was captured before they stepped). With no director attached the sim behaves exactly as before. | G6; D-007; plan review PR-5 |
| C7 | **Director rules**, per step, in this order. Time comparisons use `CombatTiming.TIME_EPSILON`. (1) Every pending arrival's time goes down by the step; one that has run out arrives (`arrive()` on its enemy, at its point), so an arrival lands at the first step end at or after its start plus the warning, and a warning of 0 arrives in the step after it started. A pending arrival whose enemy is no longer waiting is dropped silently. Nothing is rechecked at the point when it lands. (2) The fight **starts** the first time any of the room's enemies is aggroed or dead when the director looks; it never un-starts. (An enemy that notices the player by range is seen in that step; a hit or a death happens at the step's contact, after the director, and is seen in the next step.) (3) The time since the last arrival was started goes up by the step; it begins at `wave_spawn_interval`, so before any arrival the interval has passed. (3b) **Release.** The reserve is split into as many shares as the room has placed enemies: each share has `reserve / placed` enemies (whole division) and the first `reserve mod placed` shares one more. The number of **released** reinforcements is the sum of the first k shares, where k is how many placed enemies are aggroed or dead when the director looks; it is computed from the enemies every step, never stored. (4) Repeat while all of these hold: the fight has started; the index of the next reserve enemy (which is what "arrivals started" means, and what the snapshot stores) is below the released count; a reserve enemy that is still waiting is left (one that is not waiting is skipped silently and never sent; the index moves past it, so it uses a slot of its share); a living player exists; the **engaged** enemies (alive and aggroed) plus the pending arrivals are fewer than `max_engaged`; at least `wave_spawn_interval` has passed since the last arrival was started; and C8 finds a point. Each repeat makes the next waiting reserve enemy a pending arrival at that point with `wave_spawn_warning_duration` to go and sets the time since the last start to 0 (so with an interval of 0 several can start in one step, each at its own point). | The pace is the cap, not a clock; plan review PR-1, PR-2, PR-4, PR-5 |
| C8 | **Choosing a point**, a static, side-effect-free function on `RoomWaves` that the director and the tests share. Candidates are the arrival points with no pending arrival on them and no living enemy nearer than `wave_spawn_gap_tiles` (strictly nearer). A point's distance is to the nearest living player. Among candidates at least `wave_min_spawn_distance_tiles` away, inside the **arrival box** (no further than `wave_arrival_box_tiles.x` horizontally and `.y` vertically from that player) and with a **walk** to that player of at most `wave_max_walk_tiles` the nearest wins; if there is none, the nearest among those far enough and inside the box; if there is none, the nearest among those far enough; if none is that far, the farthest candidate wins. (The walk tier was added after code review round 1, CR-1: a point 8 tiles away through a wall can be a 60-tile walk. The walk is the length of the nav grid's shortest path, `NavGrid.walk_distance()`; the function takes the walks as an input, one per point, and with none given every walk counts as short, so a sim without a nav grid chooses as before.) a later point in row-major order replaces an earlier one only if it is better by more than `Geometry.DISTANCE_EPSILON`. No candidate: no arrival this step. | Near the fight, never on the player |
| C9 | **Counts.** `RoomWaves.get_kill_target()` is the number of the room's enemies; `get_kill_count()` is how many of them are neither alive nor waiting. Both are computed from the enemies on every call, never stored. `get_pending()` lists the pending arrivals whose enemy is still waiting (point, time left, total warning, enemy id) for the glue to draw. `has_started()`. `get_released_count()`. | F-011/C11: nothing that can go stale |
| C10 | **Snapshot.** With a director attached, `CombatSim.to_dict()` carries a `waves` entry (started, the index of the next reserve enemy, the time since the last start, the pending arrivals) and `from_dict()` refuses a snapshot without it or with values out of range, before anything changes. Without a director the snapshot is exactly today's. A room restored in the middle of a warning continues it to the same instant. | G7 |
| C11 | **Glue.** `Room` builds the reserve enemies after the placed ones, lists all of them in the runner's `combatant_paths` (player, placed enemies in spawn order, reserve in arrival order), and attaches a `RoomWaves` only when the room has reinforcements. `Room.get_enemies()` returns every enemy, the reserve included; `get_reserve_enemies()` only those. `is_cleared()` is "no enemy alive and none waiting". `get_kill_count()` and `get_kill_target()` work in every room (a room without waves: its dead enemies and its enemy count). `Enemy` gains `starts_in_reserve` (false by default; set by `Room` before the node enters the tree, so `_ready()` sets the logic up, holds it in reserve and then syncs the body). The `Enemy` node derives "is it there" from its logic's state every time it syncs its body, never from a signal alone, so a restore in either direction is right: while `WAITING` it has no body collision and nothing of it is drawn (no shape, bar or label); on `arrived` its body is put on the logic's position. `Enemy` gains an export `hide_when_dead` (false by default, so the debug scenes and every fixture room are unchanged); `Room` sets it on every enemy of a room that has reinforcements, and such an enemy's shape, bar and label are not drawn once dead (its damage numbers still are, so the killing hit shows its number). `CombatDebugDraw` draws no ring for a waiting enemy, and none for a dead enemy in a sim that has a director. | Views follow the logic; plan review PR-7, PR-8, PR-9 |
| C12 | **Markers.** A node of its own under `Room` draws one marker per pending arrival at its point, from `RoomWaves.get_pending()`, read every frame: a ring of the arriving enemy's body radius that fills as the warning runs out (a total warning of 0 draws it full). Colours and line width are exports on the marker node (placeholder, → Art & Game Feel). Presentation only: no collision, nothing in core reads it. | Pillar 2: readable; G6 |
| C13 | **HUD.** In a combat room of a floor the HUD shows `Kills <count> / <target>` under the location text; in the town and in a boss room it shows nothing there. The text comes from one constant or static function (F-012/C16). `Game` feeds it from the shown room every physics frame; no rule moves into `Game` or the HUD. | Lucas approved "shown on the HUD" |
| C14 | **Shipped rooms.** The 12 combat rooms get arrival points, reinforcements and `max_engaged` as the table below this one gives; reinforcements use only enemy types the room already lists. The grids of F-013 do not change otherwise (an `S` replaces a `.`), and every F-013 shipped-room rule still holds. Arrival-point rules, each with a test over every shipped combat room: (a) no wall tile at 2 tiles or nearer to an `S` (the larger of the x and y distance, the border included); (b) **the warning is on screen**: for every walkable tile taken as the player's position, the point C8 chooses with every point free, the point it chooses when that one is taken away, and the one it chooses when both of those are taken away, all three lie inside the arrival box of C8 (19 × 10 tiles; half a screen is 20 × 11.25). A room gets as many `S` tiles as (b) needs: the plan review's search needed 13 to 22 per room. Rule (b) covers the first three choices with no enemy standing on a point; C8's preference for the box covers the rest as far as the points allow. (c) `max_engaged` is at most 1 plus the room's first share, so the cap can be reached at the first fight. (d) (After code review round 1, CR-1.) **The arrival is a short walk away**: for every walkable tile taken as the player's position, with every point free, the point the director chooses with the room's nav grid has a walk of at most `wave_max_walk_tiles` to the player. | The lead's starting values (§10 Q1); plan review PR-6 |
| C15 | **Nothing changes where there are no waves.** A room without reinforcements (every fixture, every boss room, the town) behaves exactly as before, and its sim snapshot is exactly what it was. | The old suite is the proof |
| C16 | **Pre-existing tests** change only as listed here, each change listed in §8 with its reason. (1) `tests/scenes/test_f011_shipped_floors.gd`, `test_ac26_floor_{1,2,3}_every_room_loads_and_steps_clean`: the list of registered ids now holds the reserve. (2) `tests/core/floors/test_floor_tunables.gd`: the shipped-values test gains the new values (an addition). (3) A test that pins a tile of a shipped grid where an `S` now stands. Everything else, and every test on fixtures, passes unchanged; `kill_all()` keeps clearing a room because `get_enemies()` includes the reserve (C5, C7, C11). | As F-013/C16; the plan review's prototype failed exactly the three tests of (1) |
| C17 | No new third-party dependency, no new autoload, no new input action. Core stays pure. | G4, G6 |

**Wave table for C14.** "Placed" is what the room has today and keeps. Reinforcements are in
arrival order, with `|` between the shares (C7 3b; the k-th placed enemy to notice the player
releases the k-th share); ch = chaser, ca = caster, br = brute. One fight is a placed enemy
plus its share. `max_engaged` is the most that arrivals will put on the player at once; a test
checks that it can be reached at the first fight (it is at most 1 plus the first share).

| Room | Placed | Reinforcements, by share | Kill target | `max_engaged` |
|---|---|---|---|---|
| 1-1 | 2 ch | ch, ch \| ch, ch | 6 | 2 |
| 1-2 | 3 ch | ch, ch \| ch, ch \| ch, ch | 9 | 2 |
| 1-3 | 4 ch | ch, ch \| ch, ch \| ch, ch \| ch, ch | 12 | 3 |
| 2-1 | 2 ch, 1 ca | ch, ch, ca \| ch, ca, ch \| ch, ch, ca | 12 | 3 |
| 2-2 | 2 ch, 2 ca | ch, ca \| ch, ch \| ca, ch \| ch, ca | 12 | 3 |
| 2-3 | 1 ch, 3 ca | ch, ch \| ch, ca \| ch, ch \| ca, ch | 12 | 3 |
| 2-4 | 3 ch, 2 ca | ch, ca \| ch, ch \| ca, ch \| ch, ch \| ca, ch | 15 | 3 |
| 3-1 | 1 br | br, br | 3 | 1 |
| 3-2 | 1 br, 2 ch | ch, ch \| br, ch \| ch, ch | 9 | 3 |
| 3-3 | 1 br, 2 ca | ca, br \| ca \| ca | 7 | 2 |
| 3-4 | 2 br | br \| br | 4 | 2 |
| 3-5 | 1 br, 2 ch, 2 ca | ch, ca \| ch, br \| ch, ca \| ch, ch \| ca, ch | 15 | 3 |

**Must not break:** every F-011, F-012 and F-013 behaviour: room clear opening the exit, the
heal and its message, death returning to town, the debug keys N and R (a rebuilt room starts
its waves again), the camera, the routes enemies take, snapshots, tick-rate independence; the
debug scenes; the boss fights.

---

## 5. Acceptance Criteria  ·  _Planner_

Testable, observable. The Auditor checks each one. Times are sim time; "a step" is one step of
the sim's grid (1/120 s).

**Data**
- [ ] AC1: A room with reinforcements `[1, 2, 1]` on a grid with two spawns reports a kill target of 5, three reinforcement spawns of the right enemies with ids numbered on from the spawns', and its `S` tiles as arrival points in row-major order. `get_spawns()` returns what it returned before.
- [ ] AC2: Each rule of C3 is refused with its own error naming the tile or value, alone and together with others; a room with no reinforcements and no `S` gets no new error.
- [ ] AC3: The nine tunables of C4 exist with their shipped values, and `FloorTunables.validate()` refuses each bad value.

**Waiting and arriving**
- [ ] AC4: A waiting enemy is not alive in a `CombatView`, is not chosen as a target, is not hit by a sword arc that covers its position, does not aggro on a player standing on it, has no hitbox or projectile, and after 5 s of sim time its position, cooldown, phase time and HP are what they were. `apply_hit()` on it changes nothing: same HP, not aggroed, still waiting.
- [ ] AC5: `arrive()` puts it at the given position, `IDLE`, aggroed and at full HP, and emits `arrived` once; from the next step on it walks toward a player 20 tiles away. `arrive()` on an enemy that is not waiting, and `hold_in_reserve()` on one that is aggroed or in an attack, change nothing and report an error.
- [ ] AC6: A snapshot of a sim with a waiting enemy restores it waiting; one taken after it arrived restores it arrived.

**Director**
- [ ] AC7: Nothing arrives before the fight starts, however long the player waits outside every aggro radius. The fight has started by the end of the step in which an enemy first notices the player by range, and by the end of the next step after a hit or a death.
- [ ] AC8: With `max_engaged` 2, two placed enemies both aggroed and three in reserve: while both live nothing arrives; in the step after one dies a warning starts, and the reinforcement arrives at the first step end at or after `wave_spawn_warning_duration` later (96 steps for 0.8 s); at no step are more than 2 enemies engaged or on their way because of an arrival.
- [ ] AC9: With `max_engaged` 2, two placed enemies of which only one is aggroed, and a reserve: a warning starts in the step the fight starts (the sleeping one does not count, and before any arrival the interval counts as passed). With `max_engaged` 3, one aggroed placed enemy and a first share of at least 2, the second warning starts `wave_spawn_interval` after the first, in the order of `reinforcements`; with an interval of 0 both start in the same step at different points.
- [ ] AC10: `RoomWaves`'s point choice returns what C8 names, in each of its cases: the nearest far-enough point; the farthest when none is far enough; the earlier point on a tie; never a point with a pending arrival or a living enemy nearer than the gap; none when no point qualifies, and then the arrival starts in the first later step in which one does; a boxed point with a short walk before a nearer boxed point behind a wall, and that nearer one when it is the only boxed point.
- [ ] AC11: With no living player nothing new starts; pending arrivals still arrive.
- [ ] AC12: Kill count and kill target follow C9 through a whole room: 0 of n at the start, +1 by the end of the step an enemy dies, n of n when the last dies, and `Room.is_cleared()` is true exactly then.
- [ ] AC13: A scripted run on a fixture room gives the same warning start times, arrival times and points at 30, 60 and 120 ticks per second.
- [ ] AC14: A snapshot taken in the middle of a warning, restored into a freshly built room, continues to the same arrival instant, point and kill count as the original; a snapshot without the `waves` entry is refused by a sim that has a director, with nothing changed.
- [ ] AC15: A reserve enemy killed by a test while it waits (lethal damage on its `CombatState`) counts as a kill and is never sent; one killed during its own warning never arrives; neither reports an error. After `kill_all()` in a room with a reserve the room is cleared in that tick, `get_pending()` is empty at once, and for 5 s nothing arrives and no error is reported.
- [ ] AC26: With two placed enemies and a reserve of five (shares 3 and 2), `max_engaged` 4 and an interval of 0: when the first placed enemy is engaged exactly three arrivals start, and no fourth however many die; once those three and the first placed enemy are dead and the second placed enemy is engaged or killed, the last two start (while the cap is full they wait for it). `get_released_count()` is 0, 3 and 5 at those moments.
- [ ] AC27 (after code review round 1, CR-1): `NavGrid.walk_distance(from, to)` is the length in tiles of the shortest path between the two positions' tiles under the grid's own step rules (0 on the same tile, infinite when there is none), equal to an independent shortest-path computation on fixture rooms, a 64 × 36 room with blocks and room 2-4; asking it changes no answer of `direction_toward()` (the F-013 equivalence proof still passes). In a room with a wall between a boxed point and the player, the director sends the arrival to a boxed point with a short walk.

**Room, markers, HUD**
- [ ] AC16: In a `Room` with reinforcements the reserve enemies exist, are registered after the placed ones in arrival order, have no collision and draw nothing (no shape, bar, label or debug ring); a body walks through the place a waiting enemy's node stands. `CombatRunner.reset()` on such a room changes nothing and reports an error.
- [ ] AC17: While a warning runs, one marker is drawn at its point and its fill follows the time left; it is gone in the frame after the arrival; with two pending arrivals there are two.
- [ ] AC18: On arrival the enemy's node is on the arrival point, visible, with collision, and it reaches attack range of a player standing 10 tiles away behind a pillar. After a snapshot taken before the arrival is restored, the node is hidden and without collision again and its body does not move in the next 60 ticks; after one taken after it, visible and collidable on the logic's position.
- [ ] AC19: The exit of a room with reinforcements stays locked after the placed enemies are dead and opens in the tick the kill target is reached; the room-clear heal and its `+N HP` message come then, once. In such a room a dead enemy's shape, bar, label and debug ring are not drawn while the number of the hit that killed it is; in a room without reinforcements a dead enemy is drawn as before.
- [ ] AC20: The debug keys N and R, a death, and a return from the town (in a `Game`) each give a room whose waves start from the beginning.
- [ ] AC21: The HUD shows `Kills 0 / n` on entering a combat room, counts up with each kill, shows nothing in the town and in a boss room, and follows a room change in the same tick as the location text.

**Shipped rooms**
- [ ] AC22: Every shipped combat room matches the wave table (reinforcement types in order, kill target, `max_engaged`) and C14's rules (a) to (d); the shipped tower validates; F-013's shipped-room tests pass on the new grids.
- [ ] AC23: Every shipped combat room, played by this script: the player's HP is refilled every tick; the player is put 3 tiles from the placed enemy nearest to `P`, on the line toward `P`; every 3 s, counted from the moment the player was last put somewhere, the script kills the enemy that has been engaged longest; whenever nobody is engaged, nothing is pending and every released reinforcement has started, it puts the player 3 tiles from the nearest placed enemy that still sleeps, on the line toward where the player was. Then: every reinforcement arrives; no arrival takes the engaged enemies plus the pending arrivals above `max_engaged`; the engaged enemies reach `max_engaged` at some step; the k-th share never starts before k placed enemies are aggroed or dead; the room is cleared exactly at its kill target; no error is reported. From every arrival point the nav grid gives a direction toward `P`.

**Whole feature**
- [ ] AC24: A room without reinforcements has a sim snapshot with exactly today's keys, and F-011's, F-012's and F-013's tests pass unchanged except as C16 lists. (F-012's scripted runs of floors 1 to 3 reach each boss by skipping rooms, so they pass without meeting a wave; AC23 is the check that does.)
- [ ] AC25: `tools/test` passes; `gdlint` and `gdformat --check` are clean; `tools/check_core_purity` passes; `scenes/main.tscn` starts headless with no error.

**How to verify manually:** Enter floor 1. The HUD says `Kills 0 / 6`. Walk at one of the two
chasers: as it notices you, a ring appears on the floor somewhere near you and fills, and a
second chaser appears in it and comes for you, and a third after one of them dies: two are
on you at a time. That placed chaser's share is two reinforcements; when they are dead the
room is quiet until you walk up to the other placed chaser, which brings the other two. At
6 kills the exit opens and `+30 HP` shows. Later rooms keep up to three on you and have a fight like that at every placed enemy. Dead
enemies vanish. The boss rooms are as they were.

---

## 6. Task Breakdown  ·  _Planner_

Small, ordered, each independently committable. "A" and "B" are the two implementers; their
file lists never overlap while both work.

| # | Task | Files likely touched | Notes |
|---|---|---|---|
| T1 | Room data and tunables: C1–C4, AC1–AC3. | `src/core/floors/room_data.gd`, `src/core/floors/room_spawn.gd`, `src/core/tunables/floor_tunables.gd`, `data/tunables/floors.tres`, `tests/core/floors/test_f014_wave_data.gd`, `tests/core/floors/wave_fixtures.gd`, `tests/core/floors/test_floor_tunables.gd` (the shipped-values test gains the new values) | A |
| T2 | The waiting state and how an enemy is shown: C5 (without the runner's part), the `Enemy` node's part of C11 (`starts_in_reserve`, `hide_when_dead`, shown from the state) and the debug draw's, AC4–AC6. | `src/core/enemies/enemy_logic.gd`, `src/entities/enemies/enemy.gd`, `src/ui/debug/combat_debug_draw.gd`, `tests/core/enemies/test_f014_waiting.gd`, `tests/entities/test_f014_enemy_waiting.gd` | B, in parallel with T1 |
| T3 | The director and the sim hook: C6–C10, AC7–AC15 and AC26 in core (on fixture rooms, with bodies moved by the logic). | `src/core/floors/room_waves.gd`, `src/core/combat/combat_sim.gd`, `tests/core/floors/test_f014_room_waves.gd`, `tests/core/combat/test_f014_sim_waves.gd` | A, after T1 and T2 are committed |
| T4 | The room: reserve enemies, the director attached, `is_cleared()`, the counts, `hide_when_dead`, the runner's refusal to reset; C11 (the room's part), C5 (the runner's part), AC12 and AC15 (room part), AC16, AC18, AC19, AC20 (N, R and death in a floor scene). | `src/world/floors/room.gd`, `src/world/combat_runner.gd`, `tests/scenes/test_f014_room.gd` | B, after T3 |
| T5 | The markers: C12, AC17. | `src/world/floors/wave_markers.gd`, `src/world/floors/room.gd` (one line that adds the node), `tests/scenes/test_f014_markers.gd` | B, after T4 |
| T6 | The HUD line and `Game` feeding it: C13, AC21, and AC20's return from the town. | `src/ui/hud/hud.gd`, `src/ui/hud/hud.tscn`, `src/world/game.gd`, `tests/ui/test_f014_hud.gd`, `tests/scenes/test_f014_game.gd` | A, after T4. Its `Game` tests run on fixture towers (T7 rewrites the shipped rooms at the same time). |
| T7 | The shipped rooms: C14, AC22, AC23, and the test changes of C16. | `data/floors/floor_*/room_*.tres`, `tests/core/floors/test_shipped_floors.gd`, `tests/scenes/test_f011_shipped_floors.gd`, `tests/scenes/test_f014_shipped.gd` | Whoever is free after T4 and T5. The `S` tiles are placed by a search script kept in the scratchpad (rule (b) cannot be met by hand; the plan review's `place_points_r2.py` is a starting point), not committed. The lead checks the grids by their numbers and a rendered look, not point by point. |
| T8 | Design docs and glossary: `design/floors.md` (the legend and `S`, "1–6 enemies per combat room" → placed enemies, the encounter table with kill targets and caps, the arrival-point rules), `design/combat.md` (the waiting state; arrival as a third cause of aggro), `GLOSSARY.md` (kill target, reinforcement, arrival point, waiting, engaged; "Aggro"). | `studio/design/*.md`, `studio/GLOSSARY.md` | Lead, as Planner |
| T9 | Final gate: full suite, lint, format, purity, headless boot; a rendered look at a room with a warning marker and the HUD count; the physics time of a tick in room 3-5 with its reserve against the same room without one, recorded in §8 (more than 1 ms per tick added becomes a §10 question). | — | Lead |

---

## 7. Plan Review  ·  _Auditor_

<!-- review-round: 1 verdict: CHANGES_REQUESTED -->

**Date:** 2026-11-19 · **Verdict:** CHANGES_REQUESTED · **By:** Auditor (lead, D-014)

A fresh reviewer sub-agent that wrote neither the spec nor any code, read-only, on commit
`5b28e0e`. It built a throwaway prototype of C1–C11 in its own copy, gave all 12 shipped rooms
`S` tiles and the wave table, and ran the whole suite on it: 1769 of 1772 pass. One blocking
finding, eight "should fix", five suggestions. The lead checked each against the code.

### PR-1 🔴 The cap counted sleeping placed enemies, so reinforcements came one at a time in 11 of 12 rooms
C7 (4), the wave table, the goal's "a few at a time". `max_alive` equalled the placed count in
every row and counted dormant enemies. Verified by a scripted run of each room (the player 3
tiles from the nearest spawn, each enemy dying 3 s after it wakes): the most on the player at
once was 1 in eleven rooms and 2 in room 1-3, and up to 4 placed enemies were still asleep when
the reserve was spent.
> **Planner reply:** accepted; the rule was wrong. The cap now counts **engaged** enemies
> (alive and aggroed) plus pending arrivals, is called `max_engaged`, and the table's numbers
> are lowered to mean "on you at once" (2 to 4). An arrival now starts when the fight does,
> not at the first kill. The old rule is in §3 Rejected. The manual check, Q1 and Q3 follow.

### PR-2 🟡 The director was undefined for a reserve enemy that is no longer waiting
`kill()` puts lethal damage straight on `CombatState` (`f011_scene_test.gd:96-113`). After
`kill_all()` the prototype cleared the room, then started a warning in the cleared room and
called `arrive()` on a dead enemy, which GUT fails as an unexpected error.
> **Planner reply:** accepted. C7 (1) drops a pending arrival whose enemy is not waiting and
> (4) skips a reserve enemy that is not waiting, both silently. AC15 is new.

### PR-3 🟡 `apply_hit()` on a waiting enemy was undefined, and a pre-existing test calls it
As the code stands it would aggro the enemy and move it out of `WAITING` without `arrive()`,
hidden and without collision (`enemy_logic.gd:231-235`); `test_f011_shipped_floors.gd`'s wake
loop runs over every `get_enemies()`. `step()`'s default branch would also advance the
cooldown and phase time.
> **Planner reply:** accepted. C5 says `apply_hit()` changes nothing on a waiting enemy and
> `step()` returns before advancing anything; AC4 checks both.

### PR-4 🟡 AC7 and AC8 named moments C6/C7 cannot produce
A hit or a death happens at the step's contact, after the director's slot, so the fight starts
in the next step. "Exactly 0.8 s later" was 97 steps with a literal "reaches 0" and 96 with
`TIME_EPSILON`; a warning of 0 arrives one step later. Verified by a core probe at 30, 60 and
120 ticks/s (identical at all three).
> **Planner reply:** accepted. C7 uses `TIME_EPSILON`, says when an arrival lands and what a
> warning of 0 does; AC7 and AC8 name step counts.

### PR-5 🟡 Eight places in C5–C8 and C12 where the Builder would guess
The interval before any arrival; what comes from the view and what from the enemies; the
director's slot in `tick()`; whether "while" loops; ties and `<` against `<=`; whether the gap
is rechecked at arrival; `hold_in_reserve()` at the wrong moment; the marker at a warning of 0.
> **Planner reply:** accepted, one sentence each: C7 (3), C6, C6, C7 (4), C8, C7 (1), C5, C12.

### PR-6 🟡 Nothing made the marker visible
With C14's four points, the point C8 chooses was off screen for 20–31 % of the player's
possible tiles per room; with 8–12 points on an even grid, 5–13 %.
> **Planner reply:** accepted. C14 (b) is a shipped-room rule with a test: from every walkable
> tile, C8's first and second choice lie within 19 × 10 tiles. C8 is a static function so the
> test and the director share it. The "at least 4" is replaced by "as many as (b) needs".

### PR-7 🟡 The debug draw rings every waiting enemy; its file was on nobody's list
`Room` always adds a `CombatDebugDraw`; in the prototype four rings stacked on the first `S`
tile. §2 also said the hit resolver ignores enemies that are not alive; it does not read
`is_alive()`.
> **Planner reply:** accepted. The file is on T2's list, C11 and AC16 name the ring, §2 is
> corrected.

### PR-8 🟡 §2 said the glue hides a dead enemy's body; it does not
A dead enemy is drawn in `dead_color` with its bar and label; with kill targets up to 12 the
corpses would pile up where arrivals land.
> **Planner reply:** accepted. §2 is corrected. C11: `Enemy.hide_when_dead`, off by default,
> set by `Room` in a room with reinforcements; AC19 checks both kinds of room. Named in §3's
> costs.

### PR-9 🟡 No criterion checked the `Enemy` node after a restore
A restore moves an enemy between waiting and arrived with only `state_restored`.
> **Planner reply:** accepted. C11 derives "is it there" from the state on every body sync;
> AC18 checks a restore in both directions.

### PR-10 🔵 `CombatRunner.reset()` breaks a waves room
After `reset()` 6 of 6 enemies were alive, the reserve stacked on one tile. Nothing in `src`
calls it on a `Room`.
> **Planner reply:** accepted. C5: the runner refuses a reset while its sim has a director;
> AC16; `combat_runner.gd` is on T4's list.

### PR-11 🔵 Tasks
T4 was large; AC19's return from the town needs `Game`; T6's "other scene tests" is exactly
one file; T8 named a frame cost with no number.
> **Planner reply:** accepted. The markers are their own task (T5); the return from the town
> is in the `Game` task's test (T6); C16 names the tests; T9 has a number.

### PR-12 🔵 AC23 passed without meeting a wave; C14's rules had no metric
> **Planner reply:** accepted. The old AC23 is a note in AC24; the new AC23 is the scripted
> run of every room, with the reviewer's script as its shape. C14 (a) names its metric.

### PR-13 🔵 An option §3 did not list: reuse dead enemies as the reinforcements
> **Planner reply:** added to §3 Rejected, with why.

### PR-14 🔵 T7 should name the lines it changes
> **Planner reply:** accepted: T8 (the docs task) names them, and C13 points at F-012/C16
> for the HUD string.

**Confirmed by the prototype, not findings:** the three old-suite failures are
`test_ac26_floor_{1,2,3}_every_room_loads_and_steps_clean` (the registered-id list), inside
C16; F-012's tests pass; `kill_all()` clears a room with a reserve; C3 contradicts no existing
rule and `S` is already walkable to `NavGrid` and `Room`'s walls; all 12 rows of the table are
feasible (829 to 1599 tiles per room meet C3 and the old C14); an arrival 7.2 tiles from the
player walked to them and attacked, and no brain has a leash; director times are identical at
30, 60 and 120 ticks/s; a mid-warning snapshot restores to the same instant and point; with a
dead player the pending arrival lands and idles.

**Not checked in this round:** the HUD line and the markers; the reserve's frame cost; each C3
error alone and together; final positions across tick rates; a body arriving on top of a
living enemy in physics; lint, format, purity.

<!-- review-round: 2 verdict: APPROVE_WITH_NOTES -->

**Date:** 2026-11-19 · **Verdict:** APPROVE_WITH_NOTES · **By:** Auditor (lead, D-014)

The same reviewer, on commit `bc6e0ae`, read-only, with its prototype brought to the revised
C5–C8, C11 and C14 and all 12 rooms regenerated for the new table and rules (a) and (b).

**Round 1 findings:** PR-1 to PR-14 ✔ resolved, each checked on the prototype (PR-3:
`apply_hit()` on a waiting enemy left it waiting, not aggroed, at full HP; PR-4: the warning
starts in the step after the death and the arrival lands 96 steps later, identical at 30, 60
and 120 ticks/s; PR-10: `reset()` on a waves room reported the error and changed nothing).
Leftovers are the new findings below.

### PR-15 🟡 AC23 could not pass in rooms 2-4 and 3-5, and its script was underdefined
With "each enemy dying 3 s after it is first engaged" the arrivals land 0.8, 2.3 and 3.8 s
after the fight starts and the first placed enemy dies at 3.0 s, so a cap of 4 is never
reached. Verified by running both kill rules on all 12 rooms.
> **Planner reply:** accepted. AC23 is rewritten as a defined script (one kill every 3 s of
> the longest-engaged enemy, HP refilled, where the player stands, when it moves on) and no
> longer asks for the cap to be reached, which the release rule below would not guarantee.

### PR-16 🟡 `hide_when_dead` left the dead enemy's debug ring and took the killing hit's number
The debug draw skipped only `WAITING`; hiding the node also hides its damage numbers.
> **Planner reply:** accepted. C11: the shape, bar and label are hidden, the damage numbers
> stay; the debug draw skips a dead enemy in a sim with a director. AC19 names both.

### PR-17 🟡 The reserve was still spent at the first fight, and neither §3 nor Q2 said so
Killing one enemy every 3 s, the reserve was gone 3.8 to 15.8 s after the fight started and
0 to 4 placed enemies were still asleep; the rest of the room stayed as sparse as today.
> **Planner reply:** accepted, and changed rather than only stated, because it is the reason
> the feature exists. C7 (3b): the reserve is released in shares, one per placed enemy that is
> aggroed or dead, computed from the enemies each step. §3 has the option and the rejected
> "all free at once"; AC26 pins it; AC23 checks that no later share starts early; the manual
> check and Q2 describe it.

### PR-18 🟡 T7 hid a search problem
Rule (b) needs 17 to 34 `S` tiles per room, 292 in all, by a greedy search.
> **Planner reply:** accepted. T7 says the points are placed by a search script kept in the
> scratchpad and how the lead checks them; C14 names the counts.

### PR-19 🔵 C14 (b) covered the first two choices only, with no enemies in the room
On grids that meet (b) the third choice is on screen from 88–95 % of player tiles and the
fourth from 57–80 %; extending (b) to the cap needs 426 points and fails in room 2-4.
> **Planner reply:** accepted, by the reviewer's second suggestion: C8 ranks candidates inside
> a tunable arrival box (`wave_arrival_box_tiles`, 19 × 10) ahead of those outside it. C14
> states what (b) covers and what the box covers.

### PR-20 🔵 Seven places an implementer would still guess
> **Planner reply:** accepted, all seven: C7 (3) starts the time at the interval, so nothing
> new is stored; `get_pending()` leaves out enemies that are not waiting (C9, AC15);
> `Enemy.starts_in_reserve` (C11, on T2's list with `hide_when_dead`); C14 (a) says "at 2
> tiles or nearer"; `arrive()` gives a fresh combat state (C5); a waiting enemy's
> displacement is zero and AC18 checks the hidden body does not move; T6's `Game` tests use
> fixture towers.

**Confirmed by the prototype, not findings:** C14 (b) with 19 × 10 can be met in all 12 rooms;
"engaged" is readable from `is_alive()` and `is_aggroed()`, and an aggroed enemy stays aggroed
until it dies; no burst at the fight's first step; the director's slot in `tick()` works;
AC7, AC8, AC9 and AC15 are producible; `hide_when_dead` and "shown from the state" are
implementable with the default off, and no existing test asserts on a dead enemy's visuals in
a shipped combat room; no file is on both implementers' lists while both work; the full suite
on the prototype fails only the three tests C16 (1) names.

**Also reported:** `tests/scenes/test_f005_reload.gd`,
`test_ac22_a_pending_launch_rejects_the_rate_and_launches_at_its_latched_speed`, failed once
in the reviewer's full run and passed 3 of 3 alone; its scene has no room and no director.
Taken for a timing-flaky test that predates this feature; the lead watches for it in T9.

**Not checked in this round:** the HUD line and the marker node; the reserve's cost per tick;
each C3 error alone and together; final positions across tick rates; a body arriving on top
of a living enemy in physics; a moving player in the scripted runs; lint, format, purity.

<!-- review-round: 3 verdict: APPROVE_WITH_NOTES -->

**Date:** 2026-11-19 · **Verdict:** APPROVE_WITH_NOTES · **By:** Auditor (lead, D-014)

The same reviewer, on commit `522cba4`, read-only, with C7 (3), (3b), (4) and C8's arrival box
in its prototype. PR-15 to PR-20 ✔ resolved (PR-16 in the text only: the prototype still hides
the whole node). The release rule: no room gets stuck, nothing is left unreleased once every
placed enemy is aggroed or dead, "aggroed or dead" is enough, and a restore needs nothing that
C10 does not list. C8's three tiers are well defined.

### PR-21 🟡 With shares of 1 or 2, `max_engaged` no longer said what is on the player
The shares were reserve ÷ placed, 1 or 2 in every room, so one fight was a placed enemy plus
its share: at most 3 engaged, and only until the first kill. On AC23's script the cap of 4 was
never reached in rooms 2-4 and 3-5, and three were on the player for 1.4 s in total in five
rooms; only room 1-3 was paced by its cap. The table's caption, the manual check and Q1 still
promised three or four.
> **Planner reply:** accepted. The wave table is redrawn with its shares written out: a share
> of 2 in most rooms and 3 in 2-1, kill targets 6 to 15, caps of 2 and 3, and C14 (c) checks
> that each cap can be reached at the first fight. AC23 asks for the cap to be reached again.
> The caption, the manual check and Q1 say "a placed enemy plus its share".

### PR-22 🟡 C14 (b) no longer decided how many points a room gets
Because C8 itself prefers the box, (b) for two choices was met with 8–14 points per room, and
then the first choice lands up to 20.6 tiles away and the third is off screen from 9–52 % of
player tiles.
> **Planner reply:** accepted, by the reviewer's first suggestion: (b) asks for three boxed
> choices (13 to 22 points per room, met in all 12 on the prototype); the stale count is
> corrected.

### PR-23 🔵 Six small contradictions and guesses in the diff
AC26's second half while the cap is full; AC26 on no task; "seven tunables"; "arrivals
started" never said to be the next-reserve index; three wordings in AC23; AC9's fixture.
> **Planner reply:** accepted, all six: AC26 lets the first share die first; T3 lists AC26;
> AC3 says eight; C7 (4) says the index is what "started" means and that a skipped enemy
> uses a slot of its share; AC23 names its clock, its move-on condition and "k placed
> enemies"; AC9 asks for a first share of at least 2.

**Not checked in this round:** the full suite on the round 3 prototype; the pace on the new
table (the lead's change after this round; AC23 and C14 (c) are its checks); a moving player;
the HUD and the markers; the reserve's cost per tick; lint, format, purity.

Gate A: Lucas's go-ahead in chat on the lead's proposal (D-015: "I can't play test right now
so yes go ahead and build waves"), so the file goes from `PLAN_REVIEW` to `IN_PROGRESS`
without `APPROVED`.

---

## 8. Implementation Log  ·  _Builder_

**Started:** 2026-11-19  ·  **Branch:** `feature/F-014-waves` (cut from `feature/F-013-camera-rooms-dash`, D-015)

### Progress
- [x] T1 — a351404 (room data, validation, eight tunables; 37 + 9 tests)
- [x] T2 — ffe511b (`WAITING`, `hold_in_reserve()`, `arrive()`; the node and the debug draw; 32 + 17 tests)
- [x] T3 — f1576c2 (`RoomWaves`, the sim hook and snapshot; 48 + 19 tests)
- [x] T4 — ad383d0 (the room: reserve, director, `is_cleared()`, counts, runner reset refused; 27 tests)
- [x] T5 — cc2c066 (`WaveMarkers`; 14 tests)
- [x] T6 — e49d9f0 (the HUD line; 13 tests), 5d31c35 (`Game` feeds it; 9 tests)
- [x] T7 — 1684c7e (the 12 rooms' data: 204 arrival points), b36965f (core tests over the shipped rooms; 25 tests), 5d31c35 (room 1-1 in the game; C16 (1))
- [x] T8 — c994bde (`design/floors.md`, `design/combat.md`, `GLOSSARY.md`)
- [x] T9 — final gate on 65019e6, results under "How to test"
- [x] Code review round 1 — CR-2, CR-3 6350df5; CR-1 (data) 8f9422d; CR-1 (code), CR-4, CR-5 1a6b595; CR-6, CR-7, CR-8 with the replies.

### Deviations from plan
- DEV-1: the two implementers were started on T1 and T2 while plan review round 3 (a check
  of the release rule and the arrival box) was still running. — **Why:** neither task
  reads those two rules; round 2 had approved the rest. — **Impact:** none: round 3 changed
  the wave table, C14 (b) and wording, none of it in T1's or T2's part.
- DEV-2: the file skips `APPROVED` (D-015: Lucas's go-ahead in chat is Gate A).
- DEV-3: the wave table was redrawn by the lead after plan review round 3 (shares of 2 and
  3, kill targets 6 to 15) and has had no review round of its own. — **Why:** the round's
  PR-21 showed the old numbers could not reach their caps. — **Impact:** AC23 and C14 (c)
  are what check it; the numbers are data and Lucas's to tune (§10 Q1).
- DEV-4: the tasks ran in another order than §6 gives, and two were split. T7's data
  (1684c7e) and its core tests (b36965f) came before T4, T6 came as two commits, and T7's
  scene test and C16 (1) came with T6's second commit (5d31c35). — **Why:** to keep both
  implementers busy while T3 and T4 were built; the room data and the core tests need no
  `Room`. — **Impact:** between 1684c7e and ad383d0 the shipped rooms carried wave data that
  nothing read yet (every test passed); see DEV-5.
- DEV-5: commit ad383d0 (T4) leaves three tests failing, the ones C16 (1) names; 5d31c35
  fixes them. — **Why:** the fix was another implementer's file. — **Impact:** two commits
  (ad383d0, cc2c066) on which `tools/test` is not green.
- DEV-6: the full suite was not run before each commit, as in F-013 (its DEV-3): each task
  was committed after its own tests, the suites its files touch, lint and format; the full
  suite ran after the last task.
- DEV-7: AC23 is checked at core level for all 12 rooms (b36965f: a real sim, the room's
  nav grid, no walls for bodies) and in the game for room 1-1 only (5d31c35). — **Why:** a
  scene run of every room would add minutes to the suite, and `Room`'s part is tested on
  fixtures. — **Impact:** in the scene test the cap clause cannot fail (its script kills
  too fast for the cap to bind); the core test is what proves the cap. Its script also
  holds the player's HP at 60 before the last kill, so the room-clear heal is visible.
- DEV-8: test hooks that are recorded state on presentation nodes: `Enemy.did_draw_body()`
  and `WaveMarkers.get_last_drawn()`. — **Why:** draw calls cannot be observed in a
  headless run. — **Impact:** none on behaviour; both can be dropped with the lines that
  read them.
- DEV-9: `Enemy.move_with_combatant()` for a waiting enemy puts the body on the logic's
  position and skips the move and the wall reports. — **Why:** after a sim-only restore
  the runner would otherwise copy the hidden body's stale position into the waiting logic.
- DEV-10: public names the spec does not give: `RoomWaves.get_next_index()`,
  `RoomWaves.Pending`, `RoomData.ARRIVAL_POINT`, `Room.get_waves()`,
  `Room.get_wave_markers()`, `Enemy.is_body_drawn()`, `WaveMarkers.get_markers()`,
  `CombatDebugDraw.hurtboxes_for()` and `has_director()`, `Hud.kills_text()`,
  `Hud.get_kills_text()`.
- DEV-11: `Game` feeds the kills line every physics frame, as C13 says, and also when a
  room is entered. — **Why:** a debug skip happens between ticks; the per-frame feed alone
  would show the new count one tick after the location text (AC21).
- DEV-12: during T1 and T2 the implementers ran their mutations in the live checkout, and
  their two mutation scripts, both at the scratchpad's root, overwrote each other once; one
  implementer found a line of `room_data.gd` it had not written. — **Why:** the briefs did
  not forbid it. — **Impact:** none in what was committed: every file was compared with the
  implementer's clean copy and reviewed as a diff by the lead before its commit. From T3
  on, mutations ran only in scratch copies of the project and each implementer had its own
  folder.

**Pre-existing tests changed (C16), all of them:**
- C16 (1): `tests/scenes/test_f011_shipped_floors.gd`, two lines in `_check_loaded()`: the
  expected ids also hold `get_reinforcement_spawns()`'s. Nothing else in that file changed;
  its "alive" count still holds because the reserve is waiting.
- C16 (2): `tests/core/floors/test_floor_tunables.gd`: eight asserts added to the
  shipped-values test and nine `test_ac3_*` tests appended. Nothing existing changed.
- C16 (3): no test pinned a tile where an `S` now stands.
- Fixture files gained builders, appended: `tests/fixtures/floors/floor_fixtures.gd`
  (`wave_pillar_room()`).

### Assumptions made (small, reversible)
- ASSUMPTION-1: `get_kill_target()` counts the reinforcement entries that resolve to an
  enemy (as `get_spawns()` skips a bad digit); it differs from "the number of
  reinforcements" only in rooms `validate()` refuses.
- ASSUMPTION-2: in a boss room or a safe room only the "not allowed here" wave errors are
  reported, so each rule can fail alone; the spacing rules run in every room; a negative
  `max_engaged` is refused even without waves; `max_engaged` has no upper bound.
- ASSUMPTION-3: `hold_in_reserve()` and `arrive()` return a bool. "Nothing running" is:
  data present, `IDLE`, not aggroed, no latched attack, no projectile, no hitstop, no
  knockback. `arrive()` leaves the attack cooldown as it was.
- ASSUMPTION-4: `restore_errors()` of an enemy refuses a state value it does not know and a
  waiting enemy that is aggroed.
- ASSUMPTION-5: the fight starts when any of the room's enemies is aggroed or dead, the
  reserve included; a reserve enemy killed by a test while waiting starts the fight but
  releases nothing. A room with no placed enemy (validation never allows one) releases its
  whole reserve.
  **Corrected after code review round 1 (CR-5):** as first built such a room released its
  reserve but could never start. Since 1a6b595 it starts at once.
- ASSUMPTION-6: in C8 "far enough" and "inside the box" are inclusive within
  `Geometry.DISTANCE_EPSILON`, and an enemy is "nearer than the gap" only below the gap
  minus that epsilon. The shipped rooms rely on the box edge being inside: in most rooms a
  second or third choice lies exactly 19 or 10 tiles away.
- ASSUMPTION-7: a reserve enemy that is not waiting is passed over before the cap, the
  interval and the player are checked; that moves the index and nothing else.
- ASSUMPTION-8: the director's snapshot is `{started, next_index, since_last, pending}` with
  each pending entry `{index, point, left, total}`; a `waves` key given to a sim with no
  director is ignored.
- ASSUMPTION-9: without a director `Room.get_kill_count()` is the enemies that are not
  alive.
- ASSUMPTION-10: the marker's fill is a disc that grows from the centre to the ring; the
  node redraws every frame and sits at `z_index` −1 so the runner stays the room's last
  child.
- ASSUMPTION-11: the kills line is 120 px wide at y 16 (both exports), so it clears the
  banner; `hide_kills()` also clears the text; during the death pause the line keeps the
  room's counts until the town is shown.
- ASSUMPTION-12: the arrival points were placed at least 4 tiles from each other (the rule
  is 1.5) so they spread evenly; rule (b) was checked over every tile that is not a wall,
  `P` and `E` included.
- ASSUMPTION-13 (code review CR-8): players at the same distance from an arrival point
  resolve to the earlier-registered one, within `Geometry.DISTANCE_EPSILON`, as targets do
  in `design/combat.md`.
- ASSUMPTION-14 (code review CR-8): the director's `restore_errors()` also refuses a
  snapshot in which arrivals were started but the fight was not; the director cannot
  produce one.
- ASSUMPTION-15 (CR-1): the walk tier's boundary is inclusive within the same epsilon; a
  point's walk is measured to its nearest living player by straight line; a sim without a
  nav grid, and a call with no walks, choose as before the tier existed.
- ASSUMPTION-16 (CR-4): in the death pause the kills line keeps what it last showed.
- ASSUMPTION-17 (CR-1, data): points were only added, never moved; four of room 2-4's six
  new points are beyond what rule (d) needs, added to shorten the second and third
  choices' walks.

### Things the Auditor should look at closely
- `RoomWaves.step()`: the order of (1) to (4); that a pending arrival whose enemy was
  killed still counts toward the cap until the next step drops it; that
  `get_released_count()` is recomputed inside the send loop.
- The wave table's numbers (DEV-3): they passed AC23 and C14 (c) but no review round.
- `EnemyLogic`: every path that could take an enemy out of `WAITING` other than `arrive()`
  and death (`setup()` does, by design; the runner refuses a reset in a waves room).
- The `Enemy` node after a restore in both directions, and `hide_when_dead`.
- The marker is a ring of the arriving body's radius (6.4 px for a chaser at 640 × 360).
  It was seen in one rendered run; whether it reads in a fight is unverified.
- `tests/scenes/test_f005_reload.gd`, `test_ac22_a_pending_launch_rejects_the_rate…`: the
  plan reviewer saw it fail once in a full run (it has no room and no director). It passed
  in every run since, the lead's full runs included.
- One F-014 test file left 28 objects alive at the end of the test run (found by the lead
  in the gate; the game itself left none). Fixed in 65019e6.

### How to test
After code review round 1 (6350df5, 8f9422d, 1a6b595): the full suite on 1a6b595 is 141 scripts,
2047 tests, all passing (679 s), with no "Orphans" line and no leak line; lint, format and
purity are clean; the game boots with no error line. The scripted runs of the 12 rooms give
the same table as below. The block below is the first gate's.

```
tools/test                      # 140 scripts, 2023 tests, all passing (639 s)
.venv/Scripts/gdlint src tests  # no problems
.venv/Scripts/gdformat --check src tests   # 270 files unchanged
tools/check_core_purity         # core purity ok
godot --headless --path . res://scenes/main.tscn --quit-after 120   # no error line
```
Final gate (T9) on 65019e6: all of the above, with no "Orphans" line and no leak line at
the end of the suite's output.

**The scripted run of every shipped room** (AC23, core level; one kill every 3 s, so the
times say how the fights are shaped, not how long a player takes):

| Room | Kill target | Cap | Most engaged | Seconds with 1 / 2 / 3 engaged | Arrival points |
|---|---|---|---|---|---|
| 1-1 | 6 | 2 | 2 | 9.2 / 8.8 / 0 | 13 |
| 1-2 | 9 | 2 | 2 | 13.8 / 13.2 / 0 | 14 |
| 1-3 | 12 | 3 | 3 | 10.6 / 15.2 / 10.2 | 18 |
| 2-1 | 12 | 3 | 3 | 11.4 / 15.9 / 8.7 | 13 |
| 2-2 | 12 | 3 | 3 | 15.2 / 18.0 / 2.8 | 17 |
| 2-3 | 12 | 3 | 3 | 15.2 / 18.0 / 2.8 | 18 |
| 2-4 | 15 | 3 | 3 | 19.0 / 22.5 / 3.5 | 22 |
| 3-1 | 3 | 1 | 1 | 7.4 / 0 / 0 | 15 |
| 3-2 | 9 | 3 | 3 | 11.4 / 13.5 / 2.1 | 16 |
| 3-3 | 7 | 2 | 2 | 12.2 / 8.8 / 0 | 17 |
| 3-4 | 4 | 2 | 2 | 7.6 / 4.4 / 0 | 19 |
| 3-5 | 15 | 3 | 3 | 19.0 / 22.5 / 3.5 | 22 |

Every reinforcement arrives, no arrival goes over the cap, every cap is reached, no share
starts early, each room clears exactly at its kill target. From every walkable tile of
every room the director's first three choices of arrival point lie inside the arrival box
(worst offsets exactly 19 and 10 tiles).

**Cost of the reserve (T9; lead, headless, whole frame, 600 frames, two runs each):** room
3-5 with everyone asleep: median 0.63 ms a frame with its 10 waiting enemies, 0.41 ms in a
copy of the project whose room 3-5 has none. That is 0.22 ms for the reserve, under the
1 ms of T9. A fight in that room with the player's HP refilled (7 enemies alive): median
2.2 ms, 95th percentile 3.8, worst 6.4 (the same room without waves, 5 enemies of which
one or two fight: 0.63 ms; the two are not the same fight).

**Rendered (lead):** room 1-1 from the town: `Kills 0 / 6` under the location text; the
player put next to a placed chaser; a blue ring near the player while the warning runs; a
chaser in its place afterwards, chasing; the other placed chaser still asleep. One run,
screenshots only; nobody played it.

Manual: §5, "How to verify manually".

---

## 9. Code Review  ·  _Auditor_

<!-- review-round: 1 verdict: APPROVE_WITH_NOTES -->

**Reviewed commit:** 65019e6 (the diff `7f64b77..65019e6` under `src`, `tests` and `data`; §8 read at b20b1ba)

**Date:** 2026-11-19 · **Verdict:** APPROVE_WITH_NOTES · **By:** Auditor (lead, D-014)

A fresh reviewer sub-agent that wrote neither the spec nor the code and took part in no plan
review round, read-only, with its own copies for probes and mutations (58 mutants: 56 killed,
2 survived, see CR-2). No blocking finding; one "should fix", seven suggestions. The lead
checked each against the code before recording it.

### AC evidence

| AC | Status | Where | How the reviewer checked |
|---|---|---|---|
| AC1 | ✅ | `test_f014_wave_data.gd` `test_ac1_*` (11); `room_data.gd` | ran, mutated |
| AC2 | ✅ | `test_ac2_*` (28) | ran, mutated |
| AC3 | ✅ | `test_floor_tunables.gd`, `test_f014_wave_data.gd` `test_ac3_*`; `floors.tres` | ran, mutated |
| AC4 | ✅ | `test_f014_waiting.gd` `test_ac4_*` (12, each with a control) | mutated (the `sense()` guard is an equivalent mutant) |
| AC5 | ✅ with a test gap (CR-2) | `test_ac5_*` (11) | mutated |
| AC6 | ✅ | `test_ac6_*` (6) | mutated; own rewind fuzz |
| AC7 | ✅ | `test_f014_room_waves.gd` `test_ac7_*` (6) | read, mutated |
| AC8 | ✅ | `test_ac8_*` (3) | read, mutated; own fuzz |
| AC9 | ✅ | `test_ac9_*` (6) | read, mutated |
| AC10 | ✅ | `test_ac10_*` (14) | mutated; own reimplementation of C8, 60,000 inputs, 0 mismatches |
| AC11 | ✅ | `test_ac11_*` (2) | mutated |
| AC12 | ✅ | core `test_ac12_*` (4), scene `test_ac12_*` (3) | mutated; own bot, every tick of 72 room runs |
| AC13 | ✅ | `test_f014_sim_waves.gd` `test_ac13_*` (2) | own fuzz: 500 random rooms at 30/60/120, no difference |
| AC14 | ✅ | `test_ac14_*` (6), `test_c10_*` (4) | mutated; own fuzz (restored twin, rewind) |
| AC15 | ✅ | core and scene `test_ac15_*` (3 + 3) | mutated |
| AC16 | ✅ | `test_f014_room.gd` `test_ac16_*` (7), `test_f014_enemy_waiting.gd` | mutated; own bot checked every waiting node every tick |
| AC17 | ✅ | `test_f014_markers.gd` `test_ac17_*` (11); reads `get_markers()`, not pixels (DEV-8) | mutated |
| AC18 | ✅ | `test_ac18_*` (4) | mutated; own restore probe |
| AC19 | ✅ | `test_ac19_*` (3) | mutated; own probes (last kill a placed enemy that never woke; last kill and last arrival in one tick; nobody alive while one is pending): door, heal and count right, heal once |
| AC20 | ✅ | `test_ac20_*` (R, N, death; the town in `test_f014_game.gd`) | own probe: old room, director and markers freed |
| AC21 | ✅ | `test_f014_hud.gd` (13), `test_f014_game.gd` `test_ac21_*` (8) | mutated; own probe on `main.tscn`, all of floor 1 |
| AC22 | ✅ | `test_f014_shipped_waves.gd`; own Python check of the 12 files against the table, C3 and C14 (a), (b), (c); only `S` tiles and the two properties changed against 7f64b77 | ran |
| AC23 | ✅ as worded | the core run of all 12 rooms; room 1-1 in the game. The reviewer also ran all 12 rooms in the real floor scene itself | read the script; ran |
| AC24 | ✅ | `test_ac24_*` (2), `test_c15_*` (3); three pre-existing test files changed, additions only | ran |
| AC25 | ✅ | full suite in a clean copy at 65019e6: 140 scripts, 2023 tests, all passing; lint, format, purity, boot | ran |
| AC26 | ✅ | `test_ac26_*` (7) | mutated; own fuzz recomputes the released count every step |

**Rejected options:** none implemented. **Constraints:** C1–C17 and G1–G9 hold (C8's
boundary epsilons are ASSUMPTION-6). **Deviation audit:** DEV-1 to DEV-12 each justified; the
pre-existing test files changed are exactly the three §8 lists, additions only; no unlogged
deviation beyond the two small choices of CR-8. **Assumptions 1–12:** reasonable and
reversible (ASSUMPTION-5: see CR-5).

### Findings

### CR-1 🟡 An arrival can be put on the far side of a wall, where its walk to the player is long and it holds a cap slot  ·  `data/floors/floor_2/room_4.tres`, `src/core/floors/room_waves.gd:129-160`; smaller in `floor_3/room_1.tres`
C8 measures straight lines. Verified by a scene probe in room 2-4: with the player at
(54.5, 11.5) a chaser arrived 8.5 tiles away in a straight line and reached the player after
19.2 s, a caster had a clear line after 20.7 s, and with 3 of 3 engaged nothing else was sent.
By a path script over every walkable tile: in room 2-4's middle lane a first, second or third
choice with a walk of 30 tiles or more from 32 % / 37 % / 46 % of tiles (worst 60.9 tiles); in
room 3-1 a walk of 20 or more from 6–8 % of tiles; the other ten rooms never reach 30. The
code does what C8 and C14 (b) say, so it is not a constraint violation; it is a Planner
decision: prefer candidates with a bounded nav path, or bound the walk by a shipped-room rule.
> **Builder reply (lead):** fixed, by both. The Planner (the lead) amended the spec in e01fc23:
> C8 gains a first tier (far enough, inside the box and a walk of at most
> `wave_max_walk_tiles`, 18), C14 gains rule (d), AC27 is new. Code in 1a6b595:
> `NavGrid.walk_distance()` on the lazy field, the tier in `choose_point()`, the director
> reading `view.nav`. Data in 8f9422d: 13 arrival points added in rooms 2-3, 2-4, 3-2, 3-3
> and 3-5 (217 in all), nothing else in the grids changed. Result, over every walkable tile:
> the first choice's walk is at most 17.9 in all 12 rooms (it was 39.9 in room 2-4); in room
> 2-4 the second choice is at most 17.9 and the third is over 18 from 64 tiles (4.2 %), where
> the second and third together were over from about 466. In the six rooms measured (2-3,
> 2-4, 3-1, 3-2, 3-3, 3-5) the third choice is still over 18 from 3 to 12 % of tiles (worst
> 58.9, in 2-4): accepted, it needs two points taken at once near the player (§10 Q4). One
> choice costs one field build: median 3.6 ms in room 3-5, at a warning's start only.

### CR-2 🔵 A test of AC5 cannot fail on its own  ·  `tests/core/enemies/test_f014_waiting.gd:302-312`
The enemy in `test_ac5_hold_in_reserve_on_an_aggroed_enemy…` is in `CHASE`, so `IDLE` alone
refuses it; removing `and not _aggroed` from `_is_fresh()` leaves all 32 tests passing
(mutation survived). The real code does refuse an idle aggroed enemy (ran).
> **Builder reply (lead):** fixed in 6350df5: two tests on an idle aggroed enemy with a fresh combat
> state (one that just arrived, one aggroed by a hit); with `and not _aggroed` removed
> exactly those two fail.

### CR-3 🔵 A dynamic call and a stale comment  ·  `src/ui/debug/combat_debug_draw.gd:81-84`
`has_director()` still asks the sim by name (`has_method`, `call`), with a comment about a
state that ended when the sim got `get_waves()`.
> **Builder reply (lead):** fixed in 6350df5: `return sim.get_waves() != null`.

### CR-4 🔵 The two HUD lines can disagree after a skip in the death pause  ·  `src/world/game.gd:216-217, 140-146`
`_on_room_entered()` returns early when the session is not on the floor ("the session ignored
it, so the HUD does too"), but the kills line is fed every frame anyway. Verified by running:
after `skip_room()` in the death pause the location says room 1 and the kills line counts
room 2. Reachable from code only: the N key is off once the death is reported.
> **Builder reply (lead):** fixed in 1a6b595: the kills line is not fed during the death pause, so it
> keeps what it showed, as the location text does; the comment says so; `test_cr4_*`.

### CR-5 🔵 A director with no placed enemy never starts, though comment, test name and ASSUMPTION-5 say it holds nothing back  ·  `src/core/floors/room_waves.gd:104-105`
Verified by running a rig with 0 placed and 2 in reserve for 20 s: nothing started. Not
reachable through validated data.
> **Builder reply (lead):** fixed in 1a6b595: a director with no placed enemy starts at once; the
> test now runs it and sees both reinforcements arrive. ASSUMPTION-5 is corrected in §8.

### CR-6 🔵 "Reserve" has two meanings  ·  `studio/GLOSSARY.md` against `Room.get_reserve_enemies()`, `RoomWaves._reserve`
The glossary says "reinforcements that have not arrived yet"; the code's reserve holds every
reinforcement, arrived and dead ones included.
> **Builder reply (lead):** fixed in this commit: the glossary's "Reserve" is the room's
> reinforcements as a roster, whatever their state; one that has not arrived is waiting.

### CR-7 🔵 `design/floors.md` says "two to three times the enemies per room"; room 2-1 has four times
The rest of the encounter table matches the 12 data files type by type.
> **Builder reply (lead):** fixed in this commit: "two to four times".

### CR-8 🔵 Two small choices in the code that §8 does not list  ·  `room_waves.gd:385-390, 209-211`
Players at equal distance from a point: the earlier-registered one wins. `restore_errors()`
also refuses "arrivals were started but the fight has not".
> **Builder reply (lead):** logged in this commit as ASSUMPTION-13 and ASSUMPTION-14; (a) is also
> pinned by a test now (1a6b595).

**Tried, found nothing** (the reviewer's list, shortened): a director fuzz on a real sim: 500
random rooms (0–6 placed, 0–20 in reserve, caps 1–6, 2–30 points, random tunables with an
interval and a warning of 0, one or two players), random wakes, kills of placed, arrived,
waiting and pending enemies, player deaths and revivals, at 30, 60 and 120 ticks/s, with a
dozen invariants checked every step: 0 violations, 0 stuck rooms, identical at the three
rates, 500 restored twins identical on every later step (the harness caught 7 of 7 mutants).
A rewind fuzz of 150 rooms. A bot in the real floor scene: all 12 rooms in five styles (kite,
a real sword fight, stand on each arrival point, push on the locked exit, pull every placed
enemy at once), 72 runs: every room cleared at its target with one heal, no engine error. An
arrival exactly on a living enemy: the bodies separate at once.

**Not checked in this round:** how the marker and the HUD line look; two players in a scene;
F5 data reload in a waves room; a staged boss-type enemy as a reinforcement; the reserve's
frame cost; floors 2 and 3 through the real `Game`; manual play.

---

## 10. Open Questions  ·  _Anyone (append)_

| # | Raised by | Question | Blocking? | Answer (Lucas/Planner) |
|---|---|---|---|---|
| Q1 | Lead | → Lucas, at Gate B: the starting values. Kill targets (6 to 15 per room), how many arrive with each placed enemy (1 to 3) and how many are on you at once (2 in the first rooms, 3 later; the wave table), the warning (0.8 s), the pause between arrivals (1.5 s), and whether the heal (30 % per cleared room) still fits rooms with two to four times the enemies. All are data. | no | |
| Q2 | Lead | → Lucas, at Gate B: three things the lead added to what you approved. Reinforcements arrive at marked points near you (never closer than 6 tiles), they come for you at once, and they only start once the fight has (the first enemy noticing you or dying). Each enemy placed in the room brings its share of the reinforcements when it notices you, so every part of the room has its own fight and nothing arrives while you stand still after one. Enemies placed at the start that have not noticed you do not count toward the cap, so walking on can pull more onto you than the cap. Dead enemies vanish in rooms with waves. Right, or change? | no | |
| Q3 | Lead | → Lucas, at Gate B: room 3-1 sends its three brutes one at a time and 3-4 keeps two on you. Is one brute after another the lesson you want in 3-1? | no | |
| Q4 | Lead | → Lucas, at Gate B (code review CR-1): a reinforcement now arrives where its walk to you is short (at most 18 tiles), not only where it is near in a straight line, so it no longer appears behind a wall and takes 20 seconds to come round. When the two best points near you are both in use, the third can still be a long walk in a few places (room 2-4 above all). If a fight ever stalls with the count stuck and nobody coming, that is this: tell me the room. | no | |

---

## 11. Director Notes  ·  _Lucas_

