class_name WaveFixtures
extends RefCounted
## Valid rooms with reinforcements and arrival points, built in code for F-014 tests (no files).
## Built on RoomFixtures; shipped EnemyData only.

## 20 x 12, P at (1, 5), E at (19, 5) and (19, 6). Spawns: `1` at (8, 2), `2` at (13, 7).
## Arrival points `S`, row-major: (16, 3), (6, 4), (6, 9), (16, 9).
const WAVE_ROWS: Array[String] = [
	"####################",
	"#..................#",
	"#.......1..........#",
	"#...............S..#",
	"#.....S............#",
	"#P.................E",
	"#..................E",
	"#............2.....#",
	"#..................#",
	"#.....S.........S..#",
	"#..................#",
	"####################",
]
## `enemies` of wave_room(): `1` is a chaser, `2` a caster.
const REINFORCEMENTS: Array[int] = [1, 2, 1]
## The `S` tiles of WAVE_ROWS, row-major.
const ARRIVAL_TILES: Array[Vector2i] = [
	Vector2i(16, 3), Vector2i(6, 4), Vector2i(6, 9), Vector2i(16, 9)
]

const STEPS_PER_SECOND: int = 120
## Where the rigs put the player: 6.96 tiles from the first arrival point of WAVE_ROWS.
const PLAYER_AT: Vector2 = Vector2(10, 6)
## Placed enemies far from every arrival point of WAVE_ROWS and from PLAYER_AT.
const PLACED_AT: Array[Vector2] = [Vector2(2, 11), Vector2(18, 11), Vector2(2, 1), Vector2(18, 1)]


static func rules() -> FloorTunables:
	return RoomFixtures.rules()


static func wave_rows() -> PackedStringArray:
	return PackedStringArray(WAVE_ROWS)


## WAVE_ROWS with every `S` turned into floor: a room with two spawns and no waves.
static func wave_rows_without_arrival_points() -> PackedStringArray:
	var rows: PackedStringArray = wave_rows()
	for tile: Vector2i in ARRIVAL_TILES:
		rows = RoomFixtures.with_tile(rows, tile.x, tile.y, ".")
	return rows


## The room of WAVE_ROWS: chaser and caster, reinforcements [1, 2, 1], `max_engaged` 0. Valid:
## kill target 5, four arrival points.
static func wave_room(room_id: StringName = &"wave_room") -> RoomData:
	var enemies: Array[EnemyData] = [RoomFixtures.chaser(), RoomFixtures.caster()]
	var data: RoomData = RoomFixtures.room(room_id, wave_rows(), enemies)
	data.reinforcements = PackedInt32Array(REINFORCEMENTS)
	return data


## The same grid and enemies with no reinforcements and no `S`: what the room was before waves.
static func wave_room_without_waves(room_id: StringName = &"no_waves") -> RoomData:
	var enemies: Array[EnemyData] = [RoomFixtures.chaser(), RoomFixtures.caster()]
	return RoomFixtures.room(room_id, wave_rows_without_arrival_points(), enemies)


## A room on `rows` (WAVE_ROWS when omitted) with the given reinforcements and chaser, caster.
static func room_with(
	reinforcements: Array[int], rows: PackedStringArray = PackedStringArray()
) -> RoomData:
	var data: RoomData = wave_room()
	if not rows.is_empty():
		data.rows = rows
	data.reinforcements = PackedInt32Array(reinforcements)
	return data


## The room with one tile of its grid replaced (it is changed in place and returned).
static func set_tile(data: RoomData, x: int, y: int, tile_char: String) -> RoomData:
	data.rows = RoomFixtures.with_tile(data.rows, x, y, tile_char)
	return data


## The room with an `S` on each tile (it is changed in place and returned).
static func add_arrival_points(data: RoomData, tiles: Array[Vector2i]) -> RoomData:
	for tile: Vector2i in tiles:
		set_tile(data, tile.x, tile.y, RoomData.ARRIVAL_POINT)
	return data


## The room with an `S` replaced by floor on each tile (changed in place and returned).
static func remove_arrival_points(data: RoomData, tiles: Array[Vector2i]) -> RoomData:
	for tile: Vector2i in tiles:
		set_tile(data, tile.x, tile.y, RoomData.FLOOR)
	return data


## A boss room on RoomFixtures.valid_rows() (one spawn, a warden): a valid boss room with no waves.
static func boss_room(room_id: StringName = &"boss") -> RoomData:
	return RoomFixtures.valid_boss_room(room_id)


## A safe room on the grid of the town fixture's small room: no spawns, no enemies.
static func safe_room(room_id: StringName = &"safe") -> RoomData:
	return TowerFixtures.safe_room(room_id)


# --- F-014 T3: the director on a real sim ---------------------------------------------------


## One director step by step: registered last on a sim, it samples the director after every
## step's contact. A step is named by the sim clock at its end, in 120ths of a second, so a run at
## any tick rate gives the same numbers. It sits far away on the enemy team, so nothing sees it.
class Recorder:
	extends SimProbe

	const FAR_AWAY: Vector2 = Vector2(10000, 10000)

	## Per step: step, engaged (alive and aggroed), pending (the director's own list), kills.
	var samples: Array[Dictionary] = []
	## Each reinforcement the director started: step, index (in the reserve), id, point (the
	## pending arrival's point; (-1, -1) for one passed over without a warning).
	var starts: Array[Dictionary] = []
	## Each reinforcement that came in: step, id, position.
	var arrivals: Array[Dictionary] = []

	var _sim_ref: WeakRef
	var _waves: RoomWaves
	var _enemies: Array[EnemyLogic] = []
	var _reserve: Array[EnemyLogic] = []
	var _last_next: int = 0
	var _was_waiting: Array[bool] = []

	func _init(
		sim: CombatSim, waves: RoomWaves, placed: Array[EnemyLogic], reserve: Array[EnemyLogic]
	) -> void:
		super(&"wave_recorder")
		_team = Team.ENEMY
		_position = FAR_AWAY
		_sim_ref = weakref(sim)
		_waves = waves
		_enemies.append_array(placed)
		_enemies.append_array(reserve)
		_reserve = reserve
		_last_next = waves.get_next_index()
		for enemy: EnemyLogic in reserve:
			_was_waiting.append(enemy.is_waiting())

	func end_step() -> void:
		var sim: CombatSim = _sim_ref.get_ref() as CombatSim
		var step: int = roundi(sim.get_time() * STEPS_PER_SECOND)
		var engaged: int = 0
		for enemy: EnemyLogic in _enemies:
			if enemy.is_alive() and enemy.is_aggroed():
				engaged += 1
		var pending: Array[RoomWaves.Pending] = _waves.get_pending()
		for index: int in range(_last_next, _waves.get_next_index()):
			var point: Vector2 = Vector2(-1, -1)
			for entry: RoomWaves.Pending in pending:
				if entry.enemy_id == _reserve[index].get_combat_id():
					point = entry.point
			starts.append(
				{
					"step": step,
					"index": index,
					"id": _reserve[index].get_combat_id(),
					"point": point
				}
			)
		_last_next = _waves.get_next_index()
		for index: int in _reserve.size():
			var enemy: EnemyLogic = _reserve[index]
			if _was_waiting[index] and not enemy.is_waiting() and enemy.is_alive():
				arrivals.append(
					{
						"step": step,
						"id": enemy.get_combat_id(),
						"position": enemy.get_position_tiles()
					}
				)
			_was_waiting[index] = enemy.is_waiting()
		(
			samples
			. append(
				{
					"step": step,
					"engaged": engaged,
					"pending": pending.size(),
					"kills": _waves.get_kill_count(),
				}
			)
		)

	## The most engaged-plus-pending of any step.
	func most_on_the_way() -> int:
		var most: int = 0
		for sample: Dictionary in samples:
			most = maxi(most, sample["engaged"] + sample["pending"])
		return most


## A real CombatSim with one player, the placed enemies and then the reserve (held in
## reserve), a RoomWaves attached and a Recorder. The player's HP is refilled before every tick
## unless `heal_player` is off. Placed enemies sleep (aggro radius 0.01) until wake() or a hit.
class Rig:
	extends RefCounted

	var arena: EnemyArena = EnemyArena.new()
	var waves: RoomWaves = RoomWaves.new()
	var rules: FloorTunables = RoomFixtures.rules()
	var player: PlayerMotor
	var placed: Array[EnemyLogic] = []
	var reserve: Array[EnemyLogic] = []
	var points: Array[Vector2] = []
	var recorder: Recorder
	var heal_player: bool = true

	## One tick at `rate`, with the player's commands.
	func tick(
		rate: int = 120,
		move: Vector2 = Vector2.ZERO,
		attack: bool = false,
		aim: Vector2 = Vector2.DOWN
	) -> void:
		if heal_player:
			player.get_combat_state().refill()
		arena.tick(rate, move, false, attack, aim)

	func ticks(count: int, rate: int = 120) -> void:
		for _i: int in count:
			tick(rate)

	## `seconds` of sim time in whole ticks at `rate`.
	func run(seconds: float, rate: int = 120) -> void:
		ticks(roundi(seconds * rate), rate)

	func step_count() -> int:
		return roundi(arena.sim.get_time() * WaveFixtures.STEPS_PER_SECOND)

	func put_player(tiles: Vector2) -> void:
		place(player, tiles)

	## Between ticks: puts a combatant at a position in tiles.
	func place(combatant: Combatant, tiles: Vector2) -> void:
		combatant.sync_position(Units.vector_tiles_to_px(tiles))

	## A hit that does 1 damage: the enemy is aggroed from the next step start (F-004/C5).
	func wake(enemy: EnemyLogic) -> void:
		enemy.apply_hit(_event(enemy, 1), arena.rules)

	## Lethal damage straight on the combat state, as a test's kill() does. It also kills an
	## enemy that is waiting, which apply_hit() would leave alone.
	func kill(enemy: EnemyLogic) -> void:
		var hp: int = enemy.get_combat_state().get_hp()
		enemy.get_combat_state().apply_hit(_event(enemy, hp), arena.rules)

	func _event(enemy: EnemyLogic, damage: int) -> HitEvent:
		var event: HitEvent = HitEvent.new()
		event.attacker_id = &"test"
		event.target_id = enemy.get_combat_id()
		event.damage = damage
		event.direction = Vector2.RIGHT
		return event

	func all_enemies() -> Array[EnemyLogic]:
		var all: Array[EnemyLogic] = []
		all.append_array(placed)
		all.append_array(reserve)
		return all

	func kill_everyone() -> void:
		for enemy: EnemyLogic in all_enemies():
			kill(enemy)


## A rig: `placed_at` placed chasers `chaser_1`..., then `reserve_count` held in reserve,
## the arrival points of WAVE_ROWS, `max_engaged`, and the rules (a copy of the shipped ones
## unless given: change them before the first tick, or pass them in to change the interval).
static func rig(
	placed_at: Array[Vector2],
	reserve_count: int,
	max_engaged: int,
	rules: FloorTunables = null,
	arrival_points: Array[Vector2] = [],
	aggro_radius: float = 0.01,
	player_at: Vector2 = PLAYER_AT
) -> Rig:
	var result: Rig = Rig.new()
	if rules != null:
		result.rules = rules
	result.arena.chaser_data.aggro_radius_tiles = aggro_radius
	result.player = result.arena.add_player(player_at)
	for index: int in placed_at.size():
		result.placed.append(
			result.arena.add_chaser(placed_at[index], StringName("chaser_%d" % (index + 1)))
		)
	result.points = (
		arrival_points if not arrival_points.is_empty() else wave_room().get_arrival_points_tiles()
	)
	for index: int in reserve_count:
		var id: StringName = StringName("chaser_%d" % (placed_at.size() + index + 1))
		var enemy: EnemyLogic = result.arena.add_chaser(result.points[0], id)
		enemy.hold_in_reserve()
		result.reserve.append(enemy)
	result.waves.setup(result.placed, result.reserve, result.points, max_engaged, result.rules)
	result.arena.sim.set_waves(result.waves)
	result.recorder = Recorder.new(result.arena.sim, result.waves, result.placed, result.reserve)
	result.arena.sim.register(result.recorder)
	return result
