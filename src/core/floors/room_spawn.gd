class_name RoomSpawn
extends RefCounted
## One enemy placed in a room (F-011/C7). Position is the tile centre, in tiles.

var enemy: EnemyData
var position_tiles: Vector2 = Vector2.ZERO
var combat_id: StringName = &""
## F-014/C2: true for a reinforcement, which waits in reserve and arrives later at an arrival point.
var is_reinforcement: bool = false
