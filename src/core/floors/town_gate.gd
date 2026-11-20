class_name TownGate
extends RefCounted
## The tower gate of a town room: the room's `E` tiles (F-012/C8, C10). It decides from the
## player's logic position, never from physics (G6). `check()` is a latch: it fires once per
## entry and arms again only after the position has been off the gate tiles. Firing also engages
## the gate (F-012/C10, review round 1: CR-1, CR-9): the state of "the player is at the gate and
## held there" lives here, not in the UI. It lasts until release().

var _gate_tiles: Array[Vector2i] = []
var _room_size: Vector2i = Vector2i.ZERO
var _armed: bool = true
var _engaged: bool = false
var _hold_position_tiles: Vector2 = Vector2.ZERO


## Gate tiles = the room's exit tiles, row-major. Arms the latch.
func setup(room: RoomData) -> void:
	_gate_tiles = room.get_exit_tiles()
	_room_size = room.get_size()
	_armed = true
	_engaged = false
	_hold_position_tiles = Vector2.ZERO


## True once when the position is on a gate tile and the latch is armed; then it disarms and the
## gate engages, holding `player_position_tiles`. A position off the gate tiles arms it again.
## F-012/C10: while the gate is engaged this is false and changes nothing, whatever the position:
## only release() ends an engagement.
func check(player_position_tiles: Vector2) -> bool:
	if _engaged:
		return false
	if not _gate_tiles.has(_tile_of(player_position_tiles)):
		_armed = true
		return false
	if not _armed:
		return false
	_armed = false
	_engaged = true
	_hold_position_tiles = player_position_tiles
	return true


## F-012/C10: true from the check() that fired until release() (or setup()).
func is_engaged() -> bool:
	return _engaged


## F-012/C10: the position the player had when the gate engaged, to hold them on while it is
## engaged. After release() it stays at the last engagement; Vector2.ZERO before the first.
func get_hold_position_tiles() -> Vector2:
	return _hold_position_tiles


## F-012/C10: ends the engagement. The latch stays disarmed: check() fires again only after it
## has seen a position off the gate tiles. Does nothing when the gate isn't engaged.
func release() -> void:
	_engaged = false


## C10: the centre of the tile one step into the room from the gate tile whose centre is
## nearest `player_position_tiles` (ties: first in row-major order). The position itself when
## there is no gate.
func get_return_position_tiles(player_position_tiles: Vector2) -> Vector2:
	if _gate_tiles.is_empty():
		return player_position_tiles
	var nearest: Vector2i = _gate_tiles[0]
	var nearest_distance: float = INF
	for tile: Vector2i in _gate_tiles:
		var distance: float = _centre_of(tile).distance_squared_to(player_position_tiles)
		if distance < nearest_distance:
			nearest = tile
			nearest_distance = distance
	return _centre_of(nearest + _inward(nearest))


## A tile owns its left and top edges, like FloorRun.is_exit_reached.
func _tile_of(position_tiles: Vector2) -> Vector2i:
	return Vector2i(floori(position_tiles.x), floori(position_tiles.y))


func _centre_of(tile: Vector2i) -> Vector2:
	return Vector2(tile) + Vector2(0.5, 0.5)


## Direction from a non-corner border tile into the room (RoomData refuses a gate on a corner).
func _inward(tile: Vector2i) -> Vector2i:
	if tile.y == 0:
		return Vector2i.DOWN
	if tile.y == _room_size.y - 1:
		return Vector2i.UP
	return Vector2i.RIGHT if tile.x == 0 else Vector2i.LEFT
