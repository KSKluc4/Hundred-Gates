class_name PlaceholderShake
extends Camera2D
## Placeholder camera shake, only to verify the events (→ Art & Game Feel, CX2). A child of
## the local player's body, and it listens to that player alone, so a hit shakes only the
## screen of a local player involved in it (F-003/C10, D-002). Core never emits shake.

var shake_enabled: bool = true

var _player: Player
var _settings: ScreenShakeSettings
var _intensity: float = 0.0
var _time_left: float = 0.0
# F-003/C18: the running shake's look, latched by shake(), so a reload reaches the next one.
var _decay_time: float = 0.0
var _max_offset_px: float = 0.0


func _ready() -> void:
	_player = get_parent() as Player
	apply_settings(load(Tunables.SCREEN_SHAKE_PATH) as ScreenShakeSettings)
	var state: CombatState = _player.motor.get_combat_state()
	state.hit_landed.connect(_on_hit_landed)
	state.damaged.connect(_on_damaged)


func _process(delta: float) -> void:
	_time_left = maxf(0.0, _time_left - delta)
	offset = Vector2.RIGHT.rotated(randf() * TAU) * randf() * get_offset_limit_px()


## F-003/C18: takes the file's value, replacing the K toggle.
func apply_settings(settings: ScreenShakeSettings) -> void:
	_settings = settings
	shake_enabled = settings.screen_shake_enabled
	if not shake_enabled:
		clear()


func toggle() -> void:
	shake_enabled = not shake_enabled
	if not shake_enabled:
		clear()


## AC21: nothing at all while disabled. A new shake takes the larger intensity, never the sum.
func shake(intensity: float) -> void:
	if not shake_enabled:
		return
	_intensity = maxf(get_current_intensity(), intensity)
	_time_left = _settings.decay_time
	_decay_time = _settings.decay_time
	_max_offset_px = _settings.max_offset_px


func get_settings() -> ScreenShakeSettings:
	return _settings


func get_current_intensity() -> float:
	if _time_left <= 0.0:
		return 0.0
	return _intensity * _time_left / _decay_time


## The largest offset the running shake can reach right now.
func get_offset_limit_px() -> float:
	return get_current_intensity() * _max_offset_px


## F-003/C19: transient presentation, a restore or reset clears it.
func clear() -> void:
	_intensity = 0.0
	_time_left = 0.0
	offset = Vector2.ZERO


func _on_hit_landed(event: HitEvent) -> void:
	var tunables: PlayerCombatTunables = _player.get_tunables()
	shake(tunables.shake_intensity_finisher if event.is_finisher else tunables.shake_intensity_hit)


func _on_damaged(_event: HitEvent) -> void:
	shake(_player.get_tunables().shake_intensity_player_hurt)
