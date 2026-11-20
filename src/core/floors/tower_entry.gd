class_name TowerEntry
extends RefCounted
## One line of the tower gate's list (F-012/C2): a floor, and whether it starts at its boss.
## TowerProgress.get_entries() builds them; the gate menu only shows them.

var floor_number: int = 0
var at_boss: bool = false
## The floor has been cleared at least once (on both of its entries).
var is_cleared: bool = false
