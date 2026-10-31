extends GutTest


func test_tiles_to_px_and_back() -> void:
	assert_eq(Units.tiles_to_px(3.0), 3.0 * Units.TILE_SIZE_PX)
	assert_eq(Units.px_to_tiles(Units.tiles_to_px(2.5)), 2.5)


func test_vectors_convert_like_scalars() -> void:
	var tiles: Vector2 = Vector2(1.5, -2.0)
	var expected: Vector2 = Vector2(Units.tiles_to_px(1.5), Units.tiles_to_px(-2.0))
	assert_eq(Units.vector_tiles_to_px(tiles), expected)
	assert_eq(Units.vector_px_to_tiles(expected), tiles)
