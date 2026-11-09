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
