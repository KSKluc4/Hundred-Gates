class_name FloorLoot
extends Resource
## What one floor drops (F-016/C5, D-017, G9): a number of regular drops per run, a pool of swords
## that regular enemies drop (equal chance), and a boss table of swords with a percent each.

## How many regular drops one full run of the floor yields on average. The chance per kill is this
## divided by the floor's kills before the boss (C6), so it is never a number of its own.
@export var regular_drops_per_run: float = 0.0
@export var regular_swords: Array[SwordData] = []
## The boss's swords, in the order of `boss_percents`.
@export var boss_swords: Array[SwordData] = []
## One percent per boss sword. What is missing from 100 is a repeat win that drops nothing.
@export var boss_percents: PackedInt32Array = PackedInt32Array()


## F-016/C6: `regular_drops_per_run` over the floor's regular kills. Zero when it has none (the
## catalog refuses drops on such a floor).
func get_chance_per_kill(floor_data: FloorData) -> float:
	var kills: int = floor_data.get_regular_kill_count() if floor_data != null else 0
	return regular_drops_per_run / float(kills) if kills > 0 else 0.0


## The sum of the boss percents.
func get_boss_percent_sum() -> int:
	var total: int = 0
	for percent: int in boss_percents:
		total += percent
	return total
