extends GutTest
## F-003/C18: shared rules, dummy and shake bounds, both sides.

const RATE: int = 120
const STEP: float = 1.0 / RATE


func test_valid_tunables_have_no_combat_errors() -> void:
	assert_eq(_tunables().validate_combat().size(), 0)


func test_each_tunable_bound_is_rejected() -> void:
	var cases: Array[Array] = [
		["combat_step_rate", 0],
		["combat_step_rate", -120],
		["combat_step_rate", 100],
		["player_hurt_iframes", -0.01],
		["knockback_duration", 0.0],
		["hitstop_normal", -0.01],
		["hitstop_finisher", -0.01],
		["shake_intensity_hit", -0.01],
		["shake_intensity_hit", 1.01],
		["shake_intensity_finisher", -0.01],
		["shake_intensity_finisher", 1.01],
		["shake_intensity_player_hurt", -0.01],
		["shake_intensity_player_hurt", 1.01],
	]
	for case: Array in cases:
		var tunables: PlayerCombatTunables = _tunables()
		tunables.set(case[0], case[1])
		assert_eq(tunables.validate_combat().size(), 1, "%s = %s" % case)


func test_tunable_values_at_their_limits_are_valid() -> void:
	var cases: Array[Array] = [
		["combat_step_rate", 240],
		["player_hurt_iframes", 0.0],
		["hitstop_normal", 0.0],
		["hitstop_finisher", 0.0],
		["shake_intensity_hit", 0.0],
		["shake_intensity_hit", 1.0],
	]
	for case: Array in cases:
		var tunables: PlayerCombatTunables = _tunables()
		tunables.set(case[0], case[1])
		assert_eq(tunables.validate_combat().size(), 0, "%s = %s" % case)


func test_valid_dummy_has_no_errors() -> void:
	assert_eq(_dummy().validate(RATE).size(), 0)


func test_each_dummy_bound_is_rejected() -> void:
	var cases: Array[Array] = [
		["max_hp", 0],
		["hurtbox_radius_tiles", 0.0],
		["respawn_delay", -0.01],
		["pulse_interval", 0.0],
		["pulse_telegraph", -0.01],
		["pulse_radius_tiles", 0.0],
		["pulse_damage", 0],
		["pulse_knockback_tiles", -0.01],
	]
	for case: Array in cases:
		var dummy: DummyData = _dummy()
		dummy.set(case[0], case[1])
		assert_false(dummy.validate(RATE).is_empty(), "%s = %s" % case)


func test_dummy_values_at_their_limits_are_valid() -> void:
	var cases: Array[Array] = [
		["respawn_delay", 0.0],
		["pulse_knockback_tiles", 0.0],
		["pulse_damage", 1],
	]
	for case: Array in cases:
		var dummy: DummyData = _dummy()
		dummy.set(case[0], case[1])
		assert_eq(dummy.validate(RATE).size(), 0, "%s = %s" % case)


func test_ac26_pulse_active_below_one_step_is_rejected() -> void:
	var dummy: DummyData = _dummy()
	dummy.pulse_active = 0.008
	assert_eq(dummy.validate(RATE).size(), 1)
	dummy.pulse_active = STEP
	assert_eq(dummy.validate(RATE).size(), 0)


func test_ac26_zero_telegraph_needs_two_steps_of_active_time() -> void:
	var dummy: DummyData = _dummy()
	dummy.pulse_telegraph = 0.0
	dummy.pulse_active = STEP
	assert_eq(dummy.validate(RATE).size(), 1)
	dummy.pulse_active = 2.0 * STEP
	assert_eq(dummy.validate(RATE).size(), 0)


func test_pulse_must_fit_inside_its_interval() -> void:
	var dummy: DummyData = _dummy()
	dummy.pulse_interval = dummy.pulse_telegraph + dummy.pulse_active
	assert_eq(dummy.validate(RATE).size(), 0, "no wait between cycles is legal")
	dummy.pulse_interval -= 0.01
	assert_eq(dummy.validate(RATE).size(), 1)


func test_screen_shake_bounds() -> void:
	var settings: ScreenShakeSettings = _shake()
	assert_eq(settings.validate().size(), 0)
	settings.max_offset_px = 0.0
	assert_eq(settings.validate().size(), 0)
	settings.max_offset_px = -1.0
	assert_eq(settings.validate().size(), 1)
	settings = _shake()
	settings.decay_time = 0.0
	assert_eq(settings.validate().size(), 1)


func _tunables() -> PlayerCombatTunables:
	var tunables: PlayerCombatTunables = PlayerCombatTunables.new()
	tunables.combat_step_rate = RATE
	tunables.player_hurt_iframes = 0.6
	tunables.knockback_duration = 0.12
	tunables.hitstop_normal = 0.05
	tunables.hitstop_finisher = 0.1
	tunables.shake_intensity_hit = 0.2
	tunables.shake_intensity_finisher = 0.5
	tunables.shake_intensity_player_hurt = 0.6
	return tunables


func _dummy() -> DummyData:
	var dummy: DummyData = DummyData.new()
	dummy.max_hp = 200
	dummy.hurtbox_radius_tiles = 0.5
	dummy.respawn_delay = 1.0
	dummy.pulse_interval = 2.0
	dummy.pulse_telegraph = 0.6
	dummy.pulse_active = 0.1
	dummy.pulse_radius_tiles = 2.5
	dummy.pulse_damage = 20
	dummy.pulse_knockback_tiles = 1.0
	return dummy


func _shake() -> ScreenShakeSettings:
	var settings: ScreenShakeSettings = ScreenShakeSettings.new()
	settings.screen_shake_enabled = true
	settings.max_offset_px = 6.0
	settings.decay_time = 0.2
	return settings
