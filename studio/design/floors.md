# Floors Design — Hundred Gates

> Living document. Owned by the Floors & Level Design department (opened 2026-11-18 for
> F-011; brief still to be written by Direction).
> Source of truth for how floors and rooms are built. Specs must match it.
> **Status:** phase 1 structure and loop set (2026-11-18, F-011, F-012); camera and room sizes
> changed after the first playtest (2026-11-19, F-013); waves added (2026-11-19, F-014). All
> numbers are starting values.

## Fixed so far (Lucas, 2026-11-18)
- A floor is a **linear chain of rooms ending in a boss room**. No branching in phase 1.
- A room's **exit is locked until every enemy in it is dead**.
- **Healing:** clearing a room restores `room_clear_heal_fraction` of max HP (30 %). Entering
  the boss room restores full HP. No flasks, no other healing.
- **Rooms are data** (D-012): an ASCII tile grid in a `RoomData` resource. Walls, door, spawns
  and the navigation grid all come from it.
- **Enemies route around walls** with a flow field in core, only when the straight line is
  blocked (D-012).
- Death: D-006. In the game, death returns to town (F-012). In F-011's debug scenes it still
  restarts the room at full HP.
- **The town sits between every floor** (Lucas, 2026-11-18, F-012): when a boss dies a door
  opens in its room and leads back to town, with the next floor unlocked.
- **The game world fills the screen** (Lucas, 2026-11-19, F-013): a typical 2D camera that
  follows the player and stops at the room's walls. Every room and the town is larger than
  one screen, so there is space for detail later. Empty space outside a room is never shown.
- **A combat room has a kill target** (Lucas, 2026-11-19, F-014: enemies "would appear until
  the player reach a certain amount that he killed"): reinforcements arrive, each announced
  by a marker, until the target is reached; then the exit opens. Boss rooms keep one enemy.
- **The tower gate is a floor list** (Lucas, 2026-11-18, F-012): walking into the gate lists
  the unlocked floors; a floor whose boss room was reached offers "from the start" and "at
  the boss"; cleared floors can be replayed.

## Room format
Legend: `#` wall · `.` floor · `P` player start · `E` exit · `1`–`9` spawn of the room's
`enemies[digit − 1]` (a **placed** enemy) · `S` arrival point of the room's reinforcements
(floor for every rule). One character = one tile (16 px, CX1 pending).

Rules (enforced by `RoomData.validate()`, F-011/C16):
- Rectangular, 8 × 6 to 80 × 46 tiles. (One screen is 40 × 22.5 tiles; the one-screen minimum
  is a rule of the shipped tower, below, because these rules also apply to test rooms.)
- Border is wall, except the exit: one straight run of `E`, at least 2 tiles, not on a corner.
- Exactly one `P`. Every floor tile reachable from it.
- No 1-tile corridors and no 1-tile-thick interior walls.
- No 1-tile pinch either: two walkable tiles side by side must share a walkable 2 × 2 block,
  so two wall corners can't leave a 1-tile opening (bodies are up to 1.2 tiles wide).
- Spawns at least 4 tiles from `P`. 1–6 placed enemies per combat room; exactly 1 enemy in a
  boss room.
- Waves (F-014): `reinforcements` lists entries of the room's `enemies` in arrival order;
  a room with reinforcements needs at least 2 `S` tiles; an `S` is at least 4 tiles from `P`
  and 1.5 from another `S` and from a spawn; no waves and no `S` in a boss room or the town;
  the kill target (placed plus reinforcements) is at most 30.

Guidelines (not enforced by validation; true of every shipped room and checked by tests):
- `P` and `E` sit on opposite sides, so the room is crossed.
- Spawns at least 1.5 tiles apart, so bodies don't start overlapping.

## Camera and screen (F-013)
- The camera is the player's. It follows with light smoothing (`data/tunables/camera.tres`)
  and its limits are the room's outer walls. A room smaller than the screen on an axis (test
  rooms, debug scenes) is centred on that axis.
- A room change is a hard cut: the new room's camera starts on its target (FX4 still open).
- Wall-coloured strips just outside the room hide what a screen shake would uncover.
- The camera is presentation only. No rule depends on what is on screen.

## Waves (F-014)
- **Kill target.** The enemies placed at the start plus the room's reinforcements. The room
  is cleared when nobody is alive and nobody is still to come. The HUD counts the kills.
- **Reserve.** Every reinforcement exists from the start, waiting: not there for anyone
  (`design/combat.md`). The sim's roster never changes during a fight.
- **Release in shares.** The reserve is split as evenly as it goes over the placed enemies.
  Each time another placed enemy notices the player (or dies) one more share is released,
  so every part of the room brings its own fight and nothing arrives while the player
  stands still after one.
- **The cap.** A released reinforcement is sent while fewer than the room's `max_engaged`
  enemies are engaged (alive and aggroed) or on their way, and at least
  `wave_spawn_interval` after the last one was sent. Placed enemies that have not noticed
  the player do not count, so walking on can pull more onto the player than the cap.
- **Arrival.** The director picks an arrival point: the nearest one at least
  `wave_min_spawn_distance_tiles` from the player, inside the arrival box (about a screen)
  and within a walk of `wave_max_walk_tiles` along the nav grid, so it is not behind a wall;
  failing that the nearest far-enough one in the box, then the nearest far-enough one, then
  the farthest. A marker shows there for `wave_spawn_warning_duration`; then the enemy
  appears, already aggroed.
- **Order is data.** No randomness: a room plays the same every time.
- Tunables (`data/tunables/floors.tres`): `wave_max_engaged` 3 (when a room gives none),
  `wave_spawn_warning_duration` 0.8 s, `wave_spawn_interval` 1.5 s,
  `wave_min_spawn_distance_tiles` 6, `wave_spawn_gap_tiles` 1.5, `wave_min_arrival_points` 2,
  `max_kill_target` 30, `wave_arrival_box_tiles` 19 × 10, `wave_max_walk_tiles` 18.
- In a room with waves a dead enemy vanishes at once (a death effect → Art & Game Feel).

## Shipped-room rules (F-013)
Checked by tests over the shipped tower, on top of the format rules:
- **At least one screen.** `data/floors/tower.tres` names its screen, 40 × 23 tiles, and the
  game does not start on a tower with a smaller room or town.
- **A first target near the start.** In a combat room at least one spawn is within 18 tiles
  horizontally and 9 vertically of `P`.
- **Every spawn outside its own aggro radius** from `P`: the fight starts with a read.
- **Something to put behind you.** In a room with a brute or the Juggernaut no floor tile is
  more than 8 tiles (the larger of the x and y distance) from a wall tile. A rule of thumb for
  spacing, not a proof that every charge can be baited.
- **No attack starts off screen.** The longest range at which any enemy starts an attack is
  below 11 tiles (half a screen's height is 11.25; today's longest is 9).
- In a floor's room `P` is on the west side and the 2-tile `E` on the east border (the town
  has its own layout, below). Free-standing pillars and blocks are at least 2 × 2 and at
  least 2 tiles from a wall or another block.
- Arrival points (F-014): no wall tile at 2 tiles or nearer; from every walkable tile the
  first three points the director would choose are inside the arrival box, so the warning
  is on screen, and the first is a walk of at most `wave_max_walk_tiles` (13 to 28 points
  per room); `max_engaged` is at most 1 plus the first share.
- Casters start behind cover from `P`, or behind the chasers in an open room (2-1); the two
  walking bosses stand 12 to 18 tiles east of `P`; the Hexer's room has exactly four blocks.

## The tower loop (F-012)
- Floor `n` is unlocked when `n` is 1 or floor `n − 1` is cleared.
- A boss room counts as **reached** the moment it is entered (D-006). Dying there, the
  character may start that floor again directly in the boss room.
- Every entry into a floor starts at full HP. Room-clear healing is unchanged.
- Death: a short pause (`death_return_delay`, 1.5 s), then the town. Nothing is lost.
- A floor is left only by dying or through the cleared boss room's door (F-012 §10 Q1).
- Clearing a floor again gives nothing yet (rewards → Items & Economy).
- Progress is per character (D-005) and lives for one run of the game until save/load
  (phase 2).

## Town (phase 1)
One safe room (`is_safe_room`): no enemies, never a boss room, every other room rule
applies. Its `E` run is the **tower gate**.
- Size 64 × 36 tiles, border included (F-013; it was 24 × 14).
- The gate is 4 tiles wide, centred on the north border: the tower is "up".
- `P` is the tile (32, 9), just below the gate, so the gate is on screen when the game starts
  and the rest of the town lies to the south and the sides (F-013; it was in the lower half).
- Two 2 × 2 blocks flank the path to the gate, and four 3 × 3 blocks stand in the south half,
  only to make the room read as a place and to show the camera moving.
- Nothing else: NPCs, shops and storage arrive with their own features.

## Encounter tables (phase 1)
Enemy mix follows `design/combat.md` (CX6): floor 1 chasers; floor 2 adds casters; floor 3
adds brutes. Each room adds one idea; the boss is that floor's exam. Sizes and layouts were
redrawn in F-013; F-014 added the reinforcements. "Placed" enemies stand in the room from the
start; one fight is a placed enemy plus its share of the reinforcements.

| Floor | Room | Placed | Reinforcements (by share) | Kill target | On you at once | Layout idea | Size (tiles) |
|---|---|---|---|---|---|---|---|
| 1 | 1 | 2 chasers | 2 \| 2 chasers | 6 | 2 | Open room. Learn: telegraph → dash → punish. | 48 × 28 |
| 1 | 2 | 3 chasers | 2 \| 2 \| 2 chasers | 9 | 2 | Four 3 × 3 pillars around the middle. Enemies come around them. | 52 × 28 |
| 1 | 3 | 4 chasers, in two pairs more than 7 tiles apart | 2 \| 2 \| 2 \| 2 chasers | 12 | 3 | A dividing wall with two gaps: pull one pair at a time. | 56 × 30 |
| 1 | Boss | Warden | — | 1 | — | Open, no interior walls. | 56 × 32 |
| 2 | 1 | 2 chasers, 1 caster | 3 \| 3 \| 3 (6 chasers, 3 casters) | 12 | 3 | Open. The caster stands behind the chasers. | 48 × 28 |
| 2 | 2 | 2 chasers, 2 casters | 2 \| 2 \| 2 \| 2 (5 chasers, 3 casters) | 12 | 3 | Six pillars in two rows: cover from bolts. | 52 × 30 |
| 2 | 3 | 1 chaser, 3 casters | 2 \| 2 \| 2 \| 2 (6 chasers, 2 casters) | 12 | 3 | A long room; casters at the far end, blocks to advance between. | 64 × 28 |
| 2 | 4 | 3 chasers, 2 casters | 2 × 5 (7 chasers, 3 casters) | 15 | 3 | Two alcoves, formed by wall slabs, holding the casters. | 56 × 32 |
| 2 | Boss | Hexer | — | 1 | — | Four 2 × 2 cover blocks in a square around the centre. The start is in the north-west corner, so a block breaks the first line of fire. | 56 × 32 |
| 3 | 1 | 1 brute | 2 brutes | 3 | 1 | Two long interior walls and the lane between them: learn the wall stun. | 48 × 28 |
| 3 | 2 | 1 brute, 2 chasers | 2 \| 2 \| 2 (5 chasers, 1 brute) | 9 | 3 | Six pillars in two rows. | 52 × 30 |
| 3 | 3 | 1 brute, 2 casters | 2 \| 1 \| 1 (3 casters, 1 brute) | 7 | 2 | Casters behind blocks; the brute owns the middle. | 56 × 30 |
| 3 | 4 | 2 brutes | 1 \| 1 brutes | 4 | 2 | A row of blocks along the middle makes two lanes to read at once. | 60 × 32 |
| 3 | 5 | 1 brute, 2 chasers, 2 casters | 2 × 5 (6 chasers, 3 casters, 1 brute) | 15 | 3 | Everything: pillars throughout and a back row. | 64 × 36 |
| 3 | Boss | Juggernaut | — | 1 | — | A clear floor of at least 20 × 12 around the boss, with blocks around it to charge into. | 56 × 32 |

The exact order of each room's reinforcements is in its data file and in F-014's wave table.

Notes:
- Chaser aggro is 6 tiles, caster 8, brute 7: a room wider than that lets the player start a
  fight in pieces. Room 1-3 relies on it. Reinforcements arrive aggroed.
- A charge runs up to 6 tiles for the brute and 7 for the Juggernaut. An open room of these
  sizes would leave no wall within reach, so the floor 3 rooms have blocks (shipped-room rules).
  The Juggernaut's room was open before F-013; whether that is the fight wanted is F-013 §10 Q2.
- Sizes include the border walls.
- The heal is still 30 % per cleared room, with two to four times the enemies per room it
  had (F-014 §10 Q1).

## Open questions (cross-department)
| # | To | Question | Blocking? |
|---|---|---|---|
| FX1 | → Art & Game Feel | Tile size and how walls, doors and floors look (16 px placeholders now). | No |
| FX2 | → Direction | Boss rooms: do floors 2 and 3 want pre-placed dormant adds (CX9)? Designed without. | No |
| FX3 | → Combat | Hits ignore walls; casters shoot without a clear line (F-011 §10 Q1, Q2). | No |
| FX4 | → Direction | Room transitions are hard cuts. Is a fade or a short corridor wanted (F-012/F-015)? | No |
| FX5 | → Direction | Should the player be able to leave a floor mid-run without dying (F-012 §10 Q1)? | No |
| FX6 | → Items & Economy | What does replaying a cleared floor give (F-012 ASSUMPTION-4)? | No |
| FX7 | → Direction | The floor 3 rooms and the Juggernaut's room now have blocks to charge into (F-013 §10 Q2). Keep, or open them up again? | No |
| FX10 | → Direction | Waves: the starting values (kill targets, shares, how many are on the player at once, warning and interval), and whether the heal still fits (F-014 §10 Q1 to Q3). | No |
| FX11 | → Art & Game Feel | The arrival marker is a placeholder ring the size of the arriving body; a dead enemy vanishes with no effect in rooms with waves (F-014). | No |
| FX8 | → Art & Game Feel | Room detail: a visual-only decoration layer and solid props. The rooms have the space now (F-013); the format has no layer for either yet. | No |
| FX9 | → Art & Game Feel | A shake that starts while the camera is still catching up makes the view jump a little (F-013 code review CR-4, §10 Q4): the placeholder shake writes the camera's offset every frame, and each write advances the smoothing. To settle when the shake gets its real look (CX2). | No |
