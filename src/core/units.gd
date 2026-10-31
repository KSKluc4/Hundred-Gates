class_name Units
extends RefCounted
## The one place tiles become pixels (F-001/C7).

const TILE_SIZE_PX: int = 16  # CX1: tile size pending Art & Game Feel


static func tiles_to_px(tiles: float) -> float:
	return tiles * TILE_SIZE_PX


static func px_to_tiles(px: float) -> float:
	return px / TILE_SIZE_PX


static func vector_tiles_to_px(tiles: Vector2) -> Vector2:
	return tiles * TILE_SIZE_PX


static func vector_px_to_tiles(px: Vector2) -> Vector2:
	return px / TILE_SIZE_PX
