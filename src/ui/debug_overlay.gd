class_name DebugOverlay
extends CanvasLayer
## Shows FPS and versions. Toggled with the `debug_toggle` action.

const TOGGLE_ACTION: StringName = &"debug_toggle"
const GAME_VERSION_SETTING: String = "application/config/version"

@onready var _label: Label = $Label


func _ready() -> void:
	visible = Tunables.game.debug_overlay_visible_on_start


func _process(_delta: float) -> void:
	if visible:
		_label.text = _build_text()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(TOGGLE_ACTION):
		visible = not visible


func _build_text() -> String:
	var fps: float = Engine.get_frames_per_second()
	var godot_version: String = Engine.get_version_info()["string"]
	var game_version: String = ProjectSettings.get_setting(GAME_VERSION_SETTING)
	return "FPS: %d\nGodot: %s\nGame: %s" % [fps, godot_version, game_version]
