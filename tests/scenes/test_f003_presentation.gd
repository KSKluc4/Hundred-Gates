extends GutTest
## AC18-AC21 presentation, on real nodes: dummy view, damage numbers, placeholder shake.

const DUMMY_SCENE: PackedScene = preload("res://src/entities/dummy/training_dummy.tscn")

var _dummy: TrainingDummy


func before_each() -> void:
	_dummy = DUMMY_SCENE.instantiate()
	add_child_autofree(_dummy)


func test_c14_body_blocks_nothing_and_is_stopped_by_the_world() -> void:
	assert_eq(_dummy.collision_layer, 0)
	assert_eq(_dummy.collision_mask, 1)


func test_ac20_each_dummy_shows_hp_as_a_number_and_a_bar() -> void:
	_hit(50)
	_dummy.refresh_view()
	assert_eq(_dummy.get_hp_text(), "150 / 200")
	assert_almost_eq(_dummy.get_hp_fraction(), 0.75, 0.0001)


func test_ac18_ko_shows_while_it_lasts() -> void:
	assert_false(_dummy.is_ko_visible())
	_hit(500)
	_dummy.refresh_view()
	assert_true(_dummy.is_ko_visible())


func test_ac19_telegraph_ring_shows_only_during_telegraph() -> void:
	_dummy.pulses = true
	assert_false(_dummy.is_ring_visible())
	_dummy.set_pulse_on(true)
	assert_true(_dummy.is_ring_visible())
	for _i: int in 78:
		_dummy.logic.step(1.0 / 120.0)
	assert_eq(_dummy.logic.get_pulse_phase(), PulseCycle.Phase.ACTIVE)
	assert_false(_dummy.is_ring_visible())


func test_ac19_a_dummy_that_does_not_pulse_ignores_the_toggle() -> void:
	_dummy.pulses = false
	_dummy.set_pulse_on(true)
	assert_eq(_dummy.logic.get_pulse_phase(), PulseCycle.Phase.OFF)
	assert_false(_dummy.logic.is_pulse_enabled())


func test_ac20_every_damaged_spawns_one_number_with_the_damage() -> void:
	_hit(10)
	_hit(22)
	var numbers: Array[Label] = _dummy.get_damage_numbers().get_labels()
	assert_eq(numbers.size(), 2)
	assert_eq(numbers[0].text, "10")
	assert_eq(numbers[1].text, "22")


func test_ac20_finisher_numbers_are_visibly_larger() -> void:
	_hit(10)
	_hit(22, true)
	var numbers: Array[Label] = _dummy.get_damage_numbers().get_labels()
	assert_gt(_font_size(numbers[1]), _font_size(numbers[0]))


func test_ac20_a_number_floats_up_and_goes_away() -> void:
	var numbers: DamageNumbers = _dummy.get_damage_numbers()
	_hit(10)
	var label: Label = numbers.get_labels()[0]
	var start_y: float = label.position.y
	numbers._process(numbers.lifetime / 2.0)
	assert_lt(label.position.y, start_y)
	numbers._process(numbers.lifetime)
	assert_eq(numbers.get_labels().size(), 0)


func test_c19_numbers_are_transient_and_a_restore_clears_them() -> void:
	var snapshot: Dictionary = _dummy.logic.to_dict()
	_hit(10)
	_dummy.logic.from_dict(snapshot)
	assert_eq(_dummy.get_damage_numbers().get_labels().size(), 0)
	assert_eq(_dummy.get_hp_text(), "200 / 200", "the view re-synced")


func test_c20_reset_restores_everything_but_the_pulse_toggle() -> void:
	_dummy.pulses = true
	_dummy.position = Vector2(40, 8)
	_dummy.set_pulse_on(true)
	_hit(500)
	_dummy.global_position = Vector2(100, 100)
	_dummy.reset_to_start()
	assert_eq(_dummy.logic.get_combat_state().get_hp(), 200)
	assert_false(_dummy.logic.is_ko())
	assert_true(_dummy.logic.is_pulse_enabled(), "the toggle survives")
	assert_eq(_dummy.logic.get_pulse_phase(), PulseCycle.Phase.TELEGRAPH, "and restarts")
	assert_eq(_dummy.get_damage_numbers().get_labels().size(), 0)
	assert_false(_dummy.is_ko_visible())


func _hit(damage: int, finisher: bool = false) -> void:
	var event: HitEvent = HitEvent.new()
	event.attacker_id = &"player_1"
	event.target_id = _dummy.combat_id
	event.damage = damage
	event.is_finisher = finisher
	event.direction = Vector2.DOWN
	_dummy.logic.apply_hit(event, Tunables.player_combat)


func _font_size(label: Label) -> int:
	return label.get_theme_font_size("font_size")
