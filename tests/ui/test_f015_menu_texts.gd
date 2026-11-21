# gdlint:disable=max-public-methods
extends GutTest
## F-015 T4 (AC12): every heading, body, entry and default focus of the menus table, for each state.
## The strings are written out here on purpose, not read from ShellMenus' constants: a changed word
## is a failed test.

const LOCATION: String = "Floor 2 · Room 3 / 5"
const KILLS: String = "Kills 4 / 6"
const KEEP: String = "You keep everything you unlocked."


func test_ac12_the_ids_are_the_tables() -> void:
	assert_eq(ShellMenus.START, &"start")
	assert_eq(ShellMenus.SETTINGS, &"settings")
	assert_eq(ShellMenus.QUIT, &"quit")
	assert_eq(ShellMenus.RESUME, &"resume")
	assert_eq(ShellMenus.LEAVE, &"leave")
	assert_eq(ShellMenus.QUIT_TO_TITLE, &"quit_to_title")
	assert_eq(ShellMenus.SHAKE, &"shake")
	assert_eq(ShellMenus.FULLSCREEN, &"fullscreen")
	assert_eq(ShellMenus.BACK, &"back")
	assert_eq(ShellMenus.CONFIRM, &"confirm")
	assert_eq(ShellMenus.CANCEL, &"cancel")
	assert_eq(ShellMenus.RETURN, &"return")


# --- headings ---


func test_ac12_the_headings() -> void:
	assert_eq(ShellMenus.heading(ShellFlow.State.TITLE), "Hundred Gates")
	assert_eq(ShellMenus.heading(ShellFlow.State.PAUSED), "Paused")
	assert_eq(ShellMenus.heading(ShellFlow.State.SETTINGS), "Settings")
	assert_eq(ShellMenus.heading(ShellFlow.State.CONFIRM_LEAVE), "Return to town?")
	assert_eq(ShellMenus.heading(ShellFlow.State.CONFIRM_QUIT), "Quit to title?")
	assert_eq(ShellMenus.heading(ShellFlow.State.DEAD), "You died")


# --- bodies ---


func test_ac12_the_title_body_is_empty_without_a_failed_start() -> void:
	assert_eq(_body(ShellFlow.State.TITLE), "")


func test_ac12_the_title_body_names_the_number_of_errors_after_a_failed_start() -> void:
	var one: String = _body(ShellFlow.State.TITLE, "", "", 1)
	var many: String = _body(ShellFlow.State.TITLE, "", "", 12)
	assert_eq(one, ShellMenus.START_FAILED_FORMAT % 1)
	assert_eq(many, ShellMenus.START_FAILED_FORMAT % 12)
	assert_true(one.contains("1"), "the count is in the line")
	assert_true(many.contains("12"))
	assert_false(one.contains("\n"), "one line")
	assert_ne(one, many)


func test_ac12_the_title_body_ignores_the_death_lines() -> void:
	assert_eq(_body(ShellFlow.State.TITLE, LOCATION, KILLS, 0), "")


func test_ac12_the_menus_without_a_body_have_an_empty_one() -> void:
	for state: ShellFlow.State in [ShellFlow.State.PAUSED, ShellFlow.State.SETTINGS]:
		assert_eq(_body(state, LOCATION, KILLS, 3), "", "state %d" % state)


func test_ac12_the_leave_confirm_body() -> void:
	assert_eq(
		_body(ShellFlow.State.CONFIRM_LEAVE),
		"This floor's rooms start over next time. Floors you cleared and bosses you reached stay."
	)


func test_ac12_the_quit_confirm_body() -> void:
	assert_eq(
		_body(ShellFlow.State.CONFIRM_QUIT),
		"Progress is not saved yet. Everything you unlocked will be lost."
	)


func test_ac12_the_death_body_with_a_kills_line_is_three_lines() -> void:
	assert_eq(_body(ShellFlow.State.DEAD, LOCATION, KILLS), "%s\n%s\n%s" % [LOCATION, KILLS, KEEP])


func test_ac12_the_death_body_without_a_kills_line_is_two_lines() -> void:
	assert_eq(_body(ShellFlow.State.DEAD, "Floor 1 · Boss", ""), "Floor 1 · Boss\n%s" % KEEP)


func test_ac12_the_playing_state_has_no_menu() -> void:
	var playing: ShellFlow.State = ShellFlow.State.PLAYING
	assert_eq(ShellMenus.heading(playing), "")
	assert_eq(_body(playing, LOCATION, KILLS, 2), "")
	assert_eq(ShellMenus.entries(playing, true, true, true, true).size(), 0)
	assert_eq(ShellMenus.focus(playing, ShellFlow.State.PAUSED), &"")


# --- entries ---


func test_ac12_the_title_entries() -> void:
	var entries: Array[MenuEntry] = ShellMenus.entries(
		ShellFlow.State.TITLE, false, true, false, false
	)
	assert_eq(_ids(entries), [&"start", &"settings", &"quit"] as Array[StringName])
	assert_eq(_texts(entries), ["Start", "Settings", "Quit"] as Array[String])
	assert_eq(_enabled(entries), [true, true, true] as Array[bool])


func test_ac12_the_paused_entries_on_a_floor_have_the_leave_entry() -> void:
	var entries: Array[MenuEntry] = ShellMenus.entries(
		ShellFlow.State.PAUSED, true, true, false, false
	)
	assert_eq(
		_ids(entries),
		[&"resume", &"equipment", &"leave", &"settings", &"quit_to_title"] as Array[StringName]
	)
	assert_eq(
		_texts(entries),
		["Resume", "Equipment", "Return to town", "Settings", "Quit to title"] as Array[String]
	)
	assert_eq(_enabled(entries), [true, true, true, true, true] as Array[bool])


func test_ac12_the_paused_entries_in_the_town_have_no_leave_entry() -> void:
	var entries: Array[MenuEntry] = ShellMenus.entries(
		ShellFlow.State.PAUSED, false, true, false, false
	)
	assert_eq(
		_ids(entries), [&"resume", &"equipment", &"settings", &"quit_to_title"] as Array[StringName]
	)
	assert_eq(
		_texts(entries), ["Resume", "Equipment", "Settings", "Quit to title"] as Array[String]
	)
	assert_eq(_enabled(entries), [true, true, true, true] as Array[bool])


func test_ac12_the_settings_entries_for_each_on_off_combination() -> void:
	var cases: Array[Array] = [
		[true, true, "Screen shake: On", "Fullscreen: On"],
		[true, false, "Screen shake: On", "Fullscreen: Off"],
		[false, true, "Screen shake: Off", "Fullscreen: On"],
		[false, false, "Screen shake: Off", "Fullscreen: Off"],
	]
	for case: Array in cases:
		var shake: bool = case[0]
		var fullscreen: bool = case[1]
		var entries: Array[MenuEntry] = ShellMenus.entries(
			ShellFlow.State.SETTINGS, false, shake, fullscreen, false
		)
		var label: String = "shake %s, fullscreen %s" % [shake, fullscreen]
		assert_eq(_ids(entries), [&"shake", &"fullscreen", &"back"] as Array[StringName], label)
		assert_eq(_texts(entries), [case[2], case[3], "Back"] as Array[String], label)
		assert_eq(_enabled(entries), [true, true, true] as Array[bool], label)


func test_ac12_the_settings_entries_do_not_depend_on_where_the_player_is() -> void:
	var on_floor: Array[MenuEntry] = ShellMenus.entries(
		ShellFlow.State.SETTINGS, true, true, true, true
	)
	var in_town: Array[MenuEntry] = ShellMenus.entries(
		ShellFlow.State.SETTINGS, false, true, true, false
	)
	assert_eq(_ids(on_floor), _ids(in_town))
	assert_eq(_texts(on_floor), _texts(in_town))


func test_ac12_the_in_place_texts_are_the_entries_texts() -> void:
	assert_eq(ShellMenus.shake_text(true), "Screen shake: On")
	assert_eq(ShellMenus.shake_text(false), "Screen shake: Off")
	assert_eq(ShellMenus.fullscreen_text(true), "Fullscreen: On")
	assert_eq(ShellMenus.fullscreen_text(false), "Fullscreen: Off")


func test_ac12_the_leave_confirm_entries() -> void:
	var entries: Array[MenuEntry] = ShellMenus.entries(
		ShellFlow.State.CONFIRM_LEAVE, true, true, false, false
	)
	assert_eq(_ids(entries), [&"confirm", &"cancel"] as Array[StringName])
	assert_eq(_texts(entries), ["Return to town", "Keep fighting"] as Array[String])
	assert_eq(_enabled(entries), [true, true] as Array[bool])


func test_ac12_the_quit_confirm_entries() -> void:
	var entries: Array[MenuEntry] = ShellMenus.entries(
		ShellFlow.State.CONFIRM_QUIT, true, true, false, false
	)
	assert_eq(_ids(entries), [&"confirm", &"cancel"] as Array[StringName])
	assert_eq(_texts(entries), ["Quit to title", "Cancel"] as Array[String])
	assert_eq(_enabled(entries), [true, true] as Array[bool])


func test_ac12_the_death_entry_is_enabled_only_when_it_can_be_confirmed() -> void:
	for can_confirm: bool in [true, false]:
		var entries: Array[MenuEntry] = ShellMenus.entries(
			ShellFlow.State.DEAD, true, true, false, can_confirm
		)
		assert_eq(_ids(entries), [&"return"] as Array[StringName])
		assert_eq(_texts(entries), ["Return to town"] as Array[String])
		assert_eq(_enabled(entries), [can_confirm] as Array[bool], "can confirm: %s" % can_confirm)


func test_ac12_the_other_menus_ignore_can_confirm_death() -> void:
	for state: ShellFlow.State in [
		ShellFlow.State.TITLE,
		ShellFlow.State.PAUSED,
		ShellFlow.State.SETTINGS,
		ShellFlow.State.CONFIRM_LEAVE,
		ShellFlow.State.CONFIRM_QUIT,
	]:
		var entries: Array[MenuEntry] = ShellMenus.entries(state, true, true, true, false)
		assert_eq(_enabled(entries).has(false), false, "state %d" % state)


func test_ac12_every_call_builds_new_entries() -> void:
	var first: Array[MenuEntry] = ShellMenus.entries(
		ShellFlow.State.TITLE, false, true, false, false
	)
	first[0].text = "changed"
	first[0].enabled = false
	var second: Array[MenuEntry] = ShellMenus.entries(
		ShellFlow.State.TITLE, false, true, false, false
	)
	assert_eq(second[0].text, "Start", "a menu that rewrote an entry cannot change the next one")
	assert_true(second[0].enabled)


# --- focus ---


func test_ac12_the_focus_when_a_menu_is_entered_forwards() -> void:
	var cases: Array[Array] = [
		[ShellFlow.State.TITLE, ShellFlow.State.TITLE, &"start"],
		[ShellFlow.State.PAUSED, ShellFlow.State.PLAYING, &"resume"],
		[ShellFlow.State.SETTINGS, ShellFlow.State.TITLE, &"shake"],
		[ShellFlow.State.SETTINGS, ShellFlow.State.PAUSED, &"shake"],
		[ShellFlow.State.CONFIRM_LEAVE, ShellFlow.State.PAUSED, &"cancel"],
		[ShellFlow.State.CONFIRM_QUIT, ShellFlow.State.PAUSED, &"cancel"],
		[ShellFlow.State.DEAD, ShellFlow.State.PLAYING, &"return"],
	]
	_assert_focus_cases(cases)


func test_ac12_the_focus_on_the_way_back_is_the_entry_that_led_there() -> void:
	var cases: Array[Array] = [
		[ShellFlow.State.PAUSED, ShellFlow.State.SETTINGS, &"settings"],
		[ShellFlow.State.PAUSED, ShellFlow.State.CONFIRM_LEAVE, &"leave"],
		[ShellFlow.State.PAUSED, ShellFlow.State.CONFIRM_QUIT, &"quit_to_title"],
		[ShellFlow.State.TITLE, ShellFlow.State.SETTINGS, &"settings"],
		[ShellFlow.State.TITLE, ShellFlow.State.CONFIRM_QUIT, &"start"],
	]
	_assert_focus_cases(cases)


func test_ac12_the_focus_of_every_state_is_an_entry_of_that_menu() -> void:
	# For every (state, previous) pair, with the pause menu as it is on a floor and in the town: the
	# focus is one of the menu's own entries. A way back through the leave confirm only exists on a
	# floor, where `leave` is an entry.
	for state: ShellFlow.State in ShellFlow.State.values():
		# PLAYING has no menu; EQUIPMENT's entries and focus come from EquipmentMenu (F-016/C17).
		if state == ShellFlow.State.PLAYING or state == ShellFlow.State.EQUIPMENT:
			continue
		for previous: ShellFlow.State in ShellFlow.State.values():
			var on_floor: bool = previous == ShellFlow.State.CONFIRM_LEAVE
			var entries: Array[MenuEntry] = ShellMenus.entries(state, on_floor, true, false, true)
			var label: String = "state %d from %d" % [state, previous]
			assert_true(_ids(entries).has(ShellMenus.focus(state, previous)), label)


func _assert_focus_cases(cases: Array[Array]) -> void:
	for case: Array in cases:
		var state: ShellFlow.State = case[0]
		var previous: ShellFlow.State = case[1]
		assert_eq(
			ShellMenus.focus(state, previous), case[2], "state %d, previous %d" % [state, previous]
		)


# --- helpers ---


func _body(
	state: ShellFlow.State, location: String = "", kills: String = "", error_count: int = 0
) -> String:
	return ShellMenus.body(state, location, kills, error_count)


func _ids(entries: Array[MenuEntry]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for entry: MenuEntry in entries:
		ids.append(entry.id)
	return ids


func _texts(entries: Array[MenuEntry]) -> Array[String]:
	var texts: Array[String] = []
	for entry: MenuEntry in entries:
		texts.append(entry.text)
	return texts


func _enabled(entries: Array[MenuEntry]) -> Array[bool]:
	var flags: Array[bool] = []
	for entry: MenuEntry in entries:
		flags.append(entry.enabled)
	return flags
