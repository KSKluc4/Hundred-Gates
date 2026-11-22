extends F015ShellTest
## F-017/T1 (AC2, AC3, AC4's positive halves; C2, C3, C10): the switch of the developer tools, seen
## from the real main scene (and from a `Game` built without a shell). With the switch off the
## overlay is hidden and deaf, R and N do nothing on a floor and N nothing in town even where the
## game's own `debug_keys_enabled` is on, the text under an enemy is hidden, and no action whose
## name starts with `debug_` does anything in the four places a player can be (the title screen,
## the town, a floor in a fight, the pause menu). With it on, all of that works as it did.
## Every test that turns the switch off puts the old value back in after_each() (C10): a leaked
## `false` would fail the files that read the overlay, the keys and the text.
## An action is pressed two ways (C3): every event bound to it, pressed and released between two
## ticks, and an `InputEventAction`. The bound events are the InputMap's own, read in the test, so
## an action added later is covered with no edit here.

enum Way { BOUND_EVENTS, ACTION_EVENT }

const WAYS: Array[Way] = [Way.BOUND_EVENTS, Way.ACTION_EVENT]
const OVERLAY_NODE: NodePath = ^"DebugOverlay"
const DEBUG_ACTION_PREFIX: String = "debug_"
const TOGGLE_ACTION: StringName = &"debug_toggle"
const RESET_ACTION: StringName = &"debug_reset"
const NEXT_ROOM_ACTION: StringName = &"debug_next_room"
## What C3 says the InputMap holds today: F3, F5, P, K, R, I and N.
const MIN_DEBUG_ACTIONS: int = 7
const DEBUG_LABEL_NODE: NodePath = ^"DebugLabel"
## The twin fight: the actions are pressed at the first of these sim times and the snapshots are
## taken at the second, so the chaser has walked, wound up and struck in between.
const PRESS_AT_SECONDS: float = 0.5
const COMPARE_AT_SECONDS: float = 1.6
const RUN_LIMIT_TICKS: int = 900
## Where the player stands in a fight: inside the chaser's aggro radius (6 tiles) of its spawn at
## (9.5, 5.5), so it chases, winds up and strikes.
const FIGHT_PLAYER_TILES: Vector2 = Vector2(5.5, 5.5)
const ROOMS_PER_FLOOR: int = 2
const FLOORS: int = 2

var _switch_before: bool = true


func before_each() -> void:
	super.before_each()
	_switch_before = DevTools.enabled


func after_each() -> void:
	DevTools.enabled = _switch_before
	await super.after_each()


# --- the helpers ---


func _overlay() -> DebugOverlay:
	return _main.get_node(OVERLAY_NODE)


## The real main scene past its title screen, on `tower` (null: the shipped one), in the town.
func _start_main(tower: TowerData = null) -> void:
	var prepare: Callable = func(shell_node: Shell) -> void:
		if tower != null:
			shell_node.tower_data = tower
	await spawn_main_on_title(prepare)
	await start_game()


func _fixture_tower() -> TowerData:
	return TowerFixtures.tower_of(FLOORS, ROOMS_PER_FLOOR)


## Every action of the InputMap whose name starts with `debug_`, read now (C3).
func _debug_actions() -> Array[StringName]:
	var names: Array[StringName] = []
	for action: StringName in InputMap.get_actions():
		if String(action).begins_with(DEBUG_ACTION_PREFIX):
			names.append(action)
	names.sort_custom(func(first: StringName, second: StringName) -> bool: return first < second)
	return names


## `action` pressed and released between two ticks, the way `way` says.
func _press_debug(action: StringName, way: Way) -> void:
	await get_tree().process_frame
	match way:
		Way.BOUND_EVENTS:
			for bound: InputEvent in InputMap.action_get_events(action):
				_send_bound(bound, true)
				_send_bound(bound, false)
		Way.ACTION_EVENT:
			press_action(action)


## The event as the action has it (the keycode and physical keycode it is bound with), pressed or
## released.
func _send_bound(bound: InputEvent, pressed: bool) -> void:
	var event: InputEvent = bound.duplicate() as InputEvent
	event.set(&"pressed", pressed)
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _way_name(way: Way) -> String:
	return "the bound events" if way == Way.BOUND_EVENTS else "an InputEventAction"


## The identity of every resource `Tunables` holds (and the value of anything else it holds).
func _tunables_identity() -> Dictionary:
	var identity: Dictionary = {}
	for property: Dictionary in Tunables.get_property_list():
		if (int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var value: Variant = Tunables.get(property["name"])
		identity[property["name"]] = value.get_instance_id() if value is Object else value
	return identity


## The session's snapshot as text, without the loot roller's seed: the game draws that one at random
## for every new game, so two games (the twins of _fight()) differ in it whatever was pressed.
func _session_text() -> String:
	var snapshot: Dictionary = session().to_dict()
	(snapshot[TowerSession.KEY_LOOT] as Dictionary).erase(CharacterLoot.KEY_ROLLER)
	return JSON.stringify(snapshot)


func _enemy_label(target: Enemy) -> Label:
	return target.get_node(DEBUG_LABEL_NODE)


func _entry_ids() -> Array[StringName]:
	return panel().get_entry_ids()


# --- the plumbing of the helpers ---


func test_the_input_map_holds_at_least_seven_debug_actions_each_with_an_event() -> void:
	var actions: Array[StringName] = _debug_actions()
	assert_gte(actions.size(), MIN_DEBUG_ACTIONS, str(actions))
	for action: StringName in actions:
		assert_gt(InputMap.action_get_events(action).size(), 0, "%s is bound" % action)


# --- AC2: the switch is off ---


func test_ac2_the_overlay_is_hidden_at_start_and_deaf_to_the_toggle() -> void:
	DevTools.enabled = false
	assert_true(Tunables.game.debug_overlay_visible_on_start, "the control: the tunable says show")
	await spawn_main_on_title()
	assert_not_null(_overlay(), "in the tree: Main keeps its two children")
	assert_false(_overlay().visible, "hidden at start")
	assert_eq(_main.get_child_count(), 2)
	for way: Way in WAYS:
		await _press_debug(TOGGLE_ACTION, way)
		assert_false(_overlay().visible, "still hidden after %s" % _way_name(way))
	await tap_key(KEY_F3)
	assert_false(_overlay().visible, "and after a real F3")
	assert_eq(flow().get_state(), ShellFlow.State.TITLE)


func test_ac2_the_overlay_stays_hidden_in_the_town_and_in_the_pause_menu() -> void:
	DevTools.enabled = false
	await _start_main()
	assert_false(_overlay().visible, "the town")
	await tap_key(KEY_F3)
	assert_false(_overlay().visible, "F3 in the town")
	await pause_with_escape()
	await tap_key(KEY_F3)
	assert_false(_overlay().visible, "F3 under the pause menu")
	assert_eq(flow().get_state(), ShellFlow.State.PAUSED)


func test_ac2_r_and_n_do_nothing_on_a_floor_and_n_nothing_in_town_in_the_main_scene() -> void:
	DevTools.enabled = false
	await _start_main()
	var progress_before: String = JSON.stringify(session().get_progress().to_dict())
	await _press_both(NEXT_ROOM_ACTION)
	await tap_key(KEY_N)
	assert_eq(JSON.stringify(session().get_progress().to_dict()), progress_before, "N in town")
	assert_false(session().get_progress().is_floor_cleared(1))
	await enter_floor_through_gate(1)
	var first: Room = room()
	var index: int = floor_scene().get_run().get_room_index()
	set_hp(40)
	await _press_both(NEXT_ROOM_ACTION)
	await tap_key(KEY_N)
	assert_same(room(), first, "N did not skip the room")
	assert_eq(floor_scene().get_run().get_room_index(), index)
	await _press_both(RESET_ACTION)
	await tap_key(KEY_R)
	assert_same(room(), first, "R did not restart it")
	assert_eq(hp(), 40, "and did not refill the player")


func test_ac2_a_game_built_with_its_debug_keys_on_has_none_when_the_switch_is_off() -> void:
	DevTools.enabled = false
	var prepare: Callable = func(built: Game) -> void: built.debug_keys_enabled = true
	await spawn_game(_fixture_tower(), prepare)
	assert_true(game().debug_keys_enabled, "the control: the game's own keys are on")
	var progress_before: String = JSON.stringify(session().get_progress().to_dict())
	await _press_both(NEXT_ROOM_ACTION)
	await tap_key(KEY_N)
	assert_eq(JSON.stringify(session().get_progress().to_dict()), progress_before, "N in town")
	await enter_floor_through_gate(1)
	assert_true(floor_scene().debug_keys_enabled, "the control: the floor's keys are on")
	var first: Room = room()
	set_hp(40)
	await _press_both(NEXT_ROOM_ACTION)
	await tap_key(KEY_N)
	assert_same(room(), first, "N did not skip the room")
	assert_eq(floor_scene().get_run().get_room_index(), 0)
	await _press_both(RESET_ACTION)
	await tap_key(KEY_R)
	assert_same(room(), first, "R did not restart it")
	assert_eq(hp(), 40)


func test_ac2_the_text_under_an_enemy_is_hidden_after_a_frame_and_at_once_after_a_kill() -> void:
	DevTools.enabled = false
	await _start_main(TowerFixtures.tower_of(1, 1))
	await enter_floor_through_gate(1)
	var target: Enemy = enemy()
	put_player_at(FIGHT_PLAYER_TILES)
	assert_false(target.hide_when_dead, "a room without reinforcements: the body stays drawn")
	assert_true(room().get_reserve_enemies().is_empty(), "and no reinforcements")
	await run_ticks(2)
	await wait_process_frames(2)
	assert_true(target.is_body_drawn(), "the control: the body is drawn")
	assert_true(target.did_draw_body(), "and was drawn")
	assert_false(_enemy_label(target).visible, "no text after a frame")
	# The body, the telegraph, the bar and the numbers are as they were: wait for a wind-up.
	var winding: Callable = func() -> bool: return target.get_telegraph() != Enemy.Telegraph.NONE
	assert_true(await run_until(winding, RUN_LIMIT_TICKS), "the chaser winds up")
	await wait_process_frames(1)
	assert_true(target.did_draw_body(), "the body is drawn through the wind-up")
	assert_false(_enemy_label(target).visible, "no text under it")
	hit(target.logic, 10)
	assert_eq(target.get_damage_numbers().get_labels().size(), 1, "the damage number")
	assert_lt(target.get_hp_fraction(), 1.0, "the bar follows the hit")
	var numbers_before: int = target.get_damage_numbers().get_labels().size()
	kill(target)  # No frame between this and the checks: only _sync_body() has run.
	assert_true(target.is_body_drawn(), "the dead body is drawn here")
	assert_false(_enemy_label(target).visible, "no text at once after the kill")
	assert_eq(target.get_damage_numbers().get_labels().size(), numbers_before + 1, "its number")
	await wait_process_frames(2)
	assert_true(target.did_draw_body(), "the body is still drawn")
	assert_false(_enemy_label(target).visible, "and no text a frame later")


# --- AC3: no debug action does anything, in the four places ---


func test_ac3_nothing_changes_on_the_title_screen() -> void:
	DevTools.enabled = false
	await spawn_main_on_title()
	var before: Dictionary = _title_view()
	var actions: Array[StringName] = _debug_actions()
	assert_gte(actions.size(), MIN_DEBUG_ACTIONS)
	for action: StringName in actions:
		for way: Way in WAYS:
			await _press_debug(action, way)
			assert_eq(_title_view(), before, "%s by %s" % [action, _way_name(way)])
	assert_null(shell().get_game(), "no game exists")
	assert_eq(get_errors().size(), 0, str(get_errors()))


func test_ac3_nothing_changes_in_the_town() -> void:
	DevTools.enabled = false
	await _start_main()
	assert_not_null(town())
	var before: Dictionary = _town_view()
	var actions: Array[StringName] = _debug_actions()
	assert_gte(actions.size(), MIN_DEBUG_ACTIONS)
	for action: StringName in actions:
		for way: Way in WAYS:
			await _press_debug(action, way)
			assert_eq(_town_view(), before, "%s by %s" % [action, _way_name(way)])
	assert_false(session().get_progress().is_floor_cleared(1), "N cleared no floor")
	assert_eq(get_errors().size(), 0, str(get_errors()))


func test_ac3_nothing_changes_in_the_pause_menu() -> void:
	DevTools.enabled = false
	await _start_main()
	await pause_with_escape()
	var before: Dictionary = _pause_view()
	assert_eq(
		before["process_mode"], Node.PROCESS_MODE_DISABLED, "the control: the game is stopped"
	)
	var actions: Array[StringName] = _debug_actions()
	assert_gte(actions.size(), MIN_DEBUG_ACTIONS)
	for action: StringName in actions:
		for way: Way in WAYS:
			await _press_debug(action, way)
			assert_eq(flow().get_state(), ShellFlow.State.PAUSED, "%s stays paused" % action)
			assert_eq(_pause_view(), before, "%s by %s" % [action, _way_name(way)])
	assert_eq(get_errors().size(), 0, str(get_errors()))


## A floor in a fight, twice over: a twin that presses nothing, and the same game with the action
## pressed at the same sim time. Run one after the other; each snapshot is taken at the first tick
## whose sim time is COMPARE_AT_SECONDS. The twins are first checked against each other: two games
## that press nothing are the same, or the comparison below would mean nothing.
func test_ac3_nothing_changes_on_a_floor_in_a_fight() -> void:
	DevTools.enabled = false
	var tunables: Dictionary = _tunables_identity()
	var reference: Dictionary = await _fight(&"", Way.BOUND_EVENTS)
	assert_eq(reference["tunables"], tunables, "the control: the run keeps Tunables' resources")
	assert_gt(reference["time"], 0.0)
	assert_false(
		reference["enemy_states"].has(EnemyLogic.State.IDLE),
		"the control: the enemy is in the fight"
	)
	var control: Dictionary = await _fight(&"", Way.BOUND_EVENTS)
	assert_eq(control["time"], reference["time"], "the control twin: the same sim time")
	assert_eq(control["sim"], reference["sim"], "the control twin: the same snapshot")
	assert_eq(control["session"], reference["session"], "the control twin: the same session")
	var actions: Array[StringName] = _debug_actions()
	assert_gte(actions.size(), MIN_DEBUG_ACTIONS)
	for action: StringName in actions:
		for way: Way in WAYS:
			var label: String = "%s by %s" % [action, _way_name(way)]
			var run: Dictionary = await _fight(action, way)
			assert_eq(run["time"], reference["time"], "%s: the same sim time" % label)
			assert_eq(run["state"], reference["state"], "%s: the flow state" % label)
			assert_eq(run["session"], reference["session"], "%s: the session" % label)
			assert_eq(run["room_index"], reference["room_index"], "%s: the room index" % label)
			assert_eq(run["tunables"], tunables, "%s: Tunables' resources" % label)
			assert_eq(run["sim"], reference["sim"], "%s: the sim's snapshot" % label)
			assert_true(run["same_room"], "%s: the same room node, not rebuilt" % label)
			assert_true(run["same_sim"], "%s: the same sim, not a new one" % label)


# --- AC4: the switch is on ---


func test_ac4_the_overlay_is_shown_at_start_and_toggles() -> void:
	assert_true(DevTools.enabled, "the test binary has the switch on")
	assert_true(Tunables.game.debug_overlay_visible_on_start)
	await spawn_main_on_title()
	assert_true(_overlay().visible, "shown at start")
	for way: Way in WAYS:
		await _press_debug(TOGGLE_ACTION, way)
		assert_false(_overlay().visible, "hidden by %s" % _way_name(way))
		await _press_debug(TOGGLE_ACTION, way)
		assert_true(_overlay().visible, "and shown again by %s" % _way_name(way))
	assert_eq(flow().get_state(), ShellFlow.State.TITLE)


func test_ac4_n_clears_a_floor_in_town_and_r_and_n_act_on_a_floor() -> void:
	assert_true(DevTools.enabled)
	await _start_main(_fixture_tower())
	await _press_debug(NEXT_ROOM_ACTION, Way.BOUND_EVENTS)
	assert_true(session().get_progress().is_floor_cleared(1), "N cleared floor 1")
	assert_true(session().get_progress().is_floor_unlocked(2), "and unlocked floor 2")
	await _press_debug(NEXT_ROOM_ACTION, Way.ACTION_EVENT)
	assert_true(session().get_progress().is_floor_cleared(2), "an InputEventAction did too")
	await enter_floor_through_gate(1)
	var first: Room = room()
	set_hp(40)
	await _press_debug(RESET_ACTION, Way.BOUND_EVENTS)
	assert_ne(room().get_instance_id(), first.get_instance_id(), "R restarted the room")
	assert_eq(hp(), max_hp(), "with the player at full HP")
	var restarted: Room = room()
	await _press_debug(NEXT_ROOM_ACTION, Way.ACTION_EVENT)
	assert_ne(room().get_instance_id(), restarted.get_instance_id(), "N left the room")
	assert_eq(floor_scene().get_run().get_room_index(), 1, "for the next one")
	await _press_debug(RESET_ACTION, Way.ACTION_EVENT)
	assert_eq(floor_scene().get_run().get_room_index(), 1, "and R restarted that one")


func test_ac4_a_game_with_its_debug_keys_on_acts_on_them() -> void:
	assert_true(DevTools.enabled)
	var prepare: Callable = func(built: Game) -> void: built.debug_keys_enabled = true
	await spawn_game(_fixture_tower(), prepare)
	await tap_key(KEY_N)
	assert_true(session().get_progress().is_floor_cleared(1), "N in town")
	await enter_floor_through_gate(1)
	await tap_key(KEY_N)
	assert_eq(floor_scene().get_run().get_room_index(), 1, "N on a floor")


func test_ac4_the_text_under_an_enemy_is_shown() -> void:
	assert_true(DevTools.enabled)
	await _start_main(TowerFixtures.tower_of(1, 1))
	await enter_floor_through_gate(1)
	var target: Enemy = enemy()
	await run_ticks(2)
	await wait_process_frames(2)
	assert_true(_enemy_label(target).visible, "shown after a frame")
	assert_string_contains(_enemy_label(target).text, "cd ", "with its state, cooldown and target")
	assert_true(target.did_draw_body())
	kill(target)
	assert_true(_enemy_label(target).visible, "and still shown at once after a kill")
	await wait_process_frames(2)
	assert_true(_enemy_label(target).visible, "and a frame later")


# --- what the AC3 tests compare ---


## Presses `action` the two ways, one after the other.
func _press_both(action: StringName) -> void:
	await _press_debug(action, Way.BOUND_EVENTS)
	await _press_debug(action, Way.ACTION_EVENT)


func _title_view() -> Dictionary:
	return {
		"state": flow().get_state(),
		"entries": _entry_ids(),
		"focus": panel().get_focus_id(),
		"open": panel().is_open(),
		"heading": panel().get_heading(),
		"game": shell().get_game() != null,
		"overlay": _overlay().visible,
	}


func _town_view() -> Dictionary:
	return {
		"state": flow().get_state(),
		"session": JSON.stringify(session().to_dict()),
		"town": town() != null and floor_scene() == null,
		"overlay": _overlay().visible,
		"guard": shell().is_guarding(),
	}


func _pause_view() -> Dictionary:
	return {
		"state": flow().get_state(),
		"entries": _entry_ids(),
		"focus": panel().get_focus_id(),
		"heading": panel().get_heading(),
		"process_mode": game().process_mode,
		"space": space_is_active(),
		"session": JSON.stringify(session().to_dict()),
		"overlay": _overlay().visible,
	}


## One game from a fresh main scene on the fixture tower, into floor 1 and its first room, with
## `action` pressed (`way`) at PRESS_AT_SECONDS of sim time, or nothing pressed when it is empty. A
## process frame passes at that moment in both, so the twin that presses nothing waits as the
## other does. Returns what the AC3 test compares, taken at COMPARE_AT_SECONDS.
func _fight(action: StringName, way: Way) -> Dictionary:
	await _start_main(_fixture_tower())
	await enter_floor_through_gate(1)
	put_player_at(FIGHT_PLAYER_TILES)
	var first_room: Room = room()
	var first_sim: CombatSim = room().get_runner().get_sim()
	assert_true(await run_until(_sim_time_reaches.bind(PRESS_AT_SECONDS), RUN_LIMIT_TICKS))
	if action.is_empty():
		await get_tree().process_frame
	else:
		await _press_debug(action, way)
	assert_true(await run_until(_sim_time_reaches.bind(COMPARE_AT_SECONDS), RUN_LIMIT_TICKS))
	var shown: Room = room()
	var states: Array = []
	for each: Enemy in shown.get_enemies():
		states.append(each.logic.get_state())
	var result: Dictionary = {
		"time": shown.get_runner().get_sim().get_time(),
		"sim": JSON.stringify(shown.get_runner().get_sim().to_dict()),
		"state": flow().get_state(),
		"session": _session_text(),
		"room_index": floor_scene().get_run().get_room_index(),
		"tunables": _tunables_identity(),
		"same_room": shown == first_room,
		"same_sim": shown.get_runner().get_sim() == first_sim,
		"enemy_states": states,
	}
	_main.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	UserSettings.reset_to_defaults()
	return result


func _sim_time_reaches(seconds: float) -> bool:
	return room().get_runner().get_sim().get_time() >= seconds
