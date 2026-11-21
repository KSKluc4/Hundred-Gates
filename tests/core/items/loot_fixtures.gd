class_name LootFixtures
extends RefCounted
## Combatants and characters for the F-016 loot tests (T2): an actor that moves, dies and strikes on
## a script counted in combat steps, and the shortcuts every loot test starts from. Built on
## ItemFixtures and TowerFixtures; no files besides the shipped class and tunables.

## The sim's combat steps per second in these tests, and the physics tick rates they are run at.
const STEP_RATE: int = 120
const TICK_RATES: Array[int] = [30, 60, 120]


## A combatant with hit points that does what a script says, step by step. Steps are counted by the
## actor itself from 1, the first step it takes part in. Nothing moves it but its velocity.
class Actor:
	extends Combatant

	## Tiles per second, applied in every step.
	var velocity: Vector2 = Vector2.ZERO
	## Step number -> Callable, called in that step's step(), before the contact.
	var scripted: Dictionary[int, Callable] = {}
	## Step number -> damage of a 360 degree hit of `reach` tiles at the contact of that step. It is
	## built whatever the actor's hitstop.
	var hits: Dictionary[int, int] = {}
	var reach: float = 0.0
	var steps: int = 0
	## The position at the end of every step it took part in, in order.
	var positions: Array[Vector2] = []

	static func make(id: StringName, team: Team, at: Vector2, hp: int = 100) -> Actor:
		var actor: Actor = Actor.new()
		actor._combat_id = id
		actor._team = team
		actor._position = at
		actor._combat.setup(hp, false)
		return actor

	func step(duration: float) -> void:
		steps += 1
		_position += velocity * duration
		if scripted.has(steps):
			scripted[steps].call()

	func end_step() -> void:
		positions.append(_position)

	## Lethal damage through the combat state, as a hit does it: `died` fires if it was alive.
	func kill() -> void:
		var event: HitEvent = HitEvent.new()
		event.attacker_id = &"test"
		event.target_id = _combat_id
		event.damage = maxi(1, _combat.get_hp())
		_combat.apply_hit(event, Tunables.player_combat)

	## Back to life with `hp` and no signal, so that it can die again.
	func revive(hp: int = 10) -> void:
		_combat.set_hp(hp)

	func place(at: Vector2) -> void:
		_position = at

	func kill_in_step(step_number: int) -> void:
		scripted[step_number] = kill

	func get_live_hitbox() -> Hitbox:
		return _build_live_hitbox()

	func _hurtbox_radius() -> float:
		return 0.5

	func _build_live_hitbox() -> Hitbox:
		if not hits.has(steps):
			return null
		var hitbox: Hitbox = Hitbox.new()
		hitbox.owner_id = _combat_id
		hitbox.team = _team
		hitbox.origin = _position
		hitbox.direction = Vector2.RIGHT
		hitbox.arc_angle_deg = 360.0
		hitbox.range_tiles = reach
		hitbox.damage = hits[steps]
		return hitbox


## An enemy-team actor at `at`.
static func enemy(id: StringName, at: Vector2, hp: int = 100) -> Actor:
	return Actor.make(id, Combatant.Team.ENEMY, at, hp)


## A player-team actor at `at`.
static func player(at: Vector2, hp: int = 100) -> Actor:
	return Actor.make(&"player", Combatant.Team.PLAYER, at, hp)


## A character with `catalog` and `loot_seed`.
static func character(catalog: LootCatalog, loot_seed: int) -> CharacterLoot:
	var character_loot: CharacterLoot = CharacterLoot.new()
	character_loot.setup(catalog, loot_seed)
	return character_loot


## The room `room_index` of floor `floor_number` of `tower`, with the shipped item rules.
static func room_loot(
	character_loot: CharacterLoot, tower: TowerData, floor_number: int, room_index: int
) -> RoomLoot:
	return character_loot.make_room_loot(
		floor_number, tower.get_floor(floor_number), room_index, ItemFixtures.rules()
	)


## A sim at 120 steps per second with `loot` attached and every combatant registered, in order.
static func sim_of(loot: RoomLoot, combatants: Array[Combatant]) -> CombatSim:
	var sim: CombatSim = CombatSim.new()
	sim.setup(STEP_RATE, Tunables.player_combat.duplicate())
	for combatant: Combatant in combatants:
		sim.register(combatant)
	sim.set_loot(loot)
	return sim


## `seconds` of game time in ticks of 1 / `tick_rate` s.
static func run(sim: CombatSim, seconds: float, tick_rate: int) -> void:
	for _i: int in roundi(seconds * tick_rate):
		sim.tick(1.0 / tick_rate)
