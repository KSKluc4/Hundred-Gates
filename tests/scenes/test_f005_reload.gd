extends F005SceneTest
## F-005 AC2 and AC22 end to end, through the real F5 key. Works on user:// copies of the
## caster, its bolt, the enemy rules, the Warrior and the player rules, so a failed test can
## never damage the real ones.

const BOLT_PATH: String = "user://test_f005_bolt.tres"
const CASTER_PATH: String = "user://test_f005_caster.tres"
const RULES_PATH: String = "user://test_f005_enemy_rules.tres"
const CLASS_PATH: String = "user://test_f005_warrior.tres"
const PLAYER_RULES_PATH: String = "user://test_f005_player_rules.tres"
## AC22: exactly at the sampling limit at 240 steps/s with a 0.25-tile radius.
const SPEED_AT_240: float = 60.0


func before_each() -> void:
	super.before_each()
	_write_copies()


func after_each() -> void:
	super.after_each()
	for path: String in [BOLT_PATH, CASTER_PATH, RULES_PATH, CLASS_PATH, PLAYER_RULES_PATH]:
		DirAccess.remove_absolute(path)


func test_ac2_the_speed_rule_passes_at_setup_and_on_reload() -> void:
	await spawn(_use_copies)
	assert_eq(_runner.get_setup_errors().size(), 0, "2.5 against the Warrior's 5.0")
	press_key(KEY_F5)
	assert_string_contains(await overlay_text(), "reload: ok")
	assert_eq(_casters[0].logic.get_data().move_speed, 2.5)
	assert_eq(_player.class_data.move_speed, 5.0)


func test_ac2_the_speed_rule_still_rejects_a_caster_as_fast_as_the_warrior() -> void:
	await spawn(_use_copies)
	_write(CASTER_PATH, "move_speed", 5.0)
	press_key(KEY_F5)
	var text: String = await overlay_text()
	assert_string_contains(text, "reload rejected: ")
	assert_string_contains(text, "enemy caster move_speed 5.0 must be below class warrior")
	assert_eq(_casters[0].logic.get_data().move_speed, 2.5)


func test_ac22_the_caster_copy_references_its_bolt_file() -> void:
	assert_string_contains(FileAccess.get_file_as_string(CASTER_PATH), BOLT_PATH)


func test_ac22_a_bolt_in_flight_finishes_on_latched_values_and_the_next_uses_the_new() -> void:
	await spawn_fresh(_use_copies)
	var damage: Array[int] = _record_damage()
	await run_ticks(50)  # 0.83 s: projectile 0 in flight.
	assert_eq(_casters[0].logic.get_projectiles().get_projectiles().size(), 1)
	_write(BOLT_PATH, "damage", 25)
	_write(BOLT_PATH, "projectile_speed_tiles", 8.0)
	press_key(KEY_F5)
	assert_string_contains(await overlay_text(), "reload: ok")
	assert_eq(_casters[0].logic.get_data().attack.damage, 25, "CACHE_MODE_IGNORE_DEEP")
	var flying: ProjectileSet.Projectile = _casters[0].logic.get_projectiles().get_projectiles()[0]
	assert_eq(flying.speed, 6.0, "latched")
	await run_ticks(220)  # To 4.5 s: this bolt lands, the next one launches at 3.3 s and lands.
	assert_eq(damage, [18, 25] as Array[int], "latched 18, then the new 25")


func test_ac22_an_invalid_value_in_the_caster_or_bolt_file_rejects_the_whole_group() -> void:
	var edits: Array[Callable] = [
		_write.bind(CASTER_PATH, "retreat_distance_tiles", 6.5),  # Above stop 6.0.
		_write.bind(BOLT_PATH, "projectile_speed_tiles", 31.0),  # 0.258 tiles per step.
		_write.bind(BOLT_PATH, "projectile_max_distance_tiles", 0.0),
		_write.bind(BOLT_PATH, "arc_angle_deg", 90.0),
		_write.bind(BOLT_PATH, "lunge_tiles", 0.5),
	]
	for edit: Callable in edits:
		await spawn(_use_copies)
		var before: Dictionary = _what_reload_touches()
		_write(CLASS_PATH, "attack_chain_window", 0.5)  # Valid, and must not go in either.
		edit.call()
		press_key(KEY_F5)
		assert_string_contains(await overlay_text(), "reload: reload rejected: ")
		assert_eq_deep(_what_reload_touches(), before)
		_scene.queue_free()
		_write_copies()


func test_ac22_a_rate_a_bolt_in_flight_cant_take_is_rejected_and_names_it() -> void:
	await _spawn_at_240()
	await run_ticks(38)  # 0.63 s: launched at 0.6, in flight until about 0.7.
	var projectiles: Array[ProjectileSet.Projectile] = (
		_casters[0].logic.get_projectiles().get_projectiles()
	)
	assert_eq(projectiles.size(), 1)
	assert_false(projectiles[0].is_finished(), "in flight")
	_write(PLAYER_RULES_PATH, "combat_step_rate", 120)
	_write(BOLT_PATH, "projectile_speed_tiles", 30.0)  # Valid at 120: only the flying one isn't.
	press_key(KEY_F5)
	var text: String = await overlay_text()
	assert_string_contains(text, "reload rejected: running hit or pulse on caster_1: ")
	assert_string_contains(text, "projectile 0 in flight")
	assert_eq(_runner.get_sim().get_step_rate(), 240, "nothing changed")
	assert_eq(_casters[0].logic.get_data().attack.projectile_speed_tiles, SPEED_AT_240)


func test_ac22_a_pending_launch_rejects_the_rate_and_launches_at_its_latched_speed() -> void:
	await _spawn_at_240()
	await run_ticks(10)  # 0.17 s: in windup, nothing launched.
	assert_eq(_casters[0].logic.get_state(), EnemyLogic.State.WINDUP)
	assert_eq(_casters[0].logic.get_projectiles().get_projectiles().size(), 0)
	var before: Dictionary = _what_reload_touches()
	_write(PLAYER_RULES_PATH, "combat_step_rate", 120)
	_write(BOLT_PATH, "projectile_speed_tiles", 30.0)  # Valid on its own at 120.
	press_key(KEY_F5)
	var text: String = await overlay_text()
	assert_string_contains(text, "reload rejected: running hit or pulse on caster_1: ")
	assert_string_contains(text, "pending projectile of caster_bolt")
	assert_eq_deep(_what_reload_touches(), before)
	assert_eq(_runner.get_sim().get_step_rate(), 240)
	await run_ticks(26)  # To 0.6 s and a bit: launched.
	var projectiles: Array[ProjectileSet.Projectile] = (
		_casters[0].logic.get_projectiles().get_projectiles()
	)
	assert_eq(projectiles.size(), 1)
	assert_eq(projectiles[0].speed, SPEED_AT_240, "its latched speed")


## Fresh, valid copies of every file. The caster copy points at the bolt copy.
func _write_copies() -> void:
	assert_eq(ResourceSaver.save(caster_copy().attack, BOLT_PATH), OK)
	var caster: EnemyData = caster_copy()
	caster.attack = ResourceLoader.load(BOLT_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_eq(ResourceSaver.save(caster, CASTER_PATH), OK)
	assert_eq(ResourceSaver.save(Tunables.enemy_combat.duplicate(), RULES_PATH), OK)
	assert_eq(ResourceSaver.save(load(Tunables.WARRIOR_PATH).duplicate(), CLASS_PATH), OK)
	assert_eq(ResourceSaver.save(Tunables.player_combat.duplicate(), PLAYER_RULES_PATH), OK)


func _use_copies() -> void:
	place_oracle()
	_player.class_data = ResourceLoader.load(CLASS_PATH, "", ResourceLoader.CACHE_MODE_REPLACE)
	_player.tunables_path = PLAYER_RULES_PATH
	var data: EnemyData = ResourceLoader.load(CASTER_PATH, "", ResourceLoader.CACHE_MODE_REPLACE)
	for caster: Enemy in _casters:
		caster.data = data
	_runner.enemy_combat_path = RULES_PATH


func _spawn_at_240() -> void:
	var rules: PlayerCombatTunables = _tunables_before.duplicate()
	rules.combat_step_rate = 240
	Tunables.player_combat = rules
	assert_eq(ResourceSaver.save(rules, PLAYER_RULES_PATH), OK)
	_write(BOLT_PATH, "projectile_speed_tiles", SPEED_AT_240)
	await spawn_fresh(_use_copies)


## Everything an F5 could change, by value or by object.
func _what_reload_touches() -> Dictionary:
	var enemy_data: Array[EnemyData] = []
	for enemy: Enemy in [_casters[0], _casters[1], _chaser]:
		enemy_data.append(enemy.logic.get_data())
	return {
		"class": _player.class_data,
		"player_rules": Tunables.player_combat,
		"enemy_rules": Tunables.enemy_combat,
		"enemies": enemy_data,
		"rate": _runner.get_sim().get_step_rate(),
	}


func _record_damage() -> Array[int]:
	var damage: Array[int] = []
	_player.motor.get_combat_state().damaged.connect(
		func(event: HitEvent) -> void: damage.append(event.damage)
	)
	return damage


func _write(path: String, field: String, value: Variant) -> void:
	var resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	resource.set(field, value)
	assert_eq(ResourceSaver.save(resource, path), OK)
