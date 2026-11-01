class_name CombatRunner
extends Node
## The only _physics_process that steps logic (AC31). Owns the scene's CombatSim. It must be
## the scene's last child, so every body has run setup() first.

## F-003/C19: the order here is the registration order.
@export var combatant_paths: Array[NodePath] = []

var _sim: CombatSim = CombatSim.new()
var _bodies: Array[CombatBody] = []


func _ready() -> void:
	var tunables: PlayerCombatTunables = Tunables.player_combat
	_sim.setup(tunables.combat_step_rate, tunables)
	for path: NodePath in combatant_paths:
		var body: CombatBody = get_node(path)
		_bodies.append(body)
		_sim.register(body.get_combatant())
		if body is Player:
			_attach_player(body as Player)


func _physics_process(delta: float) -> void:
	for body: CombatBody in _bodies:
		body.submit_commands()
	_sim.tick(delta, _move_bodies.bind(delta))


func get_sim() -> CombatSim:
	return _sim


func _attach_player(player: Player) -> void:
	player.combat_step_rate = _sim.get_step_rate()
	player.data_reloaded.connect(_on_player_data_reloaded)


func _move_bodies(physics_delta: float) -> void:
	for body: CombatBody in _bodies:
		body.move_with_combatant(physics_delta)


func _on_player_data_reloaded(tunables: PlayerCombatTunables) -> void:
	_sim.set_tunables(tunables)
