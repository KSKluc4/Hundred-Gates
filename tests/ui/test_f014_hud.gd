extends GutTest
## F-014 T6 (AC21, the HUD's half): the kills line. It shows what it is told, sits under the
## location text, and moves nothing that was already there. When to show it is the game's.

const HUD_SCENE: PackedScene = preload("res://src/ui/hud/hud.tscn")


func _spawn_hud() -> Hud:
	var hud: Hud = HUD_SCENE.instantiate()
	add_child_autofree(hud)
	return hud


func _kills_label(hud: Hud) -> Label:
	return hud.get_node("KillsLabel")


func _location_label(hud: Hud) -> Label:
	return hud.get_node("LocationLabel")


func _banner_label(hud: Hud) -> Label:
	return hud.get_node("BannerLabel")


# --- the text ---------------------------------------------------------------------------------


func test_ac21_the_text_is_kills_count_slash_target() -> void:
	assert_eq(Hud.kills_text(0, 6), "Kills 0 / 6")
	assert_eq(Hud.kills_text(3, 12), "Kills 3 / 12")
	assert_eq(Hud.kills_text(15, 15), "Kills 15 / 15")
	assert_eq(Hud.kills_text(0, 0), "Kills 0 / 0")
	assert_eq(Hud.kills_text(30, 30), "Kills 30 / 30")


func test_ac21_the_text_comes_from_the_one_format_constant() -> void:
	assert_eq(Hud.KILLS_FORMAT, "Kills %d / %d")
	assert_eq(Hud.kills_text(4, 9), Hud.KILLS_FORMAT % [4, 9])


# --- shown and hidden -------------------------------------------------------------------------


func test_ac21_the_kills_line_is_hidden_by_default() -> void:
	var hud: Hud = _spawn_hud()
	assert_eq(hud.get_kills_text(), "")
	assert_false(_kills_label(hud).visible)


func test_ac21_set_kills_shows_the_text() -> void:
	var hud: Hud = _spawn_hud()
	hud.set_kills(0, 6)
	assert_eq(hud.get_kills_text(), "Kills 0 / 6")
	assert_true(_kills_label(hud).visible)
	assert_eq(_kills_label(hud).text, "Kills 0 / 6")


func test_ac21_set_kills_again_updates_the_count() -> void:
	var hud: Hud = _spawn_hud()
	hud.set_kills(0, 6)
	hud.set_kills(1, 6)
	assert_eq(hud.get_kills_text(), "Kills 1 / 6")
	hud.set_kills(6, 6)
	assert_eq(hud.get_kills_text(), "Kills 6 / 6")
	hud.set_kills(0, 9)
	assert_eq(hud.get_kills_text(), "Kills 0 / 9", "a new room, a new target")


func test_ac21_hide_kills_shows_nothing_and_set_kills_brings_it_back() -> void:
	var hud: Hud = _spawn_hud()
	hud.set_kills(2, 8)
	hud.hide_kills()
	assert_eq(hud.get_kills_text(), "")
	assert_false(_kills_label(hud).visible)
	assert_eq(_kills_label(hud).text, "", "no stale text under a hidden line")
	hud.hide_kills()
	assert_eq(hud.get_kills_text(), "", "hiding twice is fine")
	hud.set_kills(3, 8)
	assert_eq(hud.get_kills_text(), "Kills 3 / 8")


func test_ac21_the_kills_line_is_not_a_banner_and_does_not_time_out() -> void:
	var hud: Hud = _spawn_hud()
	hud.set_kills(1, 6)
	hud._process(100.0)
	assert_eq(hud.get_kills_text(), "Kills 1 / 6")
	assert_false(hud.is_banner_visible())
	assert_eq(hud.get_banner_text(), "")


func test_ac21_the_kills_line_and_the_location_text_are_independent() -> void:
	var hud: Hud = _spawn_hud()
	hud.set_location("Floor 1 · Room 1 / 3")
	hud.set_kills(0, 6)
	hud.set_location("Town")
	assert_eq(hud.get_kills_text(), "Kills 0 / 6")
	hud.hide_kills()
	assert_eq(hud.get_location(), "Town")


# --- where it sits ----------------------------------------------------------------------------


func test_ac21_the_line_sits_under_the_location_text_right_aligned_inside_the_view() -> void:
	var hud: Hud = _spawn_hud()
	hud.set_location(Hud.location_text(3, 4, 5, false))
	hud.set_kills(15, 15)
	await wait_process_frames(2)
	var view: Rect2 = _kills_label(hud).get_viewport_rect()
	var kills: Rect2 = _kills_label(hud).get_global_rect()
	var location: Rect2 = _location_label(hud).get_global_rect()
	assert_eq(view.size, Vector2(640, 360), "the 640 x 360 view")
	assert_true(view.encloses(kills), "inside the view: %s" % kills)
	assert_gte(kills.position.y, location.end.y, "under it: %s over %s" % [kills, location])
	assert_false(kills.intersects(location), "no overlap with the location text")
	assert_eq(kills.end.x, location.end.x, "the same right edge")
	assert_eq(kills.end.x, view.end.x - hud.margin_px.x, "margin_px from the right edge")
	assert_eq(_kills_label(hud).horizontal_alignment, HORIZONTAL_ALIGNMENT_RIGHT)
	assert_eq(
		_kills_label(hud).horizontal_alignment, _location_label(hud).horizontal_alignment, "like it"
	)


func test_ac21_the_line_does_not_overlap_the_banner() -> void:
	var hud: Hud = _spawn_hud()
	hud.set_location(Hud.location_text(3, 4, 5, false))
	hud.set_kills(15, 15)
	hud.show_banner("+30 HP", 5.0)
	await wait_process_frames(2)
	var kills: Rect2 = _kills_label(hud).get_global_rect()
	var banner: Rect2 = _banner_label(hud).get_global_rect()
	assert_true(banner.size.x > 0.0 and banner.size.y > 0.0)
	assert_false(kills.intersects(banner), "kills %s, banner %s" % [kills, banner])


func test_ac21_the_line_has_the_location_texts_font_size() -> void:
	var hud: Hud = _spawn_hud()
	assert_eq(_kills_label(hud).get_theme_font_size(&"font_size"), hud.font_size)
	assert_eq(
		_kills_label(hud).get_theme_font_size(&"font_size"),
		_location_label(hud).get_theme_font_size(&"font_size")
	)


func test_ac21_the_line_follows_the_exports() -> void:
	var hud: Hud = HUD_SCENE.instantiate()
	hud.kills_top_px = 30.0
	hud.kills_width_px = 90.0
	add_child_autofree(hud)
	hud.set_kills(0, 6)
	await wait_process_frames(2)
	var kills: Rect2 = _kills_label(hud).get_global_rect()
	assert_eq(kills.position.y, 30.0)
	assert_eq(kills.size.x, 90.0)


# --- nothing else moved -----------------------------------------------------------------------


func test_ac21_showing_the_line_moves_nothing_that_was_there() -> void:
	var hud: Hud = _spawn_hud()
	hud.set_location(Hud.location_text(2, 2, 5, false))
	hud.show_banner("You died", 5.0)
	await wait_process_frames(2)
	var location: Rect2 = _location_label(hud).get_global_rect()
	var banner: Rect2 = _banner_label(hud).get_global_rect()
	var bar: Rect2 = hud.get_health_bar().get_global_rect()
	hud.set_kills(7, 12)
	await wait_process_frames(2)
	assert_eq(_location_label(hud).get_global_rect(), location)
	assert_eq(_banner_label(hud).get_global_rect(), banner)
	assert_eq(hud.get_health_bar().get_global_rect(), bar)
	hud.hide_kills()
	await wait_process_frames(2)
	assert_eq(_location_label(hud).get_global_rect(), location)
	assert_eq(_banner_label(hud).get_global_rect(), banner)
	assert_eq(hud.get_location(), "Floor 2 · Room 3 / 5")
	assert_eq(hud.get_banner_text(), "You died")
