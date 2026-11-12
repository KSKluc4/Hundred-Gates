extends Node
## Exposes the tunables resource as `Tunables.game` (G2, F-000 Decision C).

const GAME_TUNABLES_PATH: String = "res://data/tunables/game_tunables.tres"  # G5
const PLAYER_COMBAT_PATH: String = "res://data/tunables/player_combat.tres"  # G5
const WARRIOR_PATH: String = "res://data/classes/warrior.tres"  # G5
const TRAINING_DUMMY_PATH: String = "res://data/enemies/training_dummy.tres"  # G5
const SCREEN_SHAKE_PATH: String = "res://data/tunables/screen_shake.tres"  # G5
const ENEMY_COMBAT_PATH: String = "res://data/tunables/enemy_combat.tres"  # G5
const CHASER_PATH: String = "res://data/enemies/chaser.tres"  # G5
const CHASER_SWIPE_PATH: String = "res://data/attacks/chaser_swipe.tres"  # G5
const CASTER_PATH: String = "res://data/enemies/caster.tres"  # G5
const CASTER_BOLT_PATH: String = "res://data/attacks/caster_bolt.tres"  # G5
const BRUTE_PATH: String = "res://data/enemies/brute.tres"  # G5
const BRUTE_STOMP_PATH: String = "res://data/attacks/brute_stomp.tres"  # G5
const BRUTE_CHARGE_PATH: String = "res://data/attacks/brute_charge.tres"  # G5
# F-007/C16: the Warden is data only.
const WARDEN_PATH: String = "res://data/enemies/warden.tres"  # G5
const WARDEN_STAGE_2_PATH: String = "res://data/enemies/warden_stage_2.tres"  # G5
const WARDEN_SWIPE_A_PATH: String = "res://data/attacks/warden_swipe_a.tres"  # G5
const WARDEN_SWIPE_B_PATH: String = "res://data/attacks/warden_swipe_b.tres"  # G5
const WARDEN_DASHING_CUT_PATH: String = "res://data/attacks/warden_dashing_cut.tres"  # G5
const WARDEN_P2_SWIPE_A_PATH: String = "res://data/attacks/warden_p2_swipe_a.tres"  # G5
const WARDEN_P2_SWIPE_B_PATH: String = "res://data/attacks/warden_p2_swipe_b.tres"  # G5
const WARDEN_OVERHEAD_PATH: String = "res://data/attacks/warden_overhead.tres"  # G5
const WARDEN_P2_DASHING_CUT_PATH: String = "res://data/attacks/warden_p2_dashing_cut.tres"  # G5
const WARDEN_SPIN_PATH: String = "res://data/attacks/warden_spin.tres"  # G5

var game: GameTunables = preload(GAME_TUNABLES_PATH)
var player_combat: PlayerCombatTunables = preload(PLAYER_COMBAT_PATH)
var enemy_combat: EnemyCombatTunables = preload(ENEMY_COMBAT_PATH)


## F-001/C17, F-003/C18: reads a data file from disk, never from the cache. Null if it's gone.
## The file check comes first: ResourceLoader.exists() still says yes for a deleted file that
## is in the cache. DEEP: warrior.tres references the attack files, and a plain IGNORE would
## take those from the cache, silently ignoring edits to them (F-003 §2).
func load_fresh(path: String) -> Resource:
	if not FileAccess.file_exists(path):
		return null
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)


## F-007/C13 (b): the file chain from `path` back to a file it already passed through, or empty.
## Godot's loader never returns from a cycle of external resources (a follow_up chain across
## files), so a reload must find one before load_fresh(). Reads only the dependency lists.
func find_dependency_cycle(path: String) -> PackedStringArray:
	return _cycle_from(path, PackedStringArray())


func _cycle_from(path: String, trail: PackedStringArray) -> PackedStringArray:
	if trail.has(path):
		var cycle: PackedStringArray = trail.slice(trail.find(path))
		cycle.append(path)
		return cycle
	if not (path.ends_with(".tres") or path.ends_with(".res")) or not FileAccess.file_exists(path):
		return PackedStringArray()
	var deeper: PackedStringArray = trail.duplicate()
	deeper.append(path)
	for dependency: String in ResourceLoader.get_dependencies(path):
		# "uid://…::Type::path" or a plain path: the path is the last part.
		var dependency_path: String = dependency.get_slice(
			"::", dependency.get_slice_count("::") - 1
		)
		var cycle: PackedStringArray = _cycle_from(dependency_path, deeper)
		if not cycle.is_empty():
			return cycle
	return PackedStringArray()
