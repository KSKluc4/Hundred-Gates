---
id: F-013
title: Follow camera, rooms larger than the screen, dash recovery (Gate B playtest, second pair)
status: PLAN_REVIEW      # DRAFT | PLAN_REVIEW | PLAN_CHANGES | APPROVED | IN_PROGRESS | CODE_REVIEW | CODE_CHANGES | DONE | PARKED
owner_now: Auditor       # who must act next: Planner | Auditor | Builder | Lucas
created: 2026-11-19
updated: 2026-11-19
depends_on: [F-001, F-011, F-012, D-010, D-012, D-014, D-015]
pillars: [1, 2]
department: Floors       # studio/design/floors.md; the dash part belongs to Combat (studio/design/combat.md)
---

# F-013 — Follow camera, rooms larger than the screen, dash recovery

> **How to use this file.** This is the single source of truth for this feature.
> Every agent reads the WHOLE file before acting. Write only in the sections you own
> (see studio/README.md). Never delete another role's text — reply under it.
>
> **This feature runs under D-015:** the lead (Claude Code) wrote §1–§6 and gates the work;
> up to two implementer sub-agents write code; only the lead commits and writes §8. Reviews
> are run by the lead with fresh reviewer sub-agents (D-014). The branch is stacked on
> `feature/F-012-the-loop`, which is still at Gate B.

---

## 1. Goal  ·  _Planner_

**Player-facing outcome (one sentence):**
The game world fills the whole screen: the camera follows the player and stops at the room's
walls, every room and the town is larger than one screen so there is space for detail later,
and after a dash the player stands still for a short moment.

**Why now:** Lucas's Gate B playtest of F-011 and F-012 (2026-11-18; F-012 §10 Q12, Q13). He
asked for the playtest points to be fixed two at a time before the next slice. This is the
second pair: his points 4 (dash), 5 and 6 (the map on the whole screen, space for room design).

**Out of scope (explicitly):**
- Waves and a kill target per room (his point 3, F-012 §10 Q11): the next pair.
- More enemies per room. Enemy lists stay as they are, so the bigger rooms will feel emptier
  until the waves feature.
- A decoration layer, props, tiles, any art (Art & Game Feel). This feature only makes the space.
- Camera look-ahead, a dead zone, zoom, room transition effects (FX4).
- A fullscreen window mode.
- The cameras and layouts of the debug scenes `f001` to `f009`.
- Any change to the dash's distance, duration, i-frames or cooldown.

---

## 2. Context  ·  _Planner_

What the Builder needs to know that isn't obvious from the code:

- **Lucas's words.** Playtest: "the map of the game I actually want to be in the whole
  screen"; "in the future I wanna add more design for the room etc so that's why I wanna the
  room to be full screen"; "The dash that the player has need to have a recovery". Asked whether
  he meant one-screen rooms with a fixed camera, he answered no and explained: "I wanna a
  tipical camera for a 2D camera but at same time we need to keep in mind that the town and the
  enimies rooms will have details". The lead proposed what §3 chooses; he answered: "I liked
  all the idea for the rooms and for the dash just a short end-lag yeah so go ahead with that".
- **Why the screen looks empty today.** The viewport is 640 × 360 px (`project.godot`), a tile is
  16 px (`Units.TILE_SIZE_PX`), so one screen is 40 × 22.5 tiles. Every shipped room is smaller
  (20 × 12 to 32 × 16; the town is 24 × 14). The camera is a `PlaceholderShake` (`Camera2D`)
  that `Room._build_player()` adds as a child of the player: it is centred on the player, has
  no limits and no smoothing, so it shows the empty space around the room.
- **Size limits are tunables.** `FloorTunables.min_room_size` (8 × 6) and `max_room_size`
  (40 × 22) in `data/tunables/floors.tres`. `FloorScene`, `TownScene` and `Game` validate with
  the shipped `Tunables.floors`, and almost every test builds small fixture rooms (12 × 8 and
  similar: `tests/core/floors/room_fixtures.gd`, `tower_fixtures.gd`,
  `tests/fixtures/floors/floor_fixtures.gd`).
- **The tower.** `Game` loads `data/floors/tower.tres` (`TowerData`: the town and the floors)
  and builds nothing when `TowerData.validate()` returns an error (F-012 AC32).
- **Camera shake.** `PlaceholderShake` moves `Camera2D.offset` by up to
  `ScreenShakeSettings.max_offset_px` (6 px shipped). In Godot the offset is applied after the
  limits, so a shake at a room edge can show up to 6 px outside the room.
- **Enemy ranges** (`data/enemies/*.tres`): aggro 6 tiles (chaser), 8 (caster), 7 (brute),
  10 (bosses). An enemy further away than that stands still until the player comes close. A
  charge runs up to 6 tiles for the brute (`brute_charge.tres`, `lunge_tiles`) and 7 for the
  Juggernaut, and stuns the charger when a wall stops it (`design/combat.md`); a pillar
  counts as a wall (F-011 §10 Q4).
- **The dash today** (`src/core/player/player_motor.gd`, `data/classes/warrior.tres`): 3 tiles
  in 0.15 s, i-frames for the first 0.11 s, cooldown 0.35 s starting when the dash ends. When
  the dash ends the motor goes straight to `IDLE`: the player can walk and attack at once.
  The dash values are latched when a dash fires (F-001/C17). The motor consumes time in exact
  segments (F-001/C15), which is what keeps it tick-rate independent (G1).
- **Navigation cost** (measured in plan review round 1, on this machine's console binary,
  which is a debug build). `NavGrid` builds a flow field over the whole room (a Dijkstra pass
  in GDScript) whenever the target's tile changes and a chasing enemy's straight line is
  blocked: 5.0 ms in today's largest room (32 × 16), 14 ms at 48 × 28, 20 ms at 56 × 32 and
  26–27 ms at 64 × 36, which is more than one 60 Hz frame. `has_clear_line()` scans the whole
  bounding box of its segment and runs per chasing enemy per combat step (120 a second):
  0.125 ms corner to corner at 32 × 16, 0.65 ms at 64 × 36.
- **Who uses the shipped Warrior in tests.** `tests/core/player/motor_harness.gd` and
  `tests/core/combat/combat_arena.gd` build their motor from a copy of `warrior.tres`, so
  F-001's and F-003's core tests see whatever the shipped file says. The scene tests of
  F-001 to F-009 run the real player scene.
- **Buffers.** `input_buffer_window` is 0.12 s (`player_combat.tres`). A press made during a
  dash is buffered and today fires the instant the dash ends (F-003 AC5).
- Relevant prior decisions: D-012 (rooms are data), D-006 (death and re-entry), D-007 (combat
  step grid), D-010 and D-015 (who writes), D-014 (who reviews).
- Relevant prior features: F-001 (movement and dash), F-003 (attack chain, buffers), F-011
  (rooms, `Room`, `FloorScene`), F-012 (town, `Game`, HUD).

---

## 3. Options Considered  ·  _Planner_

> This section is what stops context loss. Be honest about trade-offs.
> The Builder MUST NOT implement anything listed under Rejected.

### ✅ Chosen: the player's camera gets limits and smoothing; rooms are redrawn larger; the tower names its smallest room; the dash gets a rooted recovery

- **How it works:**
  - *Camera.* `Room` configures the `PlaceholderShake` it already creates: limits from the
    room's outer rectangle, engine position smoothing from a new `CameraTunables` file. Where a
    room is narrower or lower than the screen (fixtures, debug scenes) it is centred on that
    axis. Four wall-coloured strips just outside the room hide what a shake would uncover.
  - *Rooms.* The 15 tower rooms and the town are redrawn at the sizes in §4/C9, each keeping
    its layout idea and its enemy list. `max_room_size` goes to 80 × 46.
  - *The one-screen rule.* `TowerData` gains `screen_size_tiles`. The shipped tower sets
    40 × 23 (one screen, rounded up), and `TowerData.validate()` refuses a town or room
    smaller than that, so the game does not start on such a tower. Fixture towers leave it
    at zero.
  - *Navigation.* `NavGrid` gets faster without changing a single result (C17), because the
    new rooms would otherwise cost more than a frame per flow-field build.
  - *Dash.* `ClassData.dash_recovery_duration` (0.12 s for the Warrior). After a dash that ran
    its full length the motor is in a new state `DASH_RECOVERY`: no movement, no attack, no
    dash; presses are buffered, the buffers' clocks stop while it lasts, and a buffered action
    fires when it ends. A value of 0 is today's behaviour.
- **Why chosen:** It is what Lucas approved in chat. It reuses the engine camera and the
  existing validation path, and it leaves every fixture and debug scene as it is.
- **Costs we're accepting:**
  - The rooms hold the same few enemies in three to five times the floor, until waves arrive.
  - 16 hand-drawn grids are replaced, and the tests that pin their coordinates with them.
  - The one-screen rule lives on the tower data, not with the other room rules, because the
    other rules are also applied to test fixtures.
  - The recovery makes the dash a commitment: 0.12 s rooted and vulnerable after every dash.
    "Dash in and attack" now lands 0.12 s later than it did.
  - Smoothing means the camera trails a dash by a few frames. A teleport of the player inside
    a living room (a snapshot restore, a test helper) glides instead of cutting; the game
    itself only moves the player that way by a tile at the town gate.
  - **Overrides `design/floors.md`, Town:** `P` moves from the lower half to the upper part
    (so the gate is on screen at the start: the view is 22.5 rows of 36), and four blocks are
    added to the two it had.
  - **Overrides `design/floors.md`, encounter table:** the Juggernaut's room and the brute
    rooms are no longer open; they get blocks (C10 b, §10 Q2).
  - **Changes `design/combat.md`, Dash:** "when the dash ends … velocity continues from
    current movement input" becomes true only after the recovery.
- **Would revisit if:** Lucas finds the camera floaty or the recovery stiff at Gate B (both
  are data: `camera.tres`, `warrior.tres`), or navigation still costs frames in the big rooms
  after C17.

### ❌ Rejected: every room exactly one screen, fixed camera
- **How it would work:** all rooms 40 × 22, the camera never moves.
- **Why rejected:** Lucas rejected it in chat ("No, let me explain", then "a typical 2D camera").
- **Tempting because:** no camera work at all, and every room is fully visible.

### ❌ Rejected: raise `FloorTunables.min_room_size` to one screen
- **How it would work:** one number in `floors.tres`; `RoomData.validate()` already checks it.
- **Why rejected:** the scenes validate every room against the shipped file, fixtures included.
  Every fixture room and most scene tests would become invalid, and several hundred tests would
  be rewritten around a rule that is about shipped content, not about what a room is.
- **Tempting because:** the rule would sit next to the other room rules.

### ❌ Rejected: zoom the camera until today's rooms fill the screen
- **How it would work:** a zoom per room, computed from its size.
- **Why rejected:** the player, enemies and telegraphs would change size from room to room,
  integer pixel scaling breaks, and no space for detail is gained, which was the point.
- **Tempting because:** no room is redrawn.

### ❌ Rejected: a camera node of its own in `Room`, following the player from script
- **How it would work:** `Room` owns a camera and moves it every frame with its own smoothing.
- **Why rejected:** it re-implements what `Camera2D` does, and the shake wiring
  (`CombatRunner.shake_path`, the debug scenes) would have to move with it.
- **Tempting because:** look-ahead and dead zones would be easy to add later.

### ❌ Rejected: a longer dash cooldown and no recovery
- **How it would work:** `dash_cooldown` 0.35 → about 0.6 s.
- **Why rejected:** Lucas chose the end-lag ("just a short end-lag"). The cooldown is unchanged.
- **Tempting because:** one number, no code.

### ❌ Rejected: a recovery that blocks attack and dash but lets the player walk
- **How it would work:** as chosen, but movement input stays live.
- **Why rejected:** the dash cooldown already blocks the next dash for longer than that, so
  only the attack would be delayed and the dash would still cost no position.
- **Tempting because:** it feels less stiff.

### ❌ Rejected: replace `NavGrid`'s routing with the engine's `AStarGrid2D`
- **How it would work:** core asks the engine class for a path per enemy.
- **Why rejected:** routes and tie-breaks would change, and F-011's routing tests and the
  behaviour Lucas played with them. It is a redesign of D-012's core, not a cost fix.
- **Tempting because:** native speed, and it is a `RefCounted`, so core purity would pass.

### ❌ Rejected: let the dash and attack buffers keep ageing during the recovery
- **How it would work:** nothing special: presses go into the buffers as always.
- **Why rejected:** the buffer window (0.12 s) is not longer than the recovery (0.12 s), so
  an attack pressed at any point of a dash would be dropped before it could fire, and "dash
  in, press attack once" would read as eaten input (plan review PR-1).
- **Tempting because:** it is what "into the existing buffers" does with no extra rule.

### ❌ Rejected: add enemies now so the bigger rooms feel full
- **How it would work:** raise the enemy counts per room and `max_enemies_per_room`.
- **Why rejected:** the waves feature decides how a room is filled; the encounter tables would
  be rewritten twice.
- **Tempting because:** the rooms would feel right at this Gate B already.

---

## 4. Constraints  ·  _Planner_

Hard rules for this feature. Violating any of these = automatic `CODE_CHANGES`.

| ID | Constraint | Reason |
|---|---|---|
| C1 | The camera is presentation only. Nothing in `src/core/` reads it, and no game rule depends on what is on screen. | G6 |
| C2 | Camera limits come from one static, side-effect-free function on `Room`: `camera_limits_px(room_size_tiles: Vector2i, view_size_px: Vector2i) -> Rect2i`. With `room_px = room_size_tiles * Units.TILE_SIZE_PX`: on an axis where `room_px >= view_px` the limits are 0 and `room_px`. On an axis where it is smaller, the range starts at `floori((room_px - view_px) / 2.0)` and is `view_px` long, so the room sits in the middle of the screen on that axis. `Room` applies the result to the `PlaceholderShake` it creates (`limit_left/top/right/bottom`), with the viewport's visible size as the view. `limit_smoothed` stays false. | One place to test; fixtures and debug scenes stay usable |
| C3 | Camera settings live in a new `CameraTunables` resource, `data/tunables/camera.tres`, reachable as `Tunables.camera` and by a path constant: `follow_smoothing_enabled` (true), `follow_smoothing_speed` (8.0, the engine's `position_smoothing_speed`), `outside_margin_tiles` (2). `validate()`: speed > 0, margin ≥ 0. No camera number is hardcoded. The room's camera uses the physics process callback (`Camera2D.CAMERA2D_PROCESS_PHYSICS`), because the bodies it follows move in `_physics_process`. | G2, G5; a smoothed camera on the idle callback jitters against a body moved by physics (plan review PR-11) |
| C4 | A room's camera is current and on its limited target in the first frame the room is shown, however the room was reached (door, debug keys N and R, death, town to floor, floor to town). The camera never glides in from another room's position or from the origin. This holds because every such path builds a new room; a teleport inside a living room is not covered (§3, costs). | The first playtest's corner bug (F-011 DEV-13) must not come back in another form |
| C5 | `Room` draws four wall-coloured strips, `outside_margin_tiles` wide, just outside the room's outer rectangle (visual only: no collision, not in the nav grid). The shipped margin in px is at least the shipped `ScreenShakeSettings.max_offset_px`; a test checks it. | A shake at a room edge must not show empty space |
| C6 | `PlaceholderShake`'s own behaviour (shake, settings, toggle) and the debug scenes `f001`–`f009` are unchanged. `CombatRunner.shake_path` wiring is unchanged. | Must not break F-003 |
| C7 | `TowerData.screen_size_tiles: Vector2i`, default `Vector2i.ZERO` (no rule): the screen this tower is built for, in tiles, rounded up. `TowerData.validate()` adds one error per town or floor room narrower or lower than it: `town: screen: room <id> is W x H, smaller than one screen (SW x SH)` and `floor <n>: screen: room <id> is …`. The shipped `tower.tres` sets `Vector2i(40, 23)`. A test checks that the shipped value covers the project viewport (`ceil(viewport / Units.TILE_SIZE_PX)` on both axes). | The one-screen rule, without touching fixtures. Named apart from `FloorTunables.min_room_size`, which means "what can be built at all" |
| C8 | `FloorTunables.min_room_size` stays 8 × 6. The shipped `max_room_size` becomes 80 × 46. Every other room rule of F-011/C16 and F-012/C8 is unchanged and every shipped room passes all of them. | §3 |
| C9 | The shipped rooms are redrawn as the table below this one gives, each keeping its enemy list (same `EnemyData`, same counts). Where the table leaves a position open, the implementer chooses, within the rules of C10. The lead looks at every grid before the tests that pin it are committed. | What Lucas approved; plan review PR-7 |
| C10 | Shipped-room rules, each checked by a test over every shipped room it applies to. **New:** (a) in a combat room at least one spawn is near `P` when the room starts: within 18 tiles horizontally and 9 vertically, centre to centre. That is stricter than "on screen" (from a `P` at the west wall the limited camera shows 40 columns), on purpose: the first target is close. (b) In a room with a brute or the Juggernaut no walkable tile is more than 8 tiles (the larger of the x and y distance) from a wall tile, so the player is never far from something to put behind them; this is a spacing rule of thumb, not a proof that every charge can be baited. (c) The Juggernaut's room holds an all-walkable rectangle 20 tiles wide and 12 high that contains the boss's spawn tile. (d) No attack starts off screen: the longest range at which any shipped enemy starts an attack is below 11 tiles (half a screen's height is 11.25). **Kept from F-011, still binding on the redraw:** spawns at least 1.5 tiles apart; every spawn outside its own aggro radius from `P`; `P` and `E` on opposite sides; room 1-3's two pairs more than 7 tiles apart and its wall's two gaps; floor 2's casters behind chasers or behind cover; the long straight lane of the floor 3 brute rooms; the Warden's room has no interior wall; the Hexer's room has exactly four separate 2 × 2 blocks, the Hexer in the clear area between them, that area an arena as the existing test defines it, and a block breaking the straight line from the Hexer to `P`. **Replaced:** see C16. | The bigger rooms must still teach what the small ones did; plan review PR-5, PR-6, PR-14 |
| C11 | The town is 64 × 36. The tower gate is 4 tiles wide on the north border, tiles x 30 to 33. `P` is the tile (32, 9), so the gate is on screen at the start. Blocks: 2 × 2 at tiles (26..27, 4..5) and (36..37, 4..5) flanking the path, and 3 × 3 at (14..16, 20..22), (47..49, 20..22), (14..16, 28..30), (47..49, 28..30). Nothing else. It stays a safe room and every F-012 gate behaviour is unchanged. This overrides two lines of `design/floors.md`, Town (§3, costs). | Lucas approved "about 64 × 36, gate on the north wall"; the rest is the lead's layout (§10 Q1) |
| C12 | `ClassData.dash_recovery_duration: float`, seconds, default 0.0, `validate()` refuses a negative value. `data/classes/warrior.tres` sets 0.12. | G2; a default of 0 keeps every fixture's behaviour |
| C13 | Dash recovery rules. (a) It starts at the instant a dash completes its full duration, and only then: a dash ended by a hit has none. (b) It is a new `PlayerMotor.State.DASH_RECOVERY`, appended after `KNOCKBACK` so existing values keep their numbers. When `dash_ended` is emitted the state already reads `DASH_RECOVERY` (or `IDLE` when the latched duration is 0, as today). (c) While it lasts: velocity is zero, movement input is ignored, no attack and no dash can fire, presses go into the existing buffers, **the ages of both buffers do not advance** (as during hitstop; decided per time segment from the state at the segment's start, so the dash's own last segment still ages them), facing still updates, the dash cooldown keeps counting (it started when the dash ended, as before). (d) It ends exactly `dash_recovery_duration` after it started, in the motor's exact time segments; a buffered action that is allowed fires at that same instant, by the existing rule (the dash wins over the attack). An attack buffered during the dash and still inside its window when the dash ended therefore fires when the recovery ends. (e) A hit during recovery ends it and is handled as any other hit. (f) The duration is latched when the dash fires, with the other dash values (F-001/C17). (g) With a latched value of 0 the state is never entered and the motor behaves exactly as before this feature. (h) I-frames are unchanged: the player can be hit during recovery. | `design/combat.md`, Dash and principle 3; G1; plan review PR-1 |
| C14 | The recovery is part of the snapshot: `SNAPSHOT_KEYS`, `to_dict` and `from_dict` gain `dash_recovery_duration` (the latched value) and `dash_recovery_remaining`. A snapshot taken in mid-dash restores a dash that is followed by the same recovery; one taken in mid-recovery restores the same remaining time. | G7; plan review PR-10 |
| C15 | No signal is removed or renamed. `dash_ended` is still emitted when the dash motion ends. | F-001 views and tests |
| C16 | The old suite stays the proof that nothing else moved. A pre-existing test changes only as listed here, and every change is listed in §8 with its reason. **(1) Helpers:** `tests/core/player/motor_harness.gd` and `tests/core/combat/combat_arena.gd` set `dash_recovery_duration = 0.0` on their copy of the Warrior, so F-001's and F-003's core tests and their hand-worked timings stay as they are. A scene test of F-001 to F-009 that dashes with the real player scene does the same on a duplicate of its player's class data, never on the cached resource itself (known case: `tests/scenes/test_f003_physics.gd`, the F-003 AC22 timing, through `F003SceneTest.spawn(prepare)`); only where a helper offers no such hook is the expected value recomputed by hand, with the working in §8. **(2) Geometry pins** of the shipped rooms and town (coordinates, sizes) follow the new grids. **(3) Rule pins replaced:** `test_pin_every_room_fits_one_screen` (removed in T2; its successor is C7's rule and AC9, which arrive in T6 when every room is redrawn); `test_pin_every_room_is_within_two_tiles_of_the_design_table` (now: exactly the C9 table's size, floor by floor as T2 to T4 land); `test_ac27_juggernaut_room_has_no_interior_wall_and_enough_open_floor` (now C10 b and c); in `test_shipped_tower.gd`: `…town_is_24_by_14…`, `…player_start_is_in_the_lower_half`, `…town_has_exactly_two_two_by_two_blocks`, `…blocks_are_symmetric_about_the_gate_centre_line`, `…blocks_flank_the_path…` (now C11: six blocks, still symmetric about the gate's centre line, the two 2 × 2 ones flanking the path). **(4) The shipped value** of `max_room_size` where a test pins it. Every other pre-existing test, and every test built on fixtures, passes unchanged. | Plan review PR-4, PR-5 |
| C17 | `NavGrid` gets cheaper **without changing any result**. At least: (a) The allowed steps of every tile are computed once, in `from_rows()`. (b) The flow field is settled lazily: `direction_toward()` runs the Dijkstra pass only until the tiles it reads are final, and a later call for the same goal resumes it. (c) `has_clear_line()` visits only the tiles the swept segment can touch. Any further change is allowed if the proof passes (the review's prototype needed the heap's push and pop written in place to reach the target). Proof: a copy of today's `nav_grid.gd` is kept under `tests/` as a reference, and on the fixture rooms and a 64 × 36 room with blocks `direction_toward()` and `has_clear_line()` return exactly what the reference returns, for seeded random inputs: at least 100 goals per room with at least 8 askers per goal in varying order, so that a half-settled field is resumed, with askers and goals inside walls, outside the grid, next to the goal and in a sealed pocket among them; and at least 2,000 line checks per room including segments between tile centres, axis-aligned and exactly diagonal ones, at radius 0 and at the bodies' radii. `get_field_builds()` keeps its meaning (one per new goal). The cost of both calls before and after, in T8's own 64 × 36 room with blocks, is recorded in §8, by the asker's distance (8, 24 tiles, across the room). **Worst case, measured by the lead after T4 on room 3-5:** the player's tile changes in a tick while an enemy chases from the far side of the room behind blocks. **Target:** that tick's navigation work stays under 8 ms on this machine's console binary. If the target is missed, it becomes a blocking §10 question for Lucas with the numbers; no redesign inside this feature. | A flow-field build in the new rooms costs 14–27 ms today (plan review PR-2) |
| C18 | No new third-party dependency, no new autoload, no new input action. | G4 |

**Room table for C9.** Sizes in tiles, border included. Every room keeps what it has today:
`P` on tile x 1 or 2 (the kept pin wants its centre within 3 tiles of the west wall), at mid
height except in the Hexer's room, and a 2-tile `E` on the east border at mid height. "On
screen" in a row means near `P` as C10 (a) defines it. Free-standing pillars and blocks are
at least 2 × 2 and at least 2 tiles from any wall or other block; the dividing wall of 1-3
and the slabs of 2-4 touch the outer wall.

| Room | Size | Enemies (unchanged) | Layout |
|---|---|---|---|
| 1-1 | 48 × 28 | 2 chasers | Open, no interior wall. Both chasers on screen, at least 6 tiles apart. |
| 1-2 | 52 × 28 | 3 chasers | Four 3 × 3 pillars in a loose square around the middle. One chaser on screen, two beyond the pillars. |
| 1-3 | 56 × 30 | 4 chasers | A dividing wall 2 tiles thick across the room near the middle, with two gaps. One pair west of it, on screen; one pair east of it; the pairs more than 7 tiles apart. |
| 1 boss | 56 × 32 | Warden | Open, no interior wall. The Warden 12 to 18 tiles east of `P`. |
| 2-1 | 48 × 28 | 2 chasers, 1 caster | Open. Chasers on screen; the caster behind them, further east. |
| 2-2 | 52 × 30 | 2 chasers, 2 casters | Six pillars (2 × 2 or 3 × 3) in two rows. Chasers in front; each caster behind a pillar. |
| 2-3 | 64 × 28 | 1 chaser, 3 casters | A long room. At least five blocks staggered along its length to advance between. The chaser on screen; the casters in the east third. |
| 2-4 | 56 × 32 | 3 chasers, 2 casters | Two wall slabs 2 tiles thick run west from the east wall and form a north and a south alcove; one caster in each. Chasers in the open part, one on screen. |
| 2 boss | 56 × 32 | Hexer | Exactly four 2 × 2 blocks in a square around the room's centre; the Hexer in the clear area between them. `P` stays in the north-west corner, tile (2, 2), as today, so a block breaks the line from the Hexer to `P`. |
| 3-1 | 48 × 28 | 1 brute | Two long interior walls (2 thick, at least 14 long) parallel to the long side, leaving a straight lane of at least 14 tiles: learn the wall stun. The brute on screen. |
| 3-2 | 52 × 30 | 1 brute, 2 chasers | Six 3 × 3 pillars in two rows. The brute on screen. |
| 3-3 | 56 × 30 | 1 brute, 2 casters | Blocks through the room; the casters behind blocks in the east part; the brute within 18 tiles of `P` and more than 7 away (it is the spawn C10 a needs). |
| 3-4 | 60 × 32 | 2 brutes | A row of blocks along the middle of the long axis splits the room into two lanes, one brute in each. |
| 3-5 | 64 × 36 | 1 brute, 2 chasers, 2 casters | Pillars throughout and a back row: chasers first, the brute in the middle, the casters at the east end behind cover. |
| 3 boss | 56 × 32 | Juggernaut | A clear floor of at least 20 × 12 around the Juggernaut (C10 c), ringed by blocks so C10 (b) holds. The Juggernaut 12 to 18 tiles east of `P`. |

**Must not break:** every F-011 and F-012 behaviour (room clear, healing and its `+N HP`
message, the gate list, death returning to town, re-entry at the boss, the debug keys); the
debug scenes; snapshots of a room; tick-rate independence of the motor; the F-011 DEV-13 fix
(old rooms are removed and freed with `queue_free()`); the routes enemies take (C17).

---

## 5. Acceptance Criteria  ·  _Planner_

Testable, observable. The Auditor checks each one.

In the camera criteria, "settled" means: the test turned the room's shake off, then called
`reset_smoothing()` and `force_update_scroll()` on the camera. The camera's place is read with
`get_screen_center_position()`.

**Camera**
- [ ] AC1: `Room.camera_limits_px()` returns the room's outer rectangle in px for a room at least one view large on both axes, and a view-long range centred on the room on an axis where the room is smaller (cases: 64 × 36, 40 × 23, 12 × 8, 64 × 12 and 12 × 36, against a 640 × 360 view, and 12 × 8 against a 641 × 361 view for the rounding).
- [ ] AC2: In a 48 × 28 and a 64 × 36 room built by the test (a `Room` on a `RoomData`, no floor scene), with the player placed at each corner of the walkable floor and at the centre, the settled visible rectangle lies inside the room's outer rectangle. The same check runs on the smallest and the largest shipped room once they exist (T6).
- [ ] AC3: In those rooms, with the player at least half a view from every wall, the settled camera centre is the player's position (within 1 px).
- [ ] AC4: In a 12 × 8 fixture room the settled room is centred on the screen wherever the player stands.
- [ ] AC5: One physics frame after a room is shown, without any settling call, the camera is the viewport's current camera and its centre is the limited target for the player's start; true for a room reached through the door, with N, with R (as key events), after a death in the game, from the town into a floor and from a floor back to the town.
- [ ] AC6: The room's camera has `position_smoothing_enabled` and `position_smoothing_speed` equal to `camera.tres`'s values and the physics process callback. With smoothing off in the tunables, the camera centre equals the limited player position on every physics frame of a walk. `CameraTunables.validate()` refuses a speed of 0 or less and a negative margin.
- [ ] AC7: The four outside strips exist, have the wall colour, cover `outside_margin_tiles` on every side including the corners, and have no collision. The shipped margin in px is at least the shipped shake `max_offset_px`.
- [ ] AC8: A hit still shakes the camera in a `Room` (non-zero offset limit after a hit), and the HUD and the boss bar keep their screen position while the player crosses a room larger than the view.

**Rooms and town**
- [ ] AC9: The shipped tower is valid, its `screen_size_tiles` is `(40, 23)` and covers the viewport, and every room has exactly the size the C9 table gives.
- [ ] AC10: A tower with a room or a town smaller than its `screen_size_tiles` reports the error C7 describes, names the room, and `Game` builds nothing on it. A tower that leaves it at zero accepts any room `FloorTunables` accepts.
- [ ] AC11: Every shipped room has the same enemy list as before (the table in `design/floors.md`).
- [ ] AC12: Each rule of C10, new and kept, holds for every shipped room it applies to.
- [ ] AC13: The town matches C11 and every F-012 gate behaviour passes on it.
- [ ] AC14: On the new rooms, F-011's path test (`test_shipped_floors.gd`, every spawn has a tile path to the player start) and its wake test (`test_f011_shipped_floors.gd`: an enemy woken by a hit acts and leaves its spawn tile) pass.
- [ ] AC15: F-012's scripted runs of floors 1 to 3 (`put_player_at_door()`, `skip_to_boss()`) pass on the new rooms without a change to the tests' logic.
- [ ] AC16: C17's equivalence tests pass, and the before and after costs are in §8.

**Dash recovery** (fixture values are named where the shipped ones cannot show the rule)
- [ ] AC17: With the Warrior's shipped data, at the instant a full dash ends the state is `DASH_RECOVERY`, also when read inside a `dash_ended` handler, and for 0.12 s the position does not change whatever the movement input.
- [ ] AC18: An attack pressed during recovery starts at the instant recovery ends and not before. An attack pressed during the dash, at most `input_buffer_window` before the dash ends, also starts at that instant. With a recovery of 0.12 s and a cooldown of 0.05 s, a dash pressed during recovery fires at the instant recovery ends; with a cooldown of 0.20 s it fires when the cooldown ends; with the shipped cooldown (0.35 s) it never fires, because the press is older than the buffer window by then. Each case gives the same times at 30, 60 and 120 ticks per second.
- [ ] AC19: The recovery ends at the same motor time, with the same position, at 30, 60, 120 and 240 ticks per second.
- [ ] AC20: With `dash_recovery_duration` 0 the state is never `DASH_RECOVERY`. F-001's and F-003's core tests pass with no change other than the two helper lines of C16 (1).
- [ ] AC21: A hit during recovery applies its damage and knockback and ends the recovery. A dash ended by a hit is followed by no recovery.
- [ ] AC22: A snapshot taken in mid-recovery, restored into a new motor, ends its recovery at the same instant as the original. A snapshot taken in mid-dash, restored into a new motor, is followed by the same recovery.
- [ ] AC23: Changing the class data in mid-dash does not change that dash's recovery; the next dash uses the new value.
- [ ] AC24: The i-frame window of a dash is the same as before, and a hit that lands during recovery is not blocked.
- [ ] AC25: `ClassData.validate()` refuses a negative `dash_recovery_duration`.
- [ ] AC26: During recovery the facing follows the aim input, and the dash cooldown has run down by the recovery's length when it ends.

**Whole feature**
- [ ] AC27: `tools/test` passes; `gdlint` and `gdformat --check` are clean; `tools/check_core_purity` passes; `scenes/main.tscn` starts headless with no error.

**How to verify manually:** Start the game. In the town the room fills the window, the gate
is at the top of the screen and the view scrolls when you walk south or sideways; no empty
space is ever visible. Enter floor 1: the camera follows you and stops at the walls. Dash:
the player stops dead for a moment after each dash, and walking or attacking only starts after
it. Dash at an enemy and press attack once during the dash: the attack comes out. Take a hit
near a wall: the shake shows no empty space.

---

## 6. Task Breakdown  ·  _Planner_

Small, ordered, each independently committable. "A" and "B" are the two implementers; their
file lists never overlap while both work. A test file on another task's list is changed only
through the lead.

| # | Task | Files likely touched | Notes |
|---|---|---|---|
| T1 | Camera: `CameraTunables` and its file, `Tunables.camera`, `Room.camera_limits_px()`, limits, smoothing and callback on the room's camera, the outside strips. Tests AC1–AC8 in new files, on rooms the tests build (48 × 28, 64 × 36, 12 × 8) and on fixture towers. | `src/core/tunables/camera_tunables.gd`, `data/tunables/camera.tres`, `src/autoload/tunables.gd`, `src/world/floors/room.gd`, `tests/core/test_camera_tunables.gd`, `tests/scenes/test_f013_camera.gd` | A. Where a test needs a `Game` on a room larger than the shipped `max_room_size` allows before T2 lands (AC8), it raises `Tunables.floors.max_room_size` for its own duration and restores it, as `F012GameTest` does with the tower tunables. |
| T2 | Rooms, part 1: `max_room_size` 80 × 46; the town (C11) and floor 1 (C9); their geometry and rule pins (C16 2–4). | `data/tunables/floors.tres`, `data/floors/town.tres`, `data/floors/floor_1/**`, `tests/core/floors/test_shipped_tower.gd`, `tests/core/floors/test_shipped_floors.gd`, `tests/core/floors/test_floor_tunables.gd`, scene tests only where they pin these coordinates | B. A generator script in the scratchpad may draw the grids; only `.tres` files are committed. The grids go to the lead before the pins are written (C9). |
| T3 | Rooms, part 2: floor 2. | `data/floors/floor_2/**`, the same two shipped test files | B |
| T4 | Rooms, part 3: floor 3; the C10 rule tests over all rooms; AC14's core test. | `data/floors/floor_3/**`, the same two shipped test files, `tests/scenes/test_f011_shipped_floors.gd` where it pins coordinates | B |
| T5 | The one-screen rule: `TowerData.screen_size_tiles`, its errors, tests on fixtures (AC10). | `src/core/floors/tower_data.gd`, `tests/core/floors/test_tower_data.gd` (new tests appended), `tests/scenes/test_f013_tower_rule.gd` for the `Game` case | A, after T1. Does not set the shipped value. |
| T6 | Set `screen_size_tiles = Vector2i(40, 23)` in `data/floors/tower.tres`; the shipped tests of AC9; AC2's shipped-room pass. | `data/floors/tower.tres`, `tests/core/floors/test_shipped_tower.gd`, `tests/scenes/test_f013_camera.gd` | B, after T4 and T5 are committed (T1 is committed by then, so `test_f013_camera.gd` is free). |
| T7 | Dash recovery in core, the Warrior's value, tests AC17–AC26 in a new file; the helper lines and the scene-test changes of C16 (1). | `src/core/classes/class_data.gd`, `src/core/player/player_motor.gd`, `data/classes/warrior.tres`, `tests/core/player/test_f013_dash_recovery.gd`, `tests/core/player/motor_harness.gd`, `tests/core/combat/combat_arena.gd`, `tests/scenes/test_f003_physics.gd` and its helper | A, after T5. |
| T8 | Navigation cost (C17): the three changes, the reference copy, the equivalence tests, the before and after timings. | `src/core/floors/nav_grid.gd`, `tests/core/floors/nav_grid_reference.gd`, `tests/core/floors/test_f013_nav_equivalence.gd` | Whoever is free first; before T9's gate. |
| T9 | Final gate: full suite, lint, format, purity, headless boot; a rendered look at the town and one room per floor; a rendered walk at a frame rate other than 60 to look for camera jitter (C3). | — | Lead. |
| T10 | Design docs and glossary: `design/floors.md` (room rules, sizes, encounter table, town), `design/combat.md` (dash recovery), `GLOSSARY.md`. | `studio/design/*.md`, `studio/GLOSSARY.md` | Lead, as Planner. |

---

## 7. Plan Review  ·  _Auditor_

<!-- review-round: 1 verdict: CHANGES_REQUESTED -->

**Date:** 2026-11-19 · **Verdict:** CHANGES_REQUESTED · **By:** Auditor (lead, D-014)

A fresh reviewer sub-agent that wrote neither the spec nor any code, read-only, on commit
`19d2193`. It ran its probes on a scratch copy: the project patched with a minimal recovery
(its reading of C13), a standalone `Camera2D` project, and a timing probe of `NavGrid`.
Three blocking findings, nine "should fix", two suggestions. The lead checked each against
the code before recording it.

### PR-1 🔴 An attack pressed during a dash can never fire once the recovery exists
C13 (c), AC18; `player_motor.gd:140-143, 432-437`; `player_combat.tres`
(`input_buffer_window = 0.12`). Presses go "into the existing buffers", whose age keeps
running; window and recovery are both 0.12 s, so a press made at any point of the 0.15 s dash
is too old when the recovery ends. Verified by running a probe at 120 ticks/s: with recovery 0
presses at 0.05–0.142 s start an attack at the dash end; with 0.12 no press made before 0.15 s
ever fires. It inverts F-003 AC5 and reads as eaten input (principle 3).
> **Planner reply:** accepted. C13 (c) now stops both buffers' clocks during the recovery, as
> in hitstop, and (d) says what follows; the ageing variant is in §3 Rejected; AC18 covers a
> press during the dash; the manual check names "dash in and attack".

### PR-2 🔴 C17's 4 ms threshold is already exceeded; the new rooms cost 14–27 ms per flow-field build
C17, AC16; `nav_grid.gd:156-185, 70-81`; `enemy_brain.gd:60-64`. Measured medians of one
build: 5.0 ms at 32 × 16, 14.3 at 48 × 28, 19.8 at 56 × 32, 26–27 at 64 × 36 (debug console
binary). `has_clear_line()` scans its segment's bounding box per chasing enemy per combat
step: 0.125 ms corner to corner at 32 × 16, 0.65 ms at 64 × 36. "Measured, not optimised in
this feature" had a known answer before any code.
> **Planner reply:** accepted. C17 is now a task (T8): three changes that may not alter a
> single result, proved against a kept copy of today's code, with a target and a blocking
> question for Lucas if it is missed. §2 carries the measurements. The `AStarGrid2D` route is
> in §3 Rejected.

### PR-3 🔴 C11 contradicts the town rules in `design/floors.md` while citing that doc
C11; `design/floors.md:59-61`. The doc says `P` in the lower half and two blocks, "nothing
else"; C11 puts `P` at row 9 of 36 and adds four blocks, without naming the override.
> **Planner reply:** accepted. §3 "Costs" names both overrides of `floors.md` (the town and
> the open brute rooms) and the change to `combat.md`'s dash line; C11 and §10 Q1 say which
> part Lucas approved and which is the lead's layout. T10 updates the docs.

### PR-4 🟡 AC20 could not be true; six existing tests pin the shipped Warrior after a dash
AC20, C16, T5 (now T7); `motor_harness.gd:10-11`, `combat_arena.gd:22` use a copy of the
shipped `warrior.tres`. Verified by running `tests/core` and the scene suites on the patched
copy: `test_player_motor_dash.gd:86`, `test_player_motor_buffer.gd:27`,
`test_player_attack.gd:120`, `test_player_dash_cancel.gd:88`, `test_combat_sim.gd:24`,
`test_f003_physics.gd:15`.
> **Planner reply:** accepted. C16 (1): the two helpers zero the recovery on their copy, so
> the five core tests and their hand-worked timings stay; the scene case is named, with its
> rule. AC20 says exactly that. The files are on T7's list.

### PR-5 🟡 C16 allowed only coordinate and size pins to change; rule pins break too
`test_shipped_floors.gd:181, 236, 383`; `test_shipped_tower.gd:91, 108, 116, 138`. Also
unstated: which existing pins stay binding on the redraw.
> **Planner reply:** accepted. C16 (3) lists the replaced tests by name; C10 lists the pins
> that stay, including the Hexer's four blocks, which the room table keeps.

### PR-6 🟡 C10 (b) and (c) did not deliver their stated reasons; the brute's charge is 6 tiles, not 7
`brute_charge.tres:8`, `juggernaut_charge_a.tres:9`. From 8 tiles a brute cannot reach the
wall; the "larger of x and y" distance also accepts a wall 11.3 tiles away. "A clear floor of
20 × 12" had no definition once blocks exist.
> **Planner reply:** accepted. §2 has the right lengths. C10 (b) is now stated as a spacing
> rule of thumb and no longer claims every charge can be baited; (c) is "an all-walkable
> 20 × 12 rectangle that contains the boss's spawn tile". §10 Q2 asks Lucas about the result.

### PR-7 🟡 T2 hid the largest task, and 15 layouts were left to the implementer
> **Planner reply:** accepted. The rooms are three tasks (T2–T4), C9 has a table with each
> room's layout, and the lead looks at every grid before its pins are committed.

### PR-8 🟡 AC2 could not pass on the rooms that exist when T1 runs
> **Planner reply:** accepted. AC2 and AC3 run on rooms the test builds; the shipped pass is
> in T6.

### PR-9 🟡 Five criteria were not testable as written
AC2/AC3 "settled", AC6 "approaches at", AC14's wake test, AC18's second sentence, AC15 "walked".
> **Planner reply:** accepted. §5 defines "settled"; AC6 asserts the camera's properties;
> AC14 is a core check over every spawn plus the existing wake test as it is; AC18 names
> fixture values; AC15 names the helpers the runs use.

### PR-10 🟡 The snapshot rule covered mid-recovery only
> **Planner reply:** accepted. C14 names both keys, AC22 adds the mid-dash case, C13 (b) says
> what `get_state()` reads inside `dash_ended`.

### PR-11 🟡 The camera's process callback was not specified
Not verified by the reviewer (headless cannot show jitter); inferred from the bodies moving in
`_physics_process`.
> **Planner reply:** accepted. C3 sets the physics callback, C2 keeps `limit_smoothed` off,
> AC6 asserts it, and T9 includes a rendered walk at another frame rate.

### PR-12 🟡 Smaller gaps
`TowerData.min_room_size` shared a name with `FloorTunables.min_room_size`; the rounding in C2;
no criterion for "facing still updates" and "cooldown keeps counting".
> **Planner reply:** accepted. The field is `screen_size_tiles`; C2 gives the formula with
> `Units.TILE_SIZE_PX`; AC26 is new.

### PR-13 🔵 The engine facts behind C2–C5 hold in 4.7.2; a teleport inside the tree glides
Verified by the reviewer's probe: a smoothed, limited camera entering the tree is on its
target at once; `offset` is applied after the limits; the headless visible rect is 640 × 360.
> **Planner reply:** noted in C4 and in §3 "Costs"; the camera tests settle explicitly.

### PR-14 🔵 Nothing pinned that no attack starts off screen
> **Planner reply:** accepted as C10 (d).

**Not checked in this round** (the reviewer's list): F-011's and F-012's specs in full;
that a full set of 15 rooms meeting C9, C10 and the surviving pins exists (only the
Juggernaut's, by hand); anything rendered; a release build's navigation timings; whether
Lucas's approval in chat covered the town layout and the 0.12 s (it covered "about 64 × 36"
and "a short end-lag"; the rest is in §10 Q1).

<!-- review-round: 2 verdict: CHANGES_REQUESTED -->

**Date:** 2026-11-19 · **Verdict:** CHANGES_REQUESTED · **By:** Auditor (lead, D-014)

The same reviewer, on commit `a01432b`, read-only, with its scratch copy updated to the
revised C13 and a prototype of the lazy `NavGrid` against a copy of today's code.

**Round 1 findings:** PR-1 ✔ resolved (probe: an attack pressed in the dash from 0.0333 s on,
or in recovery, starts at 0.2700 s at 30, 60 and 120 ticks/s). PR-2 ✔ resolved as a plan
(see PR-18). PR-3 ✔ resolved. PR-4 ✔ resolved (with the two helper lines `tests/core` passes
1042/1042 on the patched copy; of the other suites only `test_f003_physics.gd:15` fails, as
C16 names). PR-5: one test still missing from C16 (3), see the reply under PR-15. PR-6 to
PR-14 ✔ resolved (PR-11 by a second camera probe with the physics callback; PR-14: the largest
`trigger_max_tiles` in `data/attacks/` is 9.0).

**New material, no finding:** C13 (c)/(d) is implementable in four changed lines of
`_run_phases()` plus the new state's advance function. C17 can be exactly equivalent: the
prototype settles until every allowed neighbour of the asker's tile has been popped or the
heap is empty, and differs from today's code in 0 of 5,760 direction calls and 24,000 line
calls over four rooms. Only `test_nav_grid.gd:290-307` reads `get_field_builds()`. The task
file lists do not overlap in the stated order. Every row of the C9 table other than the
Hexer's and 3-3 can be built, by hand arithmetic.

### PR-15 🔴 The Hexer row of the C9 table cannot pass a kept test
`test_shipped_floors.gd:193-197` needs no clear line from the Hexer to `P`; with `P` at mid
height both ends lie in the clear band between the blocks. Today `P` is tile (2, 2). Verified
by brute force: over 35 centred block squares and 9,158 Hexer placements with `P` on rows 15
or 16, none breaks the line. Also: `test_ac25_blocks_are_symmetric_about_the_gate_centre_line`
asserts two blocks and is missing from C16 (3).
> **Planner reply:** accepted. The Hexer row keeps `P` at tile (2, 2); the table's header
> says so; C10's kept list names the cover-line and arena pins; C16 (3) names the symmetry
> test.

### PR-16 🟡 The Hexer is on screen at the start; the table's note and §10 Q3 said it is not
Verified by a camera probe: from the start tile the limited view is columns 0 to 40.
> **Planner reply:** accepted. The note is gone, Q3 is withdrawn in its answer cell, and
> C10 (a) now says it means "near `P`", which is stricter than "on screen", on purpose.

### PR-17 🟡 Row 3-3 contradicted C10 (a) and named chasers the room does not have
> **Planner reply:** accepted. The row now reads "the brute within 18 tiles of `P` and more
> than 7 away".

### PR-18 🟡 C17: the three changes alone miss the target; worst case and proof under-specified
Prototype, 64 × 36 with blocks, one new-goal build by the asker's distance: across the room
26 ms today, 12.1 with the three changes, 5.5 with the heap's push and pop written in place;
24 tiles: 26, 7.5, 3.3; 8.5 tiles: 27, 2.0, 0.9. A clipped `has_clear_line()`: 0.017–0.09 ms.
Random pairs with one goal each almost never resume a half-settled field.
> **Planner reply:** accepted. C17 allows any change that passes the proof, defines the worst
> case and when the lead measures it, and requires several askers per goal in varying order
> with the awkward positions and segments the reviewer lists.

### PR-19 🟡 Three ordering gaps in the task table
> **Planner reply:** accepted. C16 (3) says `fits_one_screen` is removed in T2 and what
> replaces it in T6; T1 may raise `max_room_size` for a test's duration; T6 is B's.

### PR-20 🔵 Smaller spots where the implementer would guess
> **Planner reply:** accepted, all six: the `P` tile, which walls may touch the border,
> AC18's cooldown cases and tick rates, where the freeze is decided, the duplicate rule for
> scene tests with `spawn(prepare)`, and AC14 pointing at the existing path test.

**Not checked in this round** (the reviewer's list): the grids themselves; lint, format and
purity; anything rendered; a release build's timings; two goal-tile changes inside one physics
tick as a worst case for C17.

---

## 8. Implementation Log  ·  _Builder_

**Started:** —  ·  **Branch:** `feature/F-013-camera-rooms-dash` (cut from `feature/F-012-the-loop`, D-015)

### Progress
- [ ] T1
- [ ] T2
- [ ] T3
- [ ] T4
- [ ] T5
- [ ] T6
- [ ] T7
- [ ] T8
- [ ] T9
- [ ] T10

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
| Q1 | Lead | → Lucas, at Gate B: the starting values. Camera smoothing speed 8 (`data/tunables/camera.tres`), dash recovery 0.12 s (`data/classes/warrior.tres`), room sizes and layouts (C9). In the town you approved the size and the gate on the north wall; where you start (just below the gate, so it is on screen) and the six blocks are the lead's layout (C11). | no | |
| Q2 | Lead | → Lucas, at Gate B: the Juggernaut's room and the brute rooms now have blocks to charge into, because an open 56 × 32 room leaves no wall within a charge's reach (C10 b). The old Juggernaut room was open with no interior walls. Is that the fight you want? | no | |
| Q3 | Lead | → Lucas, at Gate B: the Hexer stands at the centre of a 56 × 32 room, so it is not on screen when you enter (the boss bar is). Move it closer, or keep the walk-in? | no | Withdrawn by the lead (plan review PR-16): from the start tile the camera shows 40 columns, so the Hexer at the centre is on screen when you enter. Nothing to decide. |

---

## 11. Director Notes  ·  _Lucas_

