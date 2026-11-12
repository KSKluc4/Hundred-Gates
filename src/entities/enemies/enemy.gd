class_name Enemy
extends CombatBody
## Glue and placeholder view for EnemyLogic (F-004 T7). One generic scene for every enemy:
## what an enemy is comes from its data (G9). Every visual and the collision state are derived
## from logic (C14), so nothing here can go stale. Has no tick: CombatRunner steps it.

## What the telegraph shows right now (AC23). The look → Art & Game Feel, §10 Q1.
enum Telegraph { NONE, TRACKING, LOCKED, ACTIVE }

## F-005/C5: projectiles meet layer 1 `world` only. F-006/C7: so does a charge's sweep, so enemy
## bodies never stop it.
const WALL_LAYER_MASK: int = 1

@export var data: EnemyData
@export var body_color: Color = Color(0.45, 0.6, 0.35)
## AC23: the punish window.
@export var open_color: Color = Color(0.95, 0.85, 0.3)
## F-007/C20: a gap, the recovery before a follow-up. Placeholder: the look → Art & Game Feel.
@export var gap_color: Color = Color(0.55, 0.6, 0.85)
## F-007/C17: the stage shift cue. Placeholder: the look → Art & Game Feel.
@export var shift_color: Color = Color(0.75, 0.4, 0.95)
@export var dead_color: Color = Color(0.25, 0.25, 0.25)
@export var tracking_color: Color = Color(1.0, 0.55, 0.2, 0.5)
@export var locked_color: Color = Color(1.0, 0.3, 0.15, 0.95)
@export var locked_fill_color: Color = Color(1.0, 0.3, 0.15, 0.2)
@export var active_color: Color = Color(1.0, 0.15, 0.1, 0.8)
@export var bar_color: Color = Color(0.85, 0.25, 0.25)
@export var bar_back_color: Color = Color(0.15, 0.15, 0.15)
@export var bar_size_px: Vector2 = Vector2(16, 2)
@export var bar_offset_px: Vector2 = Vector2(-8, -11)
@export var line_width_px: float = 1.0
@export var arc_points: int = 16
## F-005 AC24: placeholder bolt and aim line. The look → Art & Game Feel, §10 Q2.
@export var bolt_color: Color = Color(1.0, 0.45, 0.85, 0.9)
@export var bolt_points: int = 16

var logic: EnemyLogic = EnemyLogic.new()

var _data_path: String = ""
var _start_position: Vector2
# F-004/C10, C11: the scene's values, for when a reset or a restore brings it back.
var _live_layer: int
var _live_mask: int
# F-005/C5: reused by every wall query, with its radius set each time.
var _query_shape: CircleShape2D = CircleShape2D.new()

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _debug_label: Label = $DebugLabel
@onready var _damage_numbers: DamageNumbers = $DamageNumbers


func _ready() -> void:
	_start_position = global_position
	_live_layer = collision_layer
	_live_mask = collision_mask
	_data_path = data.resource_path if data != null else ""
	_collision_shape.shape = CircleShape2D.new()  # Its own: the radius is this enemy's data.
	# F-004 DEV-1: see _publish_transform().
	PhysicsServer2D.body_set_mode(get_rid(), PhysicsServer2D.BODY_MODE_STATIC)
	_setup_logic()
	_damage_numbers.listen_to(logic.get_combat_state())
	logic.get_combat_state().died.connect(_sync_body)
	logic.state_restored.connect(_on_state_restored)
	_sync_body()
	refresh_view()


func _process(_delta: float) -> void:
	refresh_view()


func _draw() -> void:
	if logic.get_data() == null:
		return  # F-004/C12: setup refused the data, and the runner has stopped the fight.
	_draw_telegraph()
	var radius: float = Units.tiles_to_px(logic.get_data().hurtbox_radius_tiles)
	draw_circle(Vector2.ZERO, radius, get_body_color())
	draw_rect(Rect2(bar_offset_px, bar_size_px), bar_back_color)
	var filled: Vector2 = Vector2(bar_size_px.x * get_hp_fraction(), bar_size_px.y)
	draw_rect(Rect2(bar_offset_px, filled), bar_color)


func get_combatant() -> Combatant:
	return logic


func move_with_combatant(physics_delta: float) -> void:
	super(physics_delta)
	_publish_transform()
	_report_walls()
	_report_charge()


func sync_body_from_logic() -> void:
	super()
	_publish_transform()


## F-004/C15: a fresh setup() with current data. Only the AI toggle survives.
func reset_to_start() -> void:
	var ai_enabled: bool = logic.is_ai_enabled()
	_setup_logic()
	logic.set_ai_enabled(ai_enabled)
	global_position = _start_position
	_publish_transform()
	_damage_numbers.clear()
	_sync_body()
	refresh_view()


## F-004/C12: data that has already passed every check.
func apply_reloaded_data(
	new_data: EnemyData, enemy_tunables: EnemyCombatTunables, step_rate: int
) -> void:
	data = new_data
	logic.apply_data(new_data, enemy_tunables, step_rate)
	_sync_body()


func get_data_path() -> String:
	return _data_path


func refresh_view() -> void:
	_debug_label.text = get_debug_text()
	queue_redraw()


func get_debug_text() -> String:
	var target: StringName = logic.get_target_id()
	var state: String = EnemyLogic.State.find_key(logic.get_state())
	if logic.is_wall_stopped():
		state += " (stun)"  # F-006/C12: the stun is the recovery, lengthened.
	if logic.has_pending_follow_up():
		state += " (gap)"  # F-007/C20: another attack is coming.
	return (
		"%s\ncd %.2f\n> %s"
		% [state, logic.get_cooldown_remaining(), target if target != &"" else &"-"]
	)


func get_hp_fraction() -> float:
	var state: CombatState = logic.get_combat_state()
	return float(state.get_hp()) / state.get_max_hp()


func get_body_color() -> Color:
	match logic.get_state():
		EnemyLogic.State.DEAD:
			return dead_color
		EnemyLogic.State.RECOVERY:
			# F-007/C20: only the pattern's last recovery is the punish window.
			return gap_color if logic.has_pending_follow_up() else open_color
		EnemyLogic.State.STAGE_SHIFT:
			return shift_color
	return body_color


func get_telegraph() -> Telegraph:
	match logic.get_state():
		EnemyLogic.State.WINDUP:
			return Telegraph.LOCKED if logic.is_aim_locked() else Telegraph.TRACKING
		EnemyLogic.State.ACTIVE:
			return Telegraph.ACTIVE
	return Telegraph.NONE


func get_damage_numbers() -> DamageNumbers:
	return _damage_numbers


## F-005 AC24: during a projectile attack's windup, the line its bolt will fly, from the enemy
## along its aim, as long as the bolt's max distance. F-006/C12: during the windup of a melee
## attack that lunges further than it reaches (a charge), its lane: lunge + range long. Global
## px. Empty when there's none.
func get_aim_line() -> PackedVector2Array:
	if logic.get_state() != EnemyLogic.State.WINDUP:
		return PackedVector2Array()
	var length: float = _lane_length(logic.get_running_attack())
	if length <= 0.0:
		return PackedVector2Array()
	var start: Vector2 = logic.get_position_tiles()
	return PackedVector2Array(
		[
			Units.vector_tiles_to_px(start),
			Units.vector_tiles_to_px(start + logic.get_aim() * length),
		]
	)


## F-005 AC24: one circle per projectile, at its logic position: x, y = centre, z = radius.
## Global px.
func get_bolts_px() -> PackedVector3Array:
	var bolts: PackedVector3Array = []
	for projectile: ProjectileSet.Projectile in logic.get_projectiles().get_projectiles():
		var centre: Vector2 = Units.vector_tiles_to_px(projectile.position)
		bolts.append(Vector3(centre.x, centre.y, Units.tiles_to_px(projectile.radius)))
	return bolts


func _setup_logic() -> void:
	var start_tiles: Vector2 = Units.vector_px_to_tiles(_start_position)
	var rate: int = Tunables.player_combat.combat_step_rate
	logic.setup(data, Tunables.enemy_combat, rate, start_tiles, combat_id)


## F-004 DEV-1: enemies collide with each other (C10), and CombatRunner moves bodies one by one,
## several times per tick (F-003/C15), so each must see the ones moved before it. On its own the
## physics server wouldn't show them: a node's new transform reaches it at the end of the
## frame, and a kinematic body's only takes effect when the server steps. So this hands it over
## at once, and _ready() makes the body static, whose transform applies at once.
## move_and_slide() doesn't depend on that mode.
func _publish_transform() -> void:
	PhysicsServer2D.body_set_state(
		get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, global_transform
	)


## F-004/C2, C10, C11: everything physics knows about this enemy, from logic.
func _sync_body() -> void:
	var is_dead: bool = logic.get_state() == EnemyLogic.State.DEAD
	collision_layer = 0 if is_dead else _live_layer
	collision_mask = 0 if is_dead else _live_mask
	var current: EnemyData = logic.get_data()
	if current != null:
		var shape: CircleShape2D = _collision_shape.shape
		shape.radius = Units.tiles_to_px(current.hurtbox_radius_tiles)


## F-005/C5, D-008: after this body moved, each projectile in serial order. A launch this
## step is first checked for a wall overlap, with its radius shrunk by DISTANCE_EPSILON: a sweep
## can't see shapes it starts inside. Then the step's segment is swept, and where it got to is
## reported. Logic decides what a report means.
func _report_walls() -> void:
	var projectiles: ProjectileSet = logic.get_projectiles()
	if projectiles.get_projectiles().is_empty():
		return
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	for projectile: ProjectileSet.Projectile in projectiles.get_projectiles().duplicate():
		var shrunk: float = projectile.radius - Geometry.DISTANCE_EPSILON
		if projectile.launched_in_step and _overlaps_wall(space, projectile.origin, shrunk):
			projectiles.report_blocked_launch(projectile.serial)
			continue
		var reached: Vector2 = _sweep(
			space, projectile.step_start, projectile.position, projectile.radius
		)
		projectiles.report_position(projectile.serial, reached)


## F-006/C7 (D-008): after this body moved, the step's planned charge segment, if any. Its
## circle, shrunk by DISTANCE_EPSILON, is first checked for a wall overlap at the segment's
## start: a sweep can't see shapes it starts inside, so that is a stop (reached = start),
## whatever the direction. Otherwise the segment is swept. One report per step. The body's
## position stays the physics result (F-001/C18): the report only decides the stop.
func _report_charge() -> void:
	var segment: PackedVector2Array = logic.get_charge_segment()
	if segment.is_empty():
		return
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var radius: float = logic.get_data().hurtbox_radius_tiles - Geometry.DISTANCE_EPSILON
	var reached: Vector2 = segment[0]
	if not _overlaps_wall(space, segment[0], radius):
		reached = _sweep(space, segment[0], segment[1], radius)
	logic.report_charge_reach(reached)


func _overlaps_wall(
	space: PhysicsDirectSpaceState2D, centre_tiles: Vector2, radius_tiles: float
) -> bool:
	var query: PhysicsShapeQueryParameters2D = _wall_query(centre_tiles, radius_tiles)
	return not space.intersect_shape(query, 1).is_empty()


## The planned position when nothing is in the way, exactly, so float noise is never a stop.
func _sweep(
	space: PhysicsDirectSpaceState2D, start: Vector2, planned: Vector2, radius_tiles: float
) -> Vector2:
	if start == planned:
		return planned  # A launch exactly at the step's end: no segment to sweep.
	var query: PhysicsShapeQueryParameters2D = _wall_query(start, radius_tiles)
	query.motion = Units.vector_tiles_to_px(planned - start)
	var safe: float = space.cast_motion(query)[0]
	if safe >= 1.0:
		return planned
	return start + (planned - start) * safe


func _wall_query(centre_tiles: Vector2, radius_tiles: float) -> PhysicsShapeQueryParameters2D:
	_query_shape.radius = Units.tiles_to_px(radius_tiles)
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = _query_shape
	query.transform = Transform2D(0.0, Units.vector_tiles_to_px(centre_tiles))
	query.collision_mask = WALL_LAYER_MASK
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return query


## AC23: placeholder look. The sector always points along the aim. F-005 AC24: a projectile
## attack shows its aim line instead, and its bolts are drawn wherever logic has them.
## F-006/C12: a charge shows its lane during windup, with its sector.
func _draw_telegraph() -> void:
	_draw_bolts()
	var telegraph: Telegraph = get_telegraph()
	if telegraph == Telegraph.NONE:
		return
	var attack: EnemyAttackData = logic.get_running_attack()
	_draw_aim_line(telegraph)  # F-006/C12: a charge shows its lane as well as its sector.
	if attack.is_projectile():
		return
	var arc: float = attack.arc_angle_deg
	var radius: float = Units.tiles_to_px(attack.range_tiles)
	var aim: Vector2 = logic.get_aim()
	if telegraph == Telegraph.ACTIVE:
		CombatDebugDraw.fill_sector(self, Vector2.ZERO, aim, arc, radius, active_color, arc_points)
		return
	var is_locked: bool = telegraph == Telegraph.LOCKED
	if is_locked:
		CombatDebugDraw.fill_sector(
			self, Vector2.ZERO, aim, arc, radius, locked_fill_color, arc_points
		)
	var outline: PackedVector2Array = CombatDebugDraw.sector_points(
		Vector2.ZERO, aim, arc, radius, arc_points
	)
	outline.append(outline[0])
	draw_polyline(outline, locked_color if is_locked else tracking_color, line_width_px)


func _draw_aim_line(telegraph: Telegraph) -> void:
	var line: PackedVector2Array = get_aim_line()
	if line.is_empty():
		return
	var color: Color = locked_color if telegraph == Telegraph.LOCKED else tracking_color
	draw_line(line[0] - global_position, line[1] - global_position, color, line_width_px)


## Tiles. 0 when the attack has no line to show.
func _lane_length(attack: EnemyAttackData) -> float:
	if attack.is_projectile():
		return attack.projectile_max_distance_tiles
	if attack.lunge_tiles > attack.range_tiles:
		return attack.lunge_tiles + attack.range_tiles
	return 0.0


func _draw_bolts() -> void:
	for bolt: Vector3 in get_bolts_px():
		var centre: Vector2 = Vector2(bolt.x, bolt.y) - global_position
		draw_circle(centre, bolt.z, bolt_color)


func _on_state_restored() -> void:
	_damage_numbers.clear()
	_sync_body()
	refresh_view()
