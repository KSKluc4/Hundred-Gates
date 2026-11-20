class_name WaveMarkers
extends Node2D
## F-014/C12: a ring on the floor at each arrival that is about to happen, the size of the body
## that will stand there, filling up as the warning runs out. Presentation only (G6): nothing in
## core reads it, it has no body and no collision, and it keeps nothing of its own: every list
## is made from the director on the call, so a restore or a rebuilt room can't leave a marker
## behind. The look is a placeholder (→ Art & Game Feel).

## A cool blue-green: the enemy telegraphs are orange, red and pink, and the floor is grey.
@export var ring_color: Color = Color(0.35, 0.85, 1.0, 0.95)
@export var fill_color: Color = Color(0.35, 0.85, 1.0, 0.4)
@export var line_width_px: float = 1.5
@export var circle_points: int = 24

var _waves: RoomWaves = null
# Combat id -> body radius in tiles, of each reserve enemy. Read once, from the data.
var _radii_tiles: Dictionary = {}
# What the last _draw() drew, so a test can see a draw pass it can't see.
var _drawn: Array[Dictionary] = []


func _init() -> void:
	z_index = -1  # Under the enemies and the player, which stand at 0.


## Before the node enters the tree. `radii_tiles` maps each reserve enemy's combat id to the radius
## of its hurtbox, so this node never reaches into the sim.
func setup(waves: RoomWaves, radii_tiles: Dictionary) -> void:
	_waves = waves
	_radii_tiles = radii_tiles


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	_drawn = get_markers()
	for marker: Dictionary in _drawn:
		var centre: Vector2 = marker["position_px"]
		var radius: float = marker["radius_px"]
		var fill: float = marker["fill"]
		if fill > 0.0:
			draw_circle(centre, radius * fill, fill_color)
		draw_arc(centre, radius, 0.0, TAU, circle_points, ring_color, line_width_px)


## What is drawn right now, one entry per arrival whose warning is running, in the director's
## order: `enemy_id`, `position_px` (the arrival point's centre), `radius_px` (the arriving
## enemy's body) and `fill`, from 0 as the warning starts to 1 as it ends; a warning of 0 is
## full from the start. Made from the director on every call.
func get_markers() -> Array[Dictionary]:
	var markers: Array[Dictionary] = []
	if _waves == null:
		return markers
	for entry: RoomWaves.Pending in _waves.get_pending():
		(
			markers
			. append(
				{
					"enemy_id": entry.enemy_id,
					"position_px": Units.vector_tiles_to_px(entry.point),
					"radius_px": Units.tiles_to_px(float(_radii_tiles.get(entry.enemy_id, 0.0))),
					"fill": _fill_of(entry),
				}
			)
		)
	return markers


## What the last draw pass drew: get_markers() as it was then. Empty before any.
func get_last_drawn() -> Array[Dictionary]:
	return _drawn


func _fill_of(entry: RoomWaves.Pending) -> float:
	if entry.total <= 0.0:
		return 1.0
	return clampf(1.0 - entry.time_left / entry.total, 0.0, 1.0)
