extends GutTest
## F-011 AC10 and AC9's fall-back on the three brains: with no NavGrid each returns what it
## returned before F-011 (C2), and with one they walk around a wall but never change what they
## attack or when (C3).

const NOT_READY: float = 100.0
const EPSILON: float = 0.000001

## A wall column at x = 5 with a gap in the bottom rows. Row 4 is open all the way across.
const WALLED: PackedStringArray = [
	"############",
	"#....#.....#",
	"#....#.....#",
	"#....#.....#",
	"#....#.....#",
	"#..........#",
	"#..........#",
	"############",
]

## One wall tile at (4, 3): its bottom edge is y = 4, so row y = 4.45 passes 0.45 below it.
const GRAZE: PackedStringArray = [
	"..........",
	"..........",
	"..........",
	"....#.....",
	"..........",
	"..........",
	"..........",
]

## A full-height wall: the right half can't be reached from the left.
const SEALED: PackedStringArray = [
	"....#....",
	"....#....",
	"....#....",
	"....#....",
]

var _arena: BruteArena


func before_each() -> void:
	_arena = BruteArena.new()


# AC10, C2: no NavGrid, the same intent as before -----------------------------------------------


func test_ac10_chaser_without_a_nav_returns_the_old_straight_move() -> void:
	for pair: Array in _positions():
		var arena: BruteArena = BruteArena.new()
		arena.add_player(pair[1])
		var chaser: EnemyLogic = arena.add_chaser(pair[0])
		chaser._aggroed = true
		chaser._cooldown_remaining = NOT_READY
		var intent: EnemyIntent = _decide(ChaserBrain.new(), chaser, arena)
		# The formula as it stood: straight at the target, up to the stop distance.
		var distance: float = pair[0].distance_to(pair[1])
		var gap: float = distance - arena.chaser_data.stop_distance_tiles
		var label: String = str(pair)
		assert_eq(intent.target_id, &"player_1", label)
		assert_false(intent.start_attack, label)
		assert_eq(intent.move_direction, pair[0].direction_to(pair[1]), label)
		assert_eq(intent.max_move_distance, gap if gap > 0.000001 else 0.0, label)


func test_ac10_brute_without_a_nav_returns_the_old_straight_move() -> void:
	for pair: Array in _positions():
		var arena: BruteArena = BruteArena.new()
		arena.add_player(pair[1])
		var brute: EnemyLogic = arena.add_brute(pair[0])
		brute._aggroed = true
		brute._cooldown_remaining = NOT_READY
		var intent: EnemyIntent = _decide(BruteBrain.new(), brute, arena)
		var distance: float = pair[0].distance_to(pair[1])
		var stop: float = arena.brute_data.stop_distance_tiles
		var direction: Vector2 = pair[0].direction_to(pair[1])
		var label: String = str(pair)
		assert_eq(intent.target_id, &"player_1", label)
		assert_false(intent.start_attack, label)
		if direction != Vector2.ZERO and distance > stop + 0.000001:
			assert_eq(intent.move_direction, direction, label)
			assert_eq(intent.max_move_distance, distance - stop, label)
		else:
			assert_eq(intent.move_direction, Vector2.ZERO, label)
			assert_eq(intent.max_move_distance, 0.0, label)


func test_ac10_caster_without_a_nav_returns_the_old_straight_move() -> void:
	for pair: Array in _positions():
		var arena: BruteArena = BruteArena.new()
		arena.add_player(pair[1])
		var caster: EnemyLogic = arena.add_caster(pair[0])
		caster._aggroed = true
		caster._cooldown_remaining = NOT_READY
		var intent: EnemyIntent = _decide(CasterBrain.new(), caster, arena)
		var distance: float = pair[0].distance_to(pair[1])
		var data: EnemyData = arena.caster_data
		var direction: Vector2 = pair[0].direction_to(pair[1])
		var label: String = str(pair)
		assert_eq(intent.target_id, &"player_1", label)
		assert_false(intent.start_attack, label)
		if direction == Vector2.ZERO:
			assert_eq(intent.move_direction, Vector2.ZERO, label)
			assert_eq(intent.max_move_distance, 0.0, label)
		elif distance < data.retreat_distance_tiles - 0.000001:
			assert_eq(intent.move_direction, -direction, label)
			assert_eq(intent.max_move_distance, data.retreat_distance_tiles - distance, label)
		elif distance > data.stop_distance_tiles + 0.000001:
			assert_eq(intent.move_direction, direction, label)
			assert_eq(intent.max_move_distance, distance - data.stop_distance_tiles, label)
		else:
			assert_eq(intent.move_direction, direction, label)
			assert_eq(intent.max_move_distance, 0.0, label)


func test_ac10_attack_choice_without_a_nav_is_unchanged() -> void:
	for distance: float in [1.0, 1.6, 3.0, 5.0, 7.0]:
		for kind: int in 3:
			var arena: BruteArena = BruteArena.new()
			arena.add_player(Vector2.ZERO)
			var enemy: EnemyLogic = _add_kind(arena, kind, Vector2(0, distance))
			enemy._aggroed = true
			var intent: EnemyIntent = _decide(_brain_of(kind), enemy, arena)
			var expected: int = EnemyBrain.pick_attack_in(enemy.get_current_attacks(), distance)
			var label: String = "kind %d at %s" % [kind, distance]
			assert_eq(intent.start_attack, expected >= 0, label)
			if expected >= 0:
				assert_eq(intent.attack_index, expected, label)


func test_ac10_a_view_without_a_nav_has_none_and_capture_takes_it_as_an_option() -> void:
	_arena.add_player(Vector2.ZERO)
	var combatants: Array[Combatant] = _arena.sim.get_combatants()
	assert_null(CombatView.capture(combatants).nav)
	assert_null(CombatView.capture(combatants, null).nav)
	var grid: NavGrid = NavGrid.from_rows(WALLED)
	assert_eq(CombatView.capture(combatants, grid).nav, grid)


# AC10: routing when a wall is between --------------------------------------------------------


func test_ac10_chaser_follows_the_grid_when_a_wall_is_between() -> void:
	var grid: NavGrid = NavGrid.from_rows(WALLED)
	var own: Vector2 = Vector2(3.5, 2.5)
	var target: Vector2 = Vector2(6.5, 2.5)
	var intent: EnemyIntent = _chaser_intent(grid, own, target)
	assert_eq(intent.move_direction, grid.direction_toward(own, target))
	assert_ne(intent.move_direction, own.direction_to(target), "not the straight line")
	assert_ne(intent.move_direction, Vector2.ZERO)
	assert_eq(intent.target_id, &"player_1")
	assert_false(intent.start_attack)


func test_ac10_brute_follows_the_grid_when_a_wall_is_between() -> void:
	var grid: NavGrid = NavGrid.from_rows(WALLED)
	var own: Vector2 = Vector2(3.5, 2.5)
	var target: Vector2 = Vector2(6.5, 2.5)
	var intent: EnemyIntent = _brute_intent(grid, own, target)
	assert_eq(intent.move_direction, grid.direction_toward(own, target))
	assert_ne(intent.move_direction, own.direction_to(target))
	assert_false(intent.start_attack)


func test_ac10_caster_walks_in_by_the_grid_when_a_wall_is_between() -> void:
	var grid: NavGrid = NavGrid.from_rows(WALLED)
	var own: Vector2 = Vector2(1.5, 2.5)  # 7 tiles from the target: past its 6 tile stop distance.
	var target: Vector2 = Vector2(8.5, 2.5)
	var intent: EnemyIntent = _caster_intent(grid, own, target)
	assert_eq(intent.move_direction, grid.direction_toward(own, target))
	assert_ne(intent.move_direction, own.direction_to(target))
	assert_almost_eq(intent.max_move_distance, 1.0, EPSILON, "straight gap still caps the move")


func test_ac10_caster_still_retreats_straight_away_with_a_wall_between() -> void:
	var grid: NavGrid = NavGrid.from_rows(WALLED)
	var own: Vector2 = Vector2(4.5, 2.5)  # 2 tiles from the target: inside its 3 tile retreat.
	var target: Vector2 = Vector2(6.5, 2.5)
	assert_false(grid.has_clear_line(own, target, 0.35), "the wall is between them")
	var intent: EnemyIntent = _caster_intent(grid, own, target)
	assert_eq(intent.move_direction, Vector2.LEFT, "straight away from the target")
	assert_almost_eq(intent.max_move_distance, 1.0, EPSILON)


func test_ac10_caster_holds_in_its_band_even_with_a_wall_between() -> void:
	var grid: NavGrid = NavGrid.from_rows(WALLED)
	var own: Vector2 = Vector2(2.5, 2.5)  # 4 tiles: inside 3 to 6.
	var intent: EnemyIntent = _caster_intent(grid, own, Vector2(6.5, 2.5))
	assert_eq(intent.move_direction, own.direction_to(Vector2(6.5, 2.5)))
	assert_eq(intent.max_move_distance, 0.0)


func test_ac10_with_a_clear_line_every_brain_walks_straight() -> void:
	var grid: NavGrid = NavGrid.from_rows(WALLED)
	var own: Vector2 = Vector2(7.5, 2.5)
	var target: Vector2 = Vector2(9.5, 5.5)
	var straight: Vector2 = own.direction_to(target)
	assert_eq(_chaser_intent(grid, own, target).move_direction, straight)
	assert_eq(_brute_intent(grid, own, target).move_direction, straight)
	var caster_own: Vector2 = Vector2(6.5, 1.5)
	var caster_target: Vector2 = Vector2(10.5, 6.5)
	var caster_move: Vector2 = _caster_intent(grid, caster_own, caster_target).move_direction
	assert_eq(caster_move, caster_own.direction_to(caster_target))


func test_ac10_the_enemys_own_radius_decides_whether_the_line_is_clear() -> void:
	# Row y = 4.45 passes 0.45 below the wall: clear for a 0.4 body, blocked for a 0.6 one.
	var grid: NavGrid = NavGrid.from_rows(GRAZE)
	var own: Vector2 = Vector2(1.5, 4.45)
	var target: Vector2 = Vector2(7.5, 4.45)
	assert_eq(_chaser_intent(grid, own, target).move_direction, Vector2.RIGHT, "radius 0.4")
	var brute_direction: Vector2 = _brute_intent(grid, own, target).move_direction
	assert_eq(brute_direction, grid.direction_toward(own, target), "radius 0.6")
	assert_ne(brute_direction, Vector2.RIGHT)


# AC9: no path falls back to straight -----------------------------------------------------------


func test_ac9_a_sealed_off_target_falls_back_to_the_straight_direction() -> void:
	var grid: NavGrid = NavGrid.from_rows(SEALED)
	var own: Vector2 = Vector2(2.5, 1.5)
	var target: Vector2 = Vector2(6.5, 1.5)
	assert_eq(grid.direction_toward(own, target), Vector2.ZERO)
	assert_eq(_chaser_intent(grid, own, target).move_direction, Vector2.RIGHT)
	assert_eq(_brute_intent(grid, own, target).move_direction, Vector2.RIGHT)
	assert_eq(
		_caster_intent(grid, Vector2(0.5, 1.5), Vector2(8.5, 1.5)).move_direction, Vector2.RIGHT
	)


func test_ac9_steer_is_the_straight_direction_without_a_nav() -> void:
	_arena.add_player(Vector2(3, 4))
	var enemy: EnemyLogic = _arena.add_chaser(Vector2(0, 0))
	var view: CombatView = CombatView.capture(_arena.sim.get_combatants())
	assert_eq(EnemyBrain.steer(view, enemy, Vector2(3, 4)), Vector2(0.6, 0.8))
	assert_eq(EnemyBrain.steer(view, enemy, Vector2.ZERO), Vector2.ZERO, "on the spot")


# C3: routing never changes what the enemy does or whom it picks -------------------------------


func test_c3_attack_choice_ignores_the_nav() -> void:
	var grid: NavGrid = NavGrid.from_rows(WALLED)
	var own: Vector2 = Vector2(3.5, 2.5)
	var target: Vector2 = Vector2(6.5, 2.5)  # 3 tiles, a wall between.
	for kind: int in 3:
		var with_nav: EnemyIntent = _ready_intent(kind, grid, own, target)
		var without: EnemyIntent = _ready_intent(kind, null, own, target)
		var label: String = "kind %d" % kind
		assert_eq(with_nav.start_attack, without.start_attack, label)
		assert_eq(with_nav.attack_index, without.attack_index, label)
		assert_eq(with_nav.target_id, without.target_id, label)


func test_c3_aggro_and_target_pick_ignore_the_nav() -> void:
	var grid: NavGrid = NavGrid.from_rows(WALLED)
	var arena: BruteArena = BruteArena.new()
	arena.add_player(Vector2(6.5, 2.5), &"player_1")  # Behind the wall, 3 tiles.
	arena.add_player(Vector2(1.5, 6.5), &"player_2")  # In the open, 4.5 tiles.
	var chaser: EnemyLogic = arena.add_chaser(Vector2(3.5, 2.5))
	chaser._cooldown_remaining = NOT_READY
	var plain: EnemyIntent = ChaserBrain.new().decide(
		chaser, CombatView.capture(arena.sim.get_combatants())
	)
	var routed: EnemyIntent = ChaserBrain.new().decide(
		chaser, CombatView.capture(arena.sim.get_combatants(), grid)
	)
	assert_eq(plain.target_id, &"player_1", "the nearest as the crow flies")
	assert_eq(routed.target_id, &"player_1", "still the same player")
	# A far player stays out of aggro whatever the grid says.
	var far: BruteArena = BruteArena.new()
	far.add_player(Vector2(10.5, 6.5))
	var sleeper: EnemyLogic = far.add_chaser(Vector2(1.5, 1.5))
	var idle: EnemyIntent = ChaserBrain.new().decide(
		sleeper, CombatView.capture(far.sim.get_combatants(), grid)
	)
	assert_false(idle.has_target())


func _ready_intent(kind: int, grid: NavGrid, own: Vector2, target: Vector2) -> EnemyIntent:
	var arena: BruteArena = BruteArena.new()
	arena.add_player(target)
	var enemy: EnemyLogic = _add_kind(arena, kind, own)
	enemy._aggroed = true
	return _brain_of(kind).decide(enemy, CombatView.capture(arena.sim.get_combatants(), grid))


func _chaser_intent(grid: NavGrid, own: Vector2, target: Vector2) -> EnemyIntent:
	var arena: BruteArena = BruteArena.new()
	arena.add_player(target)
	var chaser: EnemyLogic = arena.add_chaser(own)
	chaser._aggroed = true
	chaser._cooldown_remaining = NOT_READY
	return ChaserBrain.new().decide(chaser, CombatView.capture(arena.sim.get_combatants(), grid))


func _brute_intent(grid: NavGrid, own: Vector2, target: Vector2) -> EnemyIntent:
	var arena: BruteArena = BruteArena.new()
	arena.add_player(target)
	var brute: EnemyLogic = arena.add_brute(own)
	brute._aggroed = true
	brute._cooldown_remaining = NOT_READY
	return BruteBrain.new().decide(brute, CombatView.capture(arena.sim.get_combatants(), grid))


func _caster_intent(grid: NavGrid, own: Vector2, target: Vector2) -> EnemyIntent:
	var arena: BruteArena = BruteArena.new()
	arena.add_player(target)
	var caster: EnemyLogic = arena.add_caster(own)
	caster._aggroed = true
	caster._cooldown_remaining = NOT_READY
	return CasterBrain.new().decide(caster, CombatView.capture(arena.sim.get_combatants(), grid))


## Where the old tests put things: along an axis, diagonal, far, on the spot and at the bands.
func _positions() -> Array:
	return [
		[Vector2(0, 0), Vector2(0, 5)],
		[Vector2(0, 5), Vector2(0, 0)],
		[Vector2(2, 3), Vector2(5, 7)],
		[Vector2(-1.5, 2), Vector2(2.5, -1)],
		[Vector2(3, 3), Vector2(3, 3)],
		[Vector2(0, 0), Vector2(0, 0.5)],
		[Vector2(0, 0), Vector2(0, 1.5)],
		[Vector2(0, 0), Vector2(0, 2.5)],
		[Vector2(0, 0), Vector2(0, 3.5)],
		[Vector2(0, 0), Vector2(0, 6.0)],
		[Vector2(0, 0), Vector2(0, 6.5)],
		[Vector2(1, 1), Vector2(1 + 4.5, 1 + 3.0)],
	]


func _add_kind(arena: BruteArena, kind: int, position: Vector2) -> EnemyLogic:
	match kind:
		0:
			return arena.add_chaser(position)
		1:
			return arena.add_caster(position)
	return arena.add_brute(position)


func _brain_of(kind: int) -> EnemyBrain:
	match kind:
		0:
			return ChaserBrain.new()
		1:
			return CasterBrain.new()
	return BruteBrain.new()


func _decide(brain: EnemyBrain, enemy: EnemyLogic, arena: BruteArena) -> EnemyIntent:
	return brain.decide(enemy, CombatView.capture(arena.sim.get_combatants()))
