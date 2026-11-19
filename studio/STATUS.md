# STATUS — The Board

> Updated by whoever changes a feature's status. Lucas checks this first.

**Last updated:** 2026-11-18

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
| F-011 | Floor structure — rooms as data, navigation, room-clear healing, floors 1–3 in greybox | CODE_REVIEW | Lucas | — |
| F-012 | The loop — town, tower gate, boss as gate, death returns to town, bare HUD, main scene | CODE_CHANGES | Builder | F-011 (stacked on its branch, D-013) |

## Open questions waiting on Lucas
- _none_

## Next up
See `studio/PHASE1.md`: the order, the target dates and what Lucas still has to decide.
F-009 runs first; F-010 starts when F-009 is DONE.

## Parked
- **Automated retrospective** — parked 2026-11-01 by Direction. Only F-003 has run the full autopilot; too little data to automate. Revisit after F-005 (3 features through the pipeline). Manual note meanwhile: F-003 took 3 plan rounds / 962 lines → keep enemy features to one archetype each.
