class_name CombatRunner
extends Node
## The only _physics_process that steps logic (AC31). Owns the scene's CombatSim. It must be
## the scene's last child, so every body has run setup() first. Also owns the debug scene's
## atomic reload (F-003/C18), the reset (C20) and scene snapshots (C19). Debug calls arrive
## from input, so they act between ticks.

## F-003/C19: the order here is the registration order.
@export var combatant_paths: Array[NodePath] = []
## AC16: only the debug scene refills. Death itself is out of scope (D-006).
@export var refill_player_on_died: bool = false
@export var shake_path: NodePath

var dummy_data_path: String = Tunables.TRAINING_DUMMY_PATH
var shake_settings_path: String = Tunables.SCREEN_SHAKE_PATH

var _sim: CombatSim = CombatSim.new()
var _bodies: Array[CombatBody] = []
var _pulse_on: bool = false
var _shake: PlaceholderShake


func _ready() -> void:
	var tunables: PlayerCombatTunables = Tunables.player_combat
	_sim.setup(tunables.combat_step_rate, tunables)
	if not shake_path.is_empty():
		_shake = get_node(shake_path)
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


func is_pulse_on() -> bool:
	return _pulse_on


func is_shake_on() -> bool:
	return _shake != null and _shake.shake_enabled


func toggle_pulse() -> void:
	_pulse_on = not _pulse_on
	for dummy: TrainingDummy in _dummies():
		dummy.set_pulse_on(_pulse_on)


func toggle_shake() -> void:
	if _shake != null:
		_shake.toggle()


## F-003/C20: a fresh setup() on every combatant. Only pulse and shake on/off survive.
func reset() -> void:
	for body: CombatBody in _bodies:
		body.reset_to_start()
	_clear_transient_views()


func take_snapshot() -> Dictionary:
	return _sim.to_dict()


## F-003/C19: valid only at the snapshot boundary, which is where debug calls arrive.
func restore_snapshot(snapshot: Dictionary) -> bool:
	if not _sim.from_dict(snapshot):
		return false
	for body: CombatBody in _bodies:
		body.sync_body_from_logic()
	_clear_transient_views()
	return true


## F-003/C18: all of it or nothing. Returns the errors, empty when the reload was applied.
func reload_data() -> PackedStringArray:
	var player: Player = _players()[0]
	var class_data: ClassData = Tunables.load_fresh(player.get_class_data_path()) as ClassData
	var tunables: PlayerCombatTunables = Tunables.load_fresh(player.tunables_path)
	var dummy_data: DummyData = Tunables.load_fresh(dummy_data_path) as DummyData
	var settings: ScreenShakeSettings = Tunables.load_fresh(shake_settings_path)

	var errors: PackedStringArray = _load_errors(player, class_data, tunables, dummy_data, settings)
	if errors.is_empty():
		var rate: int = tunables.combat_step_rate
		errors = _validation_errors(class_data, tunables, dummy_data, settings)
		if errors.is_empty() and rate != _sim.get_step_rate():
			errors = _sim.rate_change_errors(rate)
	if errors.is_empty():
		_apply_reload(player, class_data, tunables, dummy_data, settings)
	return errors


func _attach_player(player: Player) -> void:
	player.combat_step_rate = _sim.get_step_rate()
	player.data_reloaded.connect(_on_player_data_reloaded)
	if refill_player_on_died:
		var state: CombatState = player.motor.get_combat_state()
		state.died.connect(state.refill)


func _move_bodies(physics_delta: float) -> void:
	for body: CombatBody in _bodies:
		body.move_with_combatant(physics_delta)


func _players() -> Array[Player]:
	var players: Array[Player] = []
	for body: CombatBody in _bodies:
		if body is Player:
			players.append(body as Player)
	return players


func _dummies() -> Array[TrainingDummy]:
	var dummies: Array[TrainingDummy] = []
	for body: CombatBody in _bodies:
		if body is TrainingDummy:
			dummies.append(body as TrainingDummy)
	return dummies


## F-003/C19: damage numbers clear with the dummy's own view.
func _clear_transient_views() -> void:
	if _shake != null:
		_shake.clear()


func _load_errors(
	player: Player,
	class_data: ClassData,
	tunables: PlayerCombatTunables,
	dummy_data: DummyData,
	settings: ScreenShakeSettings
) -> PackedStringArray:
	var errors: PackedStringArray = []
	if class_data == null:
		errors.append("could not load %s" % player.get_class_data_path())
	if tunables == null:
		errors.append("could not load %s" % player.tunables_path)
	if dummy_data == null:
		errors.append("could not load %s" % dummy_data_path)
	if settings == null:
		errors.append("could not load %s" % shake_settings_path)
	return errors


## F-003/C18: a reload is checked against its own new rate.
func _validation_errors(
	class_data: ClassData,
	tunables: PlayerCombatTunables,
	dummy_data: DummyData,
	settings: ScreenShakeSettings
) -> PackedStringArray:
	var rate: int = tunables.combat_step_rate
	var errors: PackedStringArray = class_data.validate()
	errors.append_array(class_data.validate_combat(rate))
	errors.append_array(tunables.validate())
	errors.append_array(tunables.validate_combat())
	errors.append_array(dummy_data.validate(rate))
	errors.append_array(settings.validate())
	return errors


func _apply_reload(
	player: Player,
	class_data: ClassData,
	tunables: PlayerCombatTunables,
	dummy_data: DummyData,
	settings: ScreenShakeSettings
) -> void:
	var rate: int = tunables.combat_step_rate
	player.apply_reloaded_data(class_data, tunables)
	player.combat_step_rate = rate
	for dummy: TrainingDummy in _dummies():
		dummy.apply_reloaded_data(dummy_data, rate)
	if _shake != null:
		_shake.apply_settings(settings)
	_sim.set_step_rate(rate)


func _on_player_data_reloaded(tunables: PlayerCombatTunables) -> void:
	_sim.set_tunables(tunables)
