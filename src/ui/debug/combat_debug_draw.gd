class_name CombatDebugDraw
extends Node2D
## Draws every hurtbox circle and live hitbox from current state (AC1, F-003/C12). Holds
## nothing, so it can't show a stale arc after a restore. Placeholder look.

const FULL_CIRCLE_DEG: float = 360.0

@export var runner: CombatRunner
@export var hitbox_color: Color = Color(1.0, 0.25, 0.2, 0.45)
@export var hurtbox_color: Color = Color(0.3, 0.9, 0.5, 0.8)
@export var line_width_px: float = 1.0
@export var circle_points: int = 32
@export var arc_points: int = 16


## The outline of a sector, from its origin around the arc. Shared with the enemy telegraph.
static func sector_points(
	origin: Vector2, direction: Vector2, arc_angle_deg: float, radius: float, arc_points: int
) -> PackedVector2Array:
	var half_arc: float = deg_to_rad(arc_angle_deg) * 0.5
	var points: PackedVector2Array = [origin]
	for index: int in arc_points + 1:
		var angle: float = lerpf(-half_arc, half_arc, float(index) / arc_points)
		points.append(origin + direction.rotated(angle) * radius)
	return points


## Call from `canvas`'s own _draw().
static func fill_sector(
	canvas: CanvasItem,
	origin: Vector2,
	direction: Vector2,
	arc_angle_deg: float,
	radius: float,
	color: Color,
	arc_points: int
) -> void:
	if arc_angle_deg >= FULL_CIRCLE_DEG:
		canvas.draw_circle(origin, radius, color)
		return
	var points: PackedVector2Array = sector_points(
		origin, direction, arc_angle_deg, radius, arc_points
	)
	canvas.draw_colored_polygon(points, color)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	for hurtbox: Hurtbox in get_hurtboxes():
		var center: Vector2 = Units.vector_tiles_to_px(hurtbox.position)
		var radius: float = Units.tiles_to_px(hurtbox.radius_tiles)
		draw_arc(center, radius, 0.0, TAU, circle_points, hurtbox_color, line_width_px)
	for hitbox: Hitbox in get_live_hitboxes():
		_draw_hitbox(hitbox)


func get_hurtboxes() -> Array[Hurtbox]:
	var hurtboxes: Array[Hurtbox] = []
	for combatant: Combatant in runner.get_sim().get_combatants():
		hurtboxes.append(combatant.get_hurtbox())
	return hurtboxes


func get_live_hitboxes() -> Array[Hitbox]:
	var hitboxes: Array[Hitbox] = []
	for combatant: Combatant in runner.get_sim().get_combatants():
		var hitbox: Hitbox = combatant.get_live_hitbox()
		if hitbox != null:
			hitboxes.append(hitbox)
	return hitboxes


func _draw_hitbox(hitbox: Hitbox) -> void:
	var origin: Vector2 = Units.vector_tiles_to_px(hitbox.origin)
	var radius: float = Units.tiles_to_px(hitbox.range_tiles)
	fill_sector(
		self, origin, hitbox.direction, hitbox.arc_angle_deg, radius, hitbox_color, arc_points
	)
