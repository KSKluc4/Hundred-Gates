class_name TrainingDummy
extends CombatBody
## Glue and placeholder view for DummyLogic (F-003 T14). Every visual is derived from state
## (C12), so nothing here can go stale. Never moves on its own and never chooses to attack.

const DEFAULT_DATA_PATH: String = "res://data/enemies/training_dummy.tres"  # G5

@export var data: DummyData = preload(DEFAULT_DATA_PATH)
## F-003/C2: the one per-instance value. 0 is anchored, 1 is loose.
@export var knockback_scale: float = 0.0
## Whether the debug pulse toggle reaches this dummy.
@export var pulses: bool = false
@export var body_color: Color = Color(0.55, 0.45, 0.3)
@export var ko_color: Color = Color(0.3, 0.3, 0.3)
@export var ring_color: Color = Color(1.0, 0.4, 0.2)
@export var bar_color: Color = Color(0.3, 0.8, 0.35)
@export var bar_back_color: Color = Color(0.15, 0.15, 0.15)
@export var bar_size_px: Vector2 = Vector2(20, 2)
@export var bar_offset_px: Vector2 = Vector2(-10, -14)
@export var ring_width_px: float = 1.0
@export var ring_points: int = 48

var logic: DummyLogic = DummyLogic.new()

var _start_position: Vector2

@onready var _hp_label: Label = $HpLabel
@onready var _ko_label: Label = $KoLabel
@onready var _damage_numbers: DamageNumbers = $DamageNumbers


func _ready() -> void:
	_start_position = global_position
	_setup_logic()
	_damage_numbers.listen_to(logic.get_combat_state())
	logic.state_restored.connect(_on_state_restored)
	refresh_view()


func _process(_delta: float) -> void:
	refresh_view()


func _draw() -> void:
	var radius: float = Units.tiles_to_px(data.hurtbox_radius_tiles)
	draw_circle(Vector2.ZERO, radius, ko_color if logic.is_ko() else body_color)
	draw_rect(Rect2(bar_offset_px, bar_size_px), bar_back_color)
	var filled: Vector2 = Vector2(bar_size_px.x * get_hp_fraction(), bar_size_px.y)
	draw_rect(Rect2(bar_offset_px, filled), bar_color)
	if is_ring_visible():
		var ring_radius: float = Units.tiles_to_px(logic.get_pulse_radius_tiles())
		draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, ring_points, ring_color, ring_width_px)


func get_combatant() -> Combatant:
	return logic


## F-003/C20: everything back to a fresh setup(), except the pulse toggle.
func reset_to_start() -> void:
	var pulse_on: bool = logic.is_pulse_enabled()
	_setup_logic()
	logic.set_pulse_enabled(pulse_on)
	global_position = _start_position
	_damage_numbers.clear()
	refresh_view()


## F-003/C20: acts between ticks.
func set_pulse_on(enabled: bool) -> void:
	if pulses:
		logic.set_pulse_enabled(enabled)


## F-003/C18: data that has already passed every check.
func apply_reloaded_data(new_data: DummyData, step_rate: int) -> void:
	data = new_data
	logic.apply_data(new_data, step_rate)


func refresh_view() -> void:
	var state: CombatState = logic.get_combat_state()
	_hp_label.text = "%d / %d" % [state.get_hp(), state.get_max_hp()]
	_ko_label.visible = logic.is_ko()
	queue_redraw()


func get_hp_text() -> String:
	return _hp_label.text


func get_hp_fraction() -> float:
	var state: CombatState = logic.get_combat_state()
	return float(state.get_hp()) / state.get_max_hp()


func is_ko_visible() -> bool:
	return _ko_label.visible


func is_ring_visible() -> bool:
	return logic.get_pulse_phase() == PulseCycle.Phase.TELEGRAPH


func get_damage_numbers() -> DamageNumbers:
	return _damage_numbers


func _setup_logic() -> void:
	var start_tiles: Vector2 = Units.vector_px_to_tiles(_start_position)
	var rate: int = Tunables.player_combat.combat_step_rate
	logic.setup(data, rate, start_tiles, knockback_scale, combat_id)


func _on_state_restored() -> void:
	_damage_numbers.clear()
	refresh_view()
