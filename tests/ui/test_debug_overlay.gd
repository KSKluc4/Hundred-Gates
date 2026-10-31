extends GutTest

const OVERLAY_SCENE: PackedScene = preload("res://src/ui/debug_overlay.tscn")

var _tunable_before_test: bool


func before_each() -> void:
	_tunable_before_test = Tunables.game.debug_overlay_visible_on_start


func after_each() -> void:
	Tunables.game.debug_overlay_visible_on_start = _tunable_before_test


func test_starts_hidden_when_tunable_is_false() -> void:
	assert_false(_spawn_overlay(false).visible)


func test_starts_visible_when_tunable_is_true() -> void:
	assert_true(_spawn_overlay(true).visible)


func test_shows_fps_and_both_versions() -> void:
	var overlay: DebugOverlay = _spawn_overlay(true)
	overlay._process(0.0)
	var text: String = (overlay.get_node("Label") as Label).text
	assert_string_contains(text, "FPS: ")
	assert_string_contains(text, Engine.get_version_info()["string"])
	assert_string_contains(text, ProjectSettings.get_setting("application/config/version"))


func test_toggle_press_flips_visibility_both_ways() -> void:
	var overlay: DebugOverlay = _spawn_overlay(true)
	overlay._unhandled_input(_toggle_event(true))
	assert_false(overlay.visible)
	overlay._unhandled_input(_toggle_event(true))
	assert_true(overlay.visible)


func test_toggle_release_does_nothing() -> void:
	var overlay: DebugOverlay = _spawn_overlay(true)
	overlay._unhandled_input(_toggle_event(false))
	assert_true(overlay.visible)


func _spawn_overlay(visible_on_start: bool) -> DebugOverlay:
	Tunables.game.debug_overlay_visible_on_start = visible_on_start
	var overlay: DebugOverlay = OVERLAY_SCENE.instantiate()
	add_child_autofree(overlay)
	return overlay


func _toggle_event(pressed: bool) -> InputEventAction:
	var event: InputEventAction = InputEventAction.new()
	event.action = DebugOverlay.TOGGLE_ACTION
	event.pressed = pressed
	return event
