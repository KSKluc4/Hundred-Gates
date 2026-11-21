class_name PickupMarkers
extends Node2D
## F-016/C20: a placeholder shape at every sword lying in the room, where it lies. Presentation only
## (G6): nothing in core reads it, it has no body and no collision, and it keeps nothing of its own:
## the list is made from the room's loot on the call, so a rebuilt room can't leave a marker behind.
## It reads nothing but `RoomLoot.get_drops()`. The look is a placeholder (→ Art & Game Feel).

## A warm gold: the floor is grey, the telegraphs are orange, red and pink, the arrival rings blue.
@export var marker_color: Color = Color(1.0, 0.85, 0.2, 0.95)
## A boss's sword stands out from a regular drop.
@export var boss_marker_color: Color = Color(0.85, 0.45, 1.0, 0.95)
@export var outline_color: Color = Color(0.1, 0.1, 0.1, 0.9)
@export var marker_size_px: float = 8.0
@export var outline_width_px: float = 1.0

var _loot: RoomLoot = null
# What the last _draw() drew, so a test can see a draw pass it can't see.
var _drawn: Array[Dictionary] = []


func _init() -> void:
	z_index = -1  # Under the enemies and the player, which stand at 0.


## Before the node enters the tree. Null draws nothing.
func setup(loot: RoomLoot) -> void:
	_loot = loot


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	_drawn = get_markers()
	for marker: Dictionary in _drawn:
		var centre: Vector2 = marker["position_px"]
		var size: float = marker["size_px"]
		var area: Rect2 = Rect2(centre - Vector2(size, size) / 2.0, Vector2(size, size))
		draw_rect(area, marker["color"])
		draw_rect(area, outline_color, false, outline_width_px)


## What is drawn right now, one entry per sword lying here, in the order they dropped: `sword_id`,
## `position_px` (where it lies), `size_px`, `color` and `boss` (a boss's sword). Made from the
## room's loot on every call.
func get_markers() -> Array[Dictionary]:
	var markers: Array[Dictionary] = []
	if _loot == null:
		return markers
	for drop: LootDrop in _loot.get_drops():
		var is_boss: bool = drop.boss_floor > 0
		(
			markers
			. append(
				{
					"sword_id": drop.sword_id,
					"position_px": Units.vector_tiles_to_px(drop.position),
					"size_px": marker_size_px,
					"color": boss_marker_color if is_boss else marker_color,
					"boss": is_boss,
				}
			)
		)
	return markers


## What the last draw pass drew: get_markers() as it was then. Empty before any.
func get_last_drawn() -> Array[Dictionary]:
	return _drawn
