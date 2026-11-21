class_name LootDrop
extends RefCounted
## F-016/C9: one sword lying in a room. A value: made once, never changed.

## The sword, by id.
var sword_id: StringName = &""
## Where it lies, in tiles.
var position: Vector2 = Vector2.ZERO
## The floor whose boss dropped it, 0 for any other drop. Taking such a drop is what ends that
## floor's guaranteed boss drop (C11).
var boss_floor: int = 0


static func make(id: StringName, at: Vector2, from_boss_floor: int = 0) -> LootDrop:
	var drop: LootDrop = LootDrop.new()
	drop.sword_id = id
	drop.position = at
	drop.boss_floor = from_boss_floor
	return drop
