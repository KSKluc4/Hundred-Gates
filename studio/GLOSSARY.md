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
| Hitbox | A sector (origin, direction, arc, range) that deals damage while live. A 360° arc is a full circle. Decided in core, never by physics or animation | `Hitbox` |
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
