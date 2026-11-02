---
id: F-004
title: Enemy base + melee chaser
status: PLAN_REVIEW      # DRAFT | PLAN_REVIEW | PLAN_CHANGES | APPROVED | IN_PROGRESS | CODE_REVIEW | CODE_CHANGES | DONE | PARKED
owner_now: Lucas       # who must act next: Planner | Auditor | Builder | Lucas
created: 2026-11-01
updated: 2026-11-01
depends_on: [F-003, D-002, D-005, D-007]
pillars: [2]
department: Combat
---

# F-004 — Enemy base + melee chaser

> **How to use this file.** This is the single source of truth for this feature.
> Every agent reads the WHOLE file before acting. Write only in the sections you own
> (see studio/README.md). Never delete another role's text — reply under it.

---

## 1. Goal  ·  _Planner_

**Player-facing outcome (one sentence):**
A chaser enemy notices the Warrior, walks at it, telegraphs a lunging swipe the player can
read, and leaves a clear punish window after it, so the fight becomes "read, dodge, punish".

**Why now:** F-003 gave the player a sword and a hit/hurt system. Nothing fights back yet
except a debug pulse. The enemy base built here is what the caster (F-005) and the brute
(F-006) plug into, and the chaser is the first thing floor 1 needs.

**Out of scope (explicitly):**
- The caster and the brute (F-005, F-006). Projectiles, charges, wall stuns and enemies with more than one attack.
- Spawners, waves, encounters, rooms that lock until cleared, floor layouts (→ Floors, phase 2).
- Pathfinding, navigation meshes, line of sight. The chaser walks straight and slides along walls.
- Leash / losing aggro. Once aggroed, a chaser stays aggroed until the debug reset.
- Loot drops, XP, currency (→ Items & Economy).
- Player death flow and return to town (D-006). The debug scene refills player HP, as in F-003.
- Enemy hurt i-frames, poise, stagger, hyper armor as a separate system. The only hurt rule is the "planted" rule in C7.
- Contact damage. Touching an enemy body never hurts.
- Final art, animation, telegraph look, sound (→ Art & Game Feel). Placeholders only.
- Floor scaling of enemy stats, elites, variants.
- Changing the training dummy. `DummyData` / `DummyLogic` stay as they are.
- Order-independent body collision. Bodies keep moving one by one in registration order (C4).

---

## 2. Context  ·  _Planner_

What the Builder needs to know that isn't obvious from the code:
- **Source of truth:** `studio/design/combat.md` → *Enemies (phase 1)* (shared enemy rules + Chaser), *Hit / hurt system*, *Tunables index*.
- **Existing systems this touches (checked on `main`):**
  - `src/core/combat/combatant.gd` (`Combatant`): the API `CombatSim` talks to. Enemies are a new `Combatant` subclass. It has no perception hook today; T3 adds one with a no-op default.
  - `src/core/combat/combat_sim.gd` (`CombatSim.tick`): per step, `step()` on every combatant, then `fire_due_actions()`, `move_bodies`, `_apply_contact()`. T3 adds one perception pass at the start of each step, before any `step()`. `_apply_contact()` takes candidates in attacker registration order (F-003/C16). That stays.
  - `src/core/combat/combat_state.gd` (`CombatState`): HP, hitstop, knockback, hurt i-frames. Enemies use it with `has_hurt_iframes = false`, like the dummy. Hitstop and `knockback_duration` come from `PlayerCombatTunables` for every hit, enemy hits included. That stays. `_start_knockback()` clears any running push first, and starts none at zero distance.
  - `src/core/player/player_motor.gd` (`PlayerMotor.apply_hit`): picks `KNOCKBACK` or `IDLE` from `event.knockback_tiles > 0.0`. `EnemyLogic` follows the same pattern (C7).
  - `src/core/combat/hit_event.gd`: `HitEvent.from_candidate()` reads `target.get_knockback_scale()` at the moment the hit is applied. The planted rule (C7) uses exactly this hook.
  - `src/core/combat/hitbox.gd`: hitboxes are built fresh at every contact, so a lunging attack's origin follows the body for free.
  - `src/world/combat_runner.gd` (`CombatRunner`): registers the exported `combatant_paths` in order, owns reload (`reload_data()` is hard-coded to the warrior, player tunables, dummy and shake files, and reads `_players()[0]` only), reset and snapshots. `_dummies()` / `_players()` filter bodies by type. `_move_bodies()` moves bodies one by one in registration order, so a body sees the earlier ones already moved.
  - `src/ui/debug/motor_debug_overlay.gd`: F5 goes to the runner when the scene has one. `Player.reload_data()` runs only in F-001's scene, which has no runner and no enemies. So `CombatRunner.reload_data()` is the only reload that can change the Warrior's speed in a scene with enemies.
  - `src/entities/combat_body.gd` (`CombatBody`): `move_with_combatant()` sets velocity from the step displacement and calls `move_and_slide()`, then `sync_position()`.
  - Collision layers in `project.godot`: layer 1 `world`, layer 2 `player`. The player body is on layer 2. The dummy body is on layer 0 with mask 1. No `enemy` layer exists yet.
  - Input map: `debug_toggle`, `debug_reload_tunables` (F5), `debug_pulse_toggle` (P), `debug_shake_toggle` (K), `debug_reset` (R) exist. The `I` key is unbound. `tests/test_input_map.gd` asserts the exact action set, so adding `debug_ai_toggle` needs the same migration as F-003 T4.
  - `src/autoload/tunables.gd`: data paths are constants there (G5). `data/enemies/` holds only `training_dummy.tres`.
- **Relevant prior decisions:** D-002 (co-op later: no mechanic that only works with one player), D-005 (classes are data), D-007 (shared step grid: enemies advance by steps and inherit every F-003 timing rule).
- **Relevant prior features:** F-003 (hit/hurt, `CombatSim`, `CombatRunner`, the dummy). F-003 §10 Q3 left enemy hurt rules to this feature: answered by C7.
- **Folder note:** `PROJECT.md` lists `src/commands/` as "player/AI action commands". This feature keeps AI decisions as an intent object inside `src/core/` (see §3). Raised to Direction in §10 Q2.

---

## 3. Options Considered  ·  _Planner_

> This section is what stops context loss. Be honest about trade-offs.
> The Builder MUST NOT implement anything listed under Rejected.

### ✅ Chosen: `EnemyLogic` base combatant + one small brain per archetype, deciding at step starts
- **How it works:**
  - `EnemyLogic` (`Combatant`, `src/core/enemies/`) owns everything every enemy shares: HP and hit reaction through `CombatState`, the attack timeline (windup → active → recovery, aim tracking, lunge), attack cooldown, chase movement, aggro, target, death, serialization, reload and rate checks.
  - A **brain** (`EnemyBrain`, `RefCounted`, no state) is the only per-archetype code. When the enemy is free at a step start, the brain reads a read-only `CombatView` plus the enemy's own state and returns an `EnemyIntent`: where to move, how far at most, and whether to start the attack. F-004 ships `ChaserBrain`. `EnemyData.brain` (enum) picks it.
  - At the start of each combat step, `CombatSim` builds one `CombatView` (every combatant's id, team, position and whether it's alive) and gives it to every combatant **before** any of them advances (C4).
  - Every number is in `data/enemies/chaser.tres` and `data/attacks/chaser_swipe.tres`. The shared telegraph minimums are in `data/tunables/enemy_combat.tres`.
- **Why chosen:**
  - Logic stays in `src/core/`, unit-testable without a scene and runnable headless (G6, phase 3 server).
  - New enemies on later floors are mostly new data on an existing brain (G9). Only a new *kind* of behavior needs code, and it's one small class.
  - Sensing once per step for everyone means swapping enemies' registration order never changes what they decide from a given view (C4). Hits and bodies keep their existing order rules.
- **Costs we're accepting:**
  - Registration order still decides competing hits on one player (F-003/C16) and body collisions (C4). Those outcomes change later views, so two runs with swapped orders can differ after them.
  - AI reacts on the 1/120 s grid, not at exact instants. That's below what anyone can feel.
  - An enemy that becomes free mid-step (recovery, knockback or hitstop ending) holds still for the rest of that step.
  - A brain with no state is enough for the chaser. F-005/F-006 may need brain state; they add it to the enemy snapshot then.
  - One attack per enemy. F-006 decides how an enemy picks between several.
- **Would revisit if:** a brain needs memory across steps (patrols, combos), or many enemies make the per-step view expensive.

### ❌ Rejected: AI in the scene node (`_physics_process` per enemy, `NavigationAgent2D`)
- **How it would work:** each enemy scene runs its own process, steers with a navigation agent and calls attack methods.
- **Why rejected:** logic lands in the node tree (G6), there would be a second thing stepping logic besides `CombatRunner` (F-003 AC31), and navigation needs baked layouts that don't exist until Floors (phase 2).
- **Tempting because:** it's the standard Godot tutorial setup, and navigation comes built in.

### ❌ Rejected: Behavior-tree addon (LimboAI, Beehave)
- **How it would work:** each archetype is a behavior tree resource or node tree.
- **Why rejected:** a new dependency (G4) whose trees live in the scene tree (G6), for three archetypes whose behavior fits in a few lines each.
- **Tempting because:** it's the "proper" AI tool and scales to complex enemies.

### ❌ Rejected: Behavior fully defined in data (a state machine in a `.tres`)
- **How it would work:** states and transitions are resource entries, with no brain code at all.
- **Why rejected:** the three archetypes differ in *kind* (walk in, keep distance, charge), not just numbers. A data state machine would be a scripting language to design and debug, for three users.
- **Tempting because:** it sounds like the purest reading of G9.

### ❌ Rejected: Reusing the player's commands for AI (`MoveCommand`, `AttackCommand`)
- **How it would work:** the brain submits the same commands the input mapper does.
- **Why rejected:** player commands have input semantics: held per tick, presses buffered with ages (F-001/C15, F-003/C17). The AI decides per step from logic state and never needs a buffer. Forcing it through those rules adds latency and edge cases with no network benefit, because the AI runs where the logic runs.
- **Tempting because:** `PROJECT.md` lists `src/commands/` for "player/AI action commands" (→ Direction, §10 Q2).

### ❌ Rejected: Each enemy senses during its own `step()`
- **How it would work:** a brain reads other combatants' current state while the sim is advancing them one by one.
- **Why rejected:** an enemy registered after the player would see the player's new position, one registered before would see the old one. Registration order would change decisions.
- **Tempting because:** no extra pass and no view object.

### ❌ Rejected: Order-independent body collision (solving every body's move at once)
- **How it would work:** all bodies plan their step, then a solver resolves them together, so swapping registration order can't change who gets a gap.
- **Why rejected:** `move_and_slide()` moves one body at a time, so this means replacing how F-003 moves bodies. When two chasers contest a gap, either one taking it is fair to the player, and a fixed order already gives the same result every run.
- **Tempting because:** it would extend the order promise from decisions to positions.

### ❌ Rejected: Checking the speed rule only inside `EnemyData.validate()`
- **How it would work:** the enemy's own validation compares `move_speed` to a stored or shipped Warrior speed.
- **Why rejected:** `setup()` has no class, and a reload that lowers the Warrior's speed never re-runs enemy validation against it. The rule involves two resources, so it's checked where both are known (C12).
- **Tempting because:** one validation function, and the shipped chaser passes.

### ❌ Rejected: Clamping an enemy's speed below the Warrior's
- **How it would work:** at load, a too-fast enemy is quietly slowed to just under the player.
- **Why rejected:** Lucas would tune a number and the game would ignore it. Bad data is rejected, as with C8.
- **Tempting because:** the scene always runs.

### ❌ Rejected: Hits interrupt an enemy's attack (flinch / stagger)
- **How it would work:** any landed hit cancels the windup and stuns the enemy briefly.
- **Why rejected:** attacking first would always win. Mashing beats reading telegraphs, and a chaser could be locked forever by the 3-hit chain (pillar 2).
- **Tempting because:** it feels powerful and many action games do it.

### ❌ Rejected: Knockback moves an attacking enemy, and its attack carries on from the new spot
- **How it would work:** knockback always applies; the attack keeps its timeline wherever the enemy ends up.
- **Why rejected:** the finisher's 1.2-tile push during a windup would become a cheap answer to every attack, and a hitbox that jumps around mid-telegraph is hard to read (principle 1).
- **Tempting because:** "the finisher sends it flying" every time feels great.
- **Instead:** a committed enemy is planted (C7). Outside its attack it's pushed normally.

### ❌ Rejected: Aim locked at windup start (no tracking)
- **How it would work:** like the Warrior, the attack direction is fixed when windup begins.
- **Why rejected:** with a 0.5 s windup, a sidestep beats every swing, so the dodge stops mattering.
- **Tempting because:** simplest, and it matches the player's rule.

### ❌ Rejected: Aim tracks through the whole windup
- **How it would work:** the swing points at the player until the instant it goes active.
- **Why rejected:** a last-instant snap can't be read, so only perfect dash timing works. A fixed locked tail (`min_locked_telegraph`) is what makes it readable.
- **Tempting because:** it makes enemies look smart.

### ❌ Rejected: Hard body collision between players and enemies
- **How it would work:** enemy bodies block the player, and the dash stops on contact.
- **Why rejected:** a pack can corner the player with bodies instead of attacks. The dash gets eaten by bodies, and in co-op players could body-block each other's enemies. Positioning should be about hitboxes.
- **Tempting because:** it feels solid and classic.

### ❌ Rejected: Bodies pass through everything (the F-003 status quo)
- **How it would work:** enemies keep collision layer 0, like the dummy.
- **Why rejected:** three chasers converge into one blob, and their stacked telegraphs can't be read (principle 1).
- **Tempting because:** zero work.

### ❌ Rejected: Contact damage
- **How it would work:** touching an enemy body deals damage.
- **Why rejected:** it's an attack with no telegraph (principle 1).
- **Tempting because:** classic and cheap.

### ❌ Rejected: Removing dead enemies from the sim
- **How it would work:** a dead enemy is unregistered and its node freed.
- **Why rejected:** snapshots match by ids and order (F-003/C19). Removing breaks restore and the debug reset.
- **Tempting because:** a shorter list and a cleaner scene tree.
- **Instead:** a dead enemy stays registered and inert (C11).

---

## 4. Constraints  ·  _Planner_

Hard rules for this feature. Violating any of these = automatic `CODE_CHANGES`.

| ID | Constraint | Reason |
|---|---|---|
| C1 | Same scripted inputs at 30, 60 and 120 ticks/s give the same AI decisions, the same hits and the same positions (§5 tolerances). Enemies advance only through `step()` on the shared grid. | G1, D-007 |
| C2 | Every number comes from `data/`: per-enemy values from `data/enemies/chaser.tres`, its attack from `data/attacks/chaser_swipe.tres`, telegraph minimums from `data/tunables/enemy_combat.tres`, shared hit rules from `player_combat.tres` (as F-003). The body's collision radius is the data's `hurtbox_radius_tiles`. Paths are constants in `Tunables` (G5). | G2, G5, G9 |
| C3 | `EnemyLogic`, `EnemyBrain`, `ChaserBrain`, `EnemyIntent`, `CombatView` live in `src/core/`. They never touch nodes, physics queries, navigation, animation or sprites. A brain reads only the `CombatView` and its own enemy's state. | G6 |
| C4 | **Perception and decisions.** See below. | D-007, F-003/C16 |
| C5 | **Enemy timeline.** See below. | design doc |
| C6 | All new state is serializable via `to_dict()`/`from_dict()`: state, attack phase and elapsed time, latched attack values, aim and whether it's locked, hit set, lunge progress, cooldown, aggro, target id, `ai_enabled`, dead, position, and `CombatState`. Snapshot boundary as F-003/C19. | G7 |
| C7 | **Enemy hit reaction ("planted").** See below. Answers F-003 §10 Q3. | pillar 2 |
| C8 | **Telegraph floor.** Every enemy attack must satisfy `windup ≥ min_telegraph` and `windup − aim_track_time ≥ min_locked_telegraph` (values in `enemy_combat.tres`). Data that breaks this is rejected by validation, not clamped. | principle 1 |
| C9 | **Targets.** See below. | D-002 |
| C10 | **Bodies.** New layer 3 `enemy`. Enemy bodies: `collision_layer` = enemy, `collision_mask` = world + enemy. The player's layer and mask are unchanged, so players and enemies pass through each other, and enemies don't overlap each other. Walls stop chase and lunge. | §3 |
| C11 | **Death.** At HP 0 the enemy emits `died` once and becomes `DEAD` at that contact instant: its attack ends (hitbox gone, hit set *replaced*, like `AttackChain`'s), it can't be hit (`can_be_hit()` false), it makes no decisions and never moves again, and its body's collision layer and mask become 0. It stays registered. A hit it found at that same contact still lands (F-003/C16 trades). Only the debug reset brings it back. | F-003/C19 |
| C12 | **Data validity and hot-reload.** See below. Extends F-003/C18. | G2 |
| C13 | Teams: enemies are `Team.ENEMY`. They never hit each other or the dummies. The player's sword hits them. No friendly fire. | F-003/C9 |
| C14 | Presentation is derived from state (F-003/C12): body, HP bar, telegraph view, debug label. After `from_dict()` or a reset every view re-syncs. | F-003/C12 |
| C15 | Combat ids are set in the scene (`chaser_1`, `chaser_2`, `chaser_3`). The debug reset (R) re-runs `setup()` on every enemy with current data and its scene start position, like F-003/C20. Only debug settings survive: `ai_enabled`, pulse on/off, shake on/off. | F-003/C19, C20 |
| C16 | No new addons or dependencies. | G4 |
| C17 | Existing input actions keep their names and bindings. Only `debug_ai_toggle` (I) is added. | F-003/C14 |

**C4 — Perception and decisions**

- At the start of every combat step, before any combatant advances, `CombatSim` builds one `CombatView` and calls `sense(view)` on every combatant, in registration order. `Combatant.sense()` is a no-op by default, so the player and the dummy are unchanged.
- The view is a read-only snapshot as of the previous contact (hits already applied): per combatant, its `combat_id`, team, position in tiles, and `is_alive` (HP > 0 and not `DEAD`).
- **Free** means: not `DEAD`, not in hitstop, and not in `WINDUP`, `ACTIVE`, `RECOVERY` or `KNOCKBACK`.
- An enemy decides **only at a step start, and only if free there**. Then it asks its brain once, and the intent holds for the whole step.
- An enemy that becomes free mid-step holds still for the rest of that step, and decides at the next step start.
- With `ai_enabled` false (debug), a free enemy makes no decision: it holds still and starts no attack. A running attack and knockback still finish.

What this promises, exactly: **swapping enemies' registration order never changes what any enemy decides from a given view.** It promises nothing about what happens after the decision:

- **Competing hits stay F-003/C16.** Candidates apply in attacker registration order. When two enemies first touch one player at one instant, the first registered lands, its hurt i-frames skip the other, and the other stays unmarked and gets no hitstop. Swapping the order swaps who lands, and so the knockback direction.
- **Body movement stays F-003/C15.** Bodies move one by one in registration order, so two chasers contesting one gap resolve by order. Collision-order independence is outside this promise (§3).
- **Target ties stay C9.** Equal distances go to the *player* registered first. That's the rule working, not a leak: swapping enemies doesn't touch it.

Once any of these changes a position or a hit, later views differ, and so may later decisions. With one fixed order, every run still gives the same result.

**C5 — Enemy timeline**

States: `IDLE`, `CHASE`, `WINDUP`, `ACTIVE`, `RECOVERY`, `KNOCKBACK`, `DEAD`. Phase ends fall at exact times inside a step and overshoot is carried (F-003/C15). Hitstop is consumed first in every step and pauses every enemy timer, including windup, lunge and cooldown (F-003/C7).

What the chaser's brain decides when free, at a step start, in this order:
1. No living player in the view → `IDLE`, no movement.
2. Not aggroed and no living player within `aggro_radius_tiles` → `IDLE`. Aggro also starts when the enemy takes damage (from the next step start). Once aggroed, it stays aggroed.
3. Pick the target (C9). If the cooldown is ready and the target's distance ≤ `attack_range_tiles` → start the attack: `WINDUP` begins at this step start.
4. Otherwise `CHASE`: move straight toward the target at `move_speed` (tiles/s, no accel). Never move closer than `stop_distance_tiles`: the step's movement is `min(move_speed × s, distance − stop_distance_tiles)`, at least 0.

Distances are center to center, in tiles, from the view. Every distance comparison uses `Geometry.DISTANCE_EPSILON` (1e-6 tiles, a new constant in `src/core/combat/geometry.gd`): "within `aggro_radius_tiles`" and "≤ `attack_range_tiles`" mean `distance ≤ value + DISTANCE_EPSILON`; a chase step whose remaining gap to `stop_distance_tiles` is ≤ `DISTANCE_EPSILON` moves 0. Positions are accumulated step by step, so without this an exact boundary (AC16's 1.6) falls on either side depending on the tick rate (C1).

The attack, with every `EnemyAttackData` field latched at windup start:
- **Windup.** Rooted. At every step start while `windup elapsed < aim_track_time`, aim = direction to the target's sensed position. From `aim_track_time` on, aim is **locked**. The target is fixed for the whole attack. If the direction is zero, aim keeps its previous value (initial facing: down).
- **Active.** The hitbox is a sector from the enemy's current position along the locked aim (`arc_angle_deg`, `range_tiles`). The enemy moves `lunge_tiles` along the aim over `active`, at constant speed on its own clock. Walls stop it (physics position is authoritative, F-003/C15). One hit per hurtbox per attack instance (F-003/C8).
- **Recovery.** Rooted, no hitbox. This is the punish window.
- When recovery ends, `attack_cooldown` starts and the enemy is free.

The cooldown runs in every state except `DEAD`, and pauses in hitstop. "Ready" means it is within `TIME_EPSILON` of 0.

**C7 — Enemy hit reaction ("planted")**

| Enemy state when hit | Damage | Hitstop | Knockback | Interrupts |
|---|---|---|---|---|
| `WINDUP`, `ACTIVE`, `RECOVERY` (committed) | yes | yes | **no** | **no** |
| Anything else alive, distance after scaling > 0 | yes | yes | `knockback × knockback_scale`, replacing any running push | yes: `KNOCKBACK` until it ends, no decisions |
| Anything else alive, distance after scaling = 0 | yes | yes | none, and any running push is cleared | yes: `IDLE` at the contact instant, never enters `KNOCKBACK` |
| `DEAD` | — (can't be hit) | — | — | — |

- Implemented through `get_knockback_scale()`, which returns 0 while committed. F-003's existing knockback code then skips the push.
- **Zero distance** adopts F-003/C17's rule. It means `event.knockback_tiles` is not > 0, whether from the attack's `knockback_tiles` = 0 or the enemy's `knockback_scale` = 0. `EnemyLogic.apply_hit()` first leaves a committed enemy's state alone, then picks `KNOCKBACK` or `IDLE` from that value, like `PlayerMotor.apply_hit()`. So `KNOCKBACK` always has a push behind it, and can't get stuck waiting for one.
- **A zero-distance hit during `KNOCKBACK`** ends the push at that contact instant: `CombatState` drops the remaining distance, and the state becomes `IDLE`. The enemy stops where it is.
- After a zero-distance hit, the enemy resumes by C4: it decides at the first step start where it's free, so after hitstop has ended. If hitstop ends mid-step, it holds still for the rest of that step.
- A committed enemy never has a running push, because an attack starts only when free and `KNOCKBACK` isn't free.
- No hurt i-frames for enemies (`has_hurt_iframes = false`). F-003/C8's once-per-instance rule is the only protection.
- The hitstop rules are F-003's: both sides, `max(remaining, new)`, and they pause the windup too. Hitting a winding-up chaser delays its swing by the hitstop. It never cancels it.

**C9 — Targets (co-op ready)**

- Candidates are combatants in the view with `Team.PLAYER` and `is_alive`.
- The target is the **nearest** candidate. Ties go to registration order.
- It is picked again at every decision (free step starts), and kept fixed during an attack.
- Nothing assumes exactly one player. Core tests run with two player motors.

**C12 — Data validity and hot-reload**

| Resource | Rule |
|---|---|
| `EnemyAttackData` (extends `AttackData`) | Every `AttackData` rule from F-003/C18, plus: `aim_track_time` ≥ 0; `windup` ≥ `min_telegraph`; `windup − aim_track_time` ≥ `min_locked_telegraph`; `lunge_tiles` ≥ 0; `is_finisher` is false |
| `EnemyData` | `id` not empty; `brain` is a known value; `max_hp` ≥ 1; `hurtbox_radius_tiles` > 0; `knockback_scale` ≥ 0; `move_speed` ≥ 0; `aggro_radius_tiles` ≥ 0; `attack_range_tiles` > 0; `stop_distance_tiles` ≥ 0; `attack_cooldown` ≥ 0; `attack` not null and valid |
| `EnemyCombatTunables` | `min_telegraph` ≥ 0; `min_locked_telegraph` ≥ 0; `min_locked_telegraph` ≤ `min_telegraph` |
| Enemy against class (speed rule) | `EnemyData.validate_against_class(class_data)`: `enemy.move_speed` < `class_data.move_speed`, strictly. Equal is rejected. Plain float comparison: both are authored values, so no epsilon |

- `EnemyData.validate(step_rate, enemy_tunables)` checks its attack. Comparisons use `TIME_EPSILON`, so exact minimums pass.
- **Speed rule.** The design doc's "never faster than the player on foot". It covers walking `move_speed` only: lunges and later charges may be faster. It isn't part of `EnemyData.validate()`, because `setup()` has no class (§3). `CombatRunner` runs it at two points:
  - **Scene setup.** In `_ready()`, after registering everyone: every enemy against every player's `class_data`. On any failure it calls `push_error` for each one, naming the enemy and both speeds, keeps them in `get_setup_errors()`, and calls `set_physics_process(false)`, so nothing steps. The fix is to correct the file and restart the scene; F5 doesn't restart a stopped fight. A scene with no enemies has nothing to check and behaves as today.
  - **Reload.** Inside the atomic group, before anything is applied: the candidate `ClassData` against every candidate `EnemyData`, so changes made in the same F5 count together. A failure rejects the whole group. F-003's reload handles one player, and this check goes with it; a second class in one scene extends both.
- **Reload group.** F5 (`CombatRunner.reload_data()`) adds to F-003's atomic group: `enemy_combat.tres` and every distinct `EnemyData` used by the scene's enemies (with their attack files), loaded with `CACHE_MODE_IGNORE_DEEP`. If any file fails, nothing changes and the overlay shows the errors.
- **Rate check.** An enemy in `WINDUP` or `ACTIVE` reports its latched `[windup, active]` from `get_running_window_errors()`, so F-003's rate check covers it.

| Value on a valid reload | Rule |
|---|---|
| Attack in progress | Latched at windup start; it finishes unchanged. The next attack reads the new data |
| `max_hp` | `hp = min(hp, max_hp)`; raising it doesn't heal |
| Cooldown, knockback, hitstop in progress | Kept |
| Movement, aggro, range, stop distance, `knockback_scale`, `hurtbox_radius_tiles` | From the next step start (radius: next contact, and the body shape follows it) |
| `enemy_combat.tres` | Applies to validation only. Running attacks are never re-checked against it |

**Must not break:** all F-001 and F-003 behavior and tests, with their test files unedited, except the input-map migration (T9). That includes F-003/C16's candidate order and the one-by-one body movement. F-003's debug scene (`f003_sword.tscn`) and F-001's scene behave as today. `tools/test`, `tools/lint`, the core purity check and `tools/test_studio` pass.

---

## 5. Acceptance Criteria  ·  _Planner_

Testable, observable. The Auditor checks each one.

**Oracle and tolerances.** As F-003: scripted commands at 30, 60 and 120 ticks/s, changed and sampled only at multiples of 1/30 s. Positions ± 0.01 tiles, combat times ± 1 µs. Default data unless stated. Times in seconds.

**Data**
- [ ] AC1 — **Validation:** every C12 bound is tested on both sides, including C8's two telegraph rules with exact minimums passing. An enemy with invalid data fails `setup()` and changes nothing.
- [ ] AC1b — **Speed rule (C12), in core:** against a class at 5.0, an enemy at 3.0 or 4.99 passes, and one at 5.0 or 6.0 is rejected. Against a class lowered to 3.0, an enemy at 3.0 is rejected, and one at 2.99 passes. Each error names the enemy and both speeds.

**Decisions**
- [ ] AC2 — **Aggro:** a chaser stays `IDLE` until a living player is within `aggro_radius_tiles`, or until it takes damage (aggroed from the next step start). Once aggroed, moving out of the radius doesn't stop it.
- [ ] AC3 — **Target (C9):** with two player motors, the chaser targets the nearer one. Equal distances → the one registered first. A target at HP 0 is skipped. The target doesn't change during an attack.
- [ ] AC4 — **Chase:** straight toward the target at `move_speed`, never ending a step closer than `stop_distance_tiles`, and holding still there.
- [ ] AC4b — **Distance boundaries (C5):** a target at exactly `attack_range_tiles`, `aggro_radius_tiles` or `stop_distance_tiles` after accumulated chase steps counts as in range / arrived at 30, 60 and 120 ticks/s; one at `value + 1e-4` does not.
- [ ] AC5 — **Perception order (C4):** in core, at each tick rate, for 3 s. Player at (0, 0), walking right the whole run. `chaser_a` at (3, 2), `chaser_b` at (3, −3). Run 1 registers `[chaser_a, player, chaser_b]`, run 2 `[chaser_b, player, chaser_a]`, so an enemy reading the live player would see a different position in each run. Compared by id at every tick: position, state, aim and target. Within one rate the values match exactly. Both chasers start a windup (at about 0.32 and 0.56) and both swings miss. The test asserts that no hit candidate ever appears, so the run has no competing hits and, in core, no bodies.
- [ ] AC5b — **Simultaneous hits keep F-003/C16:** player at (0, 0), registered first, never moves. `chaser_1` at (0, 3), `chaser_2` at (3, 0). Both start a windup at 56/120 and both first touch the player at 117/120. Registered `[player, chaser_1, chaser_2]`: `chaser_1` lands, the player has 80 HP and is knocked to (0, −0.8), and `chaser_1` gets the hitstop. `chaser_2` is skipped by the new hurt i-frames: no hitstop, the player isn't in its hit set, and its active ends at 128/120 without a hit. Registered `[player, chaser_2, chaser_1]`: `chaser_2` lands and the player is knocked to (−0.8, 0). Exactly one hit lands in each run.
- [ ] AC6 — **Decision timing (C4):** a chaser whose recovery, knockback or hitstop ends mid-step holds still for the rest of that step and decides at the next step start.

**Attack**
- [ ] AC7 — **Start:** when free, aggroed, cooldown ready and target distance ≤ `attack_range_tiles`, `WINDUP` begins at that step start and the chaser is rooted.
- [ ] AC8 — **Aim:** during windup the aim follows the target, updated at step starts, until `aim_track_time`. After that it never changes. The active hitbox points along the locked aim.
- [ ] AC9 — **Phases and lunge:** windup → active → recovery with the latched durations. The hitbox exists only during active. The chaser moves exactly `lunge_tiles` along the aim during active, with zero displacement while in hitstop.
- [ ] AC10 — **Cooldown:** starts when recovery ends, pauses in hitstop. The chaser chases during it but can't attack until it's ready.
- [ ] AC11 — **Telegraph floor:** no valid data can produce an attack with less than `min_telegraph` of windup or less than `min_locked_telegraph` between lock and active (follows from AC1, asserted on a running attack).

**Hit / hurt**
- [ ] AC12 — **Planted (C7):** a sword hit during windup, active or recovery deals damage and hitstop, moves the chaser 0 tiles and doesn't change its phase timeline except for the hitstop pause. A hit while it's chasing pushes it `knockback × knockback_scale`, puts it in `KNOCKBACK` (no movement, no decisions) and it chases again after.
- [ ] AC12b — **Zero distance (C7):** each case runs once with a sword hit of `knockback_tiles` 0 and once with `knockback_scale` 0 on the chaser.
  - A chasing chaser that is hit takes damage and hitstop, never enters `KNOCKBACK`, doesn't move during hitstop, and chases again from the first free step start after hitstop ends.
  - A chaser in the middle of a push takes a zero-distance hit: the rest of the push is dropped at that contact instant, it leaves `KNOCKBACK` for `IDLE`, and it stays where it stopped until the same first free step start. (For `knockback_scale` 0, the push comes first and a reload sets the scale before the hit.)
  - A committed chaser's phase timeline is unchanged, as in AC12.
- [ ] AC13 — **Chaser hits the player:** every F-003 rule applies unchanged: damage, knockback direction (chaser → player), hitstop on both, hurt i-frames, dash i-frames, vulnerable dash tail, once per attack instance, and candidate order (AC5b).
- [ ] AC14 — **Teams (C13):** a chaser's hitbox overlapping another chaser or a dummy produces no candidate.
- [ ] AC15 — **Death (C11):** 50 HP: a full chain (42) plus one hit 1 kills a chaser. `died` once. After that: no hitbox, no hurtbox hit, no movement, no decisions, body layer and mask 0, still in the sim's order. A chaser killed at a contact where its own hitbox also touched the player still lands that hit.

**Frame-rate oracle**
- [ ] AC16 — **Run A, standing still.** Player at (0, 0), never moves or attacks. One chaser at (0, 3), aggro on.

      | Time | Expected |
      |---|---|
      | 56/120 (0.4667) | Distance reaches 1.6 → windup starts at (0, 1.6), aim (0, −1) |
      | 92/120 (0.7667) | Aim locks |
      | 116/120 (0.9667) | Active starts. The contact at this instant misses (distance 1.6 > 1.2 + 0.35) |
      | 117/120 (0.975) | Hit lands: player HP 80, both enter 0.05 s hitstop. Player knocked to (0, −0.8) |
      | 134/120 (1.1167) | Active ends; chaser at (0, 0.8) after the full lunge |
      | 206/120 (1.7167) | Recovery ends; cooldown starts; chaser chases |
      | 230/120 (1.9167) | Chaser reaches stop distance at (0, 0.2) and holds |
      | 302/120 (2.5167) | Cooldown ready → second windup starts |

      At 2.6: player HP 80 at (0, −0.8); chaser in windup at (0, 0.2); exactly one hit landed.
- [ ] AC17 — **Run B, dash after the lock.** Same start. At 0.8 (after the lock at 0.7667): dash + move right for 1/30 s. The dash ends at (3, 0) at 0.95. The swing goes down, on its locked aim, and misses. Recovery ends at 200/120 (1.6667), the chaser chases toward (3, 0) and holds at distance 1.0, at (2.0338, 0.2577). Its cooldown is ready at 296/120 (2.4667), when it starts a windup. At 2.5: player HP 100, no hit landed.
- [ ] AC18 — Runs A and B hold in core at every rate, and once in a scene over real physics at every rate.

**State and data**
- [ ] AC19 — **Serialization:** snapshot at the C19 boundary while a chaser is mid-windup (before and after lock), mid-active with the lunge half done, mid-recovery, mid-cooldown, in knockback, in hitstop, and dead. Restore into fresh objects registered in the same order: the next 60 ticks match an unbroken run.
- [ ] AC20 — **Hot-reload (C12):** an invalid value in `chaser.tres`, `chaser_swipe.tres` or `enemy_combat.tres` rejects the whole group. A valid change to `chaser_swipe.tres` mid-attack lets that attack finish on latched values, and the next attack uses the new ones. Lowering `max_hp` clamps HP. A step-rate change that would break a running enemy window is rejected and names that enemy. The speed rule reads the candidate files together: chaser `move_speed` 5.0 or 6.0, or Warrior `move_speed` 3.0 or 2.0, rejects the whole group, and nothing changes, including valid edits to other files in that reload. Chaser 6.0 with Warrior 7.0 in one reload is accepted, and so is Warrior 2.0 with chaser 1.5.
- [ ] AC20b — **Speed rule at scene setup (C12):** a scene whose chaser has `move_speed` 5.0, or whose player class has `move_speed` 3.0, doesn't start: an error is pushed, `CombatRunner.get_setup_errors()` names the enemy and both speeds, and `CombatSim.get_time()` is still 0 after 10 physics ticks. With default data the list is empty and the fight runs.

**Scene**
- [ ] AC21 — **Bodies (C10):** in a scene, the player walks and dashes through a chaser. Three chasers converging on the player never overlap (center distance ≥ 2 × radius − 0.01 tiles). A chaser chasing or lunging into a wall stops at it, and its logic position equals its body position at every contact instant.
- [ ] AC22 — **Debug:** I toggles `ai_enabled` for every enemy (between ticks). R resets per C15. F5 reloads per C12. Each enemy shows an HP bar, a damage number on hit, a death look, a debug label (state, cooldown, target) and the telegraph view below. Every view re-syncs after restore and reset.
- [ ] AC23 — **Telegraph view (placeholder):** during windup an outline of the attack sector points along the current aim. From the lock instant it's drawn locked (brighter or filled). During active the sector is solid. During recovery the body is tinted "open". Look → Art & Game Feel (§10 Q1).
- [ ] AC24 — **Coverage map:**
  - **Core tests, no scene** (`tests/core/enemies/`): AC1–AC17 (incl. AC1b, AC4b, AC5b, AC12b), AC19, AC20's validation, latching and rate check.
  - **Scene tests** (`tests/scenes/test_f004_*.gd`): AC18's physics runs, AC20 end to end, AC20b, AC21–AC23.
  - **Input map:** `debug_ai_toggle` added, every existing assertion kept.
  - F-001 and F-003 tests pass unedited, except the input-map migration.

**How to verify manually (feel test):**
Open `scenes/debug/f004_chaser.tscn`. Play about 5 minutes with KB/M, then with a gamepad.
- **One chaser.** You should see every swing coming. Watching the outline lock, then stepping or dashing aside, should feel like *your* skill, not luck.
- **Punish.** Dodge, then turn and hit it in its recovery. A clean punish should feel earned, and the swing that follows should feel like a fair warning to back off.
- **Mash instead.** Hit it first and keep swinging. It should still swing at you: trading should feel like a bad deal.
- **Finisher while it's walking.** It should be shoved back and have to walk in again.
- **Three chasers.** Busy but readable. They should never stack into one blob, and you should never get trapped by bodies.
- **Walk away.** You should always be able to outrun them on foot.
- Tune a value (e.g. `windup`, `aim_track_time`), press F5, and feel the difference.

---

## 6. Task Breakdown  ·  _Planner_

Small, ordered, each independently committable.

| # | Task | Files likely touched | Notes |
|---|---|---|---|
| T1 | Data types | `src/core/combat/geometry.gd` (`DISTANCE_EPSILON`, C5), `src/core/enemies/enemy_data.gd` (`EnemyData`), `src/core/enemies/enemy_attack_data.gd` (`EnemyAttackData extends AttackData`), `src/core/tunables/enemy_combat_tunables.gd` (`EnemyCombatTunables`) | Fields from the design doc's *Tunables index*. `EnemyData.Brain` enum: `CHASER`. All C12 validation, using `CombatTiming` for the window rules, plus `EnemyData.validate_against_class(class_data)`. `AttackData` itself is unchanged. |
| T2 | Data files + paths | `data/enemies/chaser.tres`, `data/attacks/chaser_swipe.tres`, `data/tunables/enemy_combat.tres`, `src/autoload/tunables.gd` | Values from the design doc. Path constants (G5). |
| T3 | Perception hook, no behavior change | `src/core/combat/combatant.gd`, `src/core/combat/combat_view.gd` (`CombatView`), `src/core/combat/combat_sim.gd` | `Combatant.sense(view)` no-op. `CombatSim.tick` builds the view and calls `sense` on all combatants at each step start, before `step()` (C4). All F-003 core tests pass unedited. |
| T4 | `EnemyLogic` | `src/core/enemies/enemy_logic.gd`, `src/core/enemies/enemy_intent.gd`, `src/core/enemies/enemy_brain.gd` | `Combatant` subclass per C4, C5, C7, C9, C11. `setup(data, enemy_tunables, step_rate, start_position_tiles, combat_id)`, `apply_data()`, `set_ai_enabled()`. Brain factory from `EnemyData.brain`. `apply_hit()` picks the state per C7, zero distance included, like `PlayerMotor.apply_hit()`. Serialization (C6) and `state_restored` signal like `DummyLogic`. `get_running_window_errors()` per C12. |
| T5 | `ChaserBrain` | `src/core/enemies/chaser_brain.gd` | Stateless. Implements C5's decision order. Returns an `EnemyIntent` (move direction, max move distance, start attack). |
| T6 | Core tests | `tests/core/enemies/test_enemy_data.gd`, `test_enemy_logic.gd`, `test_chaser_brain.gd`, `test_enemy_combat.gd`, `test_enemy_snapshot.gd`, `test_enemy_oracle.gd` | AC24's core row. Uses real `PlayerMotor`s as targets, two of them for AC3. AC5 and AC5b each run both registration orders. |
| T7 | Enemy body + views | `src/entities/enemies/enemy.gd` (`Enemy extends CombatBody`), `src/entities/enemies/enemy.tscn`, `project.godot` (layer 3 `enemy`) | One generic scene for every enemy: `@export var data: EnemyData`, `combat_id`. Body circle radius from data. Layers per C10, both 0 when dead (C11). Placeholder visuals: body circle, HP bar, damage numbers (reuse `DamageNumbers`), death look, debug label, telegraph view (AC23). All derived from state (C14). |
| T8 | Runner | `src/world/combat_runner.gd` | `_enemies()` filter. Reload group and validation per C12, including the speed rule against the candidate class. Speed rule at `_ready()`, with `get_setup_errors()` and `set_physics_process(false)` on failure (C12). Reset per C15. `toggle_ai()`. Existing dummy paths and `_move_bodies()` order unchanged. |
| T9 | Input | `project.godot`, `tests/test_input_map.gd`, debug overlay key handling | Add `debug_ai_toggle` (I). Migrate the input-map test like F-003 T4. |
| T10 | Debug scene | `scenes/debug/f004_chaser.tscn` | Walled room with one inner pillar. Player, `chaser_1` about 5 tiles away, `chaser_2` and `chaser_3` further back. A `CombatRunner` last, with `refill_player_on_died` on. Shake and overlay as in F-003's scene. |
| T11 | Scene tests | `tests/scenes/test_f004_*.gd` | AC24's scene row. `user://` data copies for reload, like F-003. |
| T12 | Glossary | `studio/GLOSSARY.md` | Add: Enemy, Archetype, Brain, Intent, Combat view, Aggro, Target, Aim tracking / Aim lock, Lunge, Attack cooldown, Planted, Free (enemy). |

---

## 7. Plan Review  ·  _Auditor_

<Each completed round starts with its machine line (format in AGENTS.md), then its findings.
Severity: 🔴 blocking · 🟡 should fix · 🔵 suggestion. Example finding:>

### PR-1 🔴 <title>
<What's wrong, where, why it matters, what you'd suggest.>
> **Planner reply:** <accepted / rejected + reason / changed §X>

<!-- review-round: 1 verdict: CHANGES_REQUESTED -->

**Verdict:** CHANGES_REQUESTED — two blocking findings (PR-1, PR-2), one should-fix finding (PR-3).

The goal is a clear player-facing outcome serving pillar 2, with explicit scope boundaries and substantive alternatives. Direction has already resolved the AI-command question in Q2. The remaining issues concern the scope of the order-independence promise, a shared design constraint missing from validation, and one hit-reaction edge case.

### PR-1 🔴 Scope the perception-order oracle so it preserves F-003's hit priority

**Location:** §3 chosen option; §4 C4 and "Must not break"; §5 AC5/AC13/AC24. Related: F-003 §4 C16 and `src/core/combat/combat_sim.gd:150`.

**Problem:** AC5 requires identical positions, states and hits for 3 seconds after swapping two chasers' registration order, without excluding competing hits. With the player at (0, 0) and aggroed chasers at (0, 3) and (3, 0), both default swipes first touch the player at 117/120. F-003 applies candidates in attacker registration order: the first hit grants player hurt i-frames, so the other is skipped. Only the successful attacker receives hitstop, and its knockback direction moves the player along a different axis when the order is swapped. A shared perception snapshot cannot make those outcomes identical. Scene body movement also remains sequential in registration order (`src/world/combat_runner.gd:116`), so the perception hook alone does not establish an order-independent collision result.

**Why it matters:** The Builder cannot satisfy an unrestricted AC5 while preserving the hit rules and unedited F-003 tests required by AC13/AC24. The test needs a defined fixture and a narrower invariant.

**Suggested fix:** Define AC5 as a perception/decision test using identical starting views and a fixture without competing hits or body collisions. Compare decisions before order-dependent outcomes occur. Explicitly retain F-003's candidate priority, and add a simultaneous two-chaser hit case expecting the first registered attacker to land. State whether collision-order independence is outside this promise; if it is required, specify and task the additional body-resolution work.

> **Planner reply (Combat):** accepted. C4 now states the promise exactly: swapping enemies' registration order never changes what they decide from a given view. It keeps F-003/C16's candidate order, keeps one-by-one body movement, and says target ties go by the players' order. Collision-order independence is outside the promise: §1 out of scope, §3 Rejected, no new task. §5 AC5 now has a defined fixture: a walking player registered between the chasers, so a live read would fail, compared by id at every tick, with no hit candidate in the run. New AC5b covers the simultaneous hit in both orders. Also changed §2, §3's chosen option and costs, AC13, AC24, T6 and "Must not break", and the *Perception and decisions* rule in `design/combat.md`.

✔ resolved (round 2): C4 scopes the invariant to decisions from the same view, AC5 excludes hit candidates and bodies, and AC5b explicitly preserves competing-hit priority in both registration orders. Collision-order independence is expressly rejected and out of scope.

### PR-2 🔴 Preserve the design's enemy/player walking-speed relationship

**Location:** §4 C12 validation/reload group; §5 AC1/AC20 and "Walk away" feel test; §6 T1/T8. Related: `studio/design/combat.md:117`.

**Problem:** The shared enemy design requires every enemy's `move_speed` to be below the Warrior's so the player can always outrun it on foot. C12 checks only `move_speed ≥ 0`; neither its validation API nor the atomic reload contract checks the relationship to the class resource. Thus an enemy speed of 6 with the default Warrior speed of 5 passes the listed rules, as does lowering Warrior speed below the chaser's unchanged 3. This exception to the design is not flagged.

**Why it matters:** A reload accepted as valid can remove the promised walking escape and contradict a shared combat rule. Checking the shipped chaser resource alone misses changes to the player's speed in the same reload group.

**Suggested fix:** Specify a cross-resource check at scene setup and before committing a reload: every scene enemy's walking speed must be strictly below the applicable Warrior speed, using the candidate class and enemy resources together. Alternatively obtain an explicit design exception. Add boundary coverage for equal/faster enemy speed and for lowering Warrior speed, including atomic rejection with no state changes.

> **Planner reply (Combat):** accepted, no design exception. C12 adds `EnemyData.validate_against_class()`, strict, and `CombatRunner` runs it at both points. At `_ready()`, any failure pushes the errors, keeps them in `get_setup_errors()` and stops the fight. On reload, it checks the candidate class against the candidate enemies before anything is applied, so one F5 changing both sides is judged together. `CombatRunner.reload_data()` is the only reload path in a scene with enemies (§2). §3 rejects checking inside `validate()` alone, and clamping. New AC1b covers the boundaries in core, AC20 covers atomic rejection from both sides, and new AC20b covers scene setup. Also changed T1, T8, AC24 and the shared rule in `design/combat.md`.

✔ resolved (round 2): C12 checks the strict enemy/class speed relationship before setup can step and before an atomic reload applies anything. AC1b, AC20 and AC20b cover equal/faster enemies, a slower Warrior, jointly valid edits and rejection without state changes; T1/T8 assign the work.

### PR-3 🟡 Define the zero-knockback hit path

**Location:** §4 C7 reaction table and C12 valid ranges; §5 AC12. Related: `src/core/combat/combat_state.gd:161` and F-003 §4 C17.

**Problem:** C7 puts every uncommitted enemy that is hit into `KNOCKBACK` until it ends, but C12 permits `knockback_scale = 0` and inherited `AttackData` permits `knockback_tiles = 0`. `CombatState` clears any previous knockback and starts none for that result. The plan does not say whether the enemy skips `KNOCKBACK`, how it becomes free again, or what a zero-distance hit does to an existing push.

**Why it matters:** The Builder must invent a state transition for valid data, risking an enemy stuck waiting for knockback that never started or resuming decisions at a different instant than C4 permits.

**Suggested fix:** Explicitly adopt F-003's zero-distance rule: clear the previous push, skip `KNOCKBACK`, retain damage/hitstop, and resume decisions at the next step start where C4 says the enemy is free. Cover both zero attack distance and zero target scale, including a zero-distance hit during an existing knockback.

> **Planner reply (Combat):** accepted. C7 splits the uncommitted row by distance after scaling. At zero, damage and hitstop stay, any running push is cleared, the state becomes `IDLE` at the contact instant and `KNOCKBACK` is never entered, so it can't be left with no push behind it. The enemy resumes at the first free step start under C4. New AC12b covers `knockback_tiles` 0 and `knockback_scale` 0, each on a chasing chaser and during an existing push. AC6 now includes hitstop ending mid-step. Also changed §2, T4 and the *Planted* rule in `design/combat.md`.

✔ resolved (round 2): C7 explicitly clears an existing push and enters `IDLE` for an uncommitted zero-distance hit, while committed enemies retain their attack. AC12b covers both zero-distance sources and replacement of a running push; AC6/C4 define when decisions resume after hitstop.

**Source-reference correction (round 1):** PR-1's `_apply_contact()` starts at `src/core/combat/combat_sim.gd:121`; PR-3's `_start_knockback()` starts at `src/core/combat/combat_state.gd:149`. These replace the source-line anchors in their Location paragraphs; the findings are unchanged.

<!-- review-round: 2 verdict: APPROVE -->

**Verdict:** APPROVE — PR-1, PR-2 and PR-3 resolved; no new findings.

Checked each Planner reply against the revised constraints, acceptance criteria, tasks and shared combat design. The plan defines one player-facing outcome serving pillar 2, with explicit scope boundaries and specific reasons for rejecting alternatives. It preserves D-007's step grid, F-003's contact and snapshot rules, the core/presentation separation, serializable enemy state and data-driven content. Direction's Q2 answer resolves the AI-command question.

The revised acceptance criteria distinguish shared perception from order-dependent hit and body outcomes, exercise the cross-resource speed check at both entry points, and cover zero-distance hit reactions. The task breakdown assigns those changes and preserves the existing test suites. Independently checked AC16's step-count arithmetic and AC17's stopping position against C4/C5 and the default values; they agree. Placeholder telegraph art and encounter composition remain explicitly delegated and do not block this plan.

Gate A remains with Lucas. Status stays `PLAN_REVIEW`; next actor is `Lucas`.

---

## 8. Implementation Log  ·  _Builder_

**Started:** YYYY-MM-DD  ·  **Branch:** `feature/F-004-enemy-chaser`

### Progress
- [ ] T1 — <commit hash when done>
- [ ] T2

### Deviations from plan
<Every place the code differs from §3–§6, with reason. "None" if none.>
- DEV-1: <what changed> — **Why:** <reason> — **Impact:** <what else this affects>

### Assumptions made (small, reversible)
- ASSUMPTION-1: <the gap in the spec> → <what I chose> — **Why:** <reason>

### Things the Auditor should look at closely
- <tricky spots, edge cases you're unsure about>

### How to test
<exact steps / commands / scene to run>

---

## 9. Code Review  ·  _Auditor_

<Each completed round starts with its machine line (format in AGENTS.md), then
`**Reviewed commit:** <hash>`, AC evidence and findings. Example finding:>

### CR-1 🔴 <title>  ·  `path/to/file:line`
<problem, why it matters, suggested fix>
> **Builder reply:** <fixed in abc123 / disagree because …>

---

## 10. Open Questions  ·  _Anyone (append)_

| # | Raised by | Question | Blocking? | Answer (Lucas/Planner) |
|---|---|---|---|---|
| Q1 | Combat | → Art & Game Feel: the look of enemy telegraphs (outline, lock cue, active, "open" recovery tint) and a sound cue at windup start. Placeholders in this feature only (design doc CX5). | no | |
| Q2 | Combat | → Direction: `PROJECT.md` lists `src/commands/` as "player/AI action commands". This feature keeps AI decisions as `EnemyIntent` in `src/core/enemies/` (§3). Update the folder note, or should AI go through commands? | no | **Direction:** keep `EnemyIntent` in `src/core/enemies/`. G8 exists so player input can cross the network; AI runs where the logic runs and has nothing to send. `PROJECT.md` folder note now reads `commands/ # player action commands (G8). AI decides through intents in core/enemies/ (F-004)`. |
| Q3 | Combat | → Direction: which enemies appear on floors 1–3, and in what groups? The Floors department starts in phase 2, but phase 1 needs this (design doc CX6). | no | **Direction:** accepted as the phase-1 plan: floor 1 chasers only, floor 2 chasers + casters, floor 3 all three. Group sizes and placement belong to the feature that builds floor 1 (Direction owns floor structure until Floors starts in phase 2). F-004 needs none of it. |

---

## 11. Director Notes  ·  _Lucas_

<Overrides, priorities, gut calls. Everyone obeys these.>
