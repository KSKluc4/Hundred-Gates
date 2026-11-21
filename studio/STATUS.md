# STATUS — The Board

> Updated by whoever changes a feature's status. Lucas checks this first.

**Last updated:** 2026-11-20

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
| F-012 | The loop — town, tower gate, boss as gate, death returns to town, bare HUD, main scene | DONE | — | — |
| F-013 | Follow camera, rooms larger than the screen, dash recovery (Gate B playtest, second pair) | DONE | — | — |
| F-014 | Waves — reinforcements arrive in a room until its kill target is reached (Gate B playtest, third fix) | DONE | — | — |
| F-015 | Menus — title screen, pause menu, death screen, settings (slice 3, first part) | DONE | — | — |

## Open questions waiting on Lucas
- **Gate B for F-011 to F-014: passed on 2026-11-19.** Lucas answered the F-013 and F-014 questions ("I liked how the map is and the room, dash everything"; everything stays as shipped) and said "Yes, merge". The four features are DONE and merged into `main`, in order, and pushed to GitHub on the same day (`f6302eb`); the four feature branches are kept locally. The questions below were not blocking and are still open.
- **Gate B for F-015 (menus): passed on 2026-11-21.** Lucas played it: "good I liked later on we gonna work on make it beautifull but first focus on making sure is working", and to "Should I close it as DONE and merge it into main?" chose "DONE, merge and push". He named nothing wrong and did not say with which devices or which of the three mouse checks he did. F-015 §10 Q1, Q2, Q7, Q8, Q9 and Q11 were not answered one by one: everything stays as shipped, and they are still open, not blocking. Merged into `main` and pushed on the same day (`7bfdc4d`); the branch is kept locally.
- **Next part: basic loot (no feature file yet). Lucas's direction, 2026-11-21, in his words where quoted.** Both bosses and normal enemies drop gear. Bosses are "the reliable source of good gear": each boss has its own drop table "with a percentage per item, and the player can see those odds"; "the first kill of each boss always drops something; the percentages decide which item, and they apply as normal rolls on repeat kills"; good items, "not the best in the game: floors 1-3 gear must be replaceable later". Normal enemies: "a small chance, lower-tier items", tuned "per floor run, not per enemy" (the lead reports the average drops per run and works the per-kill chance back). Swords: "a damage value and exactly one extra attribute"; the trait "must NOT change the chain's windup, active, recovery or reach"; "4 to 6 traits with starting values, checked with Combat"; heavy and fast swords go to the Phase 2 parking lot. Equipping: he chose "Pick up, choose in a list". Limits: gear power stays small and the bosses still play as tuned (pillar 2); loot rolls use a seeded random source saved with the run (G7), safe for co-op later; items and drop tables are data (G9); no shop, crafting, upgrades or market. **Owed by the lead before any spec:** options with a recommendation for the slots of phase 1, how pickup works, whether there is an inventory screen, and whether death loses anything. His lean: "the smallest version that proves the loop".
- **Slice 3 (D-016)** is built one part at a time. First: F-015 menus (Lucas chose the death screen that waits for a button, and Return to town in the pause menu, on 2026-11-20). The tutorial is its own feature and comes last, after the other parts that change what the player does or sees (Lucas, 2026-11-21). Loot is next (see above); looks and sound come after function (D-016, note of 2026-11-21). Still his to decide before their parts start: where export builds go in the order; the art style and pixel scale.
- F-011 §10 Q5: should validation enforce "start and exit on opposite sides of a room"? Q3: the 30 % heal, room sizes, enemy counts. Q4: casters behind walls, brutes charging pillars (→ Combat).
- F-013 §10 Q4: a small view jump when a shake starts while the camera is catching up.
- F-012 §10 Q1: a way to leave a floor mid-run? Q2: death pause 1.5 s, banners 2.5 s. Q6: Space is dodge and accept. Q8: is a menu choice a player action under G8?
- `PHASE1.md` rows F-011 to F-015 are out of date (F-012 here covers the plan's F-012, F-013 and part of F-015; the F-013 on this board is a Gate B feature, D-015, not the plan's). Direction's file; not touched.

## Next up
See `studio/PHASE1.md`: the order, the target dates and what Lucas still has to decide.
F-009 runs first; F-010 starts when F-009 is DONE.

## Parked
- **Automated retrospective** — parked 2026-11-01 by Direction. Only F-003 has run the full autopilot; too little data to automate. Revisit after F-005 (3 features through the pipeline). Manual note meanwhile: F-003 took 3 plan rounds / 962 lines → keep enemy features to one archetype each.
