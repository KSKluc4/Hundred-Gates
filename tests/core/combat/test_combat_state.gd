extends GutTest
## F-003 T7: HP, hitstop, knockback and hurt i-frames, shared by player and dummy.

const Harness: GDScript = preload("res://tests/core/player/motor_harness.gd")

var _state: CombatState
var _rules: PlayerCombatTunables


func before_each() -> void:
	_rules = Harness.rules()
	_state = _with_hurt_iframes(true)


func test_setup_starts_full_with_nothing_running() -> void:
	assert_eq(_state.get_hp(), 100)
	assert_false(_state.is_in_hitstop())
	assert_false(_state.is_hurt_protected())
	assert_false(_state.has_knockback())


func test_ac11_order_is_visible_when_damaged_fires() -> void:
	var seen: Array[Dictionary] = []
	_state.damaged.connect(_record_order.bind(seen))
	_state.apply_hit(_event(10, 1.0), _rules)
	assert_eq_deep(
		seen, [{"hp": 90, "knockback": true, "hitstop": true, "iframes": true}] as Array[Dictionary]
	)


func test_ac11_hp_stops_at_zero() -> void:
	_state.apply_hit(_event(500), _rules)
	assert_eq(_state.get_hp(), 0)


func test_ac16_died_fires_once_per_drop_to_zero() -> void:
	watch_signals(_state)
	_state.apply_hit(_event(500), _rules)
	_state.apply_hit(_event(500), _rules)
	assert_signal_emit_count(_state, "died", 1)
	_state.refill()
	assert_eq(_state.get_hp(), 100)
	_state.apply_hit(_event(500), _rules)
	assert_signal_emit_count(_state, "died", 2)


func test_ac11_damaged_carries_the_event() -> void:
	watch_signals(_state)
	var event: HitEvent = _event(10)
	_state.apply_hit(event, _rules)
	assert_signal_emitted_with_parameters(_state, "damaged", [event])


func test_ac11_hit_landed_fires_on_the_attacker() -> void:
	watch_signals(_state)
	var event: HitEvent = _event(10)
	_state.apply_landed(event, _rules)
	assert_signal_emitted_with_parameters(_state, "hit_landed", [event])
	assert_eq(_state.get_hp(), 100, "the attacker takes no damage")


func test_ac13_normal_and_finisher_hitstop_values() -> void:
	_state.apply_landed(_event(10), _rules)
	assert_eq(_state.get_hitstop_remaining(), _rules.hitstop_normal)
	var other: CombatState = _with_hurt_iframes(false)
	var finisher: HitEvent = _event(10)
	finisher.is_finisher = true
	other.apply_hit(finisher, _rules)
	assert_eq(other.get_hitstop_remaining(), _rules.hitstop_finisher)


func test_c7_hitstop_takes_the_larger_and_never_adds() -> void:
	var finisher: HitEvent = _event(10)
	finisher.is_finisher = true
	_state.apply_landed(finisher, _rules)
	_state.apply_landed(_event(10), _rules)
	assert_eq(_state.get_hitstop_remaining(), _rules.hitstop_finisher)
	_state.consume_hitstop(0.08)
	_state.apply_landed(_event(10), _rules)
	assert_almost_eq(_state.get_hitstop_remaining(), _rules.hitstop_normal, 0.000001)


func test_consume_hitstop_returns_the_time_left_in_the_step() -> void:
	_state.apply_landed(_event(10), _rules)
	assert_eq(_state.consume_hitstop(0.02), 0.0)
	assert_almost_eq(_state.consume_hitstop(0.05), 0.02, 0.000001, "overshoot is carried")
	assert_false(_state.is_in_hitstop())
	assert_eq(_state.consume_hitstop(0.01), 0.01)


func test_ac12_knockback_runs_at_constant_speed_over_its_duration() -> void:
	_state.apply_hit(_event(10, 1.2), _rules)
	assert_almost_eq(_state.get_knockback_time_left(), _rules.knockback_duration, 0.000001)
	assert_almost_eq(
		_state.get_knockback_velocity(),
		Vector2.DOWN * 1.2 / _rules.knockback_duration,
		Vector2(0.0001, 0.0001)
	)
	_state.advance_knockback(_rules.knockback_duration / 2.0)
	assert_almost_eq(_state.get_knockback_time_left(), _rules.knockback_duration / 2.0, 0.000001)
	_state.advance_knockback(_rules.knockback_duration / 2.0)
	assert_false(_state.has_knockback())


func test_c17_a_new_knockback_replaces_the_remaining_one() -> void:
	var state: CombatState = _with_hurt_iframes(false)
	state.apply_hit(_event(10, 1.2), _rules)
	state.advance_knockback(0.06)
	state.apply_hit(_event(10, 0.3), _rules)
	assert_almost_eq(state.get_knockback_time_left(), _rules.knockback_duration, 0.000001)
	assert_almost_eq(
		state.get_knockback_velocity().length(), 0.3 / _rules.knockback_duration, 0.0001
	)


func test_c17_zero_knockback_has_no_knockback_and_clears_a_running_one() -> void:
	var state: CombatState = _with_hurt_iframes(false)
	state.apply_hit(_event(10, 1.2), _rules)
	state.apply_hit(_event(10, 0.0), _rules)
	assert_false(state.has_knockback())


func test_ac14_hurt_iframes_count_down_only_when_advanced() -> void:
	_state.apply_hit(_event(10), _rules)
	assert_true(_state.is_hurt_protected())
	_state.consume_hitstop(_rules.hitstop_normal)
	assert_eq(_state.get_hurt_iframes_remaining(), _rules.player_hurt_iframes, "hitstop pauses")
	_state.advance_hurt_iframes(_rules.player_hurt_iframes)
	assert_false(_state.is_hurt_protected())


func test_ac11_no_hurt_iframes_on_a_target_that_has_none() -> void:
	var dummy: CombatState = _with_hurt_iframes(false)
	dummy.apply_hit(_event(10), _rules)
	assert_false(dummy.is_hurt_protected())


func test_c18_lowering_max_hp_clamps_and_raising_does_not_heal() -> void:
	_state.set_max_hp(60)
	assert_eq(_state.get_hp(), 60)
	_state.set_max_hp(150)
	assert_eq(_state.get_hp(), 60)
	_state.refill()
	assert_eq(_state.get_hp(), 150)


func test_c5_round_trip_loses_nothing() -> void:
	_state.apply_hit(_event(10, 1.2), _rules)
	_state.consume_hitstop(0.02)
	var restored: CombatState = _with_hurt_iframes(true)
	restored.from_dict(_state.to_dict())
	assert_eq_deep(restored.to_dict(), _state.to_dict())


## A bound method, not a lambda: a lambda holding _state on its own signal would never free.
func _record_order(_event_seen: HitEvent, seen: Array[Dictionary]) -> void:
	(
		seen
		. append(
			{
				"hp": _state.get_hp(),
				"knockback": _state.has_knockback(),
				"hitstop": _state.is_in_hitstop(),
				"iframes": _state.is_hurt_protected(),
			}
		)
	)


func _with_hurt_iframes(has_them: bool) -> CombatState:
	var state: CombatState = CombatState.new()
	state.setup(100, has_them)
	return state


func _event(damage: int, knockback: float = 0.0) -> HitEvent:
	var event: HitEvent = HitEvent.new()
	event.attacker_id = &"a"
	event.target_id = &"t"
	event.damage = damage
	event.direction = Vector2.DOWN
	event.knockback_tiles = knockback
	return event
