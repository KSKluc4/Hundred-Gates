# Floors Design — Hundred Gates

> Living document. Owned by the Floors & Level Design department (opened 2026-11-18 for
> F-011; brief still to be written by Direction).
> Source of truth for how floors and rooms are built. Specs must match it.
> **Status:** phase 1 structure and loop set (2026-11-18, F-011, F-012). All numbers are starting values for
> the first playtest.

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
- **The tower gate is a floor list** (Lucas, 2026-11-18, F-012): walking into the gate lists
  the unlocked floors; a floor whose boss room was reached offers "from the start" and "at
  the boss"; cleared floors can be replayed.

## Room format
Legend: `#` wall · `.` floor · `P` player start · `E` exit · `1`–`9` spawn of the room's
`enemies[digit − 1]`. One character = one tile (16 px, CX1 pending).

Rules (enforced by `RoomData.validate()`, F-011/C16):
- Rectangular, 8 × 6 to 40 × 22 tiles (40 × 22 is one screen).
- Border is wall, except the exit: one straight run of `E`, at least 2 tiles, not on a corner.
- Exactly one `P`. Every floor tile reachable from it.
- No 1-tile corridors and no 1-tile-thick interior walls.
- Spawns at least 4 tiles from `P`. 1–6 enemies per combat room; exactly 1 in a boss room.

Guidelines (not enforced):
- `P` and `E` sit on opposite sides, so the room is crossed.
- Spawns at least 1.5 tiles apart, so bodies don't start overlapping.

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
- Size 24 × 14 tiles, border included.
- The gate is 4 tiles wide, centred on the north border: the tower is "up".
- `P` is in the lower half, centred, so the first thing the player does is walk up to it.
- Two 2 × 2 blocks flank the path to the gate, only to make the room read as a place.
- Nothing else: NPCs, shops and storage arrive with their own features.

## Encounter tables (phase 1)
Enemy mix follows `design/combat.md` (CX6): floor 1 chasers; floor 2 adds casters; floor 3
adds brutes. Each room adds one idea; the boss is that floor's exam.

| Floor | Room | Enemies | Layout idea | Size (tiles) |
|---|---|---|---|---|
| 1 | 1 | 2 chasers | Open room. Learn: telegraph → dash → punish. | 20 × 12 |
| 1 | 2 | 3 chasers | Two 2 × 2 pillars. Enemies come around them. | 24 × 14 |
| 1 | 3 | 4 chasers, in two pairs more than 7 tiles apart | A dividing wall with two gaps: pull one pair at a time. | 28 × 14 |
| 1 | Boss | Warden | Open, no interior walls. | 22 × 14 |
| 2 | 1 | 2 chasers, 1 caster | Open. The caster stands behind the chasers. | 22 × 12 |
| 2 | 2 | 2 chasers, 2 casters | Four pillars: cover from bolts. | 26 × 14 |
| 2 | 3 | 1 chaser, 3 casters | A long room; casters at the far end, blocks to advance between. | 32 × 12 |
| 2 | 4 | 3 chasers, 2 casters | Two alcoves holding the casters. | 28 × 16 |
| 2 | Boss | Hexer | Four 2 × 2 cover blocks in a square around the centre. | 24 × 16 |
| 3 | 1 | 1 brute | Open room with long walls: learn the wall stun. | 22 × 12 |
| 3 | 2 | 1 brute, 2 chasers | Two pillars. | 26 × 14 |
| 3 | 3 | 1 brute, 2 casters | Casters behind blocks; the brute owns the middle. | 28 × 14 |
| 3 | 4 | 2 brutes | Open, wide. Two lanes to read at once. | 28 × 16 |
| 3 | 5 | 1 brute, 2 chasers, 2 casters | Everything: pillars and a back row. | 32 × 16 |
| 3 | Boss | Juggernaut | Open, no interior walls, at least 20 × 12 of clear floor. | 26 × 16 |

Notes:
- Chaser aggro is 6 tiles, caster 8, brute 7: a room wider than that lets the player start a
  fight in pieces. Room 1-3 relies on it.
- The Juggernaut's charge runs 7 tiles; its room must let a charge reach a wall from the centre.
- Sizes include the border walls.

## Open questions (cross-department)
| # | To | Question | Blocking? |
|---|---|---|---|
| FX1 | → Art & Game Feel | Tile size and how walls, doors and floors look (16 px placeholders now). | No |
| FX2 | → Direction | Boss rooms: do floors 2 and 3 want pre-placed dormant adds (CX9)? Designed without. | No |
| FX3 | → Combat | Hits ignore walls; casters shoot without a clear line (F-011 §10 Q1, Q2). | No |
| FX4 | → Direction | Room transitions are hard cuts. Is a fade or a short corridor wanted (F-012/F-015)? | No |
| FX5 | → Direction | Should the player be able to leave a floor mid-run without dying (F-012 §10 Q1)? | No |
| FX6 | → Items & Economy | What does replaying a cleared floor give (F-012 ASSUMPTION-4)? | No |
