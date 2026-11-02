extends GutTest
## AC31: CombatRunner is the only thing that steps logic, in F-001's scene too.

const F001_SCENE: PackedScene = preload("res://scenes/debug/f001_movement.tscn")

var _ticks_per_second_before: int


func before_each() -> void:
	_ticks_per_second_before = Engine.physics_ticks_per_second


func after_each() -> void:
	Engine.physics_ticks_per_second = _ticks_per_second_before


func test_ac31_exact_steps_per_physics_tick_at_every_rate() -> void:
	for sample: Array in [[30, 4], [60, 2], [120, 1]]:
		Engine.physics_ticks_per_second = sample[0]
		var scene: Node = await _spawn()
		var probe: SimProbe = SimProbe.new()
		_runner(scene).get_sim().register(probe)
		await get_tree().physics_frame
		await get_tree().physics_frame  # Each await spans one whole tick from here on.
		var before: int = probe.steps
		await get_tree().physics_frame
		assert_eq(probe.steps - before, sample[1], "%d ticks/s" % sample[0])
		scene.queue_free()


func test_ac31_player_has_no_tick_of_its_own() -> void:
	var scene: Node = await _spawn()
	var player: Player = scene.get_node("Player")
	assert_false(player.is_physics_processing())
	assert_false(player.has_method("_physics_process"))


func test_ac31_the_runner_ticks_the_player_it_registered() -> void:
	var scene: Node = await _spawn()
	var runner: CombatRunner = _runner(scene)
	var player: Player = scene.get_node("Player")
	assert_true(runner.get_sim().get_combatants().has(player.motor))
	assert_eq(runner.get_sim().get_step_rate(), Tunables.player_combat.combat_step_rate)
	assert_eq(player.motor.get_combat_id(), &"player_1")
	var clock: float = player.motor.to_dict()["time"]
	await get_tree().physics_frame
	assert_gt(player.motor.to_dict()["time"], clock)


func test_ac31_a_press_reaches_the_motor_once_per_tick() -> void:
	var scene: Node = await _spawn()
	var player: Player = scene.get_node("Player")
	player.input_enabled = false
	watch_signals(player.motor)
	player.motor.submit(DashCommand.new())
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_signal_emit_count(player.motor, "dash_started", 1)


func test_c18_reload_data_rejects_another_step_rate_and_leaves_the_sim_alone() -> void:
	var scene: Node = await _spawn()
	var player: Player = scene.get_node("Player")
	var path: String = "user://test_f003_runner_rules.tres"
	var rules: PlayerCombatTunables = Tunables.player_combat.duplicate()
	rules.combat_step_rate = 240
	assert_eq(ResourceSaver.save(rules, path), OK)
	var before: PlayerCombatTunables = Tunables.player_combat
	player.tunables_path = path
	var errors: PackedStringArray = player.reload_data()
	DirAccess.remove_absolute(path)
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "combat_step_rate")
	assert_eq(_runner(scene).get_sim().get_step_rate(), 120)
	assert_eq(Tunables.player_combat, before, "nothing changed")


func test_c18_reload_data_gives_the_sim_the_new_rules() -> void:
	var scene: Node = await _spawn()
	var player: Player = scene.get_node("Player")
	var path: String = "user://test_f003_runner_rules.tres"
	var rules: PlayerCombatTunables = Tunables.player_combat.duplicate()
	rules.hitstop_normal = 0.2
	assert_eq(ResourceSaver.save(rules, path), OK)
	var before: PlayerCombatTunables = Tunables.player_combat
	player.tunables_path = path
	var errors: PackedStringArray = player.reload_data()
	DirAccess.remove_absolute(path)
	assert_eq(errors.size(), 0)
	Tunables.player_combat = before
	assert_eq(_runner(scene).get_sim().get_tunables().hitstop_normal, 0.2)


func _runner(scene: Node) -> CombatRunner:
	return scene.get_node("CombatRunner")


func _spawn() -> Node:
	var scene: Node = F001_SCENE.instantiate()
	(scene.get_node("Player") as Player).input_enabled = false
	add_child_autofree(scene)
	await get_tree().physics_frame
	return scene
