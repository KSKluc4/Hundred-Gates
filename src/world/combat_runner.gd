class_name CombatRunner
extends Node
## The only _physics_process that steps logic (AC31). Owns the scene's CombatSim. It must be
## the scene's last child, so every body has run setup() first. Also owns the debug scene's
## atomic reload (F-003/C18), the reset (C20) and scene snapshots (C19). Debug calls arrive
## from input, so they act between ticks.


## F-003/C18, F-004/C12: everything one F5 reads, before any of it counts.
class ReloadGroup:
	extends RefCounted
	var class_data: ClassData
	var tunables: PlayerCombatTunables
	var dummy_data: DummyData
	var settings: ScreenShakeSettings
	var enemy_rules: EnemyCombatTunables
	## Path to EnemyData: each distinct file once, however many enemies use it.
	var enemies: Dictionary = {}
	## F-007/C13 (b): path to the file cycle that kept it from loading.
	var cycles: Dictionary = {}


## F-003/C19: the order here is the registration order.
@export var combatant_paths: Array[NodePath] = []
## AC16: only the debug scene refills. Death itself is out of scope (D-006).
@export var refill_player_on_died: bool = false
@export var shake_path: NodePath

var dummy_data_path: String = Tunables.TRAINING_DUMMY_PATH
var shake_settings_path: String = Tunables.SCREEN_SHAKE_PATH
var enemy_combat_path: String = Tunables.ENEMY_COMBAT_PATH

var _sim: CombatSim = CombatSim.new()
var _bodies: Array[CombatBody] = []
var _shake: PlaceholderShake
var _setup_errors: PackedStringArray = []


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
	_stop_if_setup_failed()


func _physics_process(delta: float) -> void:
	for body: CombatBody in _bodies:
		body.submit_commands()
	_sim.tick(delta, _move_bodies.bind(delta))


func get_sim() -> CombatSim:
	return _sim


## F-004/C12: why this scene's fight didn't start. Empty when it did.
func get_setup_errors() -> PackedStringArray:
	return _setup_errors


## F-003/C12: read from the dummies, never stored here, so a restore can't leave it stale.
func is_pulse_on() -> bool:
	for dummy: TrainingDummy in _dummies():
		if dummy.logic.is_pulse_enabled():
			return true
	return false


func is_shake_on() -> bool:
	return _shake != null and _shake.shake_enabled


func has_enemies() -> bool:
	return not _enemies().is_empty()


## F-004/C4: read from the enemies, never stored here, so a restore can't leave it stale.
func is_ai_on() -> bool:
	for enemy: Enemy in _enemies():
		if enemy.logic.is_ai_enabled():
			return true
	return false


func toggle_pulse() -> void:
	var enabled: bool = not is_pulse_on()
	for dummy: TrainingDummy in _dummies():
		dummy.set_pulse_on(enabled)


func toggle_shake() -> void:
	if _shake != null:
		_shake.toggle()


func toggle_ai() -> void:
	var enabled: bool = not is_ai_on()
	for enemy: Enemy in _enemies():
		enemy.logic.set_ai_enabled(enabled)


## F-003/C20, F-004/C15: a fresh setup() on every combatant. Only pulse, shake and AI on/off
## survive.
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


## F-003/C18, F-004/C12: all of it or nothing. Returns the errors, empty when the reload was
## applied.
func reload_data() -> PackedStringArray:
	var player: Player = _players()[0]
	var group: ReloadGroup = _load_group(player)
	var errors: PackedStringArray = _load_errors(player, group)
	if errors.is_empty():
		var rate: int = group.tunables.combat_step_rate
		errors = _validation_errors(group)
		if errors.is_empty() and rate != _sim.get_step_rate():
			errors = _sim.rate_change_errors(rate)
		if errors.is_empty():
			errors = _live_stage_errors(group)
	if errors.is_empty():
		_apply_reload(player, group)
	return errors


func _attach_player(player: Player) -> void:
	player.combat_step_rate = _sim.get_step_rate()
	player.data_reloaded.connect(_on_player_data_reloaded)
	if refill_player_on_died:
		var state: CombatState = player.motor.get_combat_state()
		state.died.connect(state.refill)


## F-004/C12: nothing steps until the files are right. Restarting the scene is the way back.
func _stop_if_setup_failed() -> void:
	_setup_errors = _enemy_setup_errors()
	if _setup_errors.is_empty():
		return
	for error: String in _setup_errors:
		push_error("CombatRunner: %s" % error)
	set_physics_process(false)


## F-004/C12: every enemy against every player's class. An enemy that refused its data has
## nothing to compare, and can't fight either.
func _enemy_setup_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	for enemy: Enemy in _enemies():
		var data: EnemyData = enemy.logic.get_data()
		if data == null:
			errors.append("%s: setup refused its data" % enemy.combat_id)
			continue
		for player: Player in _players():
			for error: String in data.validate_against_class(player.class_data):
				errors.append("%s: %s" % [enemy.combat_id, error])
	return errors


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


func _enemies() -> Array[Enemy]:
	var enemies: Array[Enemy] = []
	for body: CombatBody in _bodies:
		if body is Enemy:
			enemies.append(body as Enemy)
	return enemies


## F-003/C19: damage numbers clear with the dummy's own view.
func _clear_transient_views() -> void:
	if _shake != null:
		_shake.clear()


func _load_group(player: Player) -> ReloadGroup:
	var group: ReloadGroup = ReloadGroup.new()
	group.class_data = Tunables.load_fresh(player.get_class_data_path()) as ClassData
	group.tunables = Tunables.load_fresh(player.tunables_path)
	group.dummy_data = Tunables.load_fresh(dummy_data_path) as DummyData
	group.settings = Tunables.load_fresh(shake_settings_path)
	group.enemy_rules = Tunables.load_fresh(enemy_combat_path) as EnemyCombatTunables
	for enemy: Enemy in _enemies():
		var path: String = enemy.get_data_path()
		if group.enemies.has(path):
			continue
		var cycle: PackedStringArray = Tunables.find_dependency_cycle(path)
		if not cycle.is_empty():
			group.cycles[path] = cycle  # F-007/C13 (b): loading it would never return.
			group.enemies[path] = null
			continue
		group.enemies[path] = Tunables.load_fresh(path) as EnemyData
	return group


func _load_errors(player: Player, group: ReloadGroup) -> PackedStringArray:
	var errors: PackedStringArray = []
	if group.class_data == null:
		errors.append("could not load %s" % player.get_class_data_path())
	if group.tunables == null:
		errors.append("could not load %s" % player.tunables_path)
	if group.dummy_data == null:
		errors.append("could not load %s" % dummy_data_path)
	if group.settings == null:
		errors.append("could not load %s" % shake_settings_path)
	if group.enemy_rules == null:
		errors.append("could not load %s" % enemy_combat_path)
	for path: String in group.enemies:
		if group.cycles.has(path):
			var chain: String = " -> ".join(group.cycles[path])
			errors.append("%s: follow_up files form a cycle: %s" % [path, chain])
		elif group.enemies[path] == null:
			errors.append("could not load %s" % path)
	return errors


## F-003/C18: a reload is checked against its own new rate. F-004/C12: the speed rule compares
## the candidates, so edits to both sides in one F5 count together.
func _validation_errors(group: ReloadGroup) -> PackedStringArray:
	var rate: int = group.tunables.combat_step_rate
	var errors: PackedStringArray = group.class_data.validate()
	errors.append_array(group.class_data.validate_combat(rate))
	errors.append_array(group.tunables.validate())
	errors.append_array(group.tunables.validate_combat())
	errors.append_array(group.dummy_data.validate(rate))
	errors.append_array(group.settings.validate())
	errors.append_array(group.enemy_rules.validate())
	for path: String in group.enemies:
		var data: EnemyData = group.enemies[path]
		for error: String in data.validate(rate, group.enemy_rules):
			errors.append("%s: %s" % [path, error])
		errors.append_array(data.validate_against_class(group.class_data))
	return errors


## F-007/C19: like a rate change a running hit would break, a stage an enemy is in must still
## exist. Checked before anything changes, for every enemy.
func _live_stage_errors(group: ReloadGroup) -> PackedStringArray:
	var errors: PackedStringArray = []
	for enemy: Enemy in _enemies():
		errors.append_array(enemy.logic.reload_errors(group.enemies[enemy.get_data_path()]))
	return errors


func _apply_reload(player: Player, group: ReloadGroup) -> void:
	var rate: int = group.tunables.combat_step_rate
	player.apply_reloaded_data(group.class_data, group.tunables)
	player.combat_step_rate = rate
	for dummy: TrainingDummy in _dummies():
		dummy.apply_reloaded_data(group.dummy_data, rate)
	Tunables.enemy_combat = group.enemy_rules
	for enemy: Enemy in _enemies():
		enemy.apply_reloaded_data(group.enemies[enemy.get_data_path()], group.enemy_rules, rate)
	if _shake != null:
		_shake.apply_settings(group.settings)
	_sim.set_step_rate(rate)


func _on_player_data_reloaded(tunables: PlayerCombatTunables) -> void:
	_sim.set_tunables(tunables)
