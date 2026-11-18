extends GutTest
## F-011 T4 (AC12): CombatState.heal() and set_hp().

const Harness: GDScript = preload("res://tests/core/player/motor_harness.gd")

var _state: CombatState


func before_each() -> void:
	_state = CombatState.new()
	_state.setup(100, true)


func test_ac12_heal_below_the_cap_adds_it_all() -> void:
	_state.set_hp(50)
	assert_eq(_state.heal(30), 30)
	assert_eq(_state.get_hp(), 80)


func test_ac12_heal_is_capped_at_max_hp_and_returns_what_was_healed() -> void:
	_state.set_hp(90)
	assert_eq(_state.heal(30), 10)
	assert_eq(_state.get_hp(), 100)


func test_ac12_heal_at_full_hp_does_nothing() -> void:
	assert_eq(_state.heal(30), 0)
	assert_eq(_state.get_hp(), 100)


func test_ac12_heal_never_revives() -> void:
	_state.set_hp(0)
	assert_eq(_state.heal(30), 0)
	assert_eq(_state.get_hp(), 0)


func test_ac12_heal_after_a_killing_hit_stays_dead() -> void:
	var event: HitEvent = HitEvent.new()
	event.damage = 500
	event.direction = Vector2.DOWN
	_state.apply_hit(event, Harness.rules())
	assert_eq(_state.heal(30), 0)
	assert_eq(_state.get_hp(), 0)


func test_ac12_negative_or_zero_amount_does_nothing() -> void:
	_state.set_hp(50)
	assert_eq(_state.heal(-10), 0)
	assert_eq(_state.heal(0), 0)
	assert_eq(_state.get_hp(), 50)


func test_ac12_heal_fires_no_signal() -> void:
	_state.set_hp(50)
	watch_signals(_state)
	_state.heal(30)
	assert_signal_not_emitted(_state, "damaged")
	assert_signal_not_emitted(_state, "died")


func test_set_hp_clamps_to_zero_and_max() -> void:
	_state.set_hp(-5)
	assert_eq(_state.get_hp(), 0)
	_state.set_hp(250)
	assert_eq(_state.get_hp(), 100)
	_state.set_hp(42)
	assert_eq(_state.get_hp(), 42)


func test_set_hp_to_zero_fires_no_died() -> void:
	watch_signals(_state)
	_state.set_hp(0)
	assert_signal_not_emitted(_state, "died")
