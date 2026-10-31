class_name AimCommand
extends Command
## Aim intent for one tick. Unit vector, or zero when there is no aim (F-001/C16).

var direction: Vector2


func _init(aim_direction: Vector2 = Vector2.ZERO) -> void:
	direction = aim_direction
