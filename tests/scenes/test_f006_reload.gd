extends F006SceneTest
## F-006 AC14 (C11) end to end, through the real F5 key, in the debug scene. Works on user://
## copies of the brute, its two attacks, the enemy rules, the Warrior and the player rules, so
## a failed test can never damage the real ones.

const STOMP_PATH: String = "user://test_f006_stomp.tres"
const CHARGE_PATH: String = "user://test_f006_charge.tres"
const BRUTE_PATH: String = "user://test_f006_brute.tres"
const RULES_PATH: String = "user://test_f006_enemy_rules.tres"
const CLASS_PATH: String = "user://test_f006_warrior.tres"
const PLAYER_RULES_PATH: String = "user://test_f006_player_rules.tres"
const PATHS: Array[String] = [
	STOMP_PATH, CHARGE_PATH, BRUTE_PATH, RULES_PATH, CLASS_PATH, PLAYER_RULES_PATH
]


func before_each() -> void:
	super()
	Engine.physics_ticks_per_second = 120
	_write_copies()


func after_each() -> void:
	super()
	for path: String in PATHS:
		DirAccess.remove_absolute(path)


func test_ac14_the_brute_copy_references_both_attack_files() -> void:
	var text: String = FileAccess.get_file_as_string(BRUTE_PATH)
	assert_string_contains(text, STOMP_PATH)
	assert_string_contains(text, CHARGE_PATH)


func test_ac14_an_edit_mid_windup_spares_the_running_charge_and_the_next_one_uses_it() -> void:
	await spawn_debug_scene(_use_copies)
	var damage: Array[int] = _record_damage()
	await run_to(0.3)
	assert_eq(_brute.logic.get_state(), EnemyLogic.State.WINDUP)
	_write(CHARGE_PATH, "damage", 30)
	_write(CHARGE_PATH, "windup", 0.9)
	press_key(KEY_F5)
	assert_string_contains(await overlay_text(), "reload: ok")
	assert_eq(_brute.logic.get_data().attacks[1].damage, 30, "CACHE_MODE_IGNORE_DEEP")
	var running: EnemyAttackData = _brute.logic.get_running_attack()
	assert_eq(running.damage, 25, "latched")
	assert_eq(running.windup, 0.8, "latched")
	await run_to(2.0)
	assert_eq(damage, [25] as Array[int], "the running charge hit with its latched 25")
	while _brute.logic.get_cooldown_remaining() > 0.05:
		await run_ticks(1)
	# Five tiles in front of it again, so the next attack is a charge.
	_put_player_at(brute_tiles() - Vector2(5.0, 0))
	while _brute.logic.get_state() != EnemyLogic.State.WINDUP:
		await run_ticks(1)
	assert_eq(_brute.logic.get_running_attack().id, &"brute_charge")
	assert_eq(_brute.logic.get_running_attack().damage, 30, "the next charge uses the edit")
	assert_eq(_brute.logic.get_running_attack().windup, 0.9)


func test_ac14_f5_rereads_both_attacks_of_the_brute() -> void:
	await spawn_debug_scene(_use_copies)
	_write(STOMP_PATH, "damage", 22)
	_write(CHARGE_PATH, "wall_stun_duration", 2.0)
	_write(BRUTE_PATH, "attack_cooldown", 1.2)
	press_key(KEY_F5)
	assert_string_contains(await overlay_text(), "reload: ok")
	var data: EnemyData = _brute.logic.get_data()
	assert_eq(data.attack_cooldown, 1.2)
	assert_eq(data.attacks[0].damage, 22)
	assert_eq(data.attacks[1].wall_stun_duration, 2.0)


func test_ac14_an_invalid_stun_in_the_charge_file_rejects_the_whole_group() -> void:
	await spawn_debug_scene(_use_copies)
	var before: EnemyData = _brute.logic.get_data()
	_write(STOMP_PATH, "damage", 22)  # Valid, and must not go in either.
	_write(CHARGE_PATH, "wall_stun_duration", 0.5)
	press_key(KEY_F5)
	var text: String = await overlay_text()
	assert_string_contains(text, "reload: reload rejected: ")
	assert_string_contains(text, "brute_charge: wall_stun_duration must be >= recovery")
	assert_eq(_brute.logic.get_data(), before, "nothing changed")
	assert_eq(_brute.logic.get_data().attacks[0].damage, 20)


## Fresh, valid copies of every file. The brute copy points at the attack copies.
func _write_copies() -> void:
	var values: EnemyData = BruteArena.brute_values()
	assert_eq(ResourceSaver.save(values.attacks[0], STOMP_PATH), OK)
	assert_eq(ResourceSaver.save(values.attacks[1], CHARGE_PATH), OK)
	values.attacks = [
		ResourceLoader.load(STOMP_PATH, "", ResourceLoader.CACHE_MODE_IGNORE),
		ResourceLoader.load(CHARGE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE),
	]
	assert_eq(ResourceSaver.save(values, BRUTE_PATH), OK)
	assert_eq(ResourceSaver.save(Tunables.enemy_combat.duplicate(), RULES_PATH), OK)
	assert_eq(ResourceSaver.save(load(Tunables.WARRIOR_PATH).duplicate(), CLASS_PATH), OK)
	assert_eq(ResourceSaver.save(Tunables.player_combat.duplicate(), PLAYER_RULES_PATH), OK)


func _use_copies() -> void:
	_player.class_data = ResourceLoader.load(CLASS_PATH, "", ResourceLoader.CACHE_MODE_REPLACE)
	_player.tunables_path = PLAYER_RULES_PATH
	_brute.data = ResourceLoader.load(BRUTE_PATH, "", ResourceLoader.CACHE_MODE_REPLACE)
	_runner.enemy_combat_path = RULES_PATH


func _write(path: String, field: String, value: Variant) -> void:
	var resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	resource.set(field, value)
	assert_eq(ResourceSaver.save(resource, path), OK)


func _record_damage() -> Array[int]:
	var damage: Array[int] = []
	_player.motor.get_combat_state().damaged.connect(
		func(event: HitEvent) -> void: damage.append(event.damage)
	)
	return damage


## Between ticks: the logic first, then the body from it (F-001/C18's restore path).
func _put_player_at(tiles: Vector2) -> void:
	_player.motor.sync_position(Units.vector_tiles_to_px(tiles))
	_player.sync_body_from_logic()
