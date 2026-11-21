extends F015ShellTest
## F-015 code review round 2 (CR-1, CR-5; AC15, C6): the twins the shell's own file lacks. A twin
## runs the same scripted input twice from a fresh shell: never paused, and with a seeded schedule
## of pauses of mixed kinds; the player's position (and every enemy's and bolt's) and the sim's
## snapshot are compared at the start of every tick. The shell's file (`test_f015_shell.gd`) runs
## its wall slides in the town built at Start, and its fight on a fixture. These run:
## - a fight on the SHIPPED floor 1 (enemies chase, attack and die: they make their physics body
##   static on the server, which `DISABLE_MODE_MAKE_STATIC` would reset on every enable);
## - a walk into the corners of the shipped floor 1 through two room changes, paused the tick
##   before, on and after each;
## - a wall slide in a town built AFTER a death (Return to town) and after a leave by the menu (a
##   town that is a new set of bodies, which the stop must reach too);
## - and the fight and the walk after a death at 60 ticks/s as well as at the helpers' 120.
## Each test says which mutation of `Shell` it was shown to catch (round 2's measurements).
## Each is real time: ticks times the tick length, twice. A run that took a pause the game refused
## (the gate list open, a place change not yet swapped) does not count: the twin fails.

enum Scenario { FIGHT, ROOMS, AFTER_DEATH, AFTER_LEAVE }

## The kinds of pause a schedule takes. PLAIN: Escape, `frames` ticks, Escape. ZERO: both in the
## same instant. SETTINGS: pause, Settings, flip both entries twice, Back, Resume. CONFIRM: pause,
## the leave confirm (on a floor; the quit confirm elsewhere), Cancel, Resume. REPAUSE: resume, then
## pause again in the tick the space lags (DEV-6) and resume. CHAIN: five pauses in a row with no
## tick between, then one across the guard's end. PAD: pad Start and pad B.
enum Kind { PLAIN, ZERO, SETTINGS, CONFIRM, REPAUSE, CHAIN, PAD }

const ESCAPE: Key = KEY_ESCAPE
const RATE_HIGH: int = 120
const RATE_LOW: int = 60
## How long each scenario runs, in game seconds (the town part after the floor for the last two).
const FIGHT_SECONDS: float = 6.0
const ROOMS_SECONDS: float = 6.0
const FLOOR_SECONDS: float = 0.5
const TOWN_SECONDS: float = 3.5
## The seeds, each a walk and a schedule. Each twin is there for a mutation of the shell that moves
## it (see the tests), and its seed was picked from several that were tried: 3 for the fight at 120
## and at 60 (the reviewer's 1 and 4 are walks of a longer fight), 5 for the walk after a death at
## 60 (a random walk: the four legs of the slide never differ at 60 ticks/s).
const FIGHT_SEED: int = 3
const ROOMS_SEED: int = 1
const AFTER_DEATH_SEED: int = 2
const AFTER_DEATH_SEED_LOW_RATE: int = 5
const AFTER_LEAVE_SEED: int = 2
## How many pauses a seeded schedule has (one in each equal part of the run), and the lengths
## (ticks) it picks from.
const PAUSES_MIN: int = 10
const PAUSES_MAX: int = 14
const FRAME_CHOICES: Array[int] = [0, 1, 2, 3, 7]
## How much of the seeded walk the player keeps while chasing the nearest enemy.
const CHASE_WALK_WEIGHT: float = 0.6
## A swing is only made when an enemy is this close (px): a swing roots the player, and swings from
## the start would keep them from ever reaching the enemies.
const SWING_RANGE_PX: float = 48.0
## The player only swings from this second of the fight on: enemies that are not cut down come in
## and crowd round the player (and each other), which is what a stale body shows in.
const SWING_FROM_SECONDS: float = 4.0
const WALK_DIRECTIONS: int = 16
const LEG_SECONDS_MIN: float = 0.4
const LEG_SECONDS_MAX: float = 1.6
## The slide's four legs (into the south wall, up the east side, down, back) of this many seconds.
const SLIDE_LEG_SECONDS: float = 1.5
const SLIDE_LEGS: Array[Vector2] = [
	Vector2(1.0, 1.0), Vector2(1.0, -0.4), Vector2(-0.3, 1.0), Vector2(-1.0, 0.6)
]
## The walk through the rooms rams the four corners in turn, a leg of this many seconds each, with a
## dash twice a second.
const CORNER_LEGS: Array[Vector2] = [
	Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(1.0, 1.0), Vector2(-1.0, 1.0)
]
const CORNER_LEG_SECONDS: float = 1.0
## Tiles from the town's south and west wall where the slide starts.
const SLIDE_MARGIN_TILES: float = 2.5
## A random walk's north corners are this many tiles from the north wall (the gate is in it).
const RANDOM_NORTH_ROW: float = 4.5
## The walk keeps off the gate (the town's north wall, in the middle): above this row it turns back.
const GATE_KEEP_OFF_TILES: float = 2.6
const ROOM_CHANGES_AT: Array[float] = [0.25, 0.5]
const SEED_MULTIPLIER: int = 7919
const SEED_OFFSET: int = 13
const WAIT_LIMIT_TICKS: int = 20

var _scenario: Scenario = Scenario.FIGHT
var _rate: int = RATE_HIGH
## The town walk: the four legs of the slide (true) or random legs (false).
var _slide: bool = true
var _legs: Array = []
var _room_changes: Array[int] = []
var _references: Dictionary = {}


func before_each() -> void:
	super.before_each()
	_legs = []
	_room_changes = []


# --- the twins ---


## Teeth: `DISABLE_MODE_MAKE_STATIC` in place of `KEEP_ACTIVE` in `Shell._keep_bodies_in_space()`
## (enemies make their own server body static and it is reset on enable, so the enemies that crowd
## round the player see each other's old place).
func test_a_fight_on_the_shipped_floor_with_pauses_is_the_same() -> void:
	await _assert_twin(Scenario.FIGHT, FIGHT_SEED, RATE_HIGH)


func test_a_fight_on_the_shipped_floor_with_pauses_is_the_same_at_60_ticks() -> void:
	await _assert_twin(Scenario.FIGHT, FIGHT_SEED, RATE_LOW)


## Teeth: the physics space left on while the game is stopped.
func test_a_walk_into_corners_through_room_changes_paused_around_each_is_the_same() -> void:
	await _assert_twin(Scenario.ROOMS, ROOMS_SEED, RATE_HIGH)


## Teeth: no `_keep_bodies_in_space()` call (or one only at Start): the new town's bodies come out
## of the space with the first pause and go back in.
func test_a_slide_in_the_town_built_after_a_death_with_pauses_is_the_same() -> void:
	await _assert_twin(Scenario.AFTER_DEATH, AFTER_DEATH_SEED, RATE_HIGH)


func test_a_walk_in_the_town_built_after_a_death_with_pauses_is_the_same_at_60_ticks() -> void:
	await _assert_twin(Scenario.AFTER_DEATH, AFTER_DEATH_SEED_LOW_RATE, RATE_LOW, false)


func test_a_slide_in_the_town_built_after_a_leave_with_pauses_is_the_same() -> void:
	await _assert_twin(Scenario.AFTER_LEAVE, AFTER_LEAVE_SEED, RATE_HIGH)


## The run without pauses is made once per script, scenario, seed and rate; the one with the
## seeded schedule is compared with it at every tick, then at the end.
func _assert_twin(scenario: Scenario, walk_seed: int, rate: int, slide: bool = true) -> void:
	var key: String = "%d/%d/%d/%s" % [scenario, walk_seed, rate, slide]
	if not _references.has(key):
		_references[key] = await _run(scenario, walk_seed, rate, slide, {})
	var reference: Dictionary = _references[key]
	var schedule: Dictionary = _schedule(scenario, walk_seed, rate, reference["trace"].size())
	var run: Dictionary = await _run(scenario, walk_seed, rate, slide, schedule)
	var label: String = "%s seed %d at %d ticks/s" % [Scenario.keys()[scenario], walk_seed, rate]
	assert_eq(run["skipped"], 0, "%s: every pause of the schedule was taken" % label)
	assert_eq(run["done"], schedule.size(), "%s: and none of them twice" % label)
	assert_eq(run["trace"].size(), reference["trace"].size(), label)
	_assert_the_scenario_happened(scenario, run, label)
	var at: int = _first_difference(reference["trace"], run["trace"])
	assert_eq(at, -1, "%s: no tick differs; pauses %s" % [label, _schedule_text(schedule)])
	assert_eq(run["final"], reference["final"], "%s: the final snapshot is the same" % label)


## The twin is only worth its seconds if the run did what its name says.
func _assert_the_scenario_happened(scenario: Scenario, run: Dictionary, label: String) -> void:
	if scenario == Scenario.FIGHT:
		assert_gt(run["seen"]["chase"], 0, "%s: enemies chased" % label)
		assert_gt(run["seen"]["attack"], 0, "%s: enemies attacked" % label)
		assert_gt(run["seen"]["dead"], 0, "%s: an enemy died" % label)
	if scenario == Scenario.ROOMS:
		assert_eq(run["rooms"], ROOM_CHANGES_AT.size(), "%s: the room changed twice" % label)


# --- the scripted run ---


## One run from a fresh shell. `schedule` maps a tick to `[Kind, frames]`; the pause is taken at the
## start of that tick, before its commands. The trace has, per tick, the sim's snapshot (its hash)
## and where everything is.
func _run(
	scenario: Scenario, walk_seed: int, rate: int, slide: bool, schedule: Dictionary
) -> Dictionary:
	_scenario = scenario
	_rate = rate
	_slide = slide
	Engine.physics_ticks_per_second = rate
	_make_walk(walk_seed)
	set_death_delay(0.0 if scenario == Scenario.AFTER_DEATH else 100000.0)
	var on_wave_tower: bool = scenario == Scenario.AFTER_DEATH or scenario == Scenario.AFTER_LEAVE
	var prepare: Callable = func(shell_node: Shell) -> void:
		if on_wave_tower:
			shell_node.tower_data = WaveFixtures.wave_tower(2)
	await spawn_shell(prepare)
	await start_game()
	await enter_floor_through_gate(1)
	var floor_ticks: int = roundi(FLOOR_SECONDS * rate)
	var length: int = _run_length(scenario, rate)
	var trace: Array = []
	var seen: Dictionary = {"chase": 0, "attack": 0, "dead": 0}
	var done: int = 0
	var skipped: int = 0
	for tick: int in length:
		if on_wave_tower and tick == floor_ticks:
			await _to_town(scenario)
			put_player_at(_walk_start(walk_seed))
		if tick in _room_changes:
			floor_scene().skip_room()
		trace.append([JSON.stringify(_sim().to_dict()).hash(), _positions()])
		_note_enemies(seen)
		if schedule.has(tick):
			if game().is_pause_allowed() and flow().get_state() == ShellFlow.State.PLAYING:
				done += 1
				var kind: Kind = schedule[tick][0]
				await _pause(kind, schedule[tick][1])
			else:
				skipped += 1
		_commands(tick)
		await get_tree().physics_frame
	var result: Dictionary = {
		"trace": trace,
		"final": JSON.stringify(_sim().to_dict()),
		"seen": seen,
		"rooms": floor_scene().get_run().get_room_index() if floor_scene() != null else -1,
		"done": done,
		"skipped": skipped,
	}
	shell().queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	UserSettings.reset_to_defaults()
	return result


## What the enemies of the shown room are doing, counted over the run (a floor only).
func _note_enemies(seen: Dictionary) -> void:
	if town() != null:
		return
	for node: Enemy in floor_scene().get_room().get_enemies():
		match node.logic.get_state():
			EnemyLogic.State.CHASE:
				seen["chase"] += 1
			EnemyLogic.State.WINDUP, EnemyLogic.State.ACTIVE:
				seen["attack"] += 1
			EnemyLogic.State.DEAD:
				seen["dead"] += 1


func _run_length(scenario: Scenario, rate: int) -> int:
	match scenario:
		Scenario.FIGHT:
			return roundi(FIGHT_SECONDS * rate)
		Scenario.ROOMS:
			return roundi(ROOMS_SECONDS * rate)
	return roundi((FLOOR_SECONDS + TOWN_SECONDS) * rate)


## The walk of the run, from its seed: random legs on a floor, the four slide legs in a town; and
## the ticks of the room changes.
func _make_walk(walk_seed: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = walk_seed
	_legs = []
	for _i: int in 64:
		var seconds: float = rng.randf_range(LEG_SECONDS_MIN, LEG_SECONDS_MAX)
		var direction: Vector2 = Vector2.RIGHT.rotated(
			TAU * rng.randi_range(0, WALK_DIRECTIONS - 1) / WALK_DIRECTIONS
		)
		_legs.append([maxi(1, roundi(seconds * _rate)), direction])
	_room_changes = _room_changes_of(_scenario, _run_length(_scenario, _rate))


func _floor_direction(tick: int) -> Vector2:
	var total: int = 0
	for leg: Array in _legs:
		total += int(leg[0])
	var at: int = tick % total
	for leg: Array in _legs:
		if at < int(leg[0]):
			return leg[1]
		at -= int(leg[0])
	return Vector2.ZERO


## The slide starts in the south-west corner; a random walk in the corner that its seed names.
func _walk_start(walk_seed: int) -> Vector2:
	var size: Vector2i = town().get_room().get_room_data().get_size()
	var corners: Array[Vector2] = [
		Vector2(SLIDE_MARGIN_TILES, size.y - SLIDE_MARGIN_TILES),
		Vector2(size.x - SLIDE_MARGIN_TILES, size.y - SLIDE_MARGIN_TILES),
		Vector2(size.x - SLIDE_MARGIN_TILES, RANDOM_NORTH_ROW),
		Vector2(SLIDE_MARGIN_TILES, RANDOM_NORTH_ROW),
	]
	return corners[0] if _slide else corners[walk_seed % corners.size()]


## What the player does in a tick: in the town, the four legs of the slide and a dash a second; on a
## floor, towards the nearest living enemy with a swing every third of a second, a dash a second,
## and the HP topped up often (nothing dies of it).
func _commands(tick: int) -> void:
	var dash: bool = tick % _rate == (_rate * 5) / 6
	if town() != null:
		_town_commands(tick)
		return
	var move: Vector2 = _floor_direction(tick)
	if _scenario == Scenario.ROOMS:
		move = CORNER_LEGS[floori(float(tick) / (CORNER_LEG_SECONDS * _rate)) % CORNER_LEGS.size()]
		dash = tick % (_rate / 2) == (_rate * 5) / 12
	var nearest: Enemy = null
	var nearest_gap: float = INF
	for node: Enemy in floor_scene().get_room().get_enemies():
		if not node.logic.is_alive():
			continue
		var gap: float = node.global_position.distance_to(player().global_position)
		if gap < nearest_gap:
			nearest = node
			nearest_gap = gap
	if nearest != null and _scenario != Scenario.ROOMS:
		var to_it: Vector2 = (nearest.global_position - player().global_position).normalized()
		move = (to_it + CHASE_WALK_WEIGHT * move).normalized()
	player().motor.submit(MoveCommand.new(move))
	player().motor.submit(AimCommand.new(move))
	if dash:
		player().motor.submit(DashCommand.new())
	elif _swings(tick, nearest_gap):
		player().motor.submit(AttackCommand.new())
	if tick % maxi(1, _rate / 6) == 0:
		set_hp(max_hp())


## A fight swings six times a second, close to an enemy and late (see SWING_FROM_SECONDS); the
## walk through the rooms, which never chases, swings eight times a second.
func _swings(tick: int, nearest_gap: float) -> bool:
	if _scenario == Scenario.ROOMS:
		return tick % maxi(1, _rate / 8) == 0
	return (
		tick >= roundi(SWING_FROM_SECONDS * _rate)
		and nearest_gap < SWING_RANGE_PX
		and tick % maxi(1, _rate / 6) == 0
	)


func _town_commands(tick: int) -> void:
	var since: int = tick - roundi(FLOOR_SECONDS * _rate)
	var dash: bool = since % (_rate / 2) == (_rate * 5) / 12
	var move: Vector2 = _floor_direction(since)
	if _slide:
		var leg: int = floori(float(since) / (SLIDE_LEG_SECONDS * _rate)) % SLIDE_LEGS.size()
		move = SLIDE_LEGS[leg].normalized()
	if player().motor.get_position_tiles().y < GATE_KEEP_OFF_TILES and move.y < 0.0:
		move.y = -move.y
	player().motor.submit(MoveCommand.new(move))
	player().motor.submit(AimCommand.new(move))
	if dash:
		player().motor.submit(DashCommand.new())


## From the floor to a new town: a death and "Return to town", or a leave by the menu. The test is
## then at the start of a tick of the running town.
func _to_town(scenario: Scenario) -> void:
	if scenario == Scenario.AFTER_DEATH:
		kill_player()
		assert_true(
			await tick_until(
				func() -> bool: return flow().get_state() == ShellFlow.State.DEAD, WAIT_LIMIT_TICKS
			),
			"the death screen is up"
		)
		for _i: int in 3:
			await get_tree().physics_frame
		choose(ShellMenus.RETURN)
	else:
		press_key(ESCAPE)
		choose(ShellMenus.LEAVE)
		choose(ShellMenus.CONFIRM)
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING, "back in the game")
	await wait_for_town()
	await get_tree().physics_frame


# --- the schedules ---


## Ten to fourteen pauses of seeded kinds and lengths, one in each equal part of the run (a pause
## in the middle of nothing can leave no mark; a dense schedule finds the moments that do), the
## first sometimes right after the start; and the ticks around what the scenario changes: the room
## changes (the tick before, the tick of the change, the two after) and the first ticks of a town
## built after a death or a leave.
func _schedule(scenario: Scenario, walk_seed: int, rate: int, length: int) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = walk_seed * SEED_MULTIPLIER + SEED_OFFSET
	var schedule: Dictionary = {}
	var count: int = rng.randi_range(PAUSES_MIN, PAUSES_MAX)
	var span: int = (length - rate / 2) / count
	for index: int in count:
		var tick: int = index * span + rng.randi_range(0, span - 1)
		if index == 0 and rng.randf() < 0.5:
			tick = rng.randi_range(0, 4)  # Right after the start.
		schedule[tick] = _random_pause(rng)
	for change: int in _room_changes_of(scenario, length):
		schedule[change - 1] = [Kind.PLAIN, 2]
		schedule[change] = [rng.randi_range(0, Kind.size() - 1), 3]
		schedule[change + 1] = [Kind.ZERO, 0]
		schedule[change + 2] = [Kind.REPAUSE, 1]
	if scenario == Scenario.AFTER_DEATH or scenario == Scenario.AFTER_LEAVE:
		var town_from: int = roundi(FLOOR_SECONDS * rate)
		schedule[town_from - 2] = [Kind.PLAIN, 3]
		schedule[town_from] = [Kind.PLAIN, 2]
		schedule[town_from + 1] = [Kind.CHAIN, 0]
		schedule[town_from + 3] = [Kind.SETTINGS, 6]
	return schedule


func _room_changes_of(scenario: Scenario, length: int) -> Array[int]:
	var ticks: Array[int] = []
	if scenario == Scenario.ROOMS:
		for fraction: float in ROOM_CHANGES_AT:
			ticks.append(roundi(fraction * length))
	return ticks


func _random_pause(rng: RandomNumberGenerator) -> Array:
	var kind: int = rng.randi_range(0, Kind.size() - 1)
	var frames: int = FRAME_CHOICES[rng.randi_range(0, FRAME_CHOICES.size() - 1)]
	return [kind, frames]


func _schedule_text(schedule: Dictionary) -> String:
	var parts: PackedStringArray = []
	var ticks: Array = schedule.keys()
	ticks.sort()
	for tick: int in ticks:
		parts.append("%d:%s/%d" % [tick, Kind.keys()[schedule[tick][0]], schedule[tick][1]])
	return ", ".join(parts)


# --- one pause ---


## From where the test stands (inside a tick): Escape or pad Start, whatever the kind does while it
## is stopped, and the resume. Leaves the test at the start of the first tick the game runs in.
func _pause(kind: Kind, frames: int) -> void:
	var on_floor: bool = session().get_place() == TowerSession.Place.FLOOR
	match kind:
		Kind.ZERO:
			press_key(ESCAPE)
			press_key(ESCAPE)
		Kind.CHAIN:
			for _i: int in 5:
				press_key(ESCAPE)
				press_key(ESCAPE)
			await wait_for_guard()
			press_key(ESCAPE)
			press_key(ESCAPE)
		Kind.PLAIN:
			press_key(ESCAPE)
			await _wait_ticks(frames)
			press_key(ESCAPE)
		Kind.PAD:
			press_pad(JOY_BUTTON_START)
			await _wait_ticks(frames)
			press_pad(JOY_BUTTON_B)
		Kind.SETTINGS:
			press_key(ESCAPE)
			await _wait_ticks(frames / 3)
			choose(ShellMenus.SETTINGS)
			await _wait_ticks(frames / 3)
			choose(ShellMenus.SHAKE)
			choose(ShellMenus.FULLSCREEN)
			await _wait_ticks(frames / 3)
			choose(ShellMenus.SHAKE)
			choose(ShellMenus.FULLSCREEN)
			choose(ShellMenus.BACK)
			choose(ShellMenus.RESUME)
		Kind.CONFIRM:
			press_key(ESCAPE)
			choose(ShellMenus.LEAVE if on_floor else ShellMenus.QUIT_TO_TITLE)
			await _wait_ticks(frames)
			choose(ShellMenus.CANCEL)
			choose(ShellMenus.RESUME)
		Kind.REPAUSE:
			press_key(ESCAPE)
			await _wait_ticks(frames)
			press_key(ESCAPE)
			await wait_for_guard()
			press_key(ESCAPE)  # In the tick the space still lags behind the game.
			await _wait_ticks(frames)
			press_key(ESCAPE)
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING, "resumed (%s)" % Kind.keys()[kind])
	await wait_for_guard()


func _wait_ticks(ticks: int) -> void:
	for _i: int in ticks:
		await get_tree().physics_frame


# --- what is compared ---


func _shown_room() -> Room:
	return town().get_room() if town() != null else floor_scene().get_room()


func _sim() -> CombatSim:
	return _shown_room().get_runner().get_sim()


## Where the player, the enemies and their projectiles are.
func _positions() -> Array:
	var list: Array = [player().global_position, player().motor.get_position_tiles()]
	for node: Enemy in _shown_room().get_enemies():
		list.append(node.global_position)
		for bolt: ProjectileSet.Projectile in node.logic.get_projectiles().get_projectiles():
			list.append(bolt.position)
	return list


func _first_difference(first: Array, second: Array) -> int:
	for index: int in mini(first.size(), second.size()):
		if first[index] != second[index]:
			return index
	return -1
