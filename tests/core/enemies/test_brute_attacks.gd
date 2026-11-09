extends GutTest
## F-006 in core: AC4 (charge timeline), AC5 (one hit, no stop; a sideways dash dodges it),
## AC10 (stomp ring), AC11 (brute body).

const TIME: float = EnemyArena.TIME
const TILES: float = EnemyArena.TILES
const STEP: float = EnemyArena.STEP
const RATES: Array[int] = EnemyArena.RATES
## Positions are Vector2: float32 over 6 tiles.
const POSITION: float = 0.00001


func test_ac4_charge_timeline_at_every_rate() -> void:
	for rate: int in RATES:
		var label: String = "%d ticks/s" % rate
		var arena: BruteArena = BruteArena.new()
		arena.add_player(Vector2(0, 5.0))
		var brute: EnemyLogic = arena.add_brute(Vector2.ZERO)
		var watch: EnemyWatch = arena.watch(brute)
		# After the lock the player walks out of the lane, so no hitstop shifts the timeline.
		var moves: Dictionary = {}
		for thirtieth: int in range(17, 32):
			moves[thirtieth] = Vector2.RIGHT
		arena.play(rate, 0, 96, moves)  # 3.2 s: the cooldown has just ended.
		assert_eq(arena.hurt_times.size(), 0, label)
		assert_almost_eq(watch.times_entered(EnemyLogic.State.WINDUP)[0], 0.0, TIME, label)
		assert_almost_eq(watch.aim_lock_times[0], 0.5, TIME, "%s: tracks until 0.5" % label)
		assert_almost_eq(watch.times_entered(EnemyLogic.State.ACTIVE)[0], 0.8, TIME, label)
		assert_almost_eq(watch.times_entered(EnemyLogic.State.RECOVERY)[0], 1.3, TIME, label)
		for step: int in range(96, 157):
			var expected: float = clampf((step - 96) * STEP * 12.0, 0.0, 6.0)
			var sample: Dictionary = watch.at(step)
			assert_almost_eq(sample["position"].y, expected, POSITION, "%s: %d" % [label, step])
			assert_almost_eq(sample["position"].x, 0.0, POSITION, "%s: along the aim" % label)
		assert_eq(watch.at(156)["state"], EnemyLogic.State.RECOVERY, label)
		assert_eq(watch.at(263)["state"], EnemyLogic.State.RECOVERY, "%s: 0.9 s" % label)
		assert_almost_eq(watch.at(264)["cooldown"], 1.0, TIME, "%s: 2.2 s" % label)
		assert_almost_eq(watch.at(383)["cooldown"], STEP, TIME, "%s: 1.0 s cooldown" % label)


func test_ac5_the_charge_hits_once_and_runs_its_full_length() -> void:
	for rate: int in RATES:
		var label: String = "%d ticks/s" % rate
		var arena: BruteArena = BruteArena.new()
		var player: PlayerMotor = arena.add_player(Vector2(0, 4.0))
		var brute: EnemyLogic = arena.add_brute(Vector2.ZERO)
		var watch: EnemyWatch = arena.watch(brute)
		arena.play(rate, 0, 60)
		assert_eq(arena.hurt_times.size(), 1, label)
		assert_eq(arena.hurt_events[0].damage, 25, label)
		assert_eq(arena.hurt_events[0].knockback_tiles, 1.5, label)
		assert_eq(player.get_combat_state().get_hp(), 75, label)
		var hitstop: float = arena.rules.hitstop_normal
		var recovery: float = watch.times_entered(EnemyLogic.State.RECOVERY)[0]
		assert_almost_eq(recovery, 1.3 + hitstop, TIME, "%s: paused, not shortened" % label)
		assert_almost_eq(brute.get_position_tiles().y, 6.0, POSITION, "%s: full 6 tiles" % label)


func test_ac5_a_sideways_dash_after_the_lock_dodges_the_charge() -> void:
	for rate: int in RATES:
		var label: String = "%d ticks/s" % rate
		var arena: BruteArena = BruteArena.new()
		arena.add_player(Vector2(0, 4.0))
		var brute: EnemyLogic = arena.add_brute(Vector2.ZERO)
		arena.play(rate, 0, 18)
		assert_true(brute.is_aim_locked(), label)
		arena.play(rate, 18, 60, {18: Vector2.RIGHT}, [18])
		assert_eq(arena.hurt_times.size(), 0, "%s: out of the lane" % label)
		assert_almost_eq(brute.get_position_tiles().y, 6.0, POSITION, label)


func test_ac10_stomp_timeline_and_ring() -> void:
	for distance: float in [1.94, 1.951, 1.96]:
		var label: String = "second player at %s" % distance
		var arena: BruteArena = BruteArena.new()
		arena.add_player(Vector2(1.0, 0))
		var other: PlayerMotor = arena.add_player(Vector2(0, -distance), &"player_2")
		var brute: EnemyLogic = arena.add_brute(Vector2.ZERO)
		var watch: EnemyWatch = arena.watch(brute)
		arena.ticks(180)
		# Its hit on player_1 at 0.6 s gives it the attacker hitstop, which delays the rest.
		var hitstop: float = arena.rules.hitstop_normal
		assert_eq(watch.times_entered(EnemyLogic.State.WINDUP)[0], 0.0, label)
		assert_almost_eq(watch.times_entered(EnemyLogic.State.ACTIVE)[0], 0.6, TIME, label)
		var recovery: float = watch.times_entered(EnemyLogic.State.RECOVERY)[0]
		assert_almost_eq(recovery, 0.7 + hitstop, TIME, "%s: active 0.1 s" % label)
		var idle: Array = watch.times_entered(EnemyLogic.State.IDLE)
		assert_almost_eq(idle[1] - recovery, 0.7, TIME, "%s: 0.7 s recovery" % label)
		assert_almost_eq(arena.hurt_times[0], 0.6, TIME, label)
		assert_eq(arena.hurt_events[0].damage, 20, label)
		assert_eq(arena.hurt_events[0].knockback_tiles, 1.2, label)
		assert_eq(other.get_combat_state().get_hp() < 100, distance < 1.95, label)
		for step: int in range(72, 85):
			_assert_tiles(watch.at(step)["position"], Vector2.ZERO, "%s: no lunge" % label)


func test_ac11_never_pushed_outside_an_attack_and_aggroed_by_damage() -> void:
	var arena: BruteArena = BruteArena.new()
	arena.add_player(Vector2.ZERO)
	var brute: EnemyLogic = arena.add_brute(Vector2(0, 1.5))
	brute.set_ai_enabled(false)
	arena.ticks(1)
	assert_false(brute.is_aggroed())
	arena.tick(120, Vector2.ZERO, false, true, Vector2.DOWN)
	arena.ticks(20)
	assert_eq(brute.get_combat_state().get_hp(), 110)
	assert_true(brute.is_aggroed(), "damage aggroes it")
	assert_eq(brute.get_state(), EnemyLogic.State.IDLE, "no knockback state")
	_assert_tiles(brute.get_position_tiles(), Vector2(0, 1.5), "knockback_scale 0")


func _assert_tiles(actual: Vector2, expected: Vector2, label: String) -> void:
	assert_almost_eq(actual.x, expected.x, TILES, label)
	assert_almost_eq(actual.y, expected.y, TILES, label)
