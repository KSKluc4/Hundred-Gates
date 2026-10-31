extends RefCounted


func run() -> void:
	get_node("Child").free()
