# STATUS — The Board

> Updated by whoever changes a feature's status. Lucas checks this first.

**Last updated:** 2026-11-19

| ID | Feature | Status | Next actor | Blocked by |
|---|---|---|---|---|
| F-000 | Project setup & architecture skeleton | DONE | — | — |
| F-001 | Warrior movement + dash | DONE | — | — |
| F-002 | Studio autopilot (tools/studio) | DONE | — | — |
| F-003 | Warrior sword chain + hit/hurt + hitstop + training dummy | DONE | — | — |
| F-004 | Enemy base + melee chaser | DONE | — | — |
| F-005 | Ranged caster + minimal projectiles | DONE | — | — |
| F-006 | Brute — charge, stomp, wall stun | DONE | — | — |
| F-007 | Boss base + floor 1 boss (Warden) | DONE | — | — |
| F-008 | Volleys + floor 2 boss (Hexer) | DONE | — | — |
| F-009 | Floor 3 boss (Juggernaut) | DONE | — | — |
| F-010 | Studio queue — chained features, auto-drafted specs, opt-in automatic Gate A | PLAN_REVIEW | Auditor | — |
| F-011 | Floor structure — rooms as data, navigation, room-clear healing, floors 1–3 in greybox | DONE | — | — |
| F-012 | The loop — town, tower gate, boss as gate, death returns to town, bare HUD, main scene | CODE_REVIEW | Lucas | F-011 (stacked on its branch, D-013; merge F-011 first) |
| F-013 | Follow camera, rooms larger than the screen, dash recovery (Gate B playtest, second pair) | CODE_REVIEW | Lucas | F-012 (stacked on its branch, D-015) |
| F-014 | Waves — reinforcements arrive in a room until its kill target is reached (Gate B playtest, third fix) | CODE_REVIEW | Lucas | F-013 (stacked on its branch, D-015) |

## Open questions waiting on Lucas
- **Gate B, second pass, for F-011 and F-012.** Lucas played on 2026-11-18 and raised six points (F-012 §10 Q9 to Q13). Fixed and reviewed: the room stuck in the corner (camera) and the invisible healing (`+30 HP`). Answered on 2026-11-19 and built as F-013, reviewed (two rounds, approved with notes) and waiting for his playtest on `feature/F-013-camera-rooms-dash`: dash recovery (Q12), a follow camera with rooms larger than the screen (Q13). Waves with a kill target (Q11): he answered "yes go ahead and build waves" on 2026-11-19, before playing F-013; built as F-014, reviewed (three plan rounds, two code rounds, approved with notes) and waiting for his playtest on `feature/F-014-waves`, which holds F-011 to F-014. No review round used a real device.
- F-011 §10 Q5: should validation enforce "start and exit on opposite sides of a room"? Q3: the 30 % heal, room sizes, enemy counts. Q4: casters behind walls, brutes charging pillars (→ Combat).
- F-014 §10 Q1 to Q4: answered by Lucas on 2026-11-19, everything stays as shipped.
- F-013 §10 Q1, Q2: answered by Lucas on 2026-11-19, everything stays as shipped. Still open, Q4: a small view jump when a shake starts while the camera is catching up.
- F-012 §10 Q1: a way to leave a floor mid-run? Q2: death pause 1.5 s, banners 2.5 s. Q6: Space is dodge and accept. Q8: is a menu choice a player action under G8?
- `PHASE1.md` rows F-011 to F-015 are out of date (F-012 here covers the plan's F-012, F-013 and part of F-015; the F-013 on this board is a Gate B feature, D-015, not the plan's). Direction's file; not touched.

## Next up
See `studio/PHASE1.md`: the order, the target dates and what Lucas still has to decide.
F-009 runs first; F-010 starts when F-009 is DONE.

## Parked
- **Automated retrospective** — parked 2026-11-01 by Direction. Only F-003 has run the full autopilot; too little data to automate. Revisit after F-005 (3 features through the pipeline). Manual note meanwhile: F-003 took 3 plan rounds / 962 lines → keep enemy features to one archetype each.
