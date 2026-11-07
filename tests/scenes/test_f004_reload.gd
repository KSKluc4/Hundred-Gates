extends F004SceneTest
## AC20 end to end, through the real F5 key. Works on user:// copies of the chaser, its swipe,
## the enemy rules and the Warrior, so a failed test can never damage the real ones.

const SWIPE_PATH: String = "user://test_f004_swipe.tres"
const CHASER_PATH: String = "user://test_f004_chaser.tres"
const RULES_PATH: String = "user://test_f004_enemy_rules.tres"
const CLASS_PATH: String = "user://test_f004_warrior.tres"
const PLAYER_RULES_PATH: String = "user://test_f004_player_rules.tres"
const ACTIVE_AT_240: float = 1.0 / 240.0
## 1.25 tiles below the player: in range at once, so chaser_1 starts a windup on the first step.
const IN_RANGE: Vector2 = Vector2(0, 20)


func before_each() -> void:
	super.before_each()
	_write_copies()


## Fresh, valid copies of every file.
func _write_copies() -> void:
	assert_eq(ResourceSaver.save(EnemyArena.chaser_values().attack, SWIPE_PATH), OK)
	_write_chaser_copy(chaser_copy())
	assert_eq(ResourceSaver.save(Tunables.enemy_combat.duplicate(), RULES_PATH), OK)
	assert_eq(ResourceSaver.save(load(Tunables.WARRIOR_PATH).duplicate(), CLASS_PATH), OK)
	assert_eq(ResourceSaver.save(Tunables.player_combat.duplicate(), PLAYER_RULES_PATH), OK)


func after_each() -> void:
	super.after_each()
	for path: String in [SWIPE_PATH, CHASER_PATH, RULES_PATH, CLASS_PATH, PLAYER_RULES_PATH]:
		DirAccess.remove_absolute(path)


func test_ac20_the_chaser_copy_references_its_swipe_file() -> void:
	assert_string_contains(FileAccess.get_file_as_string(CHASER_PATH), SWIPE_PATH)


func test_ac20_a_valid_reload_takes_every_enemy_file() -> void:
	await spawn(_use_copies)
	_write(CHASER_PATH, "attack_cooldown", 1.5)
	_write(SWIPE_PATH, "damage", 33)
	_write(RULES_PATH, "min_telegraph", 0.25)
	press_key(KEY_F5)
	assert_string_contains(await overlay_text(), "reload: ok")
	for chaser: Enemy in _chasers:
		assert_eq(chaser.logic.get_data().attack_cooldown, 1.5, String(chaser.combat_id))
		assert_eq(chaser.logic.get_data().attack.damage, 33, "CACHE_MODE_IGNORE_DEEP")
	assert_eq(_chasers[0].logic.get_data(), _chasers[1].logic.get_data(), "one file, loaded once")
	assert_eq(Tunables.enemy_combat.min_telegraph, 0.25)


func test_ac20_an_invalid_value_in_any_enemy_file_rejects_the_whole_group() -> void:
	var edits: Array[Callable] = [
		_write.bind(CHASER_PATH, "max_hp", 0),
		_write.bind(SWIPE_PATH, "windup", 0.2),  # Below min_telegraph 0.3 (C8).
		_write.bind(RULES_PATH, "min_locked_telegraph", 0.4),  # Above min_telegraph 0.3.
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


func test_ac20_a_reload_mid_attack_lets_that_swing_finish_on_its_latched_values() -> void:
	await spawn(_use_copies_in_range)
	var damage: Array[int] = _record_damage()
	await run_ticks(6)
	assert_eq(_chasers[0].logic.get_state(), EnemyLogic.State.WINDUP)
	_write(SWIPE_PATH, "damage", 33)
	press_key(KEY_F5)
	assert_string_contains(await overlay_text(), "reload: ok")
	await run_ticks(210)  # 3.5 s: this swing, its recovery and cooldown, and the next swing.
	assert_eq(damage, [20, 33] as Array[int], "latched 20, then the new 33")


func test_ac20_lowering_max_hp_clamps_hp() -> void:
	await spawn(_use_copies)
	_write(CHASER_PATH, "max_hp", 30)
	press_key(KEY_F5)
	assert_string_contains(await overlay_text(), "reload: ok")
	for chaser: Enemy in _chasers:
		var state: CombatState = chaser.logic.get_combat_state()
		assert_eq(state.get_hp(), 30, String(chaser.combat_id))
		assert_eq(state.get_max_hp(), 30)


func test_ac20_a_rate_change_that_breaks_a_running_enemy_window_is_rejected() -> void:
	await _spawn_at_240()
	await run_ticks(2)
	assert_eq(_chasers[0].logic.get_state(), EnemyLogic.State.WINDUP)
	_write(PLAYER_RULES_PATH, "combat_step_rate", 120)
	_write(SWIPE_PATH, "active", 0.1)  # Valid at 120: only the running window is short.
	press_key(KEY_F5)
	var text: String = await overlay_text()
	assert_string_contains(text, "reload rejected: running hit or pulse on chaser_1")
	assert_eq(_runner.get_sim().get_step_rate(), 240, "nothing changed")
	assert_almost_eq(_chasers[0].logic.get_data().attack.active, ACTIVE_AT_240, TIME)


func test_ac20_the_speed_rule_rejects_the_whole_group_from_either_side() -> void:
	var edits: Array[Callable] = [
		_write.bind(CHASER_PATH, "move_speed", 5.0),
		_write.bind(CHASER_PATH, "move_speed", 6.0),
		_write.bind(CLASS_PATH, "move_speed", 3.0),
		_write.bind(CLASS_PATH, "move_speed", 2.0),
	]
	for edit: Callable in edits:
		await spawn(_use_copies)
		var before: Dictionary = _what_reload_touches()
		_write(SWIPE_PATH, "damage", 33)  # Valid edits to other files in the same F5.
		_write(RULES_PATH, "min_telegraph", 0.25)
		edit.call()
		press_key(KEY_F5)
		var text: String = await overlay_text()
		assert_string_contains(text, "reload: reload rejected: ")
		assert_string_contains(text, "must be below class warrior move_speed")
		assert_eq_deep(_what_reload_touches(), before)
		_scene.queue_free()
		_write_copies()


func test_ac20_the_speed_rule_reads_both_candidates_together() -> void:
	for speeds: Array in [[6.0, 7.0], [1.5, 2.0]]:
		await spawn(_use_copies)
		_write(CHASER_PATH, "move_speed", speeds[0])
		_write(CLASS_PATH, "move_speed", speeds[1])
		press_key(KEY_F5)
		assert_string_contains(await overlay_text(), "reload: ok", "chaser %s, warrior %s" % speeds)
		assert_eq(_chasers[0].logic.get_data().move_speed, speeds[0])
		assert_eq(_player.class_data.move_speed, speeds[1])
		_scene.queue_free()
		_write_copies()


func _use_copies() -> void:
	place_oracle()
	_player.class_data = ResourceLoader.load(CLASS_PATH, "", ResourceLoader.CACHE_MODE_REPLACE)
	_player.tunables_path = PLAYER_RULES_PATH
	var data: EnemyData = ResourceLoader.load(CHASER_PATH, "", ResourceLoader.CACHE_MODE_REPLACE)
	for chaser: Enemy in _chasers:
		chaser.data = data
	_runner.enemy_combat_path = RULES_PATH


func _use_copies_in_range() -> void:
	_use_copies()
	_chasers[0].position = CENTRE + IN_RANGE


func _spawn_at_240() -> void:
	var rules: PlayerCombatTunables = _tunables_before.duplicate()
	rules.combat_step_rate = 240
	Tunables.player_combat = rules
	assert_eq(ResourceSaver.save(rules, PLAYER_RULES_PATH), OK)
	_write(SWIPE_PATH, "active", ACTIVE_AT_240)
	await spawn(_use_copies_in_range)


## Everything an F5 could change, by value or by object.
func _what_reload_touches() -> Dictionary:
	var chaser_data: Array[EnemyData] = []
	for chaser: Enemy in _chasers:
		chaser_data.append(chaser.logic.get_data())
	return {
		"class": _player.class_data,
		"player_rules": Tunables.player_combat,
		"enemy_rules": Tunables.enemy_combat,
		"chasers": chaser_data,
		"rate": _runner.get_sim().get_step_rate(),
	}


func _record_damage() -> Array[int]:
	var damage: Array[int] = []
	_player.motor.get_combat_state().damaged.connect(
		func(event: HitEvent) -> void: damage.append(event.damage)
	)
	return damage


## The chaser copy points at the swipe copy, so F5 re-reads that file too.
func _write_chaser_copy(data: EnemyData) -> void:
	data.attack = ResourceLoader.load(SWIPE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_eq(ResourceSaver.save(data, CHASER_PATH), OK)


func _write(path: String, field: String, value: Variant) -> void:
	var resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	resource.set(field, value)
	assert_eq(ResourceSaver.save(resource, path), OK)
