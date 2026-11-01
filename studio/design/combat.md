# Combat Design — Hundred Gates

> Living document. Owned by the Combat & Bosses department.
> Source of truth for how fighting works. Specs must match it; if they don't, one of
> them changes explicitly.
> **Status:** core player decisions set (CQ1–CQ8, 2026-10-31). Enemies and bosses next.

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
- **Timing (D-007):** hits are decided at the end of each combat step (1/120 s by default), the **contact instant**, using collision-corrected positions. Dash i-frames are checked exactly at that instant. Every active window lasts at least one step.
- A single attack instance hits each hurtbox **at most once**. A hurtbox skipped because of i-frames is **not** marked — if it's still inside when the i-frames end, it gets hit. Leaving the hitbox matters.
- On hit: damage → knockback → per-entity hitstop on attacker and target → hurt i-frames on the target (player only for phase 1).
- **Simultaneous hits:** hits at the same instant trade, so attackers aren't rechecked and registration order never decides an exchange. Targets are rechecked hit by hit, so a second hit on a player at the same instant is stopped by the first one's hurt i-frames.
- **Knockback:** distance × target's `knockback_scale`, over `knockback_duration`, after the target's hitstop; walls stop it. A knocked-back player can't move; dash/attack are buffered. A new knockback replaces the remaining one, never adds to it.
- **Hurt i-frames:** start on the hit, count down during knockback, pause during hitstop.
- **Hitstop:** an entity's logic timer that pauses **all** of that entity's timers (incl. input buffer ages) for N seconds. Serializable (G7), ticked (G1). New hitstop = max(remaining, new), never additive. The world keeps running. A hitbox isn't live while its owner is in hitstop.
- Presentation listens to signals (`hit_landed`, `damaged`, `died`) for shake, flash, numbers and sound — only for hits involving a local player. Shake can be disabled by the player.

## Enemies (phase 1)
_(3 archetypes — next Combat session)_

## Bosses (floors 1–3)
Template per boss:
- **Concept:** one line
- **Phases:** HP thresholds and what changes
- **Attacks:** name → telegraph (what the player sees/hears, how long) → hitbox → punish window
- **What it teaches:** the skill this boss tests before the next floor

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
| Enemy damage, floor 1 | 18–25 (→ ~4–6 hits) | `data/enemies/*.tres` (next session) |

## Open questions (cross-department)
| # | To | Question | Blocking? |
|---|---|---|---|
| CX1 | → Art & Game Feel | Tile size and pixel scale (16 px assumed above). | No — values are in tiles |
| CX2 | → Art & Game Feel | Look of screen shake, hit flash, and dash VFX. Combat only emits the events and intensities. | No |
| CX3 | → Items & Economy (phase 2) | Should death lose loot or currency? Phase 1 keeps everything. | No |
| CX4 | → Direction | The death/re-entry rule (CQ6) affects Floors and Items later — promote to a D-###? | **Answered:** yes → D-006 |