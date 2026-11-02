extends GutTest
## AC9: exact circle-sector intersection.

const ORIGIN: Vector2 = Vector2.ZERO
const RANGE: float = 2.0
const ARC: float = 90.0
const RADIUS: float = 0.5


func test_ac9_circle_fully_inside_the_sector_hits() -> void:
	assert_true(_hits(Vector2(1, 0)))


func test_ac9_center_outside_the_arc_with_its_edge_across_the_boundary_hits() -> void:
	# The boundary ray at +45 deg. 50 deg is outside the arc, but only 0.09 tiles from it.
	assert_true(_hits(Vector2.RIGHT.rotated(deg_to_rad(50.0)) * 1.5))


func test_center_outside_the_arc_and_too_far_from_the_boundary_misses() -> void:
	assert_false(_hits(Vector2.RIGHT.rotated(deg_to_rad(90.0)) * 1.5))


func test_ac9_circle_just_beyond_range_plus_radius_misses() -> void:
	assert_false(_hits(Vector2(RANGE + RADIUS + 0.001, 0)))


func test_circle_just_within_range_plus_radius_hits() -> void:
	assert_true(_hits(Vector2(RANGE + RADIUS - 0.001, 0)))


func test_ac9_circle_behind_the_attacker_misses() -> void:
	assert_false(_hits(Vector2(-1.5, 0)))


func test_ac9_full_circle_reaches_every_direction() -> void:
	for angle: float in [0.0, 90.0, 180.0, 270.0]:
		var center: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(angle)) * 2.4
		assert_true(_hits(center, 360.0), "%s deg" % angle)
		assert_false(_hits(center * 1.1, 360.0), "%s deg, too far" % angle)


func test_circle_over_the_origin_hits_from_behind() -> void:
	assert_true(_hits(Vector2(-0.3, 0)), "a sector contains its own apex")


func test_circle_near_the_end_of_the_boundary_edge_hits() -> void:
	# Past the end of the +45 deg edge, outside the arc: only the edge's end point reaches it.
	var tip: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(45.0)) * RANGE
	assert_true(_hits(tip + Vector2(-0.4, 0.2)))


func test_circle_past_the_end_of_the_boundary_edge_misses() -> void:
	var tip: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(45.0)) * RANGE
	assert_false(_hits(tip + Vector2(0.0, 0.6)))


func test_wide_arc_beyond_180_degrees() -> void:
	assert_true(_hits(Vector2(0, 1.5), 200.0))
	assert_false(_hits(Vector2(-1.5, 0), 200.0))


func test_direction_is_respected() -> void:
	assert_true(
		Geometry.circle_hits_sector(Vector2(0, 1), RADIUS, ORIGIN, Vector2.DOWN, ARC, RANGE)
	)
	assert_false(Geometry.circle_hits_sector(Vector2(0, 1), RADIUS, ORIGIN, Vector2.UP, ARC, RANGE))


func test_origin_is_respected() -> void:
	var origin: Vector2 = Vector2(10, 10)
	var center: Vector2 = Vector2(11, 10)
	assert_true(Geometry.circle_hits_sector(center, RADIUS, origin, Vector2.RIGHT, ARC, RANGE))


func _hits(center: Vector2, arc: float = ARC) -> bool:
	return Geometry.circle_hits_sector(center, RADIUS, ORIGIN, Vector2.RIGHT, arc, RANGE)
