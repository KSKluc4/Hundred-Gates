extends GutTest
## F-003 T3: the shipped data files hold the design doc's starting values.

const RATE: int = 120


func test_warrior_file_has_the_design_combat_values() -> void:
	var warrior: ClassData = load(Tunables.WARRIOR_PATH)
	assert_eq(warrior.validate_combat(RATE).size(), 0)
	assert_eq(warrior.attack_chain_window, 0.25)
	assert_eq(warrior.max_hp, 100)
	assert_eq(warrior.hurtbox_radius_tiles, 0.35)
	assert_eq(warrior.knockback_scale, 1.0)
	assert_eq(warrior.attack_chain.size(), 3)


func test_sword_files_have_the_design_values() -> void:
	var chain: Array[AttackData] = (load(Tunables.WARRIOR_PATH) as ClassData).attack_chain
	var expected: Array[Array] = [
		[&"sword_hit_1", 0.08, 0.06, 0.18, 10, 100.0, 1.4, 0.3, false],
		[&"sword_hit_2", 0.08, 0.06, 0.18, 10, 100.0, 1.4, 0.3, false],
		[&"sword_hit_3", 0.16, 0.08, 0.32, 22, 150.0, 1.8, 1.2, true],
	]
	for index: int in expected.size():
		var hit: AttackData = chain[index]
		var actual: Array = [
			hit.id,
			hit.windup,
			hit.active,
			hit.recovery,
			hit.damage,
			hit.arc_angle_deg,
			hit.range_tiles,
			hit.knockback_tiles,
			hit.is_finisher,
		]
		assert_eq_deep(actual, expected[index])


func test_shared_rules_file_has_the_design_values() -> void:
	var tunables: PlayerCombatTunables = load(Tunables.PLAYER_COMBAT_PATH)
	assert_eq(tunables.validate_combat().size(), 0)
	assert_eq(tunables.combat_step_rate, 120)
	assert_eq(tunables.player_hurt_iframes, 0.6)
	assert_eq(tunables.knockback_duration, 0.12)
	assert_eq(tunables.hitstop_normal, 0.05)
	assert_eq(tunables.hitstop_finisher, 0.1)
	assert_eq(tunables.shake_intensity_hit, 0.2)
	assert_eq(tunables.shake_intensity_finisher, 0.5)
	assert_eq(tunables.shake_intensity_player_hurt, 0.6)


func test_dummy_file_has_the_design_values() -> void:
	var dummy: DummyData = load(Tunables.TRAINING_DUMMY_PATH)
	assert_eq(dummy.validate(RATE).size(), 0)
	assert_eq(dummy.max_hp, 200)
	assert_eq(dummy.hurtbox_radius_tiles, 0.5)
	assert_eq(dummy.respawn_delay, 1.0)
	assert_eq(dummy.pulse_interval, 2.0)
	assert_eq(dummy.pulse_telegraph, 0.6)
	assert_eq(dummy.pulse_active, 0.1)
	assert_eq(dummy.pulse_radius_tiles, 2.5)
	assert_eq(dummy.pulse_damage, 20)
	assert_eq(dummy.pulse_knockback_tiles, 1.0)


func test_shake_file_has_the_design_values() -> void:
	var settings: ScreenShakeSettings = load(Tunables.SCREEN_SHAKE_PATH)
	assert_eq(settings.validate().size(), 0)
	assert_true(settings.screen_shake_enabled)
	assert_eq(settings.max_offset_px, 6.0)
	assert_eq(settings.decay_time, 0.2)
