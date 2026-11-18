# gdlint:disable=max-public-methods
extends GutTest
## F-012 T4 (AC17-AC19): the health bar, the location text and the banner. Time is driven by
## calling _process(delta) directly, as test_debug_overlay does.

const HUD_SCENE: PackedScene = preload("res://src/ui/hud/hud.tscn")
const PLAYER_SCENE: PackedScene = preload("res://src/entities/player/player.tscn")

## The test's current answer to the provider; a test changes it, the Callable follows.
var _provided: Player = null


func before_each() -> void:
	_provided = null


func test_ac17_the_bar_shows_the_providers_player() -> void:
	var hud: Hud = _spawn_hud()
	var player: Player = _spawn_player()
	_provided = player
	var bar: HealthBar = hud.get_health_bar()
	assert_eq(bar.get_fill_fraction(), 1.0)
	assert_eq(bar.get_label_text(), "HP 100 / 100")
	_set_hp(player, 70)
	assert_almost_eq(bar.get_fill_fraction(), 0.7, 0.0001)
	assert_eq(bar.get_label_text(), "HP 70 / 100")


func test_ac17_the_label_node_and_the_draw_follow_a_hit_on_the_next_frame() -> void:
	var hud: Hud = _spawn_hud()
	var player: Player = _spawn_player()
	_provided = player
	var bar: HealthBar = hud.get_health_bar()
	var label: Label = bar.get_node("Label")
	bar._process(0.0)
	assert_eq(label.text, "HP 100 / 100")
	_set_hp(player, 25)
	bar._process(0.0)
	assert_eq(label.text, "HP 25 / 100", "the node's text follows the player")
	await wait_process_frames(2)  # The real _draw, with the real engine checking for errors.
	assert_eq(label.text, "HP 25 / 100")


func test_ac17_a_hit_through_the_combat_state_is_read() -> void:
	var hud: Hud = _spawn_hud()
	var player: Player = _spawn_player()
	_provided = player
	var event: HitEvent = HitEvent.new()
	event.attacker_id = &"test"
	event.target_id = player.motor.get_combat_id()
	event.damage = 30
	event.direction = Vector2.RIGHT
	player.motor.get_combat_state().apply_hit(event, Tunables.player_combat)
	assert_eq(hud.get_health_bar().get_label_text(), "HP 70 / 100")


func test_ac17_an_unset_provider_gives_an_empty_bar() -> void:
	var hud: Hud = HUD_SCENE.instantiate()
	add_child_autofree(hud)
	var bar: HealthBar = hud.get_health_bar()
	assert_false(bar.player_provider.is_valid())
	assert_eq(bar.get_fill_fraction(), 0.0)
	assert_eq(bar.get_label_text(), "")
	await wait_process_frames(2)
	assert_eq((bar.get_node("Label") as Label).text, "")


func test_ac17_a_provider_that_returns_null_gives_an_empty_bar() -> void:
	var bar: HealthBar = _spawn_hud().get_health_bar()
	assert_null(_provided)
	assert_eq(bar.get_fill_fraction(), 0.0)
	assert_eq(bar.get_label_text(), "")
	await wait_process_frames(2)


func test_ac17_a_freed_player_gives_an_empty_bar_and_no_error() -> void:
	var hud: Hud = _spawn_hud()
	var player: Player = _spawn_player()
	_provided = player
	var bar: HealthBar = hud.get_health_bar()
	assert_eq(bar.get_label_text(), "HP 100 / 100")
	player.free()
	assert_false(is_instance_valid(_provided), "the provider still holds the freed node")
	assert_eq(bar.get_fill_fraction(), 0.0)
	assert_eq(bar.get_label_text(), "")
	await wait_process_frames(2)  # _process and _draw run on the freed answer too.
	assert_eq((bar.get_node("Label") as Label).text, "")


func test_ac17_a_player_freed_with_queue_free_is_not_read_afterwards() -> void:
	var hud: Hud = _spawn_hud()
	var player: Player = _spawn_player()
	_provided = player
	player.queue_free()
	await wait_process_frames(2)
	assert_eq(hud.get_health_bar().get_fill_fraction(), 0.0)
	assert_eq(hud.get_health_bar().get_label_text(), "")


func test_ac17_a_provider_bound_to_a_freed_object_counts_as_null() -> void:
	var bar: HealthBar = _spawn_hud().get_health_bar()
	var holder: Node = Node.new()
	bar.player_provider = Callable(holder, "get_name")
	holder.free()
	assert_false(bar.player_provider.is_valid())
	assert_eq(bar.get_fill_fraction(), 0.0)
	assert_eq(bar.get_label_text(), "")


func test_ac17_a_new_player_from_the_provider_is_shown() -> void:
	var bar: HealthBar = _spawn_hud().get_health_bar()
	var first: Player = _spawn_player()
	var second: Player = _spawn_player()
	_set_hp(first, 80)
	_set_hp(second, 40)
	_provided = first
	assert_eq(bar.get_label_text(), "HP 80 / 100")
	_provided = second
	assert_eq(bar.get_label_text(), "HP 40 / 100")
	assert_almost_eq(bar.get_fill_fraction(), 0.4, 0.0001)
	first.free()  # The room swap: the old player goes, the provider answers with the new one.
	assert_eq(bar.get_label_text(), "HP 40 / 100")


func test_ac17_the_hud_hands_a_provider_set_after_ready_to_its_bar() -> void:
	var hud: Hud = HUD_SCENE.instantiate()
	add_child_autofree(hud)
	assert_false(hud.get_health_bar().player_provider.is_valid())
	_provided = _spawn_player()
	hud.player_provider = _provide
	assert_eq(hud.get_health_bar().get_label_text(), "HP 100 / 100")


func test_ac17_the_hud_hands_a_provider_set_before_ready_to_its_bar() -> void:
	var hud: Hud = HUD_SCENE.instantiate()
	hud.player_provider = _provide
	_provided = _spawn_player()
	add_child_autofree(hud)
	assert_eq(hud.get_health_bar().get_label_text(), "HP 100 / 100")


func test_ac18_location_text_for_the_town() -> void:
	assert_eq(Hud.location_text(0, 0, 1, false), "Town")
	assert_eq(Hud.location_text(0, 3, 9, true), "Town", "the town ignores the rest")


func test_ac18_location_text_for_a_combat_room_counts_from_one() -> void:
	assert_eq(Hud.location_text(2, 2, 5, false), "Floor 2 · Room 3 / 5")
	assert_eq(Hud.location_text(1, 0, 4, false), "Floor 1 · Room 1 / 4")
	assert_eq(Hud.location_text(12, 3, 4, false), "Floor 12 · Room 4 / 4")


func test_ac18_location_text_for_a_boss_room() -> void:
	assert_eq(Hud.location_text(2, 4, 5, true), "Floor 2 · Boss")


func test_ac18_set_location_shows_it() -> void:
	var hud: Hud = _spawn_hud()
	assert_eq(hud.get_location(), "")
	hud.set_location(Hud.location_text(2, 2, 5, false))
	assert_eq(hud.get_location(), "Floor 2 · Room 3 / 5")
	assert_eq((hud.get_node("LocationLabel") as Label).text, "Floor 2 · Room 3 / 5")
	hud.set_location(Hud.location_text(0, 0, 1, false))
	assert_eq(hud.get_location(), "Town")


func test_ac19_a_banner_shows_its_text_and_hides_after_its_duration() -> void:
	var hud: Hud = _spawn_hud()
	assert_false(hud.is_banner_visible())
	assert_eq(hud.get_banner_text(), "")
	hud.show_banner("You died", 2.0)
	assert_true(hud.is_banner_visible())
	assert_eq(hud.get_banner_text(), "You died")
	hud._process(0.5)
	hud._process(0.5)
	hud._process(0.5)
	assert_true(hud.is_banner_visible(), "1.5 s of 2.0")
	hud._process(0.25)
	assert_true(hud.is_banner_visible(), "1.75 s of 2.0")
	hud._process(0.25)
	assert_false(hud.is_banner_visible(), "2.0 s")
	assert_eq(hud.get_banner_text(), "")


func test_ac19_a_banner_does_not_hide_on_a_frame_of_no_time() -> void:
	var hud: Hud = _spawn_hud()
	hud.show_banner("Hello", 1.0)
	hud._process(0.0)
	assert_true(hud.is_banner_visible())


func test_ac19_a_new_banner_replaces_the_old_and_restarts_the_time() -> void:
	var hud: Hud = _spawn_hud()
	hud.show_banner("first", 1.0)
	hud._process(0.75)
	hud.show_banner("second", 1.0)
	assert_eq(hud.get_banner_text(), "second")
	hud._process(0.75)
	assert_true(hud.is_banner_visible(), "0.75 s of the second one, 1.5 s since the first")
	assert_eq(hud.get_banner_text(), "second")
	hud._process(0.25)
	assert_false(hud.is_banner_visible())


func test_ac19_a_banner_after_the_old_one_hid_shows_again() -> void:
	var hud: Hud = _spawn_hud()
	hud.show_banner("first", 0.5)
	hud._process(0.5)
	assert_false(hud.is_banner_visible())
	hud.show_banner("second", 0.5)
	assert_true(hud.is_banner_visible())
	assert_eq(hud.get_banner_text(), "second")


func test_ac19_a_duration_of_0_hides_the_banner_on_the_next_frame() -> void:
	var hud: Hud = _spawn_hud()
	hud.show_banner("blink", 0.0)
	assert_true(hud.is_banner_visible(), "shown until the next frame")
	hud._process(0.0)
	assert_false(hud.is_banner_visible())
	assert_eq(hud.get_banner_text(), "")


func test_ac19_the_banner_is_timed_by_real_frames_too() -> void:
	var hud: Hud = _spawn_hud()
	hud.show_banner("real", 0.0)
	await wait_process_frames(2)
	assert_false(hud.is_banner_visible())


func _spawn_hud() -> Hud:
	var hud: Hud = HUD_SCENE.instantiate()
	hud.player_provider = _provide
	add_child_autofree(hud)
	return hud


func _spawn_player() -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	return player


func _provide() -> Player:
	return _provided


func _set_hp(player: Player, value: int) -> void:
	player.motor.get_combat_state().set_hp(value)
