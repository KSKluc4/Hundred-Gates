extends GutTest
## AC16 and AC17, the frame-rate oracle, at every rate. AC5 and AC5b, the order promise.

const TIME: float = EnemyArena.TIME
const TILES: float = EnemyArena.TILES


func test_ac16_run_a_standing_still() -> void:
	for rate: int in EnemyArena.RATES:
		var label: String = "%d ticks/s" % rate
		var arena: EnemyArena = EnemyArena.new()
		var player: PlayerMotor = arena.add_player()
		var chaser: EnemyLogic = arena.add_chaser(Vector2(0, 3))
		var watch: EnemyWatch = arena.watch(chaser)
		arena.play(rate, 0, 78)

		_assert_times(watch.times_entered(EnemyLogic.State.WINDUP), [56, 302], label)
		_assert_times(watch.aim_lock_times, [92], label)
		_assert_times(watch.times_entered(EnemyLogic.State.ACTIVE), [116], label)
		_assert_times(watch.times_entered(EnemyLogic.State.RECOVERY), [134], label)
		_assert_times(arena.hurt_times, [117], label)
		_assert_tiles(watch.at(56)["position"], Vector2(0, 1.6), label)
		assert_eq(watch.at(60)["aim"], Vector2.UP, label)
		assert_eq(watch.at(116)["has_hitbox"], true, "%s: active, missing" % label)
		_assert_tiles(watch.at(134)["position"], Vector2(0, 0.8), label)
		_assert_tiles(watch.at(230)["position"], Vector2(0, 0.2), label)
		_assert_tiles(watch.at(301)["position"], Vector2(0, 0.2), label)
		assert_eq(watch.at(207)["state"], EnemyLogic.State.CHASE, label)
		assert_eq(player.get_combat_state().get_hp(), 80, label)
		_assert_tiles(player.get_position_tiles(), Vector2(0, -0.8), label)
		_assert_tiles(chaser.get_position_tiles(), Vector2(0, 0.2), label)
		assert_eq(chaser.get_state(), EnemyLogic.State.WINDUP, label)
		assert_eq(arena.hurt_events.size(), 1, label)
		assert_eq(arena.hurt_events[0].direction, Vector2.UP, "%s: chaser to player" % label)
		assert_almost_eq(arena.hurt_events[0].knockback_tiles, 0.8, 0.000001, label)


func test_ac16_both_enter_hitstop_at_the_hit() -> void:
	var arena: EnemyArena = EnemyArena.new()
	var player: PlayerMotor = arena.add_player()
	var chaser: EnemyLogic = arena.add_chaser(Vector2(0, 3))
	arena.ticks(117)
	assert_almost_eq(player.get_combat_state().get_hitstop_remaining(), 0.05, TIME)
	assert_almost_eq(chaser.get_combat_state().get_hitstop_remaining(), 0.05, TIME)


func test_ac17_run_b_dash_after_the_lock() -> void:
	for rate: int in EnemyArena.RATES:
		var label: String = "%d ticks/s" % rate
		var arena: EnemyArena = EnemyArena.new()
		var player: PlayerMotor = arena.add_player()
		var chaser: EnemyLogic = arena.add_chaser(Vector2(0, 3))
		var watch: EnemyWatch = arena.watch(chaser)
		arena.play(rate, 0, 75, {24: Vector2.RIGHT}, [24])

		_assert_times(watch.times_entered(EnemyLogic.State.WINDUP), [56, 296], label)
		_assert_times(watch.times_entered(EnemyLogic.State.ACTIVE), [116], label)
		_assert_times(watch.times_entered(EnemyLogic.State.RECOVERY), [128], label)
		assert_eq(watch.at(120)["hitbox_direction"], Vector2.UP, "%s: locked aim" % label)
		_assert_tiles(watch.at(128)["position"], Vector2(0, 0.8), label)
		assert_eq(watch.at(201)["state"], EnemyLogic.State.CHASE, label)
		_assert_tiles(watch.at(295)["position"], Vector2(2.0338, 0.2577), label)
		_assert_tiles(player.get_position_tiles(), Vector2(3, 0), label)
		_assert_tiles(chaser.get_position_tiles(), Vector2(2.0338, 0.2577), label)
		assert_eq(chaser.get_state(), EnemyLogic.State.WINDUP, label)
		assert_eq(player.get_combat_state().get_hp(), 100, label)
		assert_eq(arena.hurt_times.size(), 0, label)


func test_ac5_swapping_enemies_changes_no_decision() -> void:
	for rate: int in EnemyArena.RATES:
		var first: Array[EnemyWatch] = _walking_run(rate, [&"chaser_a", &"player", &"chaser_b"])
		var second: Array[EnemyWatch] = _walking_run(rate, [&"chaser_b", &"player", &"chaser_a"])
		var label: String = "%d ticks/s" % rate
		for index: int in 2:
			assert_eq(first[index].candidates_seen, 0, "no competing hits: %s" % label)
			assert_eq(second[index].candidates_seen, 0, label)
			assert_eq(first[index].contacts.size(), 360, label)
			assert_eq_deep(first[index].contacts, second[index].contacts)
			var windups: Array = first[index].times_entered(EnemyLogic.State.WINDUP)
			assert_gt(windups.size(), 0, "%s: it did swing" % label)
		assert_almost_eq(_first_windup(first[0]), 0.32, 0.02, label)
		assert_almost_eq(_first_windup(first[1]), 0.56, 0.02, label)


func test_ac5b_the_first_registered_lands_and_the_other_is_skipped_unmarked() -> void:
	var arena: EnemyArena = _two_at_right_angles(true)
	var player: PlayerMotor = arena.players[0]
	var first: EnemyLogic = arena.enemies[0]
	var second: EnemyLogic = arena.enemies[1]
	var first_watch: EnemyWatch = arena.watch(first)
	var second_watch: EnemyWatch = arena.watch(second)
	arena.ticks(127)
	assert_eq(first_watch.times_entered(EnemyLogic.State.WINDUP).size(), 1)
	_assert_times(first_watch.times_entered(EnemyLogic.State.WINDUP), [56], "chaser_1")
	_assert_times(second_watch.times_entered(EnemyLogic.State.WINDUP), [56], "chaser_2")
	_assert_times(arena.hurt_times, [117], "one hit")
	assert_eq(player.get_combat_state().get_hp(), 80)
	assert_eq(arena.hurt_events[0].attacker_id, &"chaser_1")
	assert_eq(first.get_state(), EnemyLogic.State.ACTIVE, "its hitstop delays it")
	assert_eq(second.get_state(), EnemyLogic.State.ACTIVE)
	assert_eq(second.get_combat_state().get_hitstop_remaining(), 0.0, "no hitstop")
	assert_false(second.get_live_hitbox().has_hit(&"player_1"), "not marked")
	arena.ticks(1)
	_assert_times(second_watch.times_entered(EnemyLogic.State.RECOVERY), [128], "chaser_2 ends")
	assert_eq(arena.hurt_times.size(), 1, "exactly one hit lands")
	arena.ticks(12)
	_assert_tiles(player.get_position_tiles(), Vector2(0, -0.8), "pushed along chaser_1's line")


func test_ac5b_swapping_swaps_who_lands() -> void:
	var arena: EnemyArena = _two_at_right_angles(false)
	var player: PlayerMotor = arena.players[0]
	arena.ticks(140)
	assert_eq(arena.hurt_events.size(), 1, "exactly one hit lands")
	assert_eq(arena.hurt_events[0].attacker_id, &"chaser_2")
	assert_eq(player.get_combat_state().get_hp(), 80)
	_assert_tiles(player.get_position_tiles(), Vector2(-0.8, 0), "pushed along chaser_2's line")


func _two_at_right_angles(first_is_chaser_1: bool) -> EnemyArena:
	var arena: EnemyArena = EnemyArena.new()
	arena.add_player()
	if first_is_chaser_1:
		arena.add_chaser(Vector2(0, 3), &"chaser_1")
		arena.add_chaser(Vector2(3, 0), &"chaser_2")
	else:
		arena.add_chaser(Vector2(3, 0), &"chaser_2")
		arena.add_chaser(Vector2(0, 3), &"chaser_1")
	return arena


## Every id in order. Returns the watches of chaser_a, then chaser_b.
func _walking_run(rate: int, order: Array[StringName]) -> Array[EnemyWatch]:
	var arena: EnemyArena = EnemyArena.new()
	var starts: Dictionary = {&"chaser_a": Vector2(3, 2), &"chaser_b": Vector2(3, -3)}
	var by_id: Dictionary = {}
	for id: StringName in order:
		if id == &"player":
			arena.add_player()
		else:
			by_id[id] = arena.add_chaser(starts[id], id)
	var watches: Array[EnemyWatch] = [
		arena.watch(by_id[&"chaser_a"]), arena.watch(by_id[&"chaser_b"])
	]
	var moves: Dictionary = {}
	for thirtieth: int in 90:
		moves[thirtieth] = Vector2.RIGHT
	arena.play(rate, 0, 90, moves)
	return watches


func _first_windup(watch: EnemyWatch) -> float:
	return watch.times_entered(EnemyLogic.State.WINDUP)[0]


func _assert_times(actual: Array, expected_steps: Array, label: String) -> void:
	assert_eq(actual.size(), expected_steps.size(), "%s: %s" % [label, actual])
	for index: int in mini(actual.size(), expected_steps.size()):
		assert_almost_eq(float(actual[index]), expected_steps[index] / 120.0, TIME, label)


func _assert_tiles(actual: Vector2, expected: Vector2, label: String) -> void:
	assert_almost_eq(actual.x, expected.x, TILES, label)
	assert_almost_eq(actual.y, expected.y, TILES, label)
