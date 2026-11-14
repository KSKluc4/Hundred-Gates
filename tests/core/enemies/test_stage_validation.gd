extends GutTest
## F-007 T4: follow-up and stage validation (C13), AC12 at setup: EnemyData.validate(),
## validate_against_class(), and EnemyLogic.setup() refusing the data. The reload side is in
## tests/scenes/test_f007_reload.gd. Also apply_data()'s C19 guard.

const RATE: int = 120


func test_ac12_a_valid_boss_passes() -> void:
	var data: EnemyData = BossValues.chaser_boss()
	assert_eq(data.validate(RATE, Tunables.enemy_combat), PackedStringArray())
	assert_eq(data.validate_against_class(CombatArena.warrior()), PackedStringArray())


func test_ac12_a_follow_up_cycle_is_rejected() -> void:
	var data: EnemyData = BossValues.chaser_boss()
	var root: EnemyAttackData = data.attacks[0]
	root.follow_up.follow_up = root  # root -> next -> root
	_assert_setup_refuses(data, "closes a cycle")
	_assert_one_error(data, "next: follow_up root closes a cycle")
	root.follow_up.follow_up = null  # Or the two would keep each other alive.


func test_ac12_a_self_cycle_is_rejected() -> void:
	var data: EnemyData = BossValues.chaser_boss()
	var next: EnemyAttackData = data.attacks[0].follow_up
	next.follow_up = next
	_assert_one_error(data, "next: follow_up next closes a cycle")
	next.follow_up = null


func test_ac12_a_follow_up_under_the_locked_telegraph_floor_is_rejected() -> void:
	var data: EnemyData = BossValues.chaser_boss()
	data.attacks[0].follow_up.windup = 0.4  # 0.4 - 0.3 tracking = 0.1 locked < 0.15.
	_assert_setup_refuses(data, "min_locked_telegraph")
	_assert_one_error(data, "next: windup - aim_track_time must be >= min_locked_telegraph")


func test_c13_a_follow_up_two_deep_is_checked_too() -> void:
	var data: EnemyData = BossValues.chaser_boss()
	var third: EnemyAttackData = data.attacks[0].duplicate()
	third.id = &"third"
	third.follow_up = null
	third.damage = 0
	data.attacks[0].follow_up.follow_up = third
	_assert_one_error(data, "third: damage must be >= 1")


func test_c13_a_follow_up_must_be_of_the_brain_kind() -> void:
	var data: EnemyData = BossValues.chaser_boss()
	data.attacks[0].follow_up = CasterArena.caster_values().attacks[0]
	_assert_one_error(data, "CHASER needs a melee attack, caster_bolt is a projectile")


func test_ac12_stage_percents_must_strictly_decrease() -> void:
	var data: EnemyData = BossValues.chaser_boss()
	data.stages.append(_stage_copy(data.stages[0], 50))
	_assert_setup_refuses(data, "enter_at_hp_percent must be below")
	_assert_one_error(data, "stages[1] (built-in): enter_at_hp_percent must be below the previous")
	data.stages[1].enter_at_hp_percent = 60
	_assert_one_error(data, "stages[1] (built-in): enter_at_hp_percent must be below the previous")
	data.stages[1].enter_at_hp_percent = 49
	assert_eq(data.validate(RATE, Tunables.enemy_combat), PackedStringArray())


func test_ac12_a_percent_of_0_or_100_is_rejected() -> void:
	for percent: int in [0, 100, -5, 150]:
		var data: EnemyData = BossValues.chaser_boss()
		data.stages[0].enter_at_hp_percent = percent
		_assert_setup_refuses(data, "enter_at_hp_percent must be 1-99")
		_assert_one_error(data, "stages[0] (built-in): enter_at_hp_percent must be 1-99")
	for percent: int in [1, 99]:
		var data: EnemyData = BossValues.chaser_boss()
		data.stages[0].enter_at_hp_percent = percent
		assert_eq(data.validate(RATE, Tunables.enemy_combat), PackedStringArray(), str(percent))


func test_ac12_a_negative_shift_is_rejected() -> void:
	var data: EnemyData = BossValues.chaser_boss()
	data.stages[0].shift_duration = -0.1
	_assert_setup_refuses(data, "shift_duration must be >= 0")
	_assert_one_error(data, "stages[0] (built-in): shift_duration must be >= 0")


func test_ac12_a_stage_speed_at_or_above_the_warrior_is_rejected() -> void:
	var data: EnemyData = BossValues.chaser_boss()
	var warrior: ClassData = CombatArena.warrior()
	data.stages[0].move_speed = warrior.move_speed
	var errors: PackedStringArray = data.validate_against_class(warrior)
	assert_eq(errors.size(), 1, str(errors))
	assert_string_contains(errors[0], "enemy boss stages[0] (built-in) move_speed 5")
	assert_string_contains(errors[0], "must be below class warrior move_speed 5")
	data.stages[0].move_speed = warrior.move_speed + 1.0
	assert_eq(data.validate_against_class(warrior).size(), 1)
	data.stages[0].move_speed = warrior.move_speed - 0.01
	assert_eq(data.validate_against_class(warrior), PackedStringArray())


func test_ac12_a_negative_stage_speed_is_rejected() -> void:
	var data: EnemyData = BossValues.chaser_boss()
	data.stages[0].move_speed = -1.0
	_assert_setup_refuses(data, "move_speed must be >= 0")
	_assert_one_error(data, "stages[0] (built-in): move_speed must be >= 0")


func test_ac12_a_negative_stage_cooldown_is_rejected() -> void:
	var data: EnemyData = BossValues.chaser_boss()
	data.stages[0].attack_cooldown = -0.1
	_assert_setup_refuses(data, "attack_cooldown must be >= 0")
	_assert_one_error(data, "stages[0] (built-in): attack_cooldown must be >= 0")


func test_ac12_a_null_stage_is_rejected_by_position() -> void:
	var data: EnemyData = BossValues.chaser_boss()
	data.stages.append(null)
	_assert_setup_refuses(data, "stages[1] must not be null")
	_assert_one_error(data, "stages[1] must not be null")
	assert_eq(data.validate_against_class(CombatArena.warrior()), PackedStringArray())


func test_ac12_an_all_zero_stage_passes() -> void:
	var data: EnemyData = BossValues.chaser_boss()
	data.stages[0].move_speed = 0.0
	data.stages[0].attack_cooldown = 0.0
	data.stages[0].shift_duration = 0.0
	assert_eq(data.validate(RATE, Tunables.enemy_combat), PackedStringArray())
	assert_eq(data.validate_against_class(CombatArena.warrior()), PackedStringArray())
	var enemy: EnemyLogic = EnemyLogic.new()
	assert_true(enemy.setup(data, Tunables.enemy_combat, RATE, Vector2.ZERO, &"boss"))


func test_c13_a_stage_attack_list_gets_every_list_check() -> void:
	var data: EnemyData = BossValues.chaser_boss()
	var empty: Array[EnemyAttackData] = []
	data.stages[0].attacks = empty
	_assert_one_error(data, "stages[0] (built-in): attacks must not be empty")
	data = BossValues.chaser_boss()
	data.stages[0].attacks.append(null)
	_assert_one_error(data, "stages[0] (built-in): attacks[1] must not be null")
	data = BossValues.chaser_boss()
	data.stages[0].attacks[0].windup = 0.45
	data.stages[0].attacks[0].aim_track_time = 0.4
	_assert_one_error(data, "stages[0] (built-in): stage_swipe: windup - aim_track_time must be")


func test_c13_a_stage_error_names_its_file() -> void:
	var data: EnemyData = BossValues.chaser_boss()
	data.stages[0].take_over_path("res://data/enemies/some_stage.tres")
	data.stages[0].shift_duration = -1.0
	_assert_one_error(data, "stages[0] (res://data/enemies/some_stage.tres): shift_duration")


func test_c19_reload_errors_name_the_enemy_the_file_and_the_stage() -> void:
	var arena: EnemyArena = EnemyArena.new()
	arena.chaser_data = BossValues.chaser_boss()
	arena.chaser_data.stages[0].shift_duration = 0.0
	arena.add_player(Vector2(0, 8.0))
	var enemy: EnemyLogic = arena.add_chaser(Vector2.ZERO, &"boss_1")
	BossValues.set_hp(enemy, 200)
	arena.ticks(1)
	assert_eq(enemy.get_stage_index(), 1)
	var candidate: EnemyData = BossValues.chaser_boss()
	candidate.take_over_path("res://data/enemies/candidate.tres")
	assert_eq(enemy.reload_errors(candidate), PackedStringArray(), "stage 1 is still listed")
	var no_stages: Array[EnemyStageData] = []
	candidate.stages = no_stages
	var errors: PackedStringArray = enemy.reload_errors(candidate)
	assert_eq(errors.size(), 1)
	if errors.size() == 1:
		assert_eq(
			errors[0],
			"boss_1: in stage 1, but res://data/enemies/candidate.tres lists only 0 stages"
		)
	var before: EnemyData = enemy.get_data()
	assert_false(enemy.apply_data(candidate, arena.enemy_rules, 120), "the guard")
	assert_push_error("in stage 1, but")
	assert_eq(enemy.get_data(), before, "nothing changed")
	assert_eq(enemy.get_stage_index(), 1)


func test_c19_a_stage_0_enemy_takes_any_valid_candidate() -> void:
	var enemy: EnemyLogic = EnemyLogic.new()
	assert_true(
		enemy.setup(BossValues.chaser_boss(), Tunables.enemy_combat, RATE, Vector2.ZERO, &"boss")
	)
	var candidate: EnemyData = EnemyArena.chaser_values()
	assert_eq(enemy.reload_errors(candidate), PackedStringArray())
	assert_true(enemy.apply_data(candidate, Tunables.enemy_combat, RATE))


static func _stage_copy(stage: EnemyStageData, percent: int) -> EnemyStageData:
	var copy: EnemyStageData = stage.duplicate()
	copy.enter_at_hp_percent = percent
	var attacks: Array[EnemyAttackData] = [stage.attacks[0].duplicate()]
	copy.attacks = attacks
	return copy


func _assert_setup_refuses(data: EnemyData, error: String) -> void:
	var enemy: EnemyLogic = EnemyLogic.new()
	assert_false(enemy.setup(data, Tunables.enemy_combat, RATE, Vector2.ZERO, &"boss"), error)
	assert_push_error(error)
	assert_null(enemy.get_data(), "changes nothing")


func _assert_one_error(data: EnemyData, error: String) -> void:
	var errors: PackedStringArray = data.validate(RATE, Tunables.enemy_combat)
	assert_eq(errors.size(), 1, str(errors))
	if errors.size() == 1:
		assert_string_contains(errors[0], error)
