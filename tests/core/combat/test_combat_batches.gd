extends GutTest
## AC14, AC17, AC28 and C16: applying a contact's candidates one at a time.

const RATES: Array[int] = [30, 60, 120]
const TIME: float = 0.000001
const STEP: float = 1.0 / 120.0


func test_ac14_dash_i_frames_block_damage_knockback_and_hitstop() -> void:
	var arena: CombatArena = CombatArena.new()
	arena.dummy_data = _long_pulse()
	arena.build(Vector2.ZERO)
	arena.dummy.set_pulse_enabled(true)
	arena.play(120, 0, 3, [], [0], {}, Vector2.RIGHT)
	var state: CombatState = arena.player.get_combat_state()
	assert_true(arena.player.is_dash_protected(), "0.1 is inside 0.11")
	assert_eq(state.get_hp(), 100)
	assert_false(state.is_in_hitstop())
	assert_false(state.has_knockback())
	assert_false(state.is_hurt_protected())
	assert_eq(arena.player.get_state(), PlayerMotor.State.DASHING)


func test_c8_a_skipped_hurtbox_is_not_marked_and_is_hit_when_the_i_frames_end() -> void:
	for rate: int in RATES:
		var arena: CombatArena = CombatArena.new()
		arena.dummy_data = _long_pulse()
		arena.build(Vector2.ZERO)
		arena.dummy.set_pulse_enabled(true)
		arena.play(rate, 0, 6, [], [0], {}, Vector2.RIGHT)
		assert_eq(arena.hurt_times.size(), 1, "%d Hz" % rate)
		assert_eq(arena.player.get_state(), PlayerMotor.State.IDLE, "zero knockback ended it")


func test_ac28_two_hitboxes_on_one_player_land_once_and_the_second_stays_unmarked() -> void:
	for rate: int in RATES:
		var arena: CombatArena = _two_pulses()
		arena.play(rate, 0, 3)
		assert_eq(arena.hurt_times.size(), 1, "%d Hz, one hit at one instant" % rate)
		assert_eq(arena.player.get_combat_state().get_hp(), 80)
		assert_false(arena.other.get_live_hitbox().has_hit(PlayerMotor.DEFAULT_COMBAT_ID))


func test_ac14_ac28_the_second_hitbox_lands_at_the_first_contact_at_t_plus_065() -> void:
	for rate: int in RATES:
		var arena: CombatArena = _two_pulses()
		arena.play(rate, 0, 24)
		assert_eq(arena.hurt_times.size(), 2, "%d Hz" % rate)
		var first: float = arena.hurt_times[0]
		assert_almost_eq(first, STEP, TIME)
		assert_almost_eq(arena.hurt_times[1], first + 0.65, TIME, "%d Hz" % rate)


func test_ac28_two_hitboxes_on_one_dummy_both_land() -> void:
	var arena: CombatArena = CombatArena.new().build(Vector2(0, 1))
	var extra: PlayerMotor = PlayerMotor.new()
	extra.setup(arena.class_data, arena.rules, Vector2.ZERO, Vector2.DOWN, &"player_2")
	arena.sim.register(extra)
	extra.submit(AttackCommand.new())
	arena.play(120, 0, 3, [0])
	assert_eq(arena.dummy.get_combat_state().get_hp(), 180)


func test_ac28_if_the_first_hit_kos_the_dummy_the_second_does_not_land() -> void:
	var arena: CombatArena = CombatArena.new()
	arena.dummy_data = CombatArena.dummy_values()
	arena.dummy_data.max_hp = 5
	arena.build(Vector2(0, 1))
	var extra: PlayerMotor = PlayerMotor.new()
	extra.setup(arena.class_data, arena.rules, Vector2.ZERO, Vector2.DOWN, &"player_2")
	arena.sim.register(extra)
	extra.submit(AttackCommand.new())
	arena.play(120, 0, 3, [0])
	assert_eq(arena.hit_times.size(), 1)
	assert_true(arena.dummy.is_ko())
	assert_false(extra.get_combat_state().is_in_hitstop(), "the second hit never landed")
	assert_false(extra.get_live_hitbox() == null, "and it marked nothing")
	assert_false(extra.get_live_hitbox().has_hit(&"dummy_anchored"))


func test_ac28_sword_and_pulse_trade_in_either_registration_order() -> void:
	for player_first: bool in [true, false]:
		var arena: CombatArena = CombatArena.new()
		arena.class_data = CombatArena.warrior()
		arena.class_data.attack_chain[0].windup = 2.0 * STEP
		arena.class_data.attack_chain[0].active = 0.2
		arena.dummy_data = _long_pulse()
		arena.dummy_data.pulse_telegraph = 2.0 * STEP
		arena.dummy_data.pulse_active = 0.2
		arena.build(Vector2(0, 1), null, player_first)
		arena.dummy.set_pulse_enabled(true)
		arena.play(120, 0, 2, [0])
		assert_eq(arena.hit_times.size(), 1, "the sword landed, first=%s" % player_first)
		assert_eq(arena.hurt_times.size(), 1, "the pulse landed, first=%s" % player_first)
		assert_eq(arena.hit_times[0], arena.hurt_times[0], "at one instant")
		assert_eq(arena.dummy.get_combat_state().get_hp(), 190)
		assert_eq(arena.player.get_combat_state().get_hp(), 80)


func test_c16_a_ko_earlier_in_the_batch_does_not_cancel_the_pulse_it_already_threw() -> void:
	for player_first: bool in [true, false]:
		var arena: CombatArena = CombatArena.new()
		arena.class_data = CombatArena.warrior()
		arena.class_data.attack_chain[0].windup = 2.0 * STEP
		arena.dummy_data = _long_pulse()
		arena.dummy_data.max_hp = 5
		arena.dummy_data.pulse_telegraph = 2.0 * STEP
		arena.build(Vector2(0, 1), null, player_first)
		arena.dummy.set_pulse_enabled(true)
		arena.play(120, 0, 2, [0])
		assert_true(arena.dummy.is_ko())
		assert_eq(arena.player.get_combat_state().get_hp(), 80, "first=%s" % player_first)


func test_ac17_the_pulse_never_hits_the_dummies() -> void:
	var arena: CombatArena = CombatArena.new()
	arena.dummy_data = _long_pulse()
	arena.build(Vector2(0, 40), Vector2(0, 40.5))
	arena.dummy.set_pulse_enabled(true)
	arena.play(120, 0, 3)
	assert_eq(arena.other.get_combat_state().get_hp(), 200)


func test_ac17_the_sword_never_hits_the_player() -> void:
	var arena: CombatArena = CombatArena.new().build(Vector2(0, 40))
	arena.play(120, 0, 15, [0])
	assert_eq(arena.player.get_combat_state().get_hp(), 100)


func test_ac27_second_knockback_on_a_loose_dummy_replaces_the_first() -> void:
	var arena: CombatArena = CombatArena.new()
	arena.dummy_scale = 1.0
	arena.class_data = CombatArena.warrior()
	arena.class_data.attack_chain[0].knockback_tiles = 1.0
	arena.class_data.attack_chain[0].windup = STEP
	arena.class_data.attack_chain[0].range_tiles = 10.0
	arena.class_data.attack_chain[1].knockback_tiles = 1.0
	arena.class_data.attack_chain[1].range_tiles = 10.0
	arena.rules = CombatArena.MotorHarness.rules()
	arena.rules.hitstop_normal = 0.0
	arena.build(Vector2(0, 1))
	var start: float = arena.dummy.get_position_px().y
	# Both land while the first knockback is running: the second replaces what's left.
	arena.player.submit(AttackCommand.new())
	arena.play(120, 0, 2)
	arena.dummy.apply_hit(arena.events[0], arena.rules)
	arena.play(120, 2, 12)
	var travelled: float = Units.px_to_tiles(arena.dummy.get_position_px().y - start)
	assert_lt(travelled, 2.0)
	assert_gt(travelled, 1.0)


func _two_pulses() -> CombatArena:
	var arena: CombatArena = CombatArena.new()
	arena.dummy_data = _long_pulse()
	arena.dummy_data.pulse_telegraph = STEP
	arena.dummy_data.pulse_active = 3.0
	arena.dummy_data.pulse_interval = 4.0
	arena.build(Vector2(0, 1), Vector2(0, -1))
	arena.dummy.set_pulse_enabled(true)
	arena.other.set_pulse_enabled(true)
	return arena


func _long_pulse() -> DummyData:
	var data: DummyData = CombatArena.dummy_values()
	data.pulse_telegraph = 0.0
	data.pulse_active = 1.0
	data.pulse_radius_tiles = 20.0
	data.pulse_knockback_tiles = 0.0
	return data
