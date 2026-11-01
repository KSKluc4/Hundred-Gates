extends Node
## Exposes the tunables resource as `Tunables.game` (G2, F-000 Decision C).

const GAME_TUNABLES_PATH: String = "res://data/tunables/game_tunables.tres"  # G5
const PLAYER_COMBAT_PATH: String = "res://data/tunables/player_combat.tres"  # G5
const WARRIOR_PATH: String = "res://data/classes/warrior.tres"  # G5
const TRAINING_DUMMY_PATH: String = "res://data/enemies/training_dummy.tres"  # G5
const SCREEN_SHAKE_PATH: String = "res://data/tunables/screen_shake.tres"  # G5

var game: GameTunables = preload(GAME_TUNABLES_PATH)
var player_combat: PlayerCombatTunables = preload(PLAYER_COMBAT_PATH)
