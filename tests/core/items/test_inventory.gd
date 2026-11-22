# gdlint:disable=max-public-methods
extends GutTest
## F-016 T2 (C13): Inventory counts the swords a character owns, remembers the one equipped, and
## restores itself from a snapshot or refuses it and keeps what it had.

var _inventory: Inventory


func before_each() -> void:
	_inventory = Inventory.new()


func _stocked() -> Inventory:
	var stocked: Inventory = Inventory.new()
	stocked.add(&"a")
	stocked.add(&"b")
	stocked.add(&"a")
	stocked.equip(&"b")
	return stocked


# --- owning ---


func test_c13_a_new_inventory_owns_nothing_and_equips_nothing() -> void:
	assert_true(_inventory.get_ids().is_empty())
	assert_eq(_inventory.get_count(&"a"), 0)
	assert_false(_inventory.has(&"a"))
	assert_eq(_inventory.get_equipped_id(), &"")


func test_c13_a_duplicate_is_only_a_count() -> void:
	_inventory.add(&"a")
	_inventory.add(&"a")
	_inventory.add(&"a")
	assert_eq(_inventory.get_count(&"a"), 3)
	assert_eq(_inventory.get_ids().size(), 1)
	assert_true(_inventory.has(&"a"))


func test_c13_ids_come_in_the_order_of_first_acquisition() -> void:
	for sword_id: StringName in [&"c", &"a", &"b", &"a", &"c"]:
		_inventory.add(sword_id)
	assert_eq(_inventory.get_ids(), [&"c", &"a", &"b"] as Array[StringName])


func test_c13_an_empty_id_is_not_added() -> void:
	_inventory.add(&"")
	assert_true(_inventory.get_ids().is_empty())


# --- equipping ---


func test_c13_only_an_owned_sword_can_be_equipped() -> void:
	assert_false(_inventory.equip(&"a"), "not owned")
	assert_eq(_inventory.get_equipped_id(), &"")
	_inventory.add(&"a")
	assert_true(_inventory.equip(&"a"))
	assert_eq(_inventory.get_equipped_id(), &"a")


func test_c13_a_refused_equip_keeps_the_equipped_sword() -> void:
	_inventory.add(&"a")
	_inventory.equip(&"a")
	assert_false(_inventory.equip(&"zzz"))
	assert_eq(_inventory.get_equipped_id(), &"a")


func test_c13_equipping_the_equipped_sword_is_a_yes_that_changes_nothing() -> void:
	_inventory.add(&"a")
	_inventory.equip(&"a")
	watch_signals(_inventory)
	assert_true(_inventory.equip(&"a"))
	assert_eq(_inventory.get_equipped_id(), &"a")
	assert_signal_not_emitted(_inventory, "changed")


func test_c13_changed_fires_on_an_add_and_on_a_new_equip_only() -> void:
	watch_signals(_inventory)
	_inventory.add(&"a")
	assert_signal_emit_count(_inventory, "changed", 1)
	_inventory.add(&"b")
	assert_signal_emit_count(_inventory, "changed", 2)
	_inventory.equip(&"b")
	assert_signal_emit_count(_inventory, "changed", 3)
	_inventory.equip(&"zzz")
	_inventory.equip(&"b")
	assert_signal_emit_count(_inventory, "changed", 3, "a refusal and a repeat change nothing")


# --- the snapshot ---


func test_c13_the_empty_inventory_round_trips() -> void:
	var copy: Inventory = Inventory.new()
	copy.add(&"x")
	assert_true(copy.from_dict(_inventory.to_dict()))
	assert_true(copy.get_ids().is_empty())
	assert_eq(copy.get_equipped_id(), &"")
	assert_eq_deep(copy.to_dict(), _inventory.to_dict())


func test_c13_a_stocked_inventory_round_trips_with_counts_order_and_the_equipped_sword() -> void:
	var source: Inventory = _stocked()
	var copy: Inventory = Inventory.new()
	assert_true(copy.from_dict(source.to_dict()))
	assert_eq(copy.get_ids(), [&"a", &"b"] as Array[StringName])
	assert_eq(copy.get_count(&"a"), 2)
	assert_eq(copy.get_count(&"b"), 1)
	assert_eq(copy.get_equipped_id(), &"b")
	assert_eq_deep(copy.to_dict(), source.to_dict())


func test_c13_an_inventory_with_nothing_equipped_is_a_valid_shape() -> void:
	var source: Inventory = Inventory.new()
	source.add(&"a")
	var copy: Inventory = Inventory.new()
	assert_true(copy.from_dict(source.to_dict()))
	assert_eq(copy.get_equipped_id(), &"")
	assert_eq(copy.get_count(&"a"), 1)


func test_c13_a_restore_replaces_what_was_there_and_says_changed() -> void:
	var target: Inventory = Inventory.new()
	target.add(&"old")
	watch_signals(target)
	assert_true(target.from_dict(_stocked().to_dict()))
	assert_false(target.has(&"old"))
	assert_signal_emit_count(target, "changed", 1)


func test_c13_a_snapshot_keeps_the_ids_as_strings() -> void:
	var snapshot: Dictionary = _stocked().to_dict()
	assert_typeof(snapshot[Inventory.KEY_EQUIPPED], TYPE_STRING)
	for entry: Dictionary in snapshot[Inventory.KEY_OWNED]:
		assert_typeof(entry[Inventory.KEY_ID], TYPE_STRING)


func test_c13_string_names_are_accepted_as_ids() -> void:
	var snapshot: Dictionary = {
		Inventory.KEY_OWNED: [{Inventory.KEY_ID: &"a", Inventory.KEY_COUNT: 2}],
		Inventory.KEY_EQUIPPED: &"a",
	}
	assert_true(_inventory.from_dict(snapshot))
	assert_eq(_inventory.get_count(&"a"), 2)
	assert_eq(_inventory.get_equipped_id(), &"a")


# --- refusals: each leaves the inventory as it was ---


func _assert_refused(snapshot: Dictionary, message: String) -> void:
	var target: Inventory = _stocked()
	var before: Dictionary = target.to_dict()
	watch_signals(target)
	assert_false(target.from_dict(snapshot), message)
	assert_eq_deep(target.to_dict(), before)
	assert_signal_not_emitted(target, "changed", "%s: and nothing said" % message)


func _snapshot(owned: Variant, equipped: Variant) -> Dictionary:
	return {Inventory.KEY_OWNED: owned, Inventory.KEY_EQUIPPED: equipped}


func _entry(sword_id: Variant, count: Variant) -> Dictionary:
	return {Inventory.KEY_ID: sword_id, Inventory.KEY_COUNT: count}


func test_c13_a_count_below_one_is_refused() -> void:
	_assert_refused(_snapshot([_entry("a", 0)], ""), "count 0")
	_assert_refused(_snapshot([_entry("a", -3)], ""), "count -3")


func test_c13_an_equipped_id_that_is_not_owned_is_refused() -> void:
	_assert_refused(_snapshot([_entry("a", 1)], "b"), "equipped but not owned")
	_assert_refused(_snapshot([], "a"), "equipped with nothing owned")


func test_c13_wrong_types_are_refused() -> void:
	_assert_refused(_snapshot("a", ""), "owned is not a list")
	_assert_refused(_snapshot([_entry("a", 1)], 7), "equipped is not text")
	_assert_refused(_snapshot([_entry("a", 1.0)], ""), "a count that is a float")
	_assert_refused(_snapshot([_entry("a", "1")], ""), "a count that is text")
	_assert_refused(_snapshot([_entry(5, 1)], ""), "an id that is a number")
	_assert_refused(_snapshot(["a"], ""), "an entry that is not a dictionary")


func test_c13_missing_keys_are_refused() -> void:
	_assert_refused({}, "nothing at all")
	_assert_refused({Inventory.KEY_OWNED: []}, "no equipped key")
	_assert_refused({Inventory.KEY_EQUIPPED: ""}, "no owned key")
	_assert_refused(_snapshot([{Inventory.KEY_ID: "a"}], ""), "an entry without a count")
	_assert_refused(_snapshot([{Inventory.KEY_COUNT: 1}], ""), "an entry without an id")


func test_c13_an_empty_or_repeated_id_is_refused() -> void:
	_assert_refused(_snapshot([_entry("", 1)], ""), "an empty id")
	_assert_refused(_snapshot([_entry("a", 1), _entry("a", 2)], ""), "an id twice")
