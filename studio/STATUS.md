# STATUS — The Board

> Updated by whoever changes a feature's status. Lucas checks this first.

**Last updated:** 2026-11-12

| ID | Feature | Status | Next actor | Blocked by |
|---|---|---|---|---|
| F-000 | Project setup & architecture skeleton | DONE | — | — |
| F-001 | Warrior movement + dash | DONE | — | — |
| F-002 | Studio autopilot (tools/studio) | DONE | — | — |
| F-003 | Warrior sword chain + hit/hurt + hitstop + training dummy | DONE | — | — |
| F-004 | Enemy base + melee chaser | DONE | — | — |
| F-005 | Ranged caster + minimal projectiles | DONE | — | — |
| F-006 | Brute — charge, stomp, wall stun | DONE | — | — |
| F-007 | Boss base + floor 1 boss (Warden) | APPROVED | Builder | — |

## Open questions waiting on Lucas
- _none_

## Next up (Direction, agreed with Lucas 2026-11-12)
Trigger: F-007 reaches DONE. Then Direction starts both:
1. **F-008 — floor 2 boss (Hexer).** Combat planner writes the spec on the F-007 boss base (design: `studio/design/combat.md`, Bosses). F-009 Juggernaut follows.
2. **Floor / dungeon structure spec** (Direction). Biggest phase 1 gap: rooms, floor mix (CX6), boss room entry, death returns to town (D-006). Town hub and basic loot come after.

## Parked
- **Automated retrospective** — parked 2026-11-01 by Direction. Only F-003 has run the full autopilot; too little data to automate. Revisit after F-005 (3 features through the pipeline). Manual note meanwhile: F-003 took 3 plan rounds / 962 lines → keep enemy features to one archetype each.
