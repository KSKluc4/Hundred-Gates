# PHASE 1 PLAN — the road to a playable vertical slice

> Owned by Direction (producer). Lucas approves changes.
> `STATUS.md` says where each feature is **now**. This file says what is **left**, in what
> order, and **by when**.
> **Rule:** a target date never moves silently. Every change gets a line in the Change log
> with the reason.

**Last updated:** 2026-11-16

## Finish line

Phase 1 is done when **a stranger plays floors 1–3 and wants floor 4** (`PROJECT.md`).

**Target: Sunday 2027-02-28.** March is buffer; Lucas's semester ends April 2027.

## Time assumptions

- Lucas works about 40 h/week (9:00–17:00). Free time is roughly 17:00–23:30.
- Evening classes Tuesday and Thursday: no studio work those nights.
- Most features land on weekends. A build takes about 1 hour of machine time; the slow
  part is the gates and the handoffs, not the build.
- The Claude session limit can stop a build partway. That is a resume, not a restart.

Sizes: **S** = one evening · **M** = one weekend · **L** = two weekends.

## Features

IDs from F-011 on are provisional until the feature file exists.
Gate A mode follows D-009: `auto` only where Lucas marked it.

| # | ID | Feature | Department | Size | Gate A | Target | State |
|---|---|---|---|---|---|---|---|
| 1 | F-000 – F-008 | Setup, movement + dash, autopilot, sword chain, chaser, caster, brute, boss base + Warden, volleys + Hexer | — | — | — | — | DONE (F-008 on 2026-11-16) |
| 2 | F-009 | Floor 3 boss (Juggernaut), data only | Combat | S | manual | Sun 2026-11-22 | Spec in plan review |
| 3 | F-010 | Studio queue (chained features, auto-drafted specs, opt-in automatic Gate A) | Direction | M | manual | Sun 2026-11-29 | Spec in plan review, waits for F-009 |
| 4 | F-011 | Floor structure: rooms, enemy placement, layout of floors 1–3, boss rooms (CX6, CX9) | Floors (to open) | L | manual | Sun 2026-12-13 | Not started |
| 5 | F-012 | Floor progression: boss = gate, death returns to town, re-entry at the boss (D-006) | Floors (to open) | M | manual | Sun 2026-12-20 | Not started |
| — | — | Holiday buffer | — | — | — | 2026-12-21 → 2027-01-03 | — |
| 6 | F-013 | Minimal town hub | Floors (to open) | M | manual | Sun 2027-01-10 | Not started |
| 7 | F-014 | Basic loot: drops and equip, one weapon type | Items (to open) | M | manual | Sun 2027-01-17 | Not started |
| 8 | F-015 | HUD and menus: health, floor number, title, pause, death screen | Direction + Art & Game Feel | M | manual | Sun 2027-01-24 | Not started |
| 9 | F-016 | Sprite integration: replace placeholders | Art & Game Feel (to open) | L | manual | Sun 2027-02-07 | Not started |
| 10 | F-017 | Audio pass: hits, bosses, ambience | Art & Game Feel (to open) | M | manual | Sun 2027-02-14 | Not started |
| 11 | — | Playtest by someone who is not Lucas, then one fix pass | Direction | M | — | Sun 2027-02-28 | Not started |

## Decisions Lucas owes

| Decision | Needed by | Blocks |
|---|---|---|
| Art style and pixel scale (resolution is still TBD in `PROJECT.md`) | 2026-11-22 | Sprites, room tile size (F-011), HUD |
| Open the Art & Game Feel department | 2026-11-22 | The art style decision, telegraph looks (CX5, CX8) |
| Open the Floors & Level Design department (planned for phase 2, needed now) | 2026-11-22 | F-011, F-012, F-013 |
| Which queue rows are `auto` (none proposed: every feature left is a new system) | When F-010 ships | Nothing |
| Open the Items & Economy department | 2027-01-03 | F-014 |
| Who the outside playtester is | 2027-01-31 | The finish line |

## If phase 1 runs late: cut order

Cut from the top. Direction proposes, Lucas decides.

1. Audio pass shrinks to hit and boss sounds only (no ambience, no music).
2. Sprite pass covers the player and the three bosses; regular enemies keep placeholders.
3. Loot shrinks to one drop per boss, equipped automatically (no inventory screen).
4. Menus shrink to a title screen and a death screen (no pause menu).
5. Town hub shrinks to one room with the tower gate and nothing else.

**Never cut:** the three bosses, floor progression (boss = gate), the outside playtest.

## Phase 2+ parking lot

New ideas go here, not into phase 1.

- Parallel builds of independent features, and Agent Teams (D-010). Revisit when the
  queue is running and build time, not gates, is what a feature waits on.
- Automated retrospective (parked 2026-11-01, see `STATUS.md`).
- Online, guilds, market, crafting, a second weapon type, save/load (roadmap phases 2–4).
- Boss room cover and adds for the Hexer beyond what F-011 needs (CX9).

## Rhythm

- **Every Monday:** Direction posts the status: what moved, what is stuck and on whom,
  the next feature, and whether the finish date holds.
- **At every Gate B:** Direction updates the State column and the Change log here.

## Change log

| Date | Change | Why |
|---|---|---|
| 2026-11-12 | Plan created with dates; phase 1 target 2027-02-28. | Phase 1 had no dates. |
| 2026-11-14 | F-007 DONE, one day ahead of its 2026-11-15 target. | — |
| 2026-11-16 | F-010 studio queue added before F-009. F-009 moved from 2026-11-29 to 2026-12-02. Later features renumbered F-011 to F-017. No other date moved. | F-007 and F-008 each lost about 2 days to handoffs; the queue removes those waits for the 8 features left. |
| 2026-11-16 | F-008 DONE, six days ahead of its 2026-11-22 target. | Built and reviewed in one sitting; one resume after the session limit. |
| 2026-11-16 | Order swapped: F-009 now runs before F-010. F-009 moved from 2026-12-02 to 2026-11-22; F-010 moved from 2026-11-25 to 2026-11-29. No later date moved. | The F-009 spec was ready when F-008 closed and is data only; no reason to hold it behind tooling. |
