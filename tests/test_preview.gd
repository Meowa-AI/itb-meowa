extends GutTest


func test_preview_attack_returns_events_without_mutating():
	var s := Fixtures.blank_state()
	var prime := Fixtures.add(s, "prime", Vector2i(3, 3))
	var bug := Fixtures.add(s, "scorpion", Vector2i(4, 3))
	var evs := Preview.preview_attack(s, prime, Vector2i(4, 3))
	assert_true("unit_damaged" in evs.map(func(e): return e["type"]))
	assert_true("unit_pushed" in evs.map(func(e): return e["type"]))
	# original untouched
	assert_eq(bug.hp, 5)
	assert_eq(bug.pos, Vector2i(4, 3))
	assert_false(prime.acted)


func test_preview_shows_death():
	var s := Fixtures.blank_state()
	Fixtures.set_terrain(s, Vector2i(5, 3), "water")
	var prime := Fixtures.add(s, "prime", Vector2i(3, 3))
	var bug := Fixtures.add(s, "scorpion", Vector2i(4, 3))
	var evs := Preview.preview_attack(s, prime, Vector2i(4, 3))
	var deaths := evs.filter(func(e): return e["type"] == "unit_died")
	assert_eq(deaths.size(), 1)
	assert_eq(deaths[0]["cause"], "water")
	assert_true(bug.alive)


func test_preview_illegal_target_empty():
	var s := Fixtures.blank_state()
	var prime := Fixtures.add(s, "prime", Vector2i(3, 3))
	assert_eq(Preview.preview_attack(s, prime, Vector2i(7, 7)).size(), 0)
