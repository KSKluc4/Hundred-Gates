extends F015ShellTest
## F-015 T7 (AC13 seen from the real main scene, AC29 but its first sentence, C20): what a launch
## of scenes/main.tscn shows. It opens on the title screen with no game, the debug overlay is drawn
## above every menu and F3 still toggles it on the title screen and while paused, and Start leads
## to the town. A launch is the shared helper's spawn_main_on_title(). The input guard through this
## scene is test_f015_guard; everything test_f012_main and test_f014_shipped check after Start holds
## through spawn_main().

const MAIN_SCENE_SETTING: String = "application/run/main_scene"
const OVERLAY_NODE: NodePath = ^"DebugOverlay"
const MENU_LAYER_NODE: NodePath = ^"MenuLayer"
## C20: the overlay's layer, and the menu's and GUT's own that it must sit between.
const OVERLAY_LAYER: int = 100
const MENU_LAYER: int = 10
const GUT_LAYER: int = 128


func _overlay() -> DebugOverlay:
	return _main.get_node(OVERLAY_NODE)


# --- the scene file ---


func test_the_project_still_starts_on_the_main_scene() -> void:
	assert_eq(ProjectSettings.get_setting(MAIN_SCENE_SETTING), MAIN_SCENE_PATH)
	assert_true(ResourceLoader.exists(MAIN_SCENE_PATH))


func test_the_main_scene_holds_the_overlay_and_the_shell_and_nothing_else() -> void:
	var main_scene_node: Node = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	autofree(main_scene_node)
	assert_eq(main_scene_node.name, &"Main")
	var names: Array[StringName] = []
	for child: Node in main_scene_node.get_children():
		names.append(child.name)
	assert_eq(names, [&"DebugOverlay", &"Shell"] as Array[StringName])
	assert_true(main_scene_node.get_node(OVERLAY_NODE) is DebugOverlay)
	var shell_node: Node = main_scene_node.get_node(MAIN_SHELL_NODE)
	assert_true(shell_node is Shell)
	assert_eq(shell_node.scene_file_path, SHELL_SCENE_PATH, "an instance of shell.tscn")
	assert_null(
		main_scene_node.find_child("Game", true, false), "the shell builds the game on Start"
	)


# --- AC13, AC29: a launch ---


func test_a_launch_shows_the_title_screen_and_no_game() -> void:
	await spawn_main_on_title()
	assert_null(_main.find_child("Game", true, false), "no Game node anywhere under Main")
	assert_null(shell().get_game())
	assert_eq(_main.get_child_count(), 2)
	assert_eq(flow().get_state(), ShellFlow.State.TITLE)
	assert_true(panel().is_open())
	assert_eq(panel().get_heading(), ShellMenus.TITLE_HEADING)
	assert_eq(
		panel().get_entry_ids(),
		[ShellMenus.START, ShellMenus.SETTINGS, ShellMenus.QUIT] as Array[StringName]
	)
	assert_eq(panel().get_focus_id(), ShellMenus.START)
	assert_true(space_is_active())
	assert_eq(get_errors().size(), 0, str(get_errors()))


func test_a_launch_stays_on_the_title_screen_until_a_choice() -> void:
	await spawn_main_on_title()
	for _i: int in 30:
		await get_tree().physics_frame
	assert_null(_main.find_child("Game", true, false))
	assert_eq(flow().get_state(), ShellFlow.State.TITLE)
	assert_true(panel().is_open())


func test_a_launch_asks_for_the_window_mode_once_and_never_quits() -> void:
	await spawn_main_on_title()
	assert_eq(window_modes(), [DisplayServer.WINDOW_MODE_WINDOWED] as Array[int])
	assert_eq(quit_calls(), 0)


func test_start_from_the_main_scene_shows_the_town_with_the_hud_saying_town() -> void:
	await spawn_main_on_title()
	await start_game()
	assert_same(_main.get_node("Shell/Game"), game(), "the shell's child named Game")
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING)
	assert_false(panel().is_open())
	assert_not_null(town(), "the town is shown")
	assert_null(floor_scene())
	assert_eq(session().get_place(), TowerSession.Place.TOWN)
	assert_eq(location(), "Town")
	assert_eq(get_errors().size(), 0, str(get_errors()))


# --- C20: the debug overlay above the menus ---


func test_the_overlay_is_drawn_above_the_menu_layer_and_below_guts() -> void:
	await spawn_main_on_title()
	var menu_layer: CanvasLayer = shell().get_node(MENU_LAYER_NODE)
	assert_eq(menu_layer.layer, MENU_LAYER)
	assert_eq(_overlay().layer, OVERLAY_LAYER)
	assert_gt(_overlay().layer, menu_layer.layer, "above every menu")
	assert_lt(_overlay().layer, GUT_LAYER, "and below GUT's own")


func test_f3_toggles_the_overlay_on_the_title_screen() -> void:
	await spawn_main_on_title()
	assert_eq(flow().get_state(), ShellFlow.State.TITLE)
	var shown: bool = _overlay().visible
	await tap_key(KEY_F3)
	assert_eq(_overlay().visible, not shown, "F3 flipped it")
	await tap_key(KEY_F3)
	assert_eq(_overlay().visible, shown, "and back")
	assert_eq(flow().get_state(), ShellFlow.State.TITLE, "the menu did not take the key")
	assert_true(panel().is_open())


func test_f3_toggles_the_overlay_while_paused() -> void:
	await spawn_main_on_title()
	await start_game()
	await tap_key(KEY_ESCAPE)
	assert_eq(flow().get_state(), ShellFlow.State.PAUSED)
	var shown: bool = _overlay().visible
	await tap_key(KEY_F3)
	assert_eq(_overlay().visible, not shown, "F3 flipped it under the pause menu")
	await tap_key(KEY_F3)
	assert_eq(_overlay().visible, shown)
	assert_eq(flow().get_state(), ShellFlow.State.PAUSED, "the pause menu stayed")
	assert_true(panel().is_open())
	assert_eq(game().process_mode, Node.PROCESS_MODE_DISABLED)


func test_f3_toggles_the_overlay_while_playing() -> void:
	await spawn_main_on_title()
	await start_game()
	var shown: bool = _overlay().visible
	await tap_key(KEY_F3)
	assert_eq(_overlay().visible, not shown)
	await tap_key(KEY_F3)
	assert_eq(_overlay().visible, shown)
