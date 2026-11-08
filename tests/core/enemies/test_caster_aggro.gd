extends GutTest
## F-005 AC5: aggro and targets as F-004 AC2–AC3, run for the caster with real player motors.

const FAR: Vector2 = Vector2(0, 100)
const NOT_READY: float = 100.0

var _arena: CasterArena
var _enemy: EnemyLogic


func before_each() -> void:
	_arena = CasterArena.new()


func test_ac5_idle_until_a_player_comes_within_the_radius() -> void:
	_arena.add_player(Vector2(0, -8.5))
	_enemy = _arena.add_caster(Vector2.ZERO)
	_arena.ticks(5)
	assert_eq(_enemy.get_state(), EnemyLogic.State.IDLE)
	assert_false(_enemy.is_aggroed())
	var moves: Dictionary = {}
	for thirtieth: int in 6:
		moves[thirtieth] = Vector2.DOWN
	_arena.play(120, 0, 6, moves)  # 0.8125 tiles closer: 7.69 away.
	assert_true(_enemy.is_aggroed(), "aggroed once within 8 tiles")


func test_ac5_damage_aggroes_it_and_it_stays_aggroed() -> void:
	var player: PlayerMotor = _arena.add_player(FAR)
	_enemy = _arena.add_caster(Vector2.ZERO)
	var event: HitEvent = HitEvent.new()
	event.attacker_id = player.get_combat_id()
	event.damage = 1
	_enemy.apply_hit(event, _arena.rules)
	_arena.ticks(7)  # Its 0.05 s of hitstop first.
	assert_eq(_enemy.get_target_id(), &"player_1", "100 tiles away, but aggroed")
	_arena.ticks(60)
	assert_true(_enemy.is_aggroed())


func test_ac5_two_players_nearest_and_ties_by_registration() -> void:
	_arena.add_player(Vector2(0, 5), &"far")
	_arena.add_player(Vector2(0, 4), &"near")
	_enemy = _arena.add_caster(Vector2.ZERO)
	_arena.ticks(1)
	assert_eq(_enemy.get_target_id(), &"near")
	_arena = CasterArena.new()
	_arena.add_player(Vector2(5, 0), &"first")
	_arena.add_player(Vector2(-5, 0), &"second")
	_enemy = _arena.add_caster(Vector2.ZERO)
	_arena.ticks(1)
	assert_eq(_enemy.get_target_id(), &"first")


func test_ac5_a_dead_player_is_skipped_and_the_target_is_repicked() -> void:
	var near: PlayerMotor = _arena.add_player(Vector2(0, 4), &"near")
	_arena.add_player(Vector2(0, 5), &"far")
	_enemy = _arena.add_caster(Vector2.ZERO)
	_arena.restore_value(_enemy, "cooldown_remaining", NOT_READY)
	_arena.ticks(1)
	assert_eq(_enemy.get_target_id(), &"near")
	var event: HitEvent = HitEvent.new()
	event.damage = 1000
	near.apply_hit(event, _arena.rules)
	_arena.ticks(1)
	assert_eq(_enemy.get_target_id(), &"far")
