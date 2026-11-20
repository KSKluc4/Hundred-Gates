# gdlint:disable=max-public-methods
extends GutTest
## F-012 T1 (AC5): TownGate fires once per entry onto a gate tile and says where to put the
## player back, for a gate on each of the four borders. Firing engages the gate until release()
## (review round 1: C10, CR-1, CR-9).

# The fixture town is 24 x 14. Gate tiles: north (10..13, 0), south (10..13, 13),
# west (0, 5..8), east (23, 5..8).

const INSIDE_NORTH: Vector2 = Vector2(11.5, 0.5)  # on the gate tile (11, 0)

var _gate: TownGate


func before_each() -> void:
	_gate = _gate_on(Vector2i.UP)


# --- check() ---


func test_ac5_check_is_true_once_when_the_position_enters_a_gate_tile() -> void:
	assert_true(_gate.check(INSIDE_NORTH))


func test_ac5_check_is_false_while_the_position_stays_on_the_gate() -> void:
	_gate.check(INSIDE_NORTH)
	assert_false(_gate.check(INSIDE_NORTH))
	assert_false(_gate.check(INSIDE_NORTH))


func test_ac5_check_stays_false_when_moving_between_gate_tiles() -> void:
	_gate.check(Vector2(10.5, 0.5))
	assert_false(_gate.check(Vector2(11.5, 0.5)))
	assert_false(_gate.check(Vector2(13.5, 0.5)))


func test_ac5_check_is_false_off_the_gate() -> void:
	assert_false(_gate.check(Vector2(11.5, 5.5)))
	assert_false(_gate.check(Vector2(11.5, 1.5)), "the tile inward of the gate is not the gate")
	assert_false(_gate.check(Vector2(2.5, 0.5)), "a wall tile on the same border")


func test_ac5_check_is_true_again_after_leaving_and_re_entering() -> void:
	assert_true(_gate.check(INSIDE_NORTH))
	_gate.release()  # C10: the engagement has to end before the latch can see the player leave.
	assert_false(_gate.check(Vector2(11.5, 1.5)))
	assert_true(_gate.check(INSIDE_NORTH))
	assert_false(_gate.check(INSIDE_NORTH))


func test_ac5_check_stays_disarmed_until_the_position_is_off_the_gate() -> void:
	_gate.check(INSIDE_NORTH)
	_gate.release()
	_gate.check(Vector2(13.5, 0.5))
	assert_false(_gate.check(INSIDE_NORTH), "never left the gate tiles")


func test_ac5_a_tile_owns_its_left_and_top_edges() -> void:
	assert_true(_gate.check(Vector2(10.0, 0.0)), "the corner of tile (10, 0)")
	_gate.release()
	_gate.check(Vector2(5.0, 5.0))
	assert_false(_gate.check(Vector2(9.99, 0.5)), "one step short of tile (10, 0)")
	assert_true(_gate.check(Vector2(13.99, 0.99)), "inside tile (13, 0)")
	_gate.release()
	_gate.check(Vector2(5.0, 5.0))
	assert_false(_gate.check(Vector2(14.0, 0.5)), "tile (14, 0) is wall")


func test_ac5_a_position_outside_the_room_is_off_the_gate() -> void:
	_gate.check(INSIDE_NORTH)
	_gate.release()
	assert_false(_gate.check(Vector2(11.5, -0.5)))
	assert_true(_gate.check(INSIDE_NORTH), "outside counts as off the gate and re-arms")


func test_ac5_check_works_on_every_border() -> void:
	var gate_positions: Dictionary = {
		Vector2i.UP: Vector2(12.5, 0.5),
		Vector2i.DOWN: Vector2(12.5, 13.5),
		Vector2i.LEFT: Vector2(0.5, 6.5),
		Vector2i.RIGHT: Vector2(23.5, 6.5),
	}
	for side: Vector2i in gate_positions:
		var gate: TownGate = _gate_on(side)
		assert_true(gate.check(gate_positions[side]), str(side))
		assert_false(gate.check(gate_positions[side]), str(side))
		assert_false(gate.check(Vector2(12.5, 7.5)), "room centre, %s" % str(side))


func test_ac5_setup_arms_the_gate_again() -> void:
	_gate.check(INSIDE_NORTH)
	_gate.setup(TowerFixtures.town_room(&"town", Vector2i.UP))
	assert_true(_gate.check(INSIDE_NORTH))


func test_ac5_a_gate_that_was_never_set_up_never_fires() -> void:
	var gate: TownGate = TownGate.new()
	assert_false(gate.check(INSIDE_NORTH))
	assert_eq(gate.get_return_position_tiles(Vector2(3.5, 4.5)), Vector2(3.5, 4.5))


# --- the engaged gate (C10, CR-1, CR-9) ---


func test_c10_a_new_gate_is_not_engaged() -> void:
	assert_false(_gate.is_engaged())
	assert_eq(_gate.get_hold_position_tiles(), Vector2.ZERO, "nothing held before an engagement")


func test_c10_the_check_that_fires_engages_the_gate_and_only_that_one() -> void:
	assert_false(_gate.check(Vector2(11.5, 5.5)))
	assert_false(_gate.is_engaged(), "a position off the gate engages nothing")
	assert_true(_gate.check(INSIDE_NORTH))
	assert_true(_gate.is_engaged())
	assert_false(_gate.check(INSIDE_NORTH), "the check that did not fire")
	assert_true(_gate.is_engaged(), "still engaged")


func test_c10_a_check_that_stays_false_never_engages_a_disarmed_latch() -> void:
	_gate.check(INSIDE_NORTH)
	_gate.release()
	assert_false(_gate.check(INSIDE_NORTH), "disarmed: still on the gate")
	assert_false(_gate.is_engaged())


func test_c10_the_hold_position_is_the_position_of_the_firing_check() -> void:
	var firing: Vector2 = Vector2(12.37, 0.93)
	assert_true(_gate.check(firing))
	assert_eq(_gate.get_hold_position_tiles(), firing)
	assert_false(_gate.check(Vector2(10.5, 0.5)))
	assert_eq(_gate.get_hold_position_tiles(), firing, "later positions don't move it")
	assert_false(_gate.check(Vector2(11.5, 5.5)))
	assert_eq(_gate.get_hold_position_tiles(), firing)


func test_c10_check_while_engaged_is_false_and_does_not_rearm_the_latch() -> void:
	_gate.check(INSIDE_NORTH)
	assert_false(_gate.check(Vector2(11.5, 5.5)), "off the gate, but engaged")
	assert_false(_gate.check(Vector2(11.5, -3.0)), "outside the room")
	assert_true(_gate.is_engaged())
	_gate.release()
	assert_false(_gate.check(INSIDE_NORTH), "the off-gate positions seen while engaged don't count")
	assert_false(_gate.is_engaged())


func test_c10_release_ends_the_engagement_and_the_latch_stays_disarmed() -> void:
	_gate.check(INSIDE_NORTH)
	_gate.release()
	assert_false(_gate.is_engaged())
	assert_false(_gate.check(INSIDE_NORTH), "still on the gate")
	assert_false(_gate.check(Vector2(13.5, 0.5)), "another gate tile")
	assert_false(_gate.is_engaged())


func test_c10_after_release_the_gate_fires_again_once_the_position_has_been_off_it() -> void:
	_gate.check(INSIDE_NORTH)
	_gate.release()
	assert_false(_gate.check(Vector2(11.5, 1.5)), "off the gate: arms it")
	assert_true(_gate.check(Vector2(12.5, 0.5)))
	assert_true(_gate.is_engaged())
	assert_eq(_gate.get_hold_position_tiles(), Vector2(12.5, 0.5), "the new engagement's position")


func test_c10_release_when_not_engaged_does_nothing() -> void:
	_gate.release()
	assert_false(_gate.is_engaged())
	assert_true(_gate.check(INSIDE_NORTH), "an armed latch stays armed")
	_gate.release()
	_gate.release()
	assert_false(_gate.check(INSIDE_NORTH), "and a disarmed one stays disarmed")


func test_c10_release_keeps_the_last_hold_position() -> void:
	_gate.check(INSIDE_NORTH)
	_gate.release()
	assert_eq(_gate.get_hold_position_tiles(), INSIDE_NORTH)


func test_c10_setup_resets_the_engagement_and_the_hold_position() -> void:
	_gate.check(INSIDE_NORTH)
	_gate.setup(TowerFixtures.town_room(&"town", Vector2i.UP))
	assert_false(_gate.is_engaged())
	assert_eq(_gate.get_hold_position_tiles(), Vector2.ZERO)
	assert_true(_gate.check(INSIDE_NORTH), "and the latch is armed")


func test_c10_every_border_engages_and_releases() -> void:
	for side: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var gate: TownGate = _gate_on(side)
		var on_gate: Vector2 = Vector2(TowerFixtures.gate_tiles(side)[2]) + Vector2(0.5, 0.5)
		assert_true(gate.check(on_gate), str(side))
		assert_true(gate.is_engaged(), str(side))
		assert_eq(gate.get_hold_position_tiles(), on_gate, str(side))
		gate.release()
		assert_false(gate.is_engaged(), str(side))


func test_c10_a_gate_that_was_never_set_up_never_engages() -> void:
	var gate: TownGate = TownGate.new()
	assert_false(gate.check(INSIDE_NORTH))
	assert_false(gate.is_engaged())
	gate.release()
	assert_false(gate.is_engaged())


# --- get_return_position_tiles() ---


func test_ac5_return_position_north_is_one_tile_south_of_the_gate() -> void:
	assert_eq(_gate.get_return_position_tiles(Vector2(11.5, 0.5)), Vector2(11.5, 1.5))
	assert_eq(_gate.get_return_position_tiles(Vector2(13.5, 0.5)), Vector2(13.5, 1.5))


func test_ac5_return_position_south_is_one_tile_north_of_the_gate() -> void:
	var gate: TownGate = _gate_on(Vector2i.DOWN)
	assert_eq(gate.get_return_position_tiles(Vector2(11.5, 13.5)), Vector2(11.5, 12.5))
	assert_eq(gate.get_return_position_tiles(Vector2(10.5, 13.5)), Vector2(10.5, 12.5))


func test_ac5_return_position_west_is_one_tile_east_of_the_gate() -> void:
	var gate: TownGate = _gate_on(Vector2i.LEFT)
	assert_eq(gate.get_return_position_tiles(Vector2(0.5, 5.5)), Vector2(1.5, 5.5))
	assert_eq(gate.get_return_position_tiles(Vector2(0.5, 8.5)), Vector2(1.5, 8.5))


func test_ac5_return_position_east_is_one_tile_west_of_the_gate() -> void:
	var gate: TownGate = _gate_on(Vector2i.RIGHT)
	assert_eq(gate.get_return_position_tiles(Vector2(23.5, 6.5)), Vector2(22.5, 6.5))
	assert_eq(gate.get_return_position_tiles(Vector2(23.5, 7.5)), Vector2(22.5, 7.5))


func test_ac5_return_position_follows_the_nearest_gate_tile() -> void:
	assert_eq(_gate.get_return_position_tiles(Vector2(12.2, 4.0)), Vector2(12.5, 1.5))
	assert_eq(_gate.get_return_position_tiles(Vector2(3.0, 9.0)), Vector2(10.5, 1.5), "far left")
	assert_eq(_gate.get_return_position_tiles(Vector2(20.0, 9.0)), Vector2(13.5, 1.5), "far right")


func test_ac5_return_position_breaks_a_tie_towards_the_first_tile_row_major() -> void:
	# x = 12.0 is exactly between the centres of (11, 0) and (12, 0).
	assert_eq(_gate.get_return_position_tiles(Vector2(12.0, 0.5)), Vector2(11.5, 1.5))
	var west: TownGate = _gate_on(Vector2i.LEFT)
	# y = 7.0 is exactly between (0, 6) and (0, 7).
	assert_eq(west.get_return_position_tiles(Vector2(0.5, 7.0)), Vector2(1.5, 6.5))


func test_ac5_the_return_position_is_a_walkable_tile_of_the_room() -> void:
	for side: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var room: RoomData = TowerFixtures.town_room(&"town", side)
		var gate: TownGate = TownGate.new()
		gate.setup(room)
		for tile: Vector2i in room.get_exit_tiles():
			var back: Vector2 = gate.get_return_position_tiles(Vector2(tile) + Vector2(0.5, 0.5))
			assert_true(room.is_walkable(Vector2i(floori(back.x), floori(back.y))), str(side))


func test_ac5_putting_the_player_back_does_not_trigger_the_gate_again() -> void:
	for side: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var gate: TownGate = _gate_on(side)
		var tile: Vector2i = TowerFixtures.gate_tiles(side)[1]
		var on_gate: Vector2 = Vector2(tile) + Vector2(0.5, 0.5)
		assert_true(gate.check(on_gate), str(side))
		gate.release()
		assert_false(gate.check(gate.get_return_position_tiles(on_gate)), str(side))
		assert_true(gate.check(on_gate), "walking back in opens it again, %s" % str(side))


func _gate_on(side: Vector2i) -> TownGate:
	var gate: TownGate = TownGate.new()
	gate.setup(TowerFixtures.town_room(&"town", side))
	return gate
