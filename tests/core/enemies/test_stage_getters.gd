extends GutTest
## F-007 T1: the effective-value getters and pick_attack_in() (C4). Without stages they are
## exactly EnemyData's own values, so nothing changes for the shipped enemies (C2).

const RATE: int = 120


func test_c4_pick_attack_in_matches_pick_attack_on_the_data_list() -> void:
	var data: EnemyData = EnemyArena.chaser_values()
	var far: EnemyAttackData = data.attacks[0].duplicate()
	far.trigger_min_tiles = 3.0
	far.trigger_max_tiles = 6.0
	data.attacks.append(far)
	for distance: float in [0.0, 1.6, 2.0, 3.0, 6.0, 7.0]:
		assert_eq(
			EnemyBrain.pick_attack_in(data.attacks, distance),
			EnemyBrain.pick_attack(data, distance),
			"distance %s" % distance
		)
	assert_eq(EnemyBrain.pick_attack_in([] as Array[EnemyAttackData], 1.0), -1, "empty list")


func test_c4_without_stages_the_getters_are_the_data_values() -> void:
	for data: EnemyData in [
		EnemyArena.chaser_values(), CasterArena.caster_values(), BruteArena.brute_values()
	]:
		var enemy: EnemyLogic = EnemyLogic.new()
		assert_true(enemy.setup(data, Tunables.enemy_combat, RATE, Vector2.ZERO, &"e"))
		assert_eq(enemy.get_current_attacks(), data.attacks, str(data.id))
		assert_eq(enemy.get_current_move_speed(), data.move_speed, str(data.id))
		assert_eq(enemy.get_current_attack_cooldown(), data.attack_cooldown, str(data.id))
