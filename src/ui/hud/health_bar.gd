class_name HealthBar
extends Control
## F-012/C13: the player's HP bar and its text. Asks `player_provider` for the player on every
## frame and every call, and reads HP from that player's CombatState, so a room swap (the player
## node is rebuilt every room) or a freed player can't leave it stale. Decides nothing (G6):
## nothing reads it. The look → Art & Game Feel (§10 Q4).

## F-012/C16: the one place the text is built.
const LABEL_FORMAT: String = "HP %d / %d"

@export var bar_size_px: Vector2 = Vector2(96, 10)
@export var back_color: Color = Color(0.15, 0.15, 0.15, 0.9)
@export var fill_color: Color = Color(0.3, 0.75, 0.35)
@export var label_font_size: int = 8

## () -> Player. May return null (no player yet, or between rooms). An unset Callable counts as
## null.
var player_provider: Callable

@onready var _label: Label = $Label


func _ready() -> void:
	custom_minimum_size = bar_size_px
	_label.size = bar_size_px
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override(&"font_size", label_font_size)


func _process(_delta: float) -> void:
	_label.text = get_label_text()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, bar_size_px), back_color)
	var filled: Vector2 = Vector2(bar_size_px.x * get_fill_fraction(), bar_size_px.y)
	draw_rect(Rect2(Vector2.ZERO, filled), fill_color)


## HP left, 0-1. 0 with no player.
func get_fill_fraction() -> float:
	var state: CombatState = _get_state()
	if state == null or state.get_max_hp() <= 0:
		return 0.0
	return clampf(float(state.get_hp()) / float(state.get_max_hp()), 0.0, 1.0)


## `HP 70 / 100`. Empty with no player.
func get_label_text() -> String:
	var state: CombatState = _get_state()
	if state == null:
		return ""
	return LABEL_FORMAT % [state.get_hp(), state.get_max_hp()]


## F-012/C13: null for an unset provider, a null answer or a freed player.
func _get_state() -> CombatState:
	if not player_provider.is_valid():
		return null
	var answer: Variant = player_provider.call()
	if not is_instance_valid(answer):
		return null
	var player: Player = answer as Player
	if player == null or player.motor == null:
		return null
	return player.motor.get_combat_state()
