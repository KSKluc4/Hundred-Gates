extends GutTest
## AC1: views re-sync from state after a restore (C12), on the real nodes in a scene.

const SCENE: PackedScene = preload("res://scenes/debug/f001_movement.tscn")
const IFRAME_END_TICKS: int = 12

var _player: Player


func test_ac1_tint_comes_back_when_restoring_into_i_frames() -> void:
	await _spawn()
	await _run_ticks(2, true)
	assert_true(_player.motor.is_invulnerable(), "the snapshot is taken during i-frames")
	var snapshot: Dictionary = _player.motor.to_dict()
	await _run_ticks(IFRAME_END_TICKS)
	assert_false(_player.motor.is_invulnerable())
	assert_eq(_player.modulate, Color.WHITE)

	_player.restore_snapshot(snapshot)

	assert_eq(_player.modulate, _player.iframe_tint)


func test_ac1_tint_goes_away_when_restoring_out_of_i_frames() -> void:
	await _spawn()
	var snapshot: Dictionary = _player.motor.to_dict()
	await _run_ticks(2, true)
	assert_eq(_player.modulate, _player.iframe_tint)

	_player.restore_snapshot(snapshot)

	assert_eq(_player.modulate, Color.WHITE)


func _spawn() -> void:
	var scene: Node = SCENE.instantiate()
	_player = scene.get_node("Player")
	_player.input_enabled = false
	add_child_autofree(scene)
	await get_tree().physics_frame  # _run_ticks must start just before a Player tick.


## One Player tick per iteration. dash: press on the first one.
func _run_ticks(ticks: int, dash: bool = false) -> void:
	for index: int in ticks:
		_player.motor.submit(MoveCommand.new(Vector2.ZERO))
		_player.motor.submit(AimCommand.new(Vector2.ZERO))
		if dash and index == 0:
			_player.motor.submit(DashCommand.new())
		await get_tree().physics_frame
