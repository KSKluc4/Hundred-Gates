extends GutTest


func test_overlay_is_hidden_by_default() -> void:
	assert_false(GameTunables.new().debug_overlay_visible_on_start)


func test_tres_file_is_game_tunables() -> void:
	assert_is(load(Tunables.GAME_TUNABLES_PATH), GameTunables)
