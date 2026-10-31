extends Node
## Exposes the tunables resource as `Tunables.game` (G2, F-000 Decision C).

const GAME_TUNABLES_PATH: String = "res://data/tunables/game_tunables.tres"  # G5

var game: GameTunables = preload(GAME_TUNABLES_PATH)
