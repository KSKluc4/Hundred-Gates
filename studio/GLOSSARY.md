# GLOSSARY

> One term, one meaning. If two agents use a word differently, bugs follow.
> Add a term the first time it's used in a spec. Code names should match these.

| Term | Meaning | Code name |
|---|---|---|
| Player | The character the user controls | `Player` |
| Tick | One fixed-timestep logic update | `tick` / `_physics_process` |
| Tunable | A number Lucas may adjust for game feel; lives in config | `Tunables.*` |
| Vertical slice | First playable build containing one full gameplay loop | — |
| Dash | The player's dodge: a fixed-distance burst with a short invulnerable start. The input action is `dodge` | `dash_*`, `DashCommand` |
| I-frames | The exact time window in which an entity can't be hit. The dash's window ends before the dash does | `dash_iframe_duration`, `get_iframe_window()` |
| Facing | The unit direction the player points in. Comes from aim, not movement, unless there is no aim | `get_facing()` |
| Input buffer | Holds a dash or attack pressed too early, so it fires when allowed if still within the window. One press per action, the newest | `input_buffer_window` |
| Class | A character's fixed, data-defined archetype, bound to a weapon family (D-005) | `ClassData`, `data/classes/` |
| Aim mode | The device currently aiming: mouse or gamepad. Changes only on real device activity | `PlayerInputMapper.AimMode` |
| Deadzone | Radial stick magnitude below which input counts as zero | `stick_deadzone` |
| Hitbox | A sector (origin, direction, arc, range) that deals damage while live. A 360° arc is a full circle. Decided in core, never by physics or animation. A combatant may own several at once (its own sector, then its projectiles'). A **single-target** hitbox lands on at most one hurtbox per contact instant; one with **no attacker hitstop** gives its owner no hitstop when it lands (its `hit_landed` still fires) | `Hitbox`, `get_live_hitboxes()`, `single_target`, `attacker_hitstop` |
| Hurtbox | A circle that can receive hits | `Hurtbox` |
| Attack instance | One hit's active phase. Hits each hurtbox at most once. Hits 1, 2 and 3 are separate instances | `AttackChain` hit set |
| Windup / Active / Recovery | The three phases of a hit, on the attacker's own clock. The hitbox exists only during active | `AttackChain.Phase` |
| Chain window | The time after a hit's recovery starts in which the next attack continues the chain. Recovery itself can always chain, even if the window is shorter | `attack_chain_window` |
| Hitstop | One entity's pause: its clock and all its timers stop and it doesn't move. New = max(remaining, new). Never global | `hitstop_normal`, `hitstop_finisher` |
| Knockback | A push over a fixed time at constant speed, after the target's hitstop. Walls stop the distance, not the time. A new one replaces the old | `knockback_duration`, `knockback_scale` |
| Hurt i-frames | Protection after taking a hit. Start on the hit, run during knockback, pause in hitstop. Players only for now | `player_hurt_iframes` |
| Punish window | The time an attacker is exposed after its own attack. The finisher's recovery is the player's own | — |
| Telegraph | The visible warning before an attack goes active | `pulse_telegraph` |
| Team | Which side a combatant fights on. A hitbox never hits its own team | `Combatant.Team` |
| Combat step | One equal slice of a physics tick, at most `1 / combat_step_rate` long (D-007) | `step()`, `combat_step_rate` |
| Contact instant | The end of a combat step: the only moment hits are decided | `CombatSim` |
| Hit candidate | A hitbox touching a hurtbox at a contact instant. Not a hit until the target is rechecked | `HitCandidate` |
| Combatant | Anything that fights on the combat step grid | `Combatant` |
| Enemy | A combatant on `Team.ENEMY` driven by its own logic, not by input. Everything enemies share lives in one class; only the brain differs | `EnemyLogic`, `Enemy`, `EnemyData` |
| Archetype | One kind of enemy behavior (chaser, caster, brute). One brain per archetype; new enemies of the same kind are new data | `EnemyData.Brain` |
| Brain | The only per-archetype enemy code. Holds no state: reads the combat view and its own enemy, and returns an intent | `EnemyBrain`, `ChaserBrain` |
| Intent | What a brain decided for one step: target, move direction, how far at most, and whether to start the attack | `EnemyIntent` |
| Combat view | A read-only snapshot of every combatant (id, team, position, alive) at a step start, the same for everyone. All an enemy may know about the others | `CombatView` |
| Aggro | An enemy has noticed a player: a living player came within `aggro_radius_tiles`, or it took damage. Once aggroed, it stays aggroed until the debug reset | `aggro_radius_tiles`, `is_aggroed()` |
| Target | The player an enemy is after: the nearest living one, ties to registration order. Picked at every decision, fixed during an attack | `get_target_id()` |
| Aim tracking / Aim lock | During an enemy's windup its aim follows the target until `aim_track_time`; from then on it is locked and never changes. The locked tail is what the player reads | `aim_track_time`, `is_aim_locked()` |
| Lunge | An enemy attack's movement along its locked aim during active, at constant speed. Walls stop it | `lunge_tiles` |
| Attack cooldown | Time after an enemy's recovery ends before it may start its next attack. It may still move | `attack_cooldown` |
| Planted | An enemy in windup, active or recovery is committed: hits still deal damage and hitstop, but don't push it or interrupt its attack | `get_knockback_scale()` |
| Free (enemy) | Not dead, not in hitstop, and not in windup, active, recovery or knockback. Only a free enemy decides, and only at a step start | `EnemyLogic._is_free()` |
| Projectile | A 360° hitbox that flies straight from its launcher at constant speed on the sim clock, up to a max distance. Owned by the combatant that launched it (identity = owner id + serial), dies with it, passes through every body, and is stopped only by walls (D-008). Its radius is its attack's `range_tiles` | `ProjectileSet`, `projectile_speed_tiles`, `projectile_max_distance_tiles` |
| Spent (projectile) | Stopped by its max distance or a wall. It still gets that step's contact at its final position, then is removed before its owner's next step | `Projectile.spent` |
| Blocked launch | A projectile born already overlapping a wall. The glue reports it, and it is removed before any contact: it never hits. Its serial stays used | `report_blocked_launch()` |
| Retreat distance | Below this distance from its target, an enemy backs straight away from it (unless it can shoot). 0 never retreats | `retreat_distance_tiles` |
| Trigger band | The target distances (min–max, tiles) at which an enemy may start one attack. The first attack in list order whose band holds the distance wins | `trigger_min_tiles`, `trigger_max_tiles`, `pick_attack()` |
| Charge | A lunge long enough to cross the room (the brute's). Wall-stopped by D-008's report | `brute_charge` |
| Wall stop / Wall stun | A charge reported short of its planned step by a `world` wall (or starting that step inside one). Applied right after that step's contact, so the step still hits; its recovery then lasts `wall_stun_duration`. Enemy bodies never cause it | `wall_stun_duration`, `wall_stopped`, `report_charge_reach()` |
| End of step | The point right after a contact instant's hits are applied, before the next step starts. Where a combatant applies what was reported during the step | `Combatant.end_step()` |
| Boss | An enemy with stages and patterns that ends a floor. Same `EnemyLogic` and rules as any enemy; never pushed (`knockback_scale` 0) | `EnemyData.stages` |
| Stage | One step of a boss fight, entered at an HP percent. Swaps the attack list, move speed and attack cooldown. Only goes forward. Stage 0 is the `EnemyData` itself | `EnemyStageData`, `get_stage_index()` |
| Stage shift | The planted pause when a stage is entered: no hitbox, no movement, takes damage normally. Starts only when the enemy is free | `shift_duration`, `stage_changed` |
| Pattern | An attack plus its chain of follow-ups, run without a free moment in between. The cooldown starts when its last recovery ends | `follow_up` |
| Follow-up | The attack that starts the instant another attack's recovery ends. Its trigger band is not read; its target is re-picked | `EnemyAttackData.follow_up` |
| Gap | The recovery of a pattern attack that has a follow-up. Hittable, but not the punish window | — |
