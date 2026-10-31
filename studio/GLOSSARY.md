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
| Input buffer | Holds a dash pressed too early, so it fires when allowed if still within the window | `input_buffer_window` |
| Class | A character's fixed, data-defined archetype, bound to a weapon family (D-005) | `ClassData`, `data/classes/` |
| Aim mode | The device currently aiming: mouse or gamepad. Changes only on real device activity | `PlayerInputMapper.AimMode` |
| Deadzone | Radial stick magnitude below which input counts as zero | `stick_deadzone` |
