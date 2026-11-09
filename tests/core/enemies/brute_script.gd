class_name BruteScript
extends RefCounted
## F-006 AC12's scripted fight, shared by the core and the scene runs. The brute starts at the
## origin and the player at (5.5, 0), behind a pillar whose face stops the brute at x = 2.97:
## 1. the charge meets the pillar and the brute is stunned;
## 2. the player walks round to below the brute, which walks in and stomps;
## 3. the player walks away down an open lane, and the next charge runs its full 6 tiles.

const PLAYER_START: Vector2 = Vector2(5.5, 0)
## In tiles. The face at x = 3.57 stops the brute's 0.6-tile body at x = 2.97.
const PILLAR: Rect2 = Rect2(3.57, -1.0, 0.5, 2.0)
const END_30THS: int = 255
const STOP_STEP: int = 126


## The move for each thirtieth of a second.
static func moves() -> Dictionary:
	var result: Dictionary = {}
	for thirtieth: int in range(33, 45):
		result[thirtieth] = Vector2.DOWN
	for thirtieth: int in range(45, 60):
		result[thirtieth] = Vector2.LEFT
	for thirtieth: int in range(135, 165):
		result[thirtieth] = Vector2.DOWN
	return result
