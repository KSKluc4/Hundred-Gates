extends GutTest
## AC12, AC12b, AC13, AC14 and AC15, with real swords on a real sim.

const TIME: float = EnemyArena.TIME
const NOT_A_RANGE: float = 0.01
const CHASING_START: Vector2 = Vector2(0, 1.95)  # Sword hit 1 lands at 10/120, in reach.
const PUSHED_START: Vector2 = Vector2(0, 0.5)  # A second player, in reach of the push.


func test_ac12_a_hit_in_windup_only_delays_the_swing_by_the_hitstop() -> void:
	var arena: EnemyArena = _committed()
	var enemy: EnemyLogic = arena.enemies[0]
	var watch: EnemyWatch = arena.watch(enemy)
	arena.tick(120, Vector2.ZERO, false, true)
	arena.ticks(70)
	assert_eq(enemy.get_combat_state().get_hp(), 40, "damage")
	assert_almost_eq(arena.sword_times[0], 10.0 / 120.0, TIME)
	assert_eq(watch.at(65)["state"], EnemyLogic.State.WINDUP)
	assert_eq(watch.at(65)["position"], Vector2(0, 1.6), "0 tiles of knockback")
	_assert_steps(watch.times_entered(EnemyLogic.State.ACTIVE), [66])


func test_ac12_a_hit_in_active_pauses_it_with_no_push() -> void:
	var arena: EnemyArena = _committed()
	var enemy: EnemyLogic = arena.enemies[0]
	var watch: EnemyWatch = arena.watch(enemy)
	arena.play(120, 0, 30, {}, [], [13])  # Press at 52/120, so hit 1 lands at 62/120.
	_assert_steps(arena.sword_times, [62])
	assert_eq(enemy.get_combat_state().get_hp(), 40)
	assert_eq(watch.at(68)["position"], watch.at(62)["position"], "stopped by hitstop")
	_assert_steps(watch.times_entered(EnemyLogic.State.RECOVERY), [78])
	assert_almost_eq(float(watch.at(78)["position"].y), 0.8, 0.00001, "the lunge, nothing else")


func test_ac12_a_hit_in_recovery_pauses_it_with_no_push() -> void:
	var arena: EnemyArena = _committed()
	var enemy: EnemyLogic = arena.enemies[0]
	var watch: EnemyWatch = arena.watch(enemy)
	arena.play(120, 0, 41, {}, [], [20])  # Press at 80/120, so hit 1 lands at 90/120.
	_assert_steps(arena.sword_times, [90])
	assert_eq(enemy.get_combat_state().get_hp(), 40)
	assert_eq(watch.at(120)["position"], watch.at(72)["position"], "planted")
	assert_eq(watch.at(120)["state"], EnemyLogic.State.RECOVERY)
	arena.ticks(40)
	assert_eq(watch.times_entered(EnemyLogic.State.IDLE).size(), 2, "the timeline went on")
	_assert_steps([watch.times_entered(EnemyLogic.State.IDLE)[1]], [150])


func test_ac12_a_hit_while_chasing_pushes_it_and_it_chases_again_after() -> void:
	var arena: EnemyArena = _chasing()
	var enemy: EnemyLogic = arena.enemies[0]
	var watch: EnemyWatch = arena.watch(enemy)
	arena.tick(120, Vector2.ZERO, false, true)
	arena.ticks(29)
	_assert_steps(watch.times_entered(EnemyLogic.State.KNOCKBACK), [10])
	assert_eq(enemy.get_combat_state().get_hp(), 40)
	var hit_at: float = watch.at(10)["position"].y
	assert_eq(float(watch.at(16)["position"].y), hit_at, "hitstop first")
	assert_eq(enemy.get_state(), EnemyLogic.State.KNOCKBACK)
	arena.ticks(1)
	assert_almost_eq(enemy.get_position_tiles().y, hit_at + 0.3, 0.0001, "× knockback_scale")
	arena.ticks(1)
	assert_eq(enemy.get_state(), EnemyLogic.State.CHASE)


func test_ac12_knockback_scale_multiplies_the_push() -> void:
	var arena: EnemyArena = EnemyArena.new()
	arena.chaser_data.attack_range_tiles = NOT_A_RANGE
	arena.chaser_data.knockback_scale = 2.0
	arena.add_player()
	var enemy: EnemyLogic = arena.add_chaser(CHASING_START)
	arena.tick(120, Vector2.ZERO, false, true)
	arena.ticks(30)
	assert_almost_eq(enemy.get_position_tiles().y, 1.7 + 0.6, 0.0001)


func test_ac12b_zero_attack_distance_on_a_chasing_chaser() -> void:
	var arena: EnemyArena = EnemyArena.new()
	arena.class_data.attack_chain[0].knockback_tiles = 0.0
	arena.chaser_data.attack_range_tiles = NOT_A_RANGE
	_assert_zero_distance_on_a_chaser(arena)


func test_ac12b_zero_target_scale_on_a_chasing_chaser() -> void:
	var arena: EnemyArena = EnemyArena.new()
	arena.chaser_data.knockback_scale = 0.0
	arena.chaser_data.attack_range_tiles = NOT_A_RANGE
	_assert_zero_distance_on_a_chaser(arena)


func test_ac12b_zero_attack_distance_in_the_middle_of_a_push() -> void:
	var arena: EnemyArena = EnemyArena.new()
	arena.chaser_data.attack_range_tiles = NOT_A_RANGE
	arena.add_player()
	var no_push: ClassData = CombatArena.warrior()
	no_push.attack_chain[0].knockback_tiles = 0.0
	arena.class_data = no_push
	_assert_zero_distance_ends_a_push(arena, arena.add_player(PUSHED_START, &"player_2"))


func test_ac12b_zero_target_scale_in_the_middle_of_a_push() -> void:
	var arena: EnemyArena = EnemyArena.new()
	arena.chaser_data.attack_range_tiles = NOT_A_RANGE
	arena.add_player()
	var second: PlayerMotor = arena.add_player(PUSHED_START, &"player_2")
	_assert_zero_distance_ends_a_push(arena, second, true)


func test_ac12b_a_committed_chaser_keeps_its_timeline_for_either_source() -> void:
	for scale: float in [0.0, 1.0]:
		var arena: EnemyArena = EnemyArena.new()
		arena.chaser_data.attack.range_tiles = NOT_A_RANGE
		arena.chaser_data.knockback_scale = scale
		arena.class_data.attack_chain[0].knockback_tiles = 1.0 - scale
		arena.add_player()
		var watch: EnemyWatch = arena.watch(arena.add_chaser(Vector2(0, 1.6)))
		arena.tick(120, Vector2.ZERO, false, true)
		arena.ticks(70)
		_assert_steps(watch.times_entered(EnemyLogic.State.ACTIVE), [66])
		assert_eq(watch.times_entered(EnemyLogic.State.KNOCKBACK).size(), 0)


func test_ac13_the_swing_keeps_every_f003_rule_on_the_player() -> void:
	var arena: EnemyArena = EnemyArena.new()
	var player: PlayerMotor = arena.add_player()
	var enemy: EnemyLogic = arena.add_chaser(Vector2(0, 1.6))
	arena.ticks(61)
	_assert_steps(arena.hurt_times, [61])
	var event: HitEvent = arena.hurt_events[0]
	assert_eq(event.damage, 20)
	assert_false(event.is_finisher)
	assert_eq(event.attacker_id, &"chaser_1")
	assert_eq(event.direction, Vector2.UP, "chaser to player")
	assert_eq(player.get_state(), PlayerMotor.State.KNOCKBACK)
	assert_almost_eq(player.get_combat_state().get_hitstop_remaining(), 0.05, TIME)
	assert_almost_eq(enemy.get_combat_state().get_hitstop_remaining(), 0.05, TIME)
	assert_almost_eq(player.get_combat_state().get_hurt_iframes_remaining(), 0.6, TIME)
	assert_false(player.can_be_hit(), "hurt i-frames")


func test_ac13_once_per_attack_instance_even_with_no_hurt_iframes() -> void:
	var arena: EnemyArena = EnemyArena.new()
	arena.rules.player_hurt_iframes = 0.0
	arena.class_data.knockback_scale = 0.0
	arena.add_player()
	arena.add_chaser(Vector2(0, 1.6))
	arena.ticks(80)
	assert_eq(arena.hurt_times.size(), 1)


func test_ac13_dash_iframes_skip_it_unmarked_and_the_vulnerable_tail_is_hit() -> void:
	var arena: EnemyArena = EnemyArena.new()
	arena.class_data.dash_distance = 0.1  # Stays in the sector for the whole dash.
	var player: PlayerMotor = arena.add_player()
	var enemy: EnemyLogic = arena.add_chaser(Vector2(0, 1.6))
	arena.play(120, 0, 15, {13: Vector2.RIGHT}, [13])  # Dash at 52/120, i-frames to 65.2/120.
	assert_eq(arena.hurt_times.size(), 0, "first touch at 61/120 is inside the i-frames")
	assert_false(enemy.get_live_hitbox().has_hit(&"player_1"), "and leaves it unmarked")
	arena.ticks(6)
	_assert_steps(arena.hurt_times, [66])
	assert_eq(player.get_combat_state().get_hp(), 80)


func test_ac14_teams_a_chasers_hitbox_never_touches_a_chaser_or_a_dummy() -> void:
	var arena: EnemyArena = EnemyArena.new()
	arena.chaser_data.aggro_radius_tiles = 10.0
	arena.chaser_data.attack_range_tiles = 10.0
	arena.add_player(Vector2(0, -9))
	var enemy: EnemyLogic = arena.add_chaser(Vector2.ZERO, &"chaser_1")
	arena.add_chaser(Vector2(0, -1), &"chaser_2")
	var dummy: DummyLogic = DummyLogic.new()
	dummy.setup(CombatArena.dummy_values(), 120, Vector2(0.3, -0.8), 0.0, &"dummy")
	arena.sim.register(dummy)
	var watch: EnemyWatch = arena.watch(enemy)
	arena.ticks(62)
	assert_eq(enemy.get_state(), EnemyLogic.State.ACTIVE)
	assert_true(watch.at(61)["has_hitbox"])
	assert_eq(watch.candidates_seen, 0)
	assert_eq(arena.enemies[1].get_combat_state().get_hp(), 50)
	assert_eq(dummy.get_combat_state().get_hp(), 200)


func test_ac15_a_full_chain_plus_one_hit_1_kills_it_once() -> void:
	var arena: EnemyArena = EnemyArena.new()
	arena.chaser_data.move_speed = 0.0
	arena.chaser_data.knockback_scale = 0.0
	arena.chaser_data.attack_range_tiles = NOT_A_RANGE
	arena.add_player()
	var enemy: EnemyLogic = arena.add_chaser(Vector2(0, 1))
	var state: CombatState = enemy.get_combat_state()
	watch_signals(state)
	arena.play(120, 0, 66, {}, [], [0, 6, 12, 48])
	_assert_steps(arena.sword_times, [10, 34, 68, 202])
	assert_eq(state.get_hp(), 0)
	assert_signal_emit_count(state, "died", 1)
	assert_eq(enemy.get_state(), EnemyLogic.State.DEAD)
	_assert_inert(arena, enemy, Vector2(0, 1))


func test_ac15_a_kill_in_the_middle_of_a_push_stops_it_dead() -> void:
	var arena: EnemyArena = EnemyArena.new()
	arena.chaser_data.max_hp = 1
	arena.chaser_data.attack_range_tiles = NOT_A_RANGE
	arena.add_player()
	var enemy: EnemyLogic = arena.add_chaser(CHASING_START)
	arena.tick(120, Vector2.ZERO, false, true)
	arena.ticks(9)
	assert_eq(enemy.get_state(), EnemyLogic.State.DEAD)
	assert_false(enemy.get_combat_state().has_knockback(), "the killing hit pushes nothing")
	_assert_inert(arena, enemy, enemy.get_position_tiles())


func test_ac15_a_kill_during_an_attack_ends_it_and_replaces_the_hit_set() -> void:
	var arena: EnemyArena = _committed()
	var enemy: EnemyLogic = arena.enemies[0]
	arena.chaser_data.max_hp = 1
	enemy.setup(arena.chaser_data, arena.enemy_rules, 120, Vector2(0, 1.6), &"chaser_1")
	arena.ticks(61)
	var hitbox: Hitbox = enemy.get_live_hitbox()
	var event: HitEvent = HitEvent.new()
	event.damage = 1
	enemy.apply_hit(event, arena.rules)
	hitbox.mark_hit(&"late_mark")
	assert_eq(enemy.get_state(), EnemyLogic.State.DEAD)
	assert_null(enemy.get_running_attack())
	assert_eq_deep(enemy.to_dict()["hit_ids"], [])


func test_ac15_a_chaser_killed_at_a_contact_where_its_own_hitbox_touched_still_lands() -> void:
	for player_first: bool in [true, false]:
		var arena: EnemyArena = EnemyArena.new()
		arena.chaser_data.max_hp = 1
		arena.class_data.attack_chain[0].windup = 0.075  # Pressed at 52/120: active at 61/120.
		if player_first:
			arena.add_player()
		var enemy: EnemyLogic = arena.add_chaser(Vector2(0, 1.6))
		if not player_first:
			arena.add_player()
		arena.play(120, 0, 16, {}, [], [13])
		_assert_steps(arena.hurt_times, [61])
		_assert_steps(arena.sword_times, [61])
		assert_eq(arena.players[0].get_combat_state().get_hp(), 80, "the trade")
		assert_eq(enemy.get_state(), EnemyLogic.State.DEAD)


func _assert_zero_distance_on_a_chaser(arena: EnemyArena) -> void:
	arena.add_player()
	var enemy: EnemyLogic = arena.add_chaser(CHASING_START)
	var watch: EnemyWatch = arena.watch(enemy)
	arena.tick(120, Vector2.ZERO, false, true)
	arena.ticks(19)
	assert_eq(enemy.get_combat_state().get_hp(), 40, "damage")
	assert_eq(watch.at(11)["state"], EnemyLogic.State.IDLE, "from the contact instant on")
	assert_eq(watch.times_entered(EnemyLogic.State.KNOCKBACK).size(), 0)
	assert_false(enemy.get_combat_state().has_knockback())
	assert_eq(watch.at(16)["position"], watch.at(10)["position"], "no movement in hitstop")
	assert_eq(watch.at(16)["state"], EnemyLogic.State.IDLE)
	assert_eq(watch.at(17)["state"], EnemyLogic.State.CHASE, "the first free step start")
	assert_lt(float(watch.at(17)["position"].y), float(watch.at(16)["position"].y))


## Player 1 lands a normal hit at 10/120, whose push runs from 16/120 to 30.4/120. The second
## player's hit lands at 26/120, in the middle of it.
func _assert_zero_distance_ends_a_push(
	arena: EnemyArena, second: PlayerMotor, scale_goes_to_zero: bool = false
) -> void:
	var enemy: EnemyLogic = arena.add_chaser(CHASING_START)
	var watch: EnemyWatch = arena.watch(enemy)
	arena.tick(120, Vector2.ZERO, false, true)
	arena.ticks(15)
	assert_eq(enemy.get_state(), EnemyLogic.State.KNOCKBACK)
	if scale_goes_to_zero:
		var no_push: EnemyData = EnemyArena.chaser_values()
		no_push.attack_range_tiles = NOT_A_RANGE
		no_push.knockback_scale = 0.0
		assert_true(enemy.apply_data(no_push, arena.enemy_rules, 120))
	second.submit(AttackCommand.new())
	arena.ticks(10)
	_assert_steps([arena.sword_times[1]], [26])
	assert_eq(enemy.get_state(), EnemyLogic.State.IDLE, "out at the contact instant")
	assert_false(enemy.get_combat_state().has_knockback(), "the rest of the push is dropped")
	var stopped: Vector2 = enemy.get_position_tiles()
	assert_almost_eq(stopped.y, 1.7 + 0.3 * 10.0 / 14.4, 0.0001)
	arena.ticks(6)
	assert_eq(enemy.get_position_tiles(), stopped, "stays where it stopped")
	assert_eq(enemy.get_state(), EnemyLogic.State.IDLE)
	arena.ticks(1)
	assert_eq(watch.at(33)["state"], EnemyLogic.State.CHASE, "the first free step start")


func _assert_inert(arena: EnemyArena, enemy: EnemyLogic, position: Vector2) -> void:
	assert_null(enemy.get_live_hitbox())
	assert_false(enemy.can_be_hit())
	assert_false(enemy.is_alive())
	assert_true(arena.sim.get_combatants().has(enemy), "stays registered (F-003/C19)")
	var state: Dictionary = enemy.to_dict()
	arena.ticks(60)
	assert_eq(enemy.get_position_tiles(), position, "never moves again")
	assert_eq(enemy.get_state(), EnemyLogic.State.DEAD, "no decisions")
	assert_eq(enemy.to_dict()["cooldown_remaining"], state["cooldown_remaining"])


## A chaser committed from the first step, whose swing can't reach the player.
func _committed() -> EnemyArena:
	var arena: EnemyArena = EnemyArena.new()
	arena.chaser_data.attack.range_tiles = NOT_A_RANGE
	arena.add_player()
	arena.add_chaser(Vector2(0, 1.6))
	return arena


## A chaser walking in, that never gets to attack.
func _chasing() -> EnemyArena:
	var arena: EnemyArena = EnemyArena.new()
	arena.chaser_data.attack_range_tiles = NOT_A_RANGE
	arena.add_player()
	arena.add_chaser(CHASING_START)
	return arena


func _assert_steps(actual: Array, expected_steps: Array) -> void:
	assert_eq(actual.size(), expected_steps.size(), str(actual))
	for index: int in mini(actual.size(), expected_steps.size()):
		assert_almost_eq(float(actual[index]), expected_steps[index] / 120.0, TIME)
