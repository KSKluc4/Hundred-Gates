class_name MoveCommand
extends Command
## Movement intent for one tick. Length is the magnitude, already mapped per F-001/C14.

var direction: Vector2


func _init(move_direction: Vector2 = Vector2.ZERO) -> void:
	direction = move_direction
