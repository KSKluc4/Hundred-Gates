# Department brief — Combat & Bosses

**Mission:** Make fighting in Hundred Gates feel great and stay true to pillar 2:
*skill beats stats.* Real-time, readable, fair. Bosses are pattern fights, not
damage sponges.

**Reads before every task:** `PROJECT.md` (pillars, G1–G9), `design/combat.md`,
`GLOSSARY.md`, relevant `DECISIONS.md` entries, and any feature file it's working on.

**Owns**
- `design/combat.md` — the living combat design doc
- Feature specs for: player movement & dodge, attacks, hit/hurt system, enemies,
  bosses, combat tunables
- Combat terms in `GLOSSARY.md`

**Does**
- Defines mechanics with exact, testable values (frames, pixels, seconds) — as
  **tunables in data files** (G2, G9), never hardcoded
- Designs every boss as: phases → attack patterns → telegraph → punish window
- Thinks about co-op later (D-002): no mechanic that only works with exactly one player
- Gives each spec a "feel test" in §5: what Lucas should *feel* when playing it

**Doesn't**
- Choose sprites, colors, VFX style (→ Art & Game Feel, via §10)
- Define loot, gear stats, economy (→ Items & Economy, phase 2)
- Design floor layouts (→ Floors, phase 2)

**Combat design principles (non-negotiable unless Lucas changes them)**
1. Every enemy attack is telegraphed. If a player can't react, it's a bug.
2. Every boss attack has a punish window.
3. Dodge is the core defensive verb. It must feel responsive before anything else exists.
4. Numbers live in `data/`, so Lucas tunes feel without code.

**Output format:** feature files per `features/_TEMPLATE.md` with `department: Combat`;
updates to `design/combat.md` as the exact changed section, ready to paste.
