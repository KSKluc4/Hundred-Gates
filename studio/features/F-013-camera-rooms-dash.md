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
  10 (bosses). An enemy further away than that stands still until the player comes close. The
  brute's and the Juggernaut's charge runs up to 7 tiles and stuns the charger when a wall
  stops it (`design/combat.md`); a pillar counts as a wall (F-011 §10 Q4).
- **The dash today** (`src/core/player/player_motor.gd`, `data/classes/warrior.tres`): 3 tiles
  in 0.15 s, i-frames for the first 0.11 s, cooldown 0.35 s starting when the dash ends. When
  the dash ends the motor goes straight to `IDLE`: the player can walk and attack at once.
  The dash values are latched when a dash fires (F-001/C17). The motor consumes time in exact
  segments (F-001/C15), which is what keeps it tick-rate independent (G1).
- **Navigation cost.** `NavGrid` builds a flow field over the whole room (a Dijkstra pass in
  GDScript) whenever the target's tile changes and a straight line is blocked. The largest room
  goes from 32 × 16 = 512 tiles to 64 × 36 = 2,304.
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
  - *The one-screen rule.* `TowerData` gains `min_room_size`. The shipped tower sets 40 × 23
    (one screen, rounded up), and `TowerData.validate()` refuses a town or room smaller than
    that, so the game does not start on such a tower. Fixture towers leave it at zero.
  - *Dash.* `ClassData.dash_recovery_duration` (0.12 s for the Warrior). After a dash that ran
    its full length the motor is in a new state `DASH_RECOVERY`: no movement, no attack, no
    dash; presses are buffered and fire when it ends. A value of 0 is today's behaviour.
- **Why chosen:** It is what Lucas approved in chat. It reuses the engine camera and the
  existing validation path, and it leaves every fixture and debug scene as it is.
- **Costs we're accepting:**
  - The rooms hold the same few enemies in three to five times the floor, until waves arrive.
  - 16 hand-drawn grids are replaced, and the tests that pin their coordinates with them.
  - The one-screen rule lives on the tower data, not with the other room rules, because the
    other rules are also applied to test fixtures.
  - The recovery makes the dash a commitment: 0.12 s rooted and vulnerable after every dash.
  - Smoothing means the camera trails a dash by a few frames.
- **Would revisit if:** Lucas finds the camera floaty or the recovery stiff at Gate B (both
  are data: `camera.tres`, `warrior.tres`), or flow-field builds in the big rooms cost frames
  (C14).

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
| C2 | Camera limits come from one static, side-effect-free function on `Room`: `camera_limits_px(room_size_tiles: Vector2i, view_size_px: Vector2i) -> Rect2i`. On an axis where the room is at least as large as the view, the limits are the room's outer edge (0 and size × 16 px). On an axis where it is smaller, the limits are one view long and centred on the room, so the room sits in the middle of the screen on that axis. `Room` applies the result to the `PlaceholderShake` it creates, with the viewport's visible size as the view. | One place to test; fixtures and debug scenes stay usable |
| C3 | Camera settings live in a new `CameraTunables` resource, `data/tunables/camera.tres`, reachable as `Tunables.camera` and by a path constant: `follow_smoothing_enabled` (true), `follow_smoothing_speed` (8.0, the engine's `position_smoothing_speed`), `outside_margin_tiles` (2). `validate()`: speed > 0, margin ≥ 0. No camera number is hardcoded. | G2, G5 |
| C4 | A room's camera is current and on its limited target in the first frame the room is shown, however the room was reached (door, debug keys N and R, death, town to floor, floor to town). The camera never glides in from another room's position or from the origin. | The first playtest's corner bug (F-011 DEV-13) must not come back in another form |
| C5 | `Room` draws four wall-coloured strips, `outside_margin_tiles` wide, just outside the room's outer rectangle (visual only: no collision, not in the nav grid). The shipped margin in px is at least the shipped `ScreenShakeSettings.max_offset_px`; a test checks it. | A shake at a room edge must not show empty space |
| C6 | `PlaceholderShake`'s own behaviour (shake, settings, toggle) and the debug scenes `f001`–`f009` are unchanged. `CombatRunner.shake_path` wiring is unchanged. | Must not break F-003 |
| C7 | `TowerData.min_room_size: Vector2i`, default `Vector2i.ZERO` (no rule). `TowerData.validate()` adds one error per town or floor room narrower or lower than it: `town: size: room <id> is W x H, this tower needs at least MW x MH` and `floor <n>: size: room <id> is …`. The shipped `tower.tres` sets `Vector2i(40, 23)`. A test checks that the shipped value covers the project viewport (`ceil(viewport / 16)` on both axes). | The one-screen rule, without touching fixtures |
| C8 | `FloorTunables.min_room_size` stays 8 × 6. The shipped `max_room_size` becomes 80 × 46. Every other room rule of F-011/C16 and F-012/C8 is unchanged and every shipped room passes all of them. | §3 |
| C9 | The shipped rooms are redrawn at exactly these sizes (tiles, border included), keeping each room's enemy list (same `EnemyData`, same counts) and layout idea from `design/floors.md`: floor 1: 48 × 28, 52 × 28, 56 × 30, boss 56 × 32. Floor 2: 48 × 28, 52 × 30, 64 × 28, 56 × 32, boss 56 × 32. Floor 3: 48 × 28, 52 × 30, 56 × 30, 60 × 32, 64 × 36, boss 56 × 32. Pillars and blocks may be more numerous or larger than before so the idea still reads at the new size. | What Lucas approved |
| C10 | Shipped-room rules, each checked by a test over every shipped room: (a) at least one spawn is on screen when the room starts: within 18 tiles horizontally and 9 vertically of `P`, centre to centre; in a boss room that is the boss. (b) In a room with a brute or the Juggernaut, every walkable tile is within 8 tiles (larger of the x and y distance) of a wall tile, so a charge can always be baited into something. (c) The Juggernaut's room keeps a clear floor of at least 20 × 12 tiles. (d) Room 1-3 keeps two pairs of chasers more than 7 tiles apart. (e) `P` and `E` stay on opposite sides of each room (still a guideline for validation, F-011 §10 Q5, but true of every shipped room). | The bigger rooms must still teach what the small ones did |
| C11 | The town is 64 × 36. The tower gate is 4 tiles wide on the north border, tiles x 30 to 33. `P` is the tile (32, 9), so the gate is on screen at the start. Blocks: 2 × 2 at tiles (26..27, 4..5) and (36..37, 4..5) flanking the path, and 3 × 3 at (14..16, 20..22), (47..49, 20..22), (14..16, 28..30), (47..49, 28..30). Nothing else. It stays a safe room and every F-012 gate behaviour is unchanged. | `design/floors.md`, Town |
| C12 | `ClassData.dash_recovery_duration: float`, seconds, default 0.0, `validate()` refuses a negative value. `data/classes/warrior.tres` sets 0.12. | G2; a default of 0 keeps every fixture's behaviour |
| C13 | Dash recovery rules. (a) It starts at the instant a dash completes its full duration, and only then: a dash ended by a hit has none. (b) It is a new `PlayerMotor.State.DASH_RECOVERY`, appended after `KNOCKBACK` so existing values keep their numbers. (c) While it lasts: velocity is zero, movement input is ignored, no attack and no dash can fire, presses go into the existing buffers, facing still updates, the cooldown keeps counting (it started when the dash ended, as before). (d) It ends exactly `dash_recovery_duration` after it started, in the motor's exact time segments; a buffered action that is allowed fires at that same instant, by the existing rule (the dash wins over the attack). (e) A hit during recovery ends it and is handled as any other hit. (f) The duration is latched when the dash fires, with the other dash values (F-001/C17). (g) With a latched value of 0 the state is never entered and the motor behaves exactly as before this feature. (h) I-frames are unchanged: the player can be hit during recovery. | `design/combat.md`, Dash; G1 |
| C14 | The recovery is part of the snapshot (`to_dict` / `from_dict`, `SNAPSHOT_KEYS`): a snapshot taken in mid-recovery restores to the same remaining time. | G7 |
| C15 | No signal is removed or renamed. `dash_ended` is still emitted when the dash motion ends. | F-001 views and tests |
| C16 | A pre-existing test may be changed only when it pins something this spec changes: a shipped room's or the town's coordinates or size, the shipped `max_room_size`, or what the shipped Warrior can do in the 0.12 s after a dash. Each such change is listed in §8 with its reason. Tests built on fixtures do not change. | The old suite is the proof that nothing else moved |
| C17 | Navigation cost is measured, not guessed: the time of one flow-field build in the largest shipped room is recorded in §8. Above 4 ms on the build machine it becomes a §10 question; it is not optimised inside this feature. | 2,304 tiles in GDScript; G1 does not cover frame time |
| C18 | No new third-party dependency, no new autoload, no new input action. | G4 |

**Must not break:** every F-011 and F-012 behaviour (room clear, healing and its `+N HP`
message, the gate list, death returning to town, re-entry at the boss, the debug keys); the
debug scenes; snapshots of a room; tick-rate independence of the motor; the F-011 DEV-13 fix
(old rooms are removed and freed with `queue_free()`).

---

## 5. Acceptance Criteria  ·  _Planner_

Testable, observable. The Auditor checks each one.

**Camera**
- [ ] AC1: `Room.camera_limits_px()` returns the room's outer rectangle in px for a room at least one view large on both axes, and a view-long range centred on the room on an axis where the room is smaller (cases: 64 × 36, 40 × 23, 12 × 8, and one room larger on one axis only, against a 640 × 360 view).
- [ ] AC2: In the smallest and the largest shipped room, with the player standing at each corner of the walkable floor and at the centre, the visible rectangle lies inside the room's outer rectangle once the camera has settled.
- [ ] AC3: With the player at least half a view from every wall, the settled camera centre is the player's position (within 1 px).
- [ ] AC4: In a 12 × 8 fixture room the room stays centred on the screen wherever the player stands.
- [ ] AC5: One frame after a room is shown, the camera is the viewport's current camera and its centre is the limited target for the player's start; true for a room reached through the door, with N, with R (as key events), after a death in the game, from the town into a floor and from a floor back to the town.
- [ ] AC6: With `follow_smoothing_enabled` false the camera centre equals the limited player position every frame; with it true the centre approaches at `follow_smoothing_speed`. Both values are read from `camera.tres`, and `CameraTunables.validate()` refuses a speed of 0 or less and a negative margin.
- [ ] AC7: The four outside strips exist, have the wall colour, cover `outside_margin_tiles` on every side including the corners, and have no collision. The shipped margin in px is at least the shipped shake `max_offset_px`.
- [ ] AC8: A hit still shakes the camera in a `Room` (non-zero offset limit after a hit), and the HUD and the boss bar keep their screen position while the player crosses the room.

**Rooms and town**
- [ ] AC9: The shipped tower is valid, its `min_room_size` is `(40, 23)` and covers the viewport, and every room has exactly the size C9 gives.
- [ ] AC10: A tower with a room or a town smaller than its `min_room_size` reports the error C7 describes, names the room, and `Game` builds nothing on it. A tower that leaves `min_room_size` at zero accepts any room `FloorTunables` accepts.
- [ ] AC11: Every shipped room has the same enemy list as before (the table in `design/floors.md`).
- [ ] AC12: Each rule of C10 holds for every shipped room it applies to.
- [ ] AC13: The town matches C11 and every F-012 gate behaviour passes on it.
- [ ] AC14: In every shipped room every enemy, once the player comes inside its aggro radius, reaches attack range of the player (F-011's wake test, on the new rooms).
- [ ] AC15: Floors 1 to 3 can be walked from the town to each boss's exit and back in the game (F-012's scripted runs, on the new rooms).
- [ ] AC16: The time of one flow-field build in the largest shipped room is recorded in §8.

**Dash recovery**
- [ ] AC17: With the Warrior's data, at the instant a full dash ends the state is `DASH_RECOVERY`, and for 0.12 s the position does not change whatever the movement input.
- [ ] AC18: An attack pressed during recovery starts at the instant recovery ends and not before. A dash pressed during recovery fires when both the recovery and the cooldown are over.
- [ ] AC19: The recovery ends at the same motor time, with the same position, at 30, 60, 120 and 240 ticks per second.
- [ ] AC20: With `dash_recovery_duration` 0 the state is never `DASH_RECOVERY`, and F-001's and F-003's tests pass unchanged.
- [ ] AC21: A hit during recovery applies its damage and knockback and ends the recovery. A dash ended by a hit is followed by no recovery.
- [ ] AC22: A snapshot taken in mid-recovery, restored into a new motor, ends its recovery at the same instant as the original.
- [ ] AC23: Changing the class data in mid-dash does not change that dash's recovery; the next dash uses the new value.
- [ ] AC24: The i-frame window of a dash is the same as before, and a hit that lands during recovery is not blocked.
- [ ] AC25: `ClassData.validate()` refuses a negative `dash_recovery_duration`.

**Whole feature**
- [ ] AC26: `tools/test` passes; `gdlint` and `gdformat --check` are clean; `tools/check_core_purity` passes; `scenes/main.tscn` starts headless with no error.

**How to verify manually:** Start the game. In the town the room fills the window, the gate
is at the top of the screen and the view scrolls when you walk south or sideways; no empty
space is ever visible. Enter floor 1: the camera follows you and stops at the walls. Dash:
the player stops dead for a moment after each dash, and walking or attacking only starts after
it. Take a hit near a wall: the shake shows no empty space.

---

## 6. Task Breakdown  ·  _Planner_

Small, ordered, each independently committable. "A" and "B" are the two implementers; their
file lists never overlap while both work.

| # | Task | Files likely touched | Notes |
|---|---|---|---|
| T1 | Camera: `CameraTunables` and its file, `Tunables.camera`, `Room.camera_limits_px()`, limits and smoothing on the room's camera, the outside strips. Tests AC1–AC8 in a new file. | `src/core/tunables/camera_tunables.gd`, `data/tunables/camera.tres`, `src/autoload/tunables.gd`, `src/world/floors/room.gd`, `tests/core/test_camera_tunables.gd`, `tests/scenes/test_f013_camera.gd` | A. AC2 and the game cases of AC5 use the rooms that exist when the task runs; the lead reruns them after T4. |
| T2 | Rooms: raise `max_room_size`; redraw the 15 rooms and the town (C9–C11); update the tests that pin their geometry (C16); add the C10 rule tests; measure the flow-field build (C17). | `data/tunables/floors.tres`, `data/floors/**` except `tower.tres`, `tests/core/floors/test_shipped_*.gd`, `tests/core/floors/test_floor_tunables.gd`, `tests/scenes/test_f011_shipped_floors.gd`, other scene tests only where they pin shipped coordinates | B. A generator script in the scratchpad may draw the grids; only the `.tres` files are committed. |
| T3 | The one-screen rule: `TowerData.min_room_size`, its errors, tests on fixtures (AC10). | `src/core/floors/tower_data.gd`, `tests/core/floors/test_tower_data.gd` (new tests appended) | A, after T1. Does not set the shipped value. |
| T4 | Set `min_room_size = Vector2i(40, 23)` in `data/floors/tower.tres`; the shipped tests of AC9. | `data/floors/tower.tres`, `tests/core/floors/test_shipped_tower.gd` | After T2 and T3 are committed. |
| T5 | Dash recovery in core, the Warrior's value, tests AC17–AC25 in a new file; pinned tests updated (C16). | `src/core/classes/class_data.gd`, `src/core/player/player_motor.gd`, `data/classes/warrior.tres`, `tests/core/player/test_f013_dash_recovery.gd` | Whoever is free first. Touches no file of T1–T4; a pinned test in another task's file goes through the lead. |
| T6 | Design docs and glossary: `design/floors.md` (room rules, sizes, town), `design/combat.md` (dash recovery), `GLOSSARY.md`. | `studio/design/*.md`, `studio/GLOSSARY.md` | Lead, as Planner. |
| T7 | Final gate: full suite, lint, format, purity, headless boot, a rendered look at the town and one room per floor. | — | Lead. |

---

## 7. Plan Review  ·  _Auditor_

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
| Q1 | Lead | → Lucas, at Gate B: the starting values. Camera smoothing speed 8 (`data/tunables/camera.tres`), dash recovery 0.12 s (`data/classes/warrior.tres`), room sizes (C9). | no | |
| Q2 | Lead | → Lucas, at Gate B: the Juggernaut's room and the brute rooms now have blocks to charge into, because an open 56 × 32 room leaves no wall within a charge's reach (C10 b). The old Juggernaut room was open with no interior walls. Is that the fight you want? | no | |

---

## 11. Director Notes  ·  _Lucas_

