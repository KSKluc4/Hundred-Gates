extends F012GameTest
## F-014 T6 (AC21, and AC20's return from the town): the game feeds the HUD's kills line from
## the shown room, and a room entered again starts its waves from the beginning. On a fixture
## tower (WaveFixtures.wave_tower(): the town, two wave rooms of 5 enemies and a boss room), never
## on the shipped one.

const FIRST_ROOM_TEXT: String = "Floor 1 · Room 1 / 2"
const SECOND_ROOM_TEXT: String = "Floor 1 · Room 2 / 2"
const BOSS_TEXT: String = "Floor 1 · Boss"
const KILLS_0_OF_5: String = "Kills 0 / 5"
const DEATH_DELAY: float = 0.5
const PAUSE_TICKS: int = 60
## Ticks to wait for the reinforcements of a room: three warnings, with the interval between.
const WAVE_LOOP_LIMIT_TICKS: int = 2000


func _enter_first_room() -> void:
	await spawn_game(WaveFixtures.wave_tower(2))
	await enter_floor_through_gate(1)


func _dead_in_room() -> int:
	var dead: int = 0
	for node: Enemy in room().get_enemies():
		if not node.logic.is_alive() and not node.logic.is_waiting():
			dead += 1
	return dead


# --- AC21: shown in a combat room, hidden elsewhere --------------------------------------------


func test_ac21_nothing_is_shown_in_the_town() -> void:
	await spawn_game(WaveFixtures.wave_tower(2))
	assert_eq(location(), "Town")
	assert_eq(hud().get_kills_text(), "")
	await run_ticks(5)
	assert_eq(hud().get_kills_text(), "")


func test_ac21_entering_a_combat_room_shows_kills_0_of_its_target() -> void:
	await _enter_first_room()
	assert_eq(location(), FIRST_ROOM_TEXT)
	assert_eq(room().get_kill_target(), 5)
	assert_eq(hud().get_kills_text(), KILLS_0_OF_5)
	assert_eq(hud().get_kills_text(), Hud.kills_text(0, 5), "from the one function")


func test_ac21_the_count_goes_up_with_each_kill_reinforcements_included() -> void:
	await _enter_first_room()
	var placed: Array[Enemy] = []
	for node: Enemy in room().get_enemies():
		if not room().get_reserve_enemies().has(node):
			placed.append(node)
	assert_eq(placed.size(), 2)
	kill(placed[0])
	await run_ticks(1)
	assert_eq(hud().get_kills_text(), "Kills 1 / 5", "the next tick")
	kill(placed[1])
	await run_ticks(1)
	assert_eq(hud().get_kills_text(), "Kills 2 / 5")
	var shown: Array[String] = []
	for _i: int in WAVE_LOOP_LIMIT_TICKS:
		if room().get_kill_count() >= 5:
			break
		for node: Enemy in room().get_reserve_enemies():
			if node.logic.is_alive():
				kill(node)  # One that arrived: it fell before it moved.
		await run_ticks(1)
		var text: String = hud().get_kills_text()
		assert_eq(text, Hud.kills_text(_dead_in_room(), 5), "always what the room has")
		if shown.is_empty() or shown[-1] != text:
			shown.append(text)
	assert_eq(
		shown,
		["Kills 2 / 5", "Kills 3 / 5", "Kills 4 / 5", "Kills 5 / 5"] as Array[String],
		"three reinforcements came and fell one by one"
	)
	assert_true(room().is_cleared())


func test_ac21_nothing_is_shown_in_a_boss_room() -> void:
	await _enter_first_room()
	await clear_room_and_advance()
	await clear_room_and_advance()
	assert_eq(location(), BOSS_TEXT)
	assert_true(room().get_room_data().is_boss_room)
	assert_eq(hud().get_kills_text(), "")
	await run_ticks(10)
	assert_eq(hud().get_kills_text(), "", "and it stays so")


func test_ac21_a_room_change_by_the_door_is_followed_in_the_same_tick_as_the_location() -> void:
	await _enter_first_room()
	kill_all()
	await run_ticks(2)
	assert_eq(hud().get_kills_text(), "Kills 5 / 5", "the first room, cleared")
	var index: int = floor_scene().get_run().get_room_index()
	put_player_at_door()
	var moved: Callable = func() -> bool: return floor_scene().get_run().get_room_index() != index
	assert_true(await run_until(moved, WALK_LIMIT_TICKS, door_outward()), "the next room")
	assert_eq(location(), SECOND_ROOM_TEXT, "the location has changed")
	assert_eq(hud().get_kills_text(), KILLS_0_OF_5, "and so has the count, in this very tick")
	await clear_room_and_advance()
	assert_eq(location(), BOSS_TEXT)
	assert_eq(hud().get_kills_text(), "", "the boss room: nothing, in the tick it was entered")


func test_ac21_a_debug_skip_is_followed_at_once_not_a_tick_later() -> void:
	await _enter_first_room()
	kill(room().get_enemies()[0])
	await run_ticks(1)
	assert_eq(hud().get_kills_text(), "Kills 1 / 5")
	floor_scene().skip_room()  # N: between ticks, the location text changes right here.
	assert_eq(location(), SECOND_ROOM_TEXT)
	assert_eq(hud().get_kills_text(), KILLS_0_OF_5, "no tick has run: it changed with the text")
	floor_scene().skip_room()
	assert_eq(location(), BOSS_TEXT)
	assert_eq(hud().get_kills_text(), "")


func test_ac21_the_restart_of_a_room_by_r_starts_the_count_again() -> void:
	await _enter_first_room()
	kill(room().get_enemies()[0])
	await run_ticks(1)
	assert_eq(hud().get_kills_text(), "Kills 1 / 5")
	floor_scene().restart_room()
	assert_eq(hud().get_kills_text(), KILLS_0_OF_5, "the rebuilt room, at once")
	await run_ticks(2)
	assert_eq(hud().get_kills_text(), KILLS_0_OF_5)


func test_ac21_the_game_decides_nothing_it_shows_what_the_room_counts() -> void:
	await _enter_first_room()
	for node: Enemy in room().get_enemies():
		kill(node)
		await run_ticks(1)
		assert_eq(hud().get_kills_text(), Hud.kills_text(room().get_kill_count(), 5))
	assert_eq(hud().get_kills_text(), "Kills 5 / 5")


# --- AC20: back from the town, the waves start from the beginning ---------------------------------


func test_ac20_after_a_death_and_the_town_the_same_room_starts_its_waves_again() -> void:
	set_death_delay(DEATH_DELAY)
	await _enter_first_room()
	var first_waves: RoomWaves = room().get_waves()
	assert_not_null(first_waves)
	# Mid-wave: a placed enemy fell, a warning is running, the HUD counts.
	kill(room().get_enemies()[0])
	var warning: Callable = func() -> bool: return not room().get_waves().get_pending().is_empty()
	assert_true(await run_until(warning, 120), "a warning started")
	assert_true(first_waves.has_started())
	assert_eq(hud().get_kills_text(), "Kills 1 / 5")
	var old_floor: FloorScene = floor_scene()
	kill_player()
	await run_ticks(2)
	assert_eq(session().get_place(), TowerSession.Place.DEATH_PAUSE)
	var back: Callable = func() -> bool: return town() != null
	assert_true(await run_until(back, PAUSE_TICKS * 3), "the town came back")
	await run_ticks(1)
	assert_false(is_instance_valid(old_floor), "the floor was freed")
	assert_eq(location(), "Town")
	assert_eq(hud().get_kills_text(), "", "nothing in the town")
	# The same floor again: a new room, a new director.
	await enter_floor_through_gate(1)
	assert_eq(location(), FIRST_ROOM_TEXT)
	assert_eq(hud().get_kills_text(), KILLS_0_OF_5)
	var waves: RoomWaves = room().get_waves()
	assert_not_null(waves)
	assert_ne(waves, first_waves, "a fresh director")
	assert_false(waves.has_started())
	assert_eq(waves.get_kill_count(), 0)
	assert_eq(room().get_kill_count(), 0)
	assert_eq(waves.get_next_index(), 0)
	assert_true(waves.get_pending().is_empty())
	assert_eq(room().get_reserve_enemies().size(), 3)
	for node: Enemy in room().get_reserve_enemies():
		assert_true(node.logic.is_waiting(), "%s is waiting" % node.combat_id)
	await run_ticks(60)
	assert_true(waves.get_pending().is_empty(), "and nothing starts by itself")
	assert_eq(hud().get_kills_text(), KILLS_0_OF_5)


# --- CR-4: the two lines of the HUD agree through the death pause -------------------------------


func test_cr4_in_the_death_pause_a_debug_skip_changes_neither_the_location_nor_the_count() -> void:
	set_death_delay(5.0)
	await _enter_first_room()
	kill(room().get_enemies()[0])
	await run_ticks(1)
	assert_eq(hud().get_kills_text(), "Kills 1 / 5")
	kill_player()
	await run_ticks(2)
	assert_eq(session().get_place(), TowerSession.Place.DEATH_PAUSE)
	assert_eq(hud().get_kills_text(), "Kills 1 / 5", "the pause keeps the count it last showed")
	floor_scene().skip_room()  # What N does: the session ignores it.
	assert_eq(location(), FIRST_ROOM_TEXT, "the session ignored the skip, so does the location")
	assert_eq(hud().get_kills_text(), "Kills 1 / 5", "and so does the count, at once")
	await run_ticks(5)
	assert_eq(location(), FIRST_ROOM_TEXT)
	assert_eq(hud().get_kills_text(), "Kills 1 / 5", "and a few ticks later")
	assert_eq(session().get_place(), TowerSession.Place.DEATH_PAUSE)
