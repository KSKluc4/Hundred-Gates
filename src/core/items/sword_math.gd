class_name SwordMath
extends RefCounted
## F-016/C2: the split of a sword's damage over the hits of a chain, in integers (items.md,
## "Damage"). Static functions only.


## Hit `i` gets `(total * w_i) / W` (integer division, `W` the sum of the weights). The points left
## over go one each to the hits with the largest remainder `(total * w_i) mod W`; among equal
## remainders the last hit comes first, then hit 0, 1, 2 and so on. One entry per weight, adding up
## to `total`. Empty for no weights, a weight below 1 or a negative total.
static func split(total: int, weights: PackedInt32Array) -> PackedInt32Array:
	if total < 0 or weights.is_empty():
		return PackedInt32Array()
	var weight_sum: int = 0
	for weight: int in weights:
		if weight < 1:
			return PackedInt32Array()
		weight_sum += weight
	var hits: PackedInt32Array = PackedInt32Array()
	var remainders: PackedInt32Array = PackedInt32Array()
	var assigned: int = 0
	for weight: int in weights:
		var share: int = total * weight
		var whole: int = share / weight_sum
		hits.append(whole)
		remainders.append(share % weight_sum)
		assigned += whole
	var order: Array[int] = []
	for index: int in weights.size():
		order.append(index)
	order.sort_custom(func(a: int, b: int) -> bool: return _comes_before(a, b, remainders))
	for place: int in total - assigned:
		hits[order[place]] += 1
	return hits


## A total order (sort_custom is not stable): the larger remainder first; on equal remainders the
## last index first, then the others in order. `remainders.size()` is the number of hits.
static func _comes_before(a: int, b: int, remainders: PackedInt32Array) -> bool:
	if remainders[a] != remainders[b]:
		return remainders[a] > remainders[b]
	return _tie_rank(a, remainders.size()) < _tie_rank(b, remainders.size())


static func _tie_rank(index: int, count: int) -> int:
	return 0 if index == count - 1 else index + 1
