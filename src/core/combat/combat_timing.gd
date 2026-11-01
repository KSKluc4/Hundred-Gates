class_name CombatTiming
extends RefCounted
## The shared step grid's rules, in one place (D-007, F-003/C15). No state.

## Absorbs float rounding at exact time boundaries. Far below the 1 µs oracle.
const TIME_EPSILON: float = 1e-9


## F-003/C15: how many equal steps one physics tick of `delta` seconds splits into.
static func step_count(delta: float, step_rate: int) -> int:
	return maxi(1, ceili(step_rate * delta - TIME_EPSILON))


## F-003/C15, C18: a window with these durations always gets a contact instant at this rate.
## `lead` is the time before the window: windup or pulse_telegraph. Empty result means valid.
static func window_errors(lead: float, active: float, step_rate: int) -> PackedStringArray:
	var errors: PackedStringArray = []
	if step_rate <= 0:
		errors.append("step rate must be > 0")
		return errors
	var min_active: float = 1.0 / step_rate
	if active < min_active - TIME_EPSILON:
		errors.append("active time must be >= 1 combat step (%.4f s)" % min_active)
	elif lead + active < 2.0 * min_active - TIME_EPSILON:
		errors.append("lead + active time must be >= 2 combat steps (%.4f s)" % (2.0 * min_active))
	return errors
