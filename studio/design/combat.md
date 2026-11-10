# Combat Design — Hundred Gates

> Living document. Owned by the Combat & Bosses department.
> Source of truth for how fighting works. Specs must match it; if they don't, one of
> them changes explicitly.
> **Status:** core player decisions set (CQ1–CQ8, 2026-10-31). Phase 1 enemy archetypes set
> (CQ10–CQ12, 2026-11-01; chaser → F-004 DONE, caster → F-005 DONE, brute → F-006 DONE).
> Bosses for floors 1–3 designed (2026-11-09; Warden → F-007, Hexer → F-008, Juggernaut → F-009).

## Fixed so far (from PROJECT.md / Lucas)
- Real-time action, top-down camera.
- Pillar 2: skill beats stats. Readable telegraphs, dodging, positioning.
- Bosses are pattern fights with phases, not damage sponges.
- Phase 1: one weapon type, dodge, 3 enemy types, 3 bosses (floors 1–3).
- All numbers are tunables in `data/` (G2, G9).
- Must stay co-op compatible later (D-002).
- **Classes (D-005):** one fixed class per character, bound to a weapon family; classes are
  data in `data/classes/`. Phase 1 ships **one** class (Warrior). Healer/support arrives with co-op (P3).
- Every boss must be beatable solo by every solo-viable class.
- **Death & re-entry:** see D-006.

## Answered questions
| # | Question | Answer |
|---|---|---|
| CQ1 | Phase 1 class | **Warrior — sword, melee arcs** (D-005). Other classes (e.g. spear, bow) deferred to phase 2 (CQ9). |
| CQ2 | Movement feel | **Near-instant** start/stop with a tiny accel/decel (tunable; 0 = fully instant). |
| CQ3 | Dodge | **Dash with i-frames on its first part only.** Short cooldown, no stamina. Input buffered. |
| CQ4 | Attack aiming | **Mouse** on KB/M. Gamepad: **right stick**, fallback to movement direction, fallback to last facing. Never auto-aim. |
| CQ5 | Health model | **Integer HP with a bar.** Tuned so a correctly geared player dies in ~4–6 hits from same-floor enemies. |
| CQ6 | Death (phase 1) | **Return to town** (promoted to D-006). Cleared floors stay cleared. Once a floor's boss room is reached, the player may re-enter **directly at that boss**. Loot is kept (phase 1 default; loss rules → Items & Economy). |
| CQ7 | Combo | **3-hit chain**; hit 3 is a slower, stronger finisher. Dash may cancel any hit's recovery. |
| CQ8 | Hitstop / shake | **Hitstop yes, day one** — per-entity, part of logic state, never global time scale. **Screen shake yes**, emitted as an event with intensity; look owned by Art & Game Feel; player can disable it. |
| CQ10 | Enemy hurt rules (F-003 Q3) | **Planted while committed:** during windup, active and recovery a hit deals damage and hitstop but no knockback and no interrupt. Outside an attack, knockback applies normally. No enemy hurt i-frames. |
| CQ11 | Enemy aim | **Track, then lock:** aim follows the target during the first part of windup, then locks for at least `min_locked_telegraph` before active. |
| CQ12 | Enemy bodies | Enemies collide with walls and each other, **never with players**. No contact damage. |

### Still open
| # | Question | Answer |
|---|---|---|
| CQ9 | Which two solo-viable classes join in phase 2 (archer, assassin, …)? Decide later, but CQ1–CQ8 answers must not block them. | |

### Rejected (do not implement)
- **Rolling dodge** — slower and heavier than our near-instant movement; feels sluggish in a top-down dodge-centric game. *Tempting because:* classic action-RPG look.
- **I-frames for the whole dash** — removes the vulnerable tail, so mashing dash becomes a safe answer to everything. *Tempting because:* feels generous and simple.
- **Dash without i-frames** — every boss attack would have to be escapable by distance alone, which shrinks the pattern design space. *Tempting because:* feels "purer" and harder.
- **Stamina for dodge** — a second resource that can make the dodge fail to come out, breaking principle 3. *Tempting because:* Souls-likes use it.
- **Auto-aim** — removes positioning skill (pillar 2). *Tempting because:* easy on gamepad.
- **Aim = movement direction only** — makes retreating while attacking impossible. *Tempting because:* simplest gamepad input.
- **Hearts (3–5)** — cannot scale with gear over 100 floors (pillar 3). *Tempting because:* very readable.
- **Restart whole floor on death** — trains the hallway, not the boss; slows pattern learning. *Tempting because:* feels "fair" and simple.
- **Global hitstop (`Engine.time_scale`)** — in co-op one player's hit would freeze everyone (D-002). *Tempting because:* one line of code.
- **Hits interrupt enemy attacks (flinch/stagger)** — attacking first always wins, so mashing beats reading; the 3-hit chain could lock a chaser forever. *Tempting because:* feels powerful.
- **Contact damage** — an attack with no telegraph (principle 1). *Tempting because:* classic and cheap.
- **Hard body collision between players and enemies** — packs corner you with bodies, dashes get eaten, co-op body-blocking. *Tempting because:* feels solid.
- **Enemy aim that tracks until active** — a last-instant snap can't be read. *Tempting because:* looks smart.
- **Sword destroys bolts** — a hitbox-vs-hitbox contact the sim doesn't have, and walking in swinging replaces dashing through. *Tempting because:* feels great. Maybe a phase-2 class skill.
- **Casters lead their shots** — walking straight always gets hit, and the lock points at empty floor (principle 1). *Tempting because:* looks smart.
- **Bolts outlive their caster** — a dead combatant would own live hitboxes. *Tempting because:* physically "right".
- **Random/weighted enemy attack choice** — the player can't read the next attack from position; needs synced RNG. *Tempting because:* feels alive.
- **Per-attack cooldowns** — a charge ending next to you could stomp at once and erase its punish window. *Tempting because:* flexible, bosses may want it.
- **Wall stun from slide collisions or body position** — enemy bodies and sliding would stun it falsely; physics would decide outcomes (G6). *Tempting because:* one line.
- **A separate boss class/system** — duplicates everything enemies share (step grid, planted, targets, snapshots) and the two drift apart. *Tempting because:* bosses feel special.
- **Scripted attack rotation (fixed cycle that ignores distance)** — a second selection rule plus per-enemy memory outside the attack state; the player can no longer read the next attack from position. *Tempting because:* it's the classic boss script. Revisit if a boss gets "solved" by standing at one distance.
- **Stage change interrupts the running attack** — crossing an HP line would cancel a telegraphed attack, which is a flinch by another name (CQ10). *Tempting because:* the change feels instant.
- **Invulnerable stage shift** — takes the player's reward away mid-fight and adds an enemy invulnerability state ("no enemy hurt i-frames"). *Tempting because:* protects the show moment.
- **Enrage timer / boss HP that scales** — a stat check, not a pattern check (pillar 2). *Tempting because:* stops slow, safe play.
- **Summoned adds (combatants spawned mid-fight)** — breaks fixed ids/order in snapshots (F-003/C19). *Tempting because:* fits the floor 2 lesson. Possible later as pre-placed dormant enemies (CX9).

## Player

### Movement
- 8-directional analog movement. Facing = aim direction (CQ4), not movement direction.
- Accel/decel tunable; defaults are near-instant.
- Sticks: radial deadzone `stick_deadzone`, remapped `m = (|r| − dz)/(1 − dz)`; keys/D-pad normalized to length 1 (details: F-001 C14).
- Aim mode MOUSE or GAMEPAD, switched only by real device activity; initial facing down; mouse on top of the player → fall back to move direction (details: F-001 C16).

### Dash (dodge)
- Direction: current movement input; if none, the facing direction.
- I-frames are an exact time window starting the instant the dash fires and ending before the dash ends — the dash tail is vulnerable. Timing is exact in time, not rounded to frames (details: F-001 C8, C15).
- Cooldown starts when the dash ends. A dash interrupted by a hit ends at that instant, so its full cooldown starts there.
- A dash pressed during cooldown or an attack's active frames is **buffered** and fires as soon as allowed, if within the buffer window.
- Can cancel the **recovery** of any attack, once it can fire: cooldown still applies. A dash buffered during recovery cancels nothing until it fires. Cannot cancel windup or active frames.
- When the dash ends, no dash momentum carries over: velocity continues from current movement input with normal accel.
- During a dash, movement input is ignored; the direction is fixed at dash start. Facing still updates.
- The dash is the `dodge` input action (F-000). There is no separate `dash` action.

### Sword attack chain
- 3 hits. Each hit: **windup → active → recovery**. The hitbox exists only during active.
- The chain window opens at the start of recovery and lasts `attack_chain_window`. Attack during recovery starts the next hit at once (cancels the rest of recovery); attack after recovery but inside the window also starts the next hit. Otherwise the chain resets to hit 1.
- Attack pressed during windup/active, a dash or knockback is **buffered** (`input_buffer_window`).
- Hit 3 (finisher): longer windup and recovery, bigger arc, more damage, more knockback. Its recovery **cannot** be cancelled by attack — only by dash. This is the player's own punish window.
- The Warrior is **rooted** during all three phases (velocity decels to 0). No lunge for now.
- Aim is locked at the start of each hit's windup.
- Dash cancels recovery only. Any dash that fires resets the chain. A dash pressed during windup or active is buffered.
- If a buffered dash and a buffered attack can both fire at one instant, the dash fires and the attack is discarded (principle 3). A dash that can't fire yet doesn't block an attack that can.
- Getting hit interrupts any attack and resets the chain.
- The chain is data: the Warrior class resource holds an ordered list of attack resources, one per hit (G9, D-005).

## Hit / hurt system
- **Hurtbox:** a circle that can receive hits. **Hitbox:** a sector (origin, direction, arc, range) that deals damage while active; a full circle = 360° sector.
- Hits are decided by exact circle–sector intersection in core logic, by a per-scene `HitResolver` — never from animation frames or physics overlaps (G6).
- **Teams:** a hitbox never hits its own team. No friendly fire, no PvP.
- **Timing (D-007):** hits are decided at the end of each combat step (1/120 s by default), the **contact instant**, using collision-corrected positions. Dash i-frames are checked exactly at that instant. Every active window lasts at least one step, and windup (or telegraph) plus active lasts at least two, so every window gets a contact instant. Lowering `combat_step_rate` is refused while a running hit or pulse would break that.
- A single attack instance hits each hurtbox **at most once**. A hurtbox skipped because of i-frames is **not** marked — if it's still inside when the i-frames end, it gets hit. Leaving the hitbox matters.
- On hit: damage → knockback → per-entity hitstop on attacker and target → hurt i-frames on the target (player only for phase 1).
- **Simultaneous hits:** hits at the same instant trade, so attackers aren't rechecked and registration order never decides an exchange. Targets are rechecked hit by hit, so a second hit on a player at the same instant is stopped by the first one's hurt i-frames.
- **Knockback:** distance × target's `knockback_scale`, over `knockback_duration`, after the target's hitstop; walls stop it. A knocked-back player can't move; dash/attack are buffered. A new knockback replaces the remaining one, never adds to it.
- **Hurt i-frames:** start on the hit, count down during knockback, pause during hitstop.
- **Hitstop:** an entity's logic timer that pauses **all** of that entity's timers (incl. input buffer ages) for N seconds. Serializable (G7), ticked (G1). New hitstop = max(remaining, new), never additive. The world keeps running. A hitbox isn't live while its owner is in hitstop.
- Presentation listens to signals (`hit_landed`, `damaged`, `died`) for shake, flash, numbers and sound — only for hits involving a local player. Shake can be disabled by the player.

## Enemies (phase 1)

Three archetypes, one skill each. Together they cover the three things pillar 2 asks of the
player: **read and dodge** (chaser), **close distance and move under fire** (caster),
**don't trade, bait and punish** (brute). Names are working names (→ Lore).

### Rules shared by every enemy
- **Telegraph floor (principle 1).** Every enemy attack has `windup ≥ min_telegraph` (0.30 s)
  and at least `min_locked_telegraph` (0.15 s) between aim lock and active. Data that breaks
  this is rejected, not clamped (`data/tunables/enemy_combat.tres`).
- **Track, then lock (CQ11).** During windup the aim follows the target until
  `aim_track_time`, then never changes. The target is fixed for the whole attack.
- **Planted while committed (CQ10).** In windup, active and recovery a hit deals damage and
  hitstop, but no knockback and no interrupt. Outside an attack, knockback ×
  `knockback_scale` applies and the enemy can't act until it ends. Zero distance after
  scaling works as for players: no knockback state, any running push is cleared, and the
  enemy acts again after hitstop (F-004/C7). Hitstop pauses an enemy's windup too, so hitting
  a winding-up enemy delays its swing but never cancels it.
- **No hurt i-frames.** Once per attack instance is the only protection.
- **One punish window per attack:** its recovery. Long enough to land at least hit 1 safely.
- **Never faster than the player on foot.** Every enemy's `move_speed` is below the Warrior's
  `move_speed`, so walking away always works. Attacks (lunges, charges) may be faster.
  Checked across both resources at scene setup and on every reload (F-004/C12).
- **Bodies (CQ12).** Enemies collide with walls and each other, never with players. No
  contact damage. Enemies never hit enemies.
- **Perception and decisions.** At each combat step start, every combatant senses the same
  read-only view (positions, teams, alive) before anyone advances. An enemy decides only at
  a step start, and only when free. Swapping enemies' registration order never changes what
  they decide from a given view. Hits on one player at one instant and body collisions still
  resolve in registration order (F-003/C16, F-004/C4).
- **Targets (co-op ready).** Nearest living player; ties by registration order. Re-picked at
  every decision, fixed during an attack. Nothing assumes one player.
- **Aggro.** Starts when a living player is within `aggro_radius_tiles`, or when the enemy
  takes damage. No leash in phase 1.
- **Attack cooldown.** Starts when recovery ends. The enemy keeps moving during it.
- **Death.** `died` once, then inert: no hitbox, can't be hit, no body collision. Stays in
  the sim (snapshots match by id and order).
- **Damage band, floor 1:** 18–25 per hit, so a Warrior with 100 HP dies in 4–6 hits (CQ5).
- **Data.** One `EnemyData` per archetype in `data/enemies/`, attacks in `data/attacks/`
  (`EnemyAttackData`, an `AttackData` with `aim_track_time` and `lunge_tiles`). Behavior is
  a small stateless brain per archetype, picked by `EnemyData.brain` (F-004 §3).

### Chaser — melee pressure (F-004)
- **Concept:** walks straight at you and swipes. The enemy that teaches the loop: read,
  dodge, punish.
- **Movement:** chases at 3.0 tiles/s, holds at 1.0 tile. Slides along walls, no pathfinding.
- **Attack — Lunging swipe:** starts when the target is within 1.6 tiles.
  - Telegraph: 0.50 s windup. Tracks for 0.30 s, then the locked direction shows for 0.20 s.
  - Hitbox: 90° sector, 1.2 tiles, active 0.10 s, lunging 0.8 tiles along the aim.
  - Hit: 20 damage, 0.8 tiles knockback.
  - Punish window: 0.60 s recovery, then a 0.8 s cooldown during which it walks back in.
- **Body:** 50 HP (a full chain + one hit), hurtbox 0.4 tiles, `knockback_scale` 1.0.
- **What it teaches:** that a telegraph means *move now*, and that its recovery is yours.
  Mashing into it trades 20 damage for 10.

### Caster — ranged area denial (F-005)
- **Concept:** keeps its distance and fires slow bolts. Teaches closing in and moving under fire.
- **Movement:** stays 3–6 tiles from the target: backs off straight away below 3 tiles, walks in
  above 6, holds in between. 2.5 tiles/s both ways (slower than the player, so it can be caught).
  No memory: no hysteresis band. Aggro radius 8 tiles.
- **Attack — Bolt:** starts when the target is within 7 tiles, at any distance. Shooting beats
  backing off, so a cornered caster still shoots.
  - Telegraph: 0.60 s windup with a visible aim line. Tracks for 0.35 s, locked for 0.25 s.
  - Release: 0.10 s active. The bolt launches at its first instant, from the caster's center,
    along the locked aim. The caster's body never has a hitbox.
  - Projectile: circle of 0.25 tiles at 6 tiles/s, up to exactly 10 tiles; stopped by walls only
    (passes through every body). Flies on the sim clock: the caster's hitstop never pauses it.
  - Hit: 18 damage, 0.5 tiles knockback **along the flight direction**. One target only, then it
    disappears. Skipped by i-frames → it flies on (the dash goes *through*). The caster gets no
    hitstop from a bolt hit.
  - Punish window: 0.80 s recovery, then a 1.2 s cooldown.
  - Killing the caster removes its bolts in flight.
- **Body:** 30 HP, hurtbox 0.35 tiles, `knockback_scale` 1.2.
- **What it teaches:** dash through attacks, use walls as cover, prioritize targets in a group.
- **Projectiles (F-005, proposed D-008):** owned by the combatant that launched them (identity =
  owner id + serial, snapshotted with the owner). A projectile is a 360° hitbox whose radius is
  the attack's `range_tiles`. Core plans each move; the glue sweeps it against walls and reports
  the reached position — short of the plan means a wall stop. A bolt born already overlapping a
  wall is a **blocked launch**: the glue reports it, and it vanishes before any contact (it never
  hits). Moves at most its own radius per combat step. That is a **sampling limit**, not a
  swept-hit guarantee: hits are still checked only at contact instants (D-007), so a graze that
  exists only between two contacts is missed. The sword can't destroy bolts.

### Brute — heavy space control (F-006)
- **Concept:** slow, tough, never pushed. Its charge punishes standing in line; missing
  into a wall stuns it. Teaches baiting and not trading.
- **Movement:** chases at 2.0 tiles/s, holds at 1.5 tiles, never retreats. `knockback_scale` 0.
  Aggro radius 7 tiles.
- **Choosing an attack (F-006, all enemies):** an enemy has an ordered list of attacks, each
  with a trigger band (`trigger_min_tiles`–`trigger_max_tiles`). When ready, it uses the first
  attack in list order whose band holds the target distance. One shared cooldown per enemy.
  Never random. The brute's list: stomp (0–1.5), then charge (3–7). Between 1.5 and 3 it walks in.
- **Attack 1 — Charge:** when the target is 3–7 tiles away.
  - Telegraph: 0.80 s windup. Tracks for 0.50 s, locked for 0.30 s, with a visible lane.
  - Hitbox: 120° frontal sector, 0.9 tiles, during a 0.50 s active that lunges 6 tiles
    (12 tiles/s). It's the shared enemy lunge, not a new movement system.
  - Hit: 25 damage, 1.5 tiles knockback. The charge doesn't stop on the hit.
  - Punish window: 0.9 s recovery. If the charge is stopped by a wall: **stunned 1.5 s**
    instead (the big punish). The stun *is* the recovery, lengthened: planted, paused by
    hitstop, cooldown after it.
  - **Wall stop (D-008):** core plans each step of the charge; the glue sweeps the brute's
    circle against `world` walls only and reports how far it got. Short of the plan = wall stop.
    A graze counts. A step that starts with the brute already inside a wall (only after a radius
    reload) is a stop too. Enemy bodies never stun it: it slides along them. The stop takes effect
    right after that step's contact, so the charge can still hit someone pinned against the wall.
  - **Data rules:** a wall stun never shortens the punish (`wall_stun_duration ≥ recovery`), and
    a wall-stun attack's recovery lasts at least two combat steps (F-006/C9).
- **Attack 2 — Stomp:** when the target is within 1.5 tiles (so hugging it isn't safe).
  - Telegraph: 0.60 s windup (raises a foot), no aim (360°).
  - Hitbox: full circle, 1.6 tiles, active 0.10 s.
  - Hit: 20 damage, 1.2 tiles knockback.
  - Punish window: 0.7 s recovery.
- **Body:** 120 HP, hurtbox 0.6 tiles. Attack cooldown 1.0 s, shared by both attacks.
- **What it teaches:** dash sideways out of a lane, bait charges into walls, punish only when it's open.

### Floor mix (proposal → Direction, CX6)
Floor 1: chasers only. Floor 2: chasers + casters. Floor 3: all three. Each boss reuses its
floor's lesson.

## Bosses (floors 1–3)

A boss is an **enemy**: same `EnemyLogic`, same shared rules (telegraph floor, track then lock,
planted while committed, no hurt i-frames, slower than the player on foot, nearest-player
target, ordered attack list with trigger bands, one shared cooldown, never random). Names are
working names (→ Lore, CX7). Boss **stages** are not called phases: *phase* already means
windup / active / recovery (GLOSSARY).

### Rules shared by every boss
- **Stages (F-007).** A boss has ordered stages, each entered at an HP percent. A stage swaps
  the attack list, `move_speed` and `attack_cooldown`. Stages only go forward.
- **Stage shift.** A stage is entered at the first step start at which the boss is **free**
  after its HP crossed the line, so a running attack or pattern always finishes. The boss
  then stands planted for `shift_duration`: starts no attack (no sector, no new projectile), no
  movement, **takes damage normally**. Projectiles already in flight keep flying and can hit,
  as always (D-008). The shift is a free punish, never an invulnerable pause. The attack
  cooldown keeps counting through it.
- **Reloading a boss (F-007/C19).** A data reload that removes the stage the boss is in is
  refused as a whole. Otherwise the boss keeps its stage, shift and running pattern.
- **Patterns (F-007).** An attack may name a **follow-up**: when its recovery ends, the
  follow-up's windup starts at that instant, with no cooldown, no trigger band and no free
  moment. The target is re-picked at each follow-up (co-op), and aim tracks then locks again.
  Each attack of a pattern is its own attack instance and obeys the telegraph floor.
- **Gap vs punish window.** The recovery before a follow-up is a **gap**: short, hittable, but
  not safe. The **punish window** (principle 2) is the recovery of the pattern's last attack.
  It must fit at least hits 1 and 2. The two must read differently (placeholder: a gap colour,
  F-007/C20; final look → CX8).
- **A wall-stopped attack drops its follow-up.** The stun ends the pattern.
- **Never pushed.** Every boss has `knockback_scale` 0.
- **Damage stays in the floor's band** (floor 1–3: 18–25). Bosses are harder by pattern, not
  by number.
- **Not a sponge.** HP is budgeted in punishes: about 10–12 full chains for a clean fight,
  60–120 s. If a boss needs more HP to last, it needs more pattern instead.
- **No summons, no enrage timer, no invulnerability** (see Rejected).
- **Distance picks the attack.** The player chooses what the boss does by where they stand.
  That's the readable part; patterns and stages are what keeps it from being solved.

### Floor 1 — Warden (F-007)
- **Concept:** a big chaser with a real moveset. The exam for read → dodge → punish: now in
  sequences, with one delayed swing that punishes dodging on the first twitch.
- **Body:** 400 HP, hurtbox 0.7 tiles, `knockback_scale` 0. Chases at 3.0 tiles/s, holds at
  1.2 tiles, aggro 10 tiles. Cooldown 1.0 s. Uses the chaser brain.
- **Stage 1 (100–50%)** — list order:
  1. **Cleave** (target within 2.0 tiles) — pattern of two swipes.
     - Swipe A: 0.50 s windup (tracks 0.30, locked 0.20) → 110° sector, 1.6 tiles, active
       0.10 s, lunges 0.6 tiles → 20 damage, 0.8 knockback → gap 0.25 s.
     - Swipe B: 0.45 s windup (0.25 / 0.20) → same sector, lunges 0.8 → 20 damage →
       **punish: 0.80 s recovery**.
  2. **Dashing cut** (target 3.0–6.0 tiles) — 0.70 s windup (0.45 / 0.25) → 120° sector,
     1.2 tiles, during a 0.30 s active that lunges 5.0 tiles → 22 damage, 1.2 knockback →
     **punish: 0.90 s recovery**. Walk out of the lane if you read it early; dash if late.
  - Between 2.0 and 3.0 tiles it walks in.
- **Stage 2 (≤ 50%)** — shift 1.2 s. Walks at 3.5 tiles/s, cooldown 0.7 s.
  1. **Triple cleave** (within 2.0) — Swipe A → Swipe B (now a 0.25 s gap) → **Overhead**:
     0.75 s windup (0.50 / 0.25), 150° sector, 2.0 tiles, active 0.10 s, lunges 1.0 →
     25 damage, 1.5 knockback → **punish: 1.00 s recovery**. The long windup is the trap:
     dash on the rhythm of A and B and the dash is over before it lands.
  2. **Dashing cut → Spin** (3.0–6.0) — the cut's recovery becomes a 0.30 s gap, then
     **Spin**: 0.45 s windup, no aim, full circle of 1.8 tiles, active 0.10 s → 20 damage,
     1.2 knockback → **punish: 0.90 s recovery**. Stage 1's habit (rush in after the cut)
     now gets hit.
- **What it teaches:** dodge each hit of a sequence, not the sequence once; wait for the real
  opening; a windup's length is information.

### Floor 2 — Hexer (F-008, needs volleys)
- **Concept:** a caster that fills the room with lanes. The exam for closing distance under
  fire, dashing *through* shots and using cover.
- **Body:** 320 HP, hurtbox 0.5 tiles, `knockback_scale` 0. Keeps 4–7 tiles from the target
  at 2.5 tiles/s (catchable), aggro 10 tiles. Cooldown 1.2 s. Uses the caster brain.
- **Stage 1 (100–50%)** — list order:
  1. **Nova** (within 2.5 tiles) — 0.60 s windup, no aim → full circle of 2.5 tiles, active
     0.10 s → 18 damage, 3.0 knockback → **punish: 1.00 s recovery**. Reaching it is not the
     win; baiting the nova and dashing through it is.
  2. **Fan volley** (2.5–9.0) — Fan A: 0.70 s windup (0.45 / 0.25) with aim lines → 3 bolts
     at −20° / 0° / +20° → gap 0.30 s → Fan B: 0.45 s windup (0.25 / 0.20) → 2 bolts at ±10°
     (the lanes that were safe) → **punish: 0.90 s recovery**. Bolts as the caster's
     (0.25 tiles, 6 tiles/s, 18 damage, single target).
- **Stage 2 (≤ 50%)** — shift 1.2 s. Moves at 3.0 tiles/s, cooldown 0.9 s.
  1. **Nova → Ring** (within 2.5) — after the nova's 0.30 s gap: 0.60 s windup → 12 bolts,
     one every 30°, at 4 tiles/s → **punish: 1.00 s recovery**. The nova pushes you out, the
     ring comes after you: dash through it back in.
  2. **Triple fan** (2.5–9.0) — 3 → 2 → 3 bolts → **punish: 0.90 s recovery**.
- **What it teaches:** move toward danger, i-frame through a line instead of away from it,
  break line of sight, and that arriving in melee starts a new read.
- **Needs:** several projectiles per attack (count + spread, F-008). A boss room with cover
  (CX9). One hit gives hurt i-frames, so a volley never hits one player twice.

### Floor 3 — Juggernaut (F-009)
- **Concept:** a brute that owns the room. The exam for not trading: its normal recovery is
  too short to punish, so the wall is the only real opening.
- **Body:** 500 HP, hurtbox 0.8 tiles, `knockback_scale` 0. Chases at 2.0 tiles/s, holds at
  1.5 tiles, aggro 10 tiles. Cooldown 1.0 s. Uses the brute brain.
- **Stage 1 (100–50%)** — list order:
  1. **Stomp** (within 1.8 tiles) — 0.60 s windup, no aim → full circle of 2.0 tiles, active
     0.10 s → 22 damage, 1.5 knockback → **punish: 0.70 s recovery**.
  2. **Double charge** (3.0–9.0) — Charge A: 0.80 s windup (0.50 / 0.30) with a lane → 120°
     sector, 1.0 tile, during a 0.50 s active that lunges 7 tiles → 25 damage, 1.5 knockback
     → gap 0.35 s → Charge B: 0.60 s windup (0.35 / 0.25), re-aimed, same charge →
     recovery 0.60 s. **A wall stop on either charge: stunned 1.5 s and the pattern ends** —
     that's the punish.
- **Stage 2 (≤ 50%)** — shift 1.2 s. Chases at 2.5 tiles/s, cooldown 0.8 s.
  1. **Stomp → Debris** (within 1.8) — after a 0.30 s gap: 0.50 s windup → 8 bolts, one every
     45°, at 5 tiles/s, 18 damage → **punish: 0.80 s recovery** (needs F-008 volleys).
  2. **Triple charge** (3.0–9.0) — a third charge with a 0.50 s windup (0.30 / 0.20).
- **What it teaches:** position before the attack, not during it; make the room do the
  damage window for you; a boss that looks open isn't always open.

### Build order
F-007 boss base + Warden → F-008 volleys + Hexer → F-009 Juggernaut. Each in a test room;
boss rooms, doors and floor gates belong to Direction.

## Tunables index
> Starting values for the first playtest — expect to change them. Distances in **tiles**
> (1 tile = 16 px, pending Art & Game Feel). Times in seconds. Logic runs on ticks (G1).
>
> **Where values live (D-005):** anything a future class could do differently lives in the
> **class resource** (`data/classes/warrior.tres`). Rules shared by every class live in
> `data/tunables/player_combat.tres`. Each attack is its own resource in `data/attacks/`.

| Tunable | Start value | File |
|---|---|---|
| `move_speed` | 5.0 tiles/s | `data/classes/warrior.tres` |
| `move_accel_time` | 0.05 s (0 = instant) | `data/classes/warrior.tres` |
| `move_decel_time` | 0.04 s | `data/classes/warrior.tres` |
| `dash_distance` | 3.0 tiles | `data/classes/warrior.tres` |
| `dash_duration` | 0.15 s | `data/classes/warrior.tres` |
| `dash_iframe_duration` | 0.11 s (from dash start) | `data/classes/warrior.tres` |
| `dash_cooldown` | 0.35 s | `data/classes/warrior.tres` |
| `input_buffer_window` | 0.12 s | `data/tunables/player_combat.tres` |
| `stick_deadzone` | 0.2 (0–1) | `data/tunables/player_combat.tres` |
| `max_hp` | 100 | `data/classes/warrior.tres` |
| `player_hurt_iframes` | 0.6 s | `data/tunables/player_combat.tres` |
| `attack_chain_window` | 0.25 s | `data/classes/warrior.tres` |
| Hit 1 windup / active / recovery | 0.08 / 0.06 / 0.18 s | `data/attacks/sword_hit_1.tres` |
| Hit 2 windup / active / recovery | 0.08 / 0.06 / 0.18 s | `data/attacks/sword_hit_2.tres` |
| Hit 3 windup / active / recovery | 0.16 / 0.08 / 0.32 s | `data/attacks/sword_hit_3.tres` |
| Hit 1 / 2 / 3 damage | 10 / 10 / 22 | per-hit files |
| Hit 1 / 2 / 3 arc angle | 100° / 100° / 150° | per-hit files |
| Hit 1 / 2 / 3 range | 1.4 / 1.4 / 1.8 tiles | per-hit files |
| Hit 1 / 2 / 3 knockback | 0.3 / 0.3 / 1.2 tiles | per-hit files |
| `hitstop_normal` | 0.05 s | `data/tunables/player_combat.tres` |
| `hitstop_finisher` | 0.10 s | same |
| `shake_intensity_hit` / `_finisher` / `_player_hurt` | 0.2 / 0.5 / 0.6 (0–1 scale) | `data/tunables/player_combat.tres` |
| `hurtbox_radius_tiles` (Warrior) | 0.35 | `data/classes/warrior.tres` |
| `knockback_scale` (Warrior) | 1.0 | `data/classes/warrior.tres` |
| `knockback_duration` | 0.12 s | `data/tunables/player_combat.tres` |
| `combat_step_rate` | 120 steps/s (multiple of 120, D-007) | `data/tunables/player_combat.tres` |
| Dummy `max_hp` / `hurtbox_radius_tiles` / `respawn_delay` | 200 / 0.5 / 1.0 s | `data/enemies/training_dummy.tres` |
| Dummy `knockback_scale` | 0 (anchored) / 1 (loose) | per dummy instance in scene; default 0 |
| Dummy pulse `interval` (start to start) / `telegraph` / `active` | 2.0 / 0.6 / 0.1 s | `data/enemies/training_dummy.tres` |
| Dummy pulse `radius` / `damage` / `knockback` | 2.5 tiles / 20 / 1.0 tile | same |
| `screen_shake_enabled` / `max_offset_px` / `decay_time` | true / 6 / 0.2 s | `data/tunables/screen_shake.tres` (placeholder → Art) |
| Enemy damage, floor 1 | 18–25 (→ ~4–6 hits) | `data/enemies/*.tres` per archetype below |
| `min_telegraph` / `min_locked_telegraph` (all enemies) | 0.30 / 0.15 s | `data/tunables/enemy_combat.tres` |
| Chaser `max_hp` / `hurtbox_radius_tiles` / `knockback_scale` | 50 / 0.4 / 1.0 | `data/enemies/chaser.tres` |
| Chaser `move_speed` / `aggro_radius_tiles` / `stop_distance_tiles` | 3.0 tiles/s / 6.0 / 1.0 | same |
| Chaser `attack_cooldown` | 0.8 s (from recovery end) | same |
| Chaser swipe windup / `aim_track_time` / active / recovery | 0.50 / 0.30 / 0.10 / 0.60 s | `data/attacks/chaser_swipe.tres` |
| Chaser swipe damage / arc / range / knockback / `lunge_tiles` | 20 / 90° / 1.2 / 0.8 / 0.8 tiles | same |
| Caster `max_hp` / `hurtbox_radius_tiles` / `knockback_scale` | 30 / 0.35 / 1.2 | `data/enemies/caster.tres` |
| Caster `move_speed` / `aggro_radius_tiles` / `stop_distance_tiles` / `retreat_distance_tiles` | 2.5 tiles/s / 8.0 / 6.0 / 3.0 | same |
| Caster `attack_cooldown` | 1.2 s (from recovery end) | same |
| Caster bolt windup / `aim_track_time` / active / recovery | 0.60 / 0.35 / 0.10 / 0.80 s | `data/attacks/caster_bolt.tres` |
| Caster bolt damage / arc / range (= bolt radius) / knockback / `lunge_tiles` | 18 / 360° / 0.25 / 0.5 / 0 tiles | same |
| Caster bolt `projectile_speed_tiles` / `projectile_max_distance_tiles` | 6.0 tiles/s / 10.0 tiles | same |
| Brute `max_hp` / `hurtbox_radius_tiles` / `knockback_scale` | 120 / 0.6 / 0 | `data/enemies/brute.tres` |
| Brute `move_speed` / `aggro_radius_tiles` / `stop_distance_tiles` / `retreat_distance_tiles` | 2.0 tiles/s / 7.0 / 1.5 / 0 | same |
| Brute `attack_cooldown` / `attacks` | 1.0 s (shared) / [stomp, charge] | same |
| Brute charge windup / `aim_track_time` / active / recovery / `wall_stun_duration` | 0.80 / 0.50 / 0.50 / 0.90 / 1.50 s | `data/attacks/brute_charge.tres` |
| Brute charge damage / arc / range / knockback / `lunge_tiles` / trigger band | 25 / 120° / 0.9 / 1.5 / 6.0 / 3.0–7.0 tiles | same |
| Brute stomp windup / `aim_track_time` / active / recovery | 0.60 / 0 / 0.10 / 0.70 s | `data/attacks/brute_stomp.tres` |
| Brute stomp damage / arc / range / knockback / `lunge_tiles` / trigger band | 20 / 360° / 1.6 / 1.2 / 0 / 0–1.5 tiles | same |
| Chaser swipe / caster bolt trigger band | 0–1.6 / 0–7.0 tiles (was `EnemyData.attack_range_tiles`, removed by F-006) | their attack files |
| Warden `max_hp` / `hurtbox_radius_tiles` / `knockback_scale` | 400 / 0.7 / 0 | `data/enemies/warden.tres` |
| Warden `move_speed` / `aggro_radius_tiles` / `stop_distance_tiles` / `retreat_distance_tiles` | 3.0 tiles/s / 10.0 / 1.2 / 0 | same |
| Warden `attack_cooldown` / `attacks` (stage 1) | 1.0 s / [swipe_a, dashing_cut] | same |
| Warden stage 2 `enter_at_hp_percent` / `shift_duration` / `move_speed` / `attack_cooldown` / `attacks` | 50 / 1.2 s / 3.5 tiles/s / 0.7 s / [p2_swipe_a, p2_dashing_cut] | `data/enemies/warden_stage_2.tres` |
| Warden swipe A windup / `aim_track_time` / active / recovery (gap) | 0.50 / 0.30 / 0.10 / 0.25 s | `data/attacks/warden_swipe_a.tres`, `warden_p2_swipe_a.tres` |
| Warden swipe B windup / `aim_track_time` / active / recovery | 0.45 / 0.25 / 0.10 / 0.80 s (stage 2: 0.25 s gap) | `data/attacks/warden_swipe_b.tres`, `warden_p2_swipe_b.tres` |
| Warden swipe A / B damage / arc / range / knockback / `lunge_tiles` | 20 / 110° / 1.6 / 0.8 / 0.6 (A), 0.8 (B) tiles | same files |
| Warden cleave trigger band | 0–2.0 tiles (on swipe A) | same files |
| Warden dashing cut windup / `aim_track_time` / active / recovery | 0.70 / 0.45 / 0.30 / 0.90 s (stage 2: 0.30 s gap) | `data/attacks/warden_dashing_cut.tres`, `warden_p2_dashing_cut.tres` |
| Warden dashing cut damage / arc / range / knockback / `lunge_tiles` / trigger band | 22 / 120° / 1.2 / 1.2 / 5.0 / 3.0–6.0 tiles | same files |
| Warden overhead windup / `aim_track_time` / active / recovery | 0.75 / 0.50 / 0.10 / 1.00 s | `data/attacks/warden_overhead.tres` |
| Warden overhead damage / arc / range / knockback / `lunge_tiles` | 25 / 150° / 2.0 / 1.5 / 1.0 tiles | same |
| Warden spin windup / `aim_track_time` / active / recovery | 0.45 / 0 / 0.10 / 0.90 s | `data/attacks/warden_spin.tres` |
| Warden spin damage / arc / range / knockback / `lunge_tiles` | 20 / 360° / 1.8 / 1.2 / 0 tiles | same |

## Open questions (cross-department)
| # | To | Question | Blocking? |
|---|---|---|---|
| CX1 | → Art & Game Feel | Tile size and pixel scale (16 px assumed above). | No — values are in tiles |
| CX2 | → Art & Game Feel | Look of screen shake, hit flash, and dash VFX. Combat only emits the events and intensities. | No |
| CX3 | → Items & Economy (phase 2) | Should death lose loot or currency? Phase 1 keeps everything. | No |
| CX4 | → Direction | The death/re-entry rule (CQ6) affects Floors and Items later — promote to a D-###? | **Answered:** yes → D-006 |
| CX5 | → Art & Game Feel | Look and sound of enemy telegraphs: windup cue, lock cue, active, "open" recovery; caster aim line and brute charge lane. Combat fixes only the timing. | No |
| CX6 | → Direction | Floor mix for floors 1–3 (proposal in *Enemies*). Floors starts in phase 2, but phase 1 needs it. | No |
| CX7 | → Lore | Names for chaser, caster, brute and the three bosses (Warden, Hexer, Juggernaut are working names; no SAO names). | No |
| CX8 | → Art & Game Feel | Look and sound of the boss bar, the stage shift cue, and how a gap reads differently from a punish window. Combat fixes only the timing. | No |
| CX9 | → Direction | Boss rooms: size, cover for the Hexer, clear walls for the Juggernaut. Are pre-placed dormant adds wanted for floor 2? Combat designed without them. | No (F-007 uses a test room) |
