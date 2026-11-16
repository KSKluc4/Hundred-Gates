extends GutTest
## F-008 T2: volley data (C3), max_volley_size and volley validation (C7, AC9), and the latched
## copy through a reload (C8, AC11) and a snapshot.

const RATE: int = 120
const FAN: Array[float] = [-20.0, 0.0, 20.0]


func test_c3_the_default_is_empty_and_means_one_bolt_along_the_aim() -> void:
	var bolt: EnemyAttackData = load(Tunables.CASTER_BOLT_PATH)
	assert_eq(bolt.volley_angles_deg, PackedFloat64Array())
	var directions: Array[Vector2] = bolt.volley_directions(Vector2.UP)
	assert_eq(directions.size(), 1)
	assert_eq(directions[0], Vector2.UP)


func test_c4_directions_are_the_aim_rotated_by_each_angle_in_list_order() -> void:
	var aim: Vector2 = Vector2(0.6, 0.8)
	var directions: Array[Vector2] = _volley(FAN).volley_directions(aim)
	assert_eq(directions.size(), 3)
	for index: int in 3:
		var expected: Vector2 = aim.rotated(deg_to_rad(FAN[index]))
		assert_almost_eq(directions[index], expected, Vector2.ONE * 1e-9, "entry %d" % index)


func test_c7_max_volley_size_defaults_to_16_and_the_file_holds_16() -> void:
	assert_eq(EnemyCombatTunables.new().max_volley_size, 16, "script default")
	assert_eq(Tunables.enemy_combat.max_volley_size, 16, "enemy_combat.tres")
	var rules: EnemyCombatTunables = EnemyCombatTunables.new()
	assert_eq(rules.validate(), PackedStringArray())
	rules.max_volley_size = 1
	assert_eq(rules.validate(), PackedStringArray(), "1 is the minimum")


func test_ac9_max_volley_size_0_is_rejected_at_setup() -> void:
	var rules: EnemyCombatTunables = Tunables.enemy_combat.duplicate()
	rules.max_volley_size = 0
	assert_eq(rules.validate(), PackedStringArray(["max_volley_size must be >= 1"]))
	var enemy: EnemyLogic = EnemyLogic.new()
	assert_false(enemy.setup(_caster(_volley(FAN)), rules, RATE, Vector2.ZERO, &"e"))
	assert_push_error("max_volley_size must be >= 1")


func test_ac9_a_valid_fan_and_a_full_ring_pass() -> void:
	_assert_valid(FAN)
	_assert_valid([0, 30, 60, 90, 120, 150, 180, -150, -120, -90, -60, -30])
	_assert_valid([-180, 179.98])
	_assert_valid([0, 0.01])


func test_ac9_a_melee_attack_with_a_list_is_rejected() -> void:
	var swipe: EnemyAttackData = EnemyArena.chaser_values().attacks[0]
	swipe.volley_angles_deg = PackedFloat64Array([0.0])
	_assert_one_error(swipe, "volley_angles_deg must be empty for a melee attack")


func test_ac9_an_angle_out_of_range_or_not_finite_is_rejected() -> void:
	var message: String = "volley_angles_deg[1] must be finite and within -180..180"
	_assert_volley_error([0, 181], message)
	_assert_volley_error([0, -180.001], message)
	_assert_volley_error([0, NAN], message)
	_assert_volley_error([0, INF], message)
	_assert_valid([0, 180])
	_assert_valid([0, -180])


func test_ac9_two_entries_pointing_the_same_way_are_rejected() -> void:
	_assert_volley_error([10, 10], "volley_angles_deg[0] and [1] point the same way")
	_assert_volley_error([-180, 180], "volley_angles_deg[0] and [1] point the same way")
	_assert_volley_error([0, 0.005], "volley_angles_deg[0] and [1] point the same way")
	_assert_volley_error([5, 0, 5.001], "volley_angles_deg[0] and [2] point the same way")


## F-008 CR-1: exactly VOLLEY_ANGLE_EPSILON_DEG apart passes in either list order, also when
## translated and across the -180/180 seam; a pair just under it is still rejected either way.
func test_cr1_the_cutoff_does_not_depend_on_list_order() -> void:
	var at_cutoff: Array = [
		[0, 0.01],
		[0.01, 0],
		[10, 10.01],
		[10.01, 10],
		[-10, -10.01],
		[-10.01, -10],
		[123.45, 123.46],
		[123.46, 123.45],
		[-180, 179.99],
		[179.99, -180],
		[180, -179.99],
		[-179.99, 180],
	]
	for pair: Array in at_cutoff:
		_assert_valid(pair)
	var under: Array = [
		[0, 0.005],
		[0.005, 0],
		[10, 10.009],
		[10.009, 10],
		[-180, 179.995],
		[179.995, -180],
		[180, -179.995],
		[-179.995, 180],
	]
	for pair: Array in under:
		_assert_volley_error(pair, "volley_angles_deg[0] and [1] point the same way")


func test_ac9_at_most_max_volley_size_entries() -> void:
	_assert_valid(_spread(16))
	_assert_volley_error(
		_spread(17), "volley_angles_deg has 17 entries, more than max_volley_size (16)"
	)


func test_ac9_errors_name_the_attack_in_the_enemy_list() -> void:
	var data: EnemyData = _caster(_volley([10, 10]))
	var errors: PackedStringArray = data.validate(RATE, Tunables.enemy_combat)
	assert_eq(errors, PackedStringArray(["fan: volley_angles_deg[0] and [1] point the same way"]))
	var enemy: EnemyLogic = EnemyLogic.new()
	assert_false(enemy.setup(data, Tunables.enemy_combat, RATE, Vector2.ZERO, &"e"))
	assert_push_error("fan: volley_angles_deg[0] and [1] point the same way")


func test_ac9_a_bad_follow_up_is_rejected() -> void:
	var root: EnemyAttackData = _volley(FAN)
	var next: EnemyAttackData = _volley([181])
	next.id = &"next"
	root.follow_up = next
	var errors: PackedStringArray = _caster(root).validate(RATE, Tunables.enemy_combat)
	assert_eq(errors.size(), 1)
	assert_eq(errors[0], "next: volley_angles_deg[0] must be finite and within -180..180")


func test_ac9_a_bad_attack_in_a_stage_list_is_rejected() -> void:
	var data: EnemyData = _caster(_volley(FAN))
	var bad: EnemyAttackData = _volley(_spread(17))
	bad.id = &"stage_fan"
	var stages: Array[EnemyStageData] = [BossValues.stage(50, 1.0, bad, 2.0, 1.0)]
	data.stages = stages
	var errors: PackedStringArray = data.validate(RATE, Tunables.enemy_combat)
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "stages[0] (built-in): stage_fan: volley_angles_deg has 17")


func test_ac9_a_bad_list_is_rejected_on_reload_and_changes_nothing() -> void:
	var arena: CasterArena = CasterArena.new()
	arena.caster_data = _caster(_volley(FAN))
	var caster: EnemyLogic = arena.add_caster(Vector2.ZERO)
	var bad: EnemyData = _caster(_volley([0, NAN]))
	assert_false(caster.apply_data(bad, arena.enemy_rules, RATE))
	assert_push_error("fan: volley_angles_deg[1] must be finite")
	assert_eq(caster.get_data(), arena.caster_data, "the old data stays")


func test_c3_the_snapshot_carries_its_own_copy_of_the_list() -> void:
	var fan: EnemyAttackData = _volley(FAN)
	var snapshot: Dictionary = fan.to_dict()
	assert_eq(snapshot["volley_angles_deg"], PackedFloat64Array(FAN))
	fan.volley_angles_deg = PackedFloat64Array([1.0])
	assert_eq(snapshot["volley_angles_deg"], PackedFloat64Array(FAN), "not the attack's list")
	var copy: EnemyAttackData = EnemyAttackData.from_snapshot(snapshot)
	assert_eq(copy.volley_angles_deg, PackedFloat64Array(FAN))
	snapshot["volley_angles_deg"][0] = 99.0
	assert_eq(copy.volley_angles_deg, PackedFloat64Array(FAN), "not the snapshot's list")


func test_ac11_a_reload_in_windup_keeps_the_latched_list_and_the_next_attack_uses_the_new() -> void:
	var arena: CasterArena = CasterArena.new()
	arena.caster_data = _caster(_volley(FAN))
	arena.add_player()
	var caster: EnemyLogic = arena.add_caster(Vector2(0, 5.0))
	arena.tick()
	assert_eq(caster.get_state(), EnemyLogic.State.WINDUP)
	var reloaded: EnemyData = _caster(_volley([-10, 10]))
	assert_true(caster.apply_data(reloaded, arena.enemy_rules, RATE))
	assert_eq(caster.get_running_attack().volley_angles_deg, PackedFloat64Array(FAN), "latched")
	reloaded.attacks[0].volley_angles_deg = PackedFloat64Array([45.0])
	assert_eq(caster.get_running_attack().volley_angles_deg, PackedFloat64Array(FAN), "its own")
	reloaded.attacks[0].volley_angles_deg = PackedFloat64Array([-10.0, 10.0])
	while caster.get_state() == EnemyLogic.State.WINDUP:
		arena.tick()
	for _i: int in 600:
		arena.tick()
		if caster.get_state() == EnemyLogic.State.WINDUP:
			break
	assert_eq(caster.get_state(), EnemyLogic.State.WINDUP, "a second attack started")
	assert_eq(caster.get_running_attack().volley_angles_deg, PackedFloat64Array([-10.0, 10.0]))


## The caster's bolt as a volley named `fan`, at 120 steps/s.
static func _volley(angles: Array) -> EnemyAttackData:
	var attack: EnemyAttackData = CasterArena.caster_values().attacks[0]
	attack.id = &"fan"
	attack.volley_angles_deg = PackedFloat64Array(angles)
	return attack


static func _caster(attack: EnemyAttackData) -> EnemyData:
	var data: EnemyData = CasterArena.caster_values()
	data.attacks = [attack]
	return data


## `count` distinct angles within -180..180.
static func _spread(count: int) -> Array:
	var angles: Array = []
	for index: int in count:
		angles.append(-170.0 + 10.0 * index)
	return angles


func _assert_valid(angles: Array) -> void:
	var errors: PackedStringArray = _volley(angles).validate_enemy(RATE, Tunables.enemy_combat)
	assert_eq(errors, PackedStringArray(), str(angles))


func _assert_volley_error(angles: Array, message: String) -> void:
	_assert_one_error(_volley(angles), message)


func _assert_one_error(attack: EnemyAttackData, message: String) -> void:
	var errors: PackedStringArray = attack.validate_enemy(RATE, Tunables.enemy_combat)
	assert_eq(errors.size(), 1, str(errors))
	if errors.size() == 1:
		assert_string_contains(errors[0], message)
