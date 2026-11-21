# Items Design — Hundred Gates

> Living document. Owned by the Items & Economy department (opened 2026-11-21 for F-016,
> D-017, for basic loot only; brief still to be written by Direction).
> Source of truth for swords, traits and drop tables. Specs must match it.
> **Status:** phase 1 basic loot set (2026-11-21, F-016). All numbers are starting values:
> computed from the data files and checked twice against `combat.md`, none played yet.

## Fixed so far (Lucas, 2026-11-21, D-017)
- Both bosses and regular enemies drop gear. Bosses are "the reliable source of good gear";
  regular enemies give "a small chance, lower-tier items".
- Floors 1–3 gear is "good items, not the best in the game": it "must be replaceable later".
- **Gear power stays small** (pillar 2: a skilled player with weaker gear still wins), and
  the three boss fights must still work as tuned.
- Every sword has "a damage value and exactly one extra attribute, so two swords can both be
  'the better one' depending on how the player fights". The trait "must NOT change the
  chain's windup, active, recovery or reach".
- The weapon is the only slot. No shop, crafting, upgrades or market (phase 2).
- Items and drop tables are data (G9). Loot rolls use a seeded random source saved with the
  run (G7), "nothing that breaks co-op later".
- Death keeps everything.

## Damage
- A sword's **damage** is the damage of one full chain with it. The Warrior's chain deals 42
  with the starter sword (10 + 10 + 22).
- **Split rule (integer HP).** The damage is split over the chain's hits by weights, by
  largest remainder: hit `i` gets `floor(damage × w_i / W)`; the points left over go one each
  to the hits with the largest remainder `(damage × w_i) mod W`; ties go to the last hit
  first, then to the earliest. `W` is the sum of the weights.
  - A sword without its own weights uses the class chain's own damages as weights (10, 10,
    22). So 42 → 10/10/22, 44 → 11/10/23, 45 → 11/11/23, 46 → 11/11/24, 48 → 12/11/25.
  - Heavy finisher and Quick cuts swords carry their own weights: the three hits themselves.
- **Caps** (Combat's breakpoints; `data/tunables/items.tres`):
  - a chain never deals more than 49: a chaser (50 HP) still takes "a full chain and one hit";
  - the first two hits together never more than 29, and the finisher alone never more than
    29: a caster (30 HP) still takes three hits, and never dies to a finisher alone.
- With every sword below, a chaser takes 4 hits, a caster 3 and a brute 9, as with
  the starter sword. The best sword (49) brings the Warden from 9.5 chains to 8.2.

## Traits
One per sword. The starter sword has none.

| Trait | What it does | Regular drop | Boss drop |
|---|---|---|---|
| Heavy finisher | Weaker light hits, a much stronger third hit. 3 more damage in total than the tier's Quick cuts sword, because at equal damage Quick cuts is never behind on one target | 9/9/28 | 9/9/29, 10/10/29 |
| Quick cuts | Stronger first and second hits, a weaker finisher. Pays the player who lands two hits per opening (30–33 % more than Heavy finisher there) | 12/12/19 | 12/12/21, 13/13/20 |
| Vitality | Max HP +8. One value, because +5 and +8 survive the same number of hits; never more, or a seventh Hexer bolt is survived (CQ5). No boss version: one more hit survived costs a boss sword | +8 | — |
| Quickstep | Dash cooldown shorter | −0.05 s | −0.08 s |
| Mending | A bonus added to `room_clear_heal_fraction`, so it follows if the base changes | +0.05 | +0.10 |

- Vitality gains nothing against the Hexer (every attack of his deals 18; 108 HP is still six).
- Quickstep makes no boss pattern dashable that was not (shortest gap in any pattern 0.80 s; a
  dash already repeats every 0.50 s). The dash cooldown never goes below `min_dash_cooldown`.
- Mending does nothing inside a boss fight: the boss room is entered at full HP and its clear
  gives no heal. The heal after the pre-boss room is overwritten by that full heal, so a floor
  has 2 / 3 / 4 useful heals on floors 1 / 2 / 3.

## The swords
Names are working names (→ Lore, IX2).

| Sword | Damage | Hits | Trait | Dropped by |
|---|---|---|---|---|
| Recruit's Sword | 42 | 10/10/22 | — | start |
| Iron Cleaver | 46 | 9/9/28 | Heavy finisher | regular enemies |
| Twin Edge | 43 | 12/12/19 | Quick cuts | regular enemies |
| Guard's Blade | 44 | 11/10/23 | Vitality +8 | regular enemies |
| Swift Blade | 44 | 11/10/23 | Quickstep −0.05 s | regular enemies |
| Pilgrim's Blade | 44 | 11/10/23 | Mending +0.05 | regular enemies |
| Warden's Mercy | 45 | 11/11/23 | Mending +0.10 | Warden 30 % |
| Warden's Stride | 45 | 11/11/23 | Quickstep −0.08 s | Warden 20 % |
| Warden's Verdict | 47 | 9/9/29 | Heavy finisher | Warden 10 % |
| Hexer's Needle | 45 | 12/12/21 | Quick cuts | Hexer 30 % |
| Hexer's Balm | 46 | 11/11/24 | Mending +0.10 | Hexer 20 % |
| Hexer's Slip | 46 | 11/11/24 | Quickstep −0.08 s | Hexer 10 % |
| Juggernaut's Maul | 49 | 10/10/29 | Heavy finisher | Juggernaut 30 % |
| Juggernaut's Fangs | 46 | 13/13/20 | Quick cuts | Juggernaut 20 % |
| Juggernaut's Rush | 48 | 12/11/25 | Quickstep −0.08 s | Juggernaut 10 % |

Known weak spots: the regular and the Warden's Heavy finisher swords are nearly the same
(finisher 28 against 29); Quickstep is on all three boss tables and Mending on two, and the
later ones only add damage.

## Drops
- **Regular enemies.** Each floor names its **drops per run** (1.0 on floors 1–3) and a pool
  of swords (the five regular ones, equal chance). The chance per kill is the drops per run
  divided by the floor's kills before the boss: 27, 51 and 38 kills give 3.7 %, 2.0 % and
  2.6 %. About 36 % of full runs drop nothing. A first full climb gives about six swords.
- **Bosses.** Three swords with a percentage each (30, 20, 10). A repeat win rolls once: that
  sword at its percentage, nothing for the rest (40 %). The **first win** always drops one,
  in the same proportions (3 : 2 : 1). It is built as: until the character has **taken** a
  sword from that floor's boss, every win drops one (F-016/C11). That is Lucas's rule in
  every case but one, where it is kinder: a sword that dropped and was lost to a death does
  not end the guarantee (F-016 §10 Q1).
- A drop lies where the enemy died. Walking within `pickup_radius_tiles` takes it. A sword
  still lying in a room is taken when the player leaves the room alive (through the exit, or
  by Return to town in the pause menu), and lost when the player dies (F-016/C16, Q2).
- A sword already owned is kept as a count. It has no use until phase 2.
- The player sees each boss's table at the tower gate.
- Rolls come from one seeded source per character, saved with the session (G7).

## Owning and switching
- A character starts with the Recruit's Sword, equipped.
- The Equipment list is in the pause menu. Swords can be **switched in the town and in the
  pre-boss room once it is cleared**; everywhere else on a floor the list is read-only
  (Lucas, 2026-11-21).
- Switching to a sword with less max HP lowers current HP to the new max; more max HP does
  not heal. The town and every floor entry are at full HP anyway, and so is the boss room.
- The inventory lives as long as tower progress: kept on death and on Return to town, gone
  on quit to title until save/load (phase 2).

## Rejected (do not implement)
See D-017: more slots; a grid inventory; automatic equip; a compare popup; switching anywhere;
a new safe room before bosses; losing swords on death; Knockback; Opener; swords that change
windup, recovery or reach (Phase 2 parking lot); shop, crafting, upgrades, market; random
stat rolls per drop.

## Open questions (cross-department)
| # | To | Question | Blocking |
|---|---|---|---|
| IX1 | → Combat | After play: is one sword picked for every fight? Is the Vitality sword in every Warden win? Is −0.05 s of dash cooldown felt at all? Juggernaut's Fangs kills a chaser with four light hits and no finisher (52). The routine the place rule leaves: Mending through the rooms, then a switch in the pre-boss room (Vitality there turns five Warden hits into six). | No |
| IX2 | → Lore | Names of the 15 swords (working names; no SAO names). | No |
| IX3 | → Art & Game Feel | Look of a drop on the floor, of the pickup moment, and of the Equipment list. | No |
| IX4 | → Direction (phase 2) | What duplicates are for (shop, upgrades); whether death should lose anything (CX3). | No |
