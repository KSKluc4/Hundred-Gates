class_name Geometry
extends RefCounted
## Exact shape tests for hits (F-003 §3). No state. Tiles.


## True iff the circle touches the sector. A sector with a 360 degree arc is a full circle.
static func circle_hits_sector(
	center: Vector2,
	radius: float,
	origin: Vector2,
	direction: Vector2,
	arc_angle_deg: float,
	range_tiles: float
) -> bool:
	var to_center: Vector2 = center - origin
	var distance: float = to_center.length()
	if distance <= radius:
		return true  # The circle covers the apex, whichever way the sector points.
	if distance > range_tiles + radius:
		return false
	var half_arc: float = deg_to_rad(arc_angle_deg) * 0.5
	if absf(direction.angle_to(to_center)) <= half_arc:
		return true
	# Outside the arc, the sector's nearest point is on one of its two straight edges. The
	# ends of those edges cover the rim, because the center's angle is past both of them.
	return (
		_within_edge(center, radius, origin, direction.rotated(half_arc) * range_tiles)
		or _within_edge(center, radius, origin, direction.rotated(-half_arc) * range_tiles)
	)


static func _within_edge(center: Vector2, radius: float, origin: Vector2, edge: Vector2) -> bool:
	var along: float = clampf((center - origin).dot(edge) / edge.length_squared(), 0.0, 1.0)
	return center.distance_to(origin + edge * along) <= radius
