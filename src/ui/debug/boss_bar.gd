class_name BossBar
extends Control
## F-007/C17: placeholder screen-space boss bar for the debug scenes. HP, a mark at each
## stage's HP percent, and a cue during the stage shift. Reads the boss's logic through
## getters every frame, so a reset, reload or restore can't leave it stale. Nothing reads it.
## The look → Art & Game Feel (§10 Q3).

@export var boss: Enemy
@export var bar_size_px: Vector2 = Vector2(200, 6)
@export var back_color: Color = Color(0.15, 0.15, 0.15, 0.9)
@export var fill_color: Color = Color(0.85, 0.25, 0.25)
@export var mark_color: Color = Color(1.0, 1.0, 1.0, 0.9)
## The stage shift cue: the bar's outline and its label.
@export var shift_color: Color = Color(0.75, 0.4, 0.95)
@export var outline_width_px: float = 1.0
@export var mark_width_px: float = 1.0

@onready var _label: Label = $Label


func _process(_delta: float) -> void:
	_label.text = get_label_text()
	_label.modulate = shift_color if is_shift_cue_on() else Color.WHITE
	queue_redraw()


func _draw() -> void:
	if boss == null or boss.logic.get_data() == null:
		return
	draw_rect(Rect2(Vector2.ZERO, bar_size_px), back_color)
	var filled: Vector2 = Vector2(bar_size_px.x * get_fill_fraction(), bar_size_px.y)
	draw_rect(Rect2(Vector2.ZERO, filled), fill_color)
	for mark: float in get_marks():
		var x: float = bar_size_px.x * mark
		draw_line(Vector2(x, 0), Vector2(x, bar_size_px.y), mark_color, mark_width_px)
	if is_shift_cue_on():
		draw_rect(Rect2(Vector2.ZERO, bar_size_px), shift_color, false, outline_width_px)


## HP left, 0-1.
func get_fill_fraction() -> float:
	return boss.get_hp_fraction()


## Each stage's line as a fraction of the bar, in stage order.
func get_marks() -> Array[float]:
	var marks: Array[float] = []
	for stage: EnemyStageData in boss.logic.get_data().stages:
		marks.append(stage.enter_at_hp_percent / 100.0)
	return marks


func is_shift_cue_on() -> bool:
	return boss.logic.get_state() == EnemyLogic.State.STAGE_SHIFT


func get_label_text() -> String:
	var logic: EnemyLogic = boss.logic
	if logic.get_data() == null:
		return ""
	var state: CombatState = logic.get_combat_state()
	var text: String = (
		"%s  %d / %d  stage %d"
		% [logic.get_data().id, state.get_hp(), state.get_max_hp(), logic.get_stage_index() + 1]
	)
	if is_shift_cue_on():
		text += "  STAGE SHIFT"
	return text
