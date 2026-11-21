class_name LootRoller
extends RefCounted
## F-016/C10-C12: the one place in `src/core` that draws. One generator per character, always
## seeded explicitly: a roller nobody seeded is seeded with 0, never from the clock. Its seed and
## state are saved with the character, so a restored roller goes on exactly where it was (G7).
## Every roll is a fixed sequence of draws: a rule that draws nothing says so before it draws.

const KEY_SEED: String = "seed"
const KEY_STATE: String = "state"

var _generator: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	seed_with(0)  # C12: never self-seeded, also before setup.


## Starts the sequence over from `new_seed`.
func seed_with(new_seed: int) -> void:
	_generator.seed = new_seed


func get_seed() -> int:
	return _generator.seed


func get_state() -> int:
	return _generator.state


## C10: one draw; a drop when it is strictly below `chance`; only then one more, an index into a
## pool of `pool_size` swords, each equally likely. -1 is no drop. Draws nothing, and gives no
## drop, with an empty pool or a chance that is not above 0.
func roll_regular(chance: float, pool_size: int) -> int:
	if pool_size < 1 or not chance > 0.0:
		return -1
	if not _generator.randf() < chance:
		return -1
	return _generator.randi_range(0, pool_size - 1)


## C11: with `guaranteed`, one draw over 1 to the sum of the percents, and the result is a
## sword unless the table is empty; otherwise one draw over 1 to 100. The index of the sword
## (boss_pick), -1 for nothing. Draws nothing with an empty table (or one with no percent).
func roll_boss(percents: PackedInt32Array, guaranteed: bool) -> int:
	var total: int = sum_of(percents)
	if total < 1:
		return -1
	var roll: int = (
		_generator.randi_range(1, total) if guaranteed else _generator.randi_range(1, 100)
	)
	return boss_pick(roll, percents)


## C11: sword 0 is the rolls 1 to p0, sword 1 the next p1, and so on; a roll below 1 or above the
## sum is nothing (-1).
static func boss_pick(roll: int, percents: PackedInt32Array) -> int:
	var upper: int = 0
	for index: int in percents.size():
		upper += percents[index]
		if roll >= 1 and roll <= upper:
			return index
	return -1


## The sum of the percents.
static func sum_of(percents: PackedInt32Array) -> int:
	var total: int = 0
	for percent: int in percents:
		total += percent
	return total


## G7, C12.
func to_dict() -> Dictionary:
	return {KEY_SEED: _generator.seed, KEY_STATE: _generator.state}


## Why `snapshot` can't be restored, empty when it can. Any two integers are a valid seed and
## state.
func restore_errors(snapshot: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	if not snapshot.has_all([KEY_SEED, KEY_STATE]):
		errors.append("roller: missing keys")
	elif not (snapshot[KEY_SEED] is int and snapshot[KEY_STATE] is int):
		errors.append("roller: seed and state must be integers")
	return errors


## Refuses what restore_errors() lists, and then changes nothing. The seed goes first: setting it
## resets the state, which is then set to the saved one.
func from_dict(snapshot: Dictionary) -> bool:
	if not restore_errors(snapshot).is_empty():
		return false
	_generator.seed = snapshot[KEY_SEED]
	_generator.state = snapshot[KEY_STATE]
	return true
