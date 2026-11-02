class_name DamageNumbers
extends Node2D
## Floating numbers over a dummy (AC20). Placeholder look (→ Art & Game Feel, Q1). Transient
## presentation: never saved, and a restore clears them (F-003/C19).

@export var lifetime: float = 0.7
@export var rise_px: float = 20.0
@export var font_size: int = 8
@export var finisher_font_size: int = 16
@export var finisher_color: Color = Color(1.0, 0.8, 0.2)

var _labels: Array[Label] = []
var _ages: Array[float] = []


func _process(delta: float) -> void:
	for index: int in range(_labels.size() - 1, -1, -1):
		_ages[index] += delta
		_labels[index].position.y -= rise_px * delta / lifetime
		if _ages[index] >= lifetime:
			_labels[index].queue_free()
			_labels.remove_at(index)
			_ages.remove_at(index)


func listen_to(state: CombatState) -> void:
	state.damaged.connect(_on_damaged)


func get_labels() -> Array[Label]:
	return _labels


func clear() -> void:
	for label: Label in _labels:
		label.queue_free()
	_labels.clear()
	_ages.clear()


func _on_damaged(event: HitEvent) -> void:
	var label: Label = Label.new()
	label.text = str(event.damage)
	label.add_theme_font_size_override(
		"font_size", finisher_font_size if event.is_finisher else font_size
	)
	if event.is_finisher:
		label.add_theme_color_override("font_color", finisher_color)
	add_child(label)
	_labels.append(label)
	_ages.append(0.0)
