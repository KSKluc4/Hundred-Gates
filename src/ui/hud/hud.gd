class_name Hud
extends CanvasLayer
## F-012/C13: the bare HUD. A health bar (top left), where the player is (top right) and a banner
## (top centre). It decides nothing and nothing reads it (G6): the game tells it what to say, and
## the health bar asks `player_provider` for the player every frame. The look → Art & Game Feel
## (§10 Q4).

## F-012/C16: every player-facing string of the location line.
const TOWN_TEXT: String = "Town"
const BOSS_FORMAT: String = "Floor %d · Boss"
const ROOM_FORMAT: String = "Floor %d · Room %d / %d"

@export var margin_px: Vector2 = Vector2(4, 4)
@export var location_width_px: float = 160.0
@export var banner_width_px: float = 320.0
@export var banner_top_px: float = 24.0
@export var font_size: int = 8
@export var banner_color: Color = Color(1.0, 0.9, 0.5)

## () -> Player, may return null. Passed on to the HealthBar, also when set after _ready: the
## game sets it once and the provider answers with each room's player.
var player_provider: Callable:
	set(value):
		player_provider = value
		if _health_bar != null:
			_health_bar.player_provider = value

var _banner_time_left: float = 0.0

@onready var _health_bar: HealthBar = $HealthBar
@onready var _location_label: Label = $LocationLabel
@onready var _banner_label: Label = $BannerLabel


func _ready() -> void:
	_health_bar.player_provider = player_provider
	_health_bar.position = margin_px
	# Anchored to the right and to the middle, so the 640 x 360 placeholder sizes aren't assumed.
	_location_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_location_label.offset_left = -location_width_px - margin_px.x
	_location_label.offset_right = -margin_px.x
	_location_label.offset_top = margin_px.y
	_location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_banner_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner_label.offset_left = -banner_width_px / 2.0
	_banner_label.offset_right = banner_width_px / 2.0
	_banner_label.offset_top = banner_top_px
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.modulate = banner_color
	for label: Label in [_location_label, _banner_label]:
		label.add_theme_font_size_override(&"font_size", font_size)
	_banner_label.visible = false


## F-012/C13: time is counted here, in frames, so a banner can't outlive a paused tree.
func _process(delta: float) -> void:
	if not _banner_label.visible:
		return
	_banner_time_left -= delta
	if _banner_time_left <= 0.0:
		_banner_label.visible = false
		_banner_label.text = ""


## Floor 0 is the town. A boss room has no number of its own.
static func location_text(
	floor_number: int, room_index: int, room_count: int, is_boss_room: bool
) -> String:
	if floor_number == 0:
		return TOWN_TEXT
	if is_boss_room:
		return BOSS_FORMAT % floor_number
	return ROOM_FORMAT % [floor_number, room_index + 1, room_count]


func set_location(text: String) -> void:
	_location_label.text = text


func get_location() -> String:
	return _location_label.text


## A new banner replaces the one showing and restarts the time. 0 hides it on the next _process.
func show_banner(text: String, duration: float) -> void:
	_banner_label.text = text
	_banner_label.visible = true
	_banner_time_left = maxf(duration, 0.0)


func is_banner_visible() -> bool:
	return _banner_label.visible


## Empty when hidden.
func get_banner_text() -> String:
	return _banner_label.text if _banner_label.visible else ""


func get_health_bar() -> HealthBar:
	return _health_bar
