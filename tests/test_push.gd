extends GutTest

const RIGHT := Vector2i(1, 0)


func _types(events: Array) -> Array:
	return events.map(func(e): return e["type"])


func test_push_into_empty_moves_unit():
	var s := Fixtures.blank_state()
	var u := Fixtures.add(s, "scorpion", Vector2i(3, 3))
	var evs := Push.displace(s, Vector2i(3, 3), RIGHT)
	assert_eq(u.pos, Vector2i(4, 3))
	assert_eq(_types(evs), ["unit_pushed"])


func test_push_into_unit_damages_both_no_move():
	var s := Fixtures.blank_state()
	var a := Fixtures.add(s, "scorpion", Vector2i(3, 3))
	var b := Fixtures.add(s, "firefly", Vector2i(4, 3))
	Push.displace(s, Vector2i(3, 3), RIGHT)
	assert_eq(a.pos, Vector2i(3, 3))
	assert_eq(b.pos, Vector2i(4, 3))
	assert_eq(a.hp, 4)
	assert_eq(b.hp, 2)


func test_push_collision_can_kill():
	var s := Fixtures.blank_state()
	var a := Fixtures.add(s, "hornet", Vector2i(3, 3))
	a.hp = 1
	Fixtures.add(s, "scorpion", Vector2i(4, 3))
	var evs := Push.displace(s, Vector2i(3, 3), RIGHT)
	assert_false(a.alive)
	assert_true("unit_died" in _types(evs))


func test_push_ground_into_water_kills():
	var s := Fixtures.blank_state()
	Fixtures.set_terrain(s, Vector2i(4, 3), "water")
	var u := Fixtures.add(s, "scorpion", Vector2i(3, 3))
	var evs := Push.displace(s, Vector2i(3, 3), RIGHT)
	assert_false(u.alive)
	assert_eq(u.pos, Vector2i(4, 3))  # died in the water tile
	var died: Dictionary = evs.filter(func(e): return e["type"] == "unit_died")[0]
	assert_eq(died["cause"], "water")


func test_push_flying_over_water_survives():
	var s := Fixtures.blank_state()
	Fixtures.set_terrain(s, Vector2i(4, 3), "water")
	var u := Fixtures.add(s, "hornet", Vector2i(3, 3))
	Push.displace(s, Vector2i(3, 3), RIGHT)
	assert_true(u.alive)
	assert_eq(u.pos, Vector2i(4, 3))


func test_push_into_chasm_kills_even_flying_no():  # flying survives chasm push? spec: chasm kills non-flying
	var s := Fixtures.blank_state()
	Fixtures.set_terrain(s, Vector2i(4, 3), "chasm")
	var flyer := Fixtures.add(s, "hornet", Vector2i(3, 3))
	Push.displace(s, Vector2i(3, 3), RIGHT)
	assert_true(flyer.alive)


func test_push_ground_into_chasm_kills_even_if_tanky():
	var s := Fixtures.blank_state()
	Fixtures.set_terrain(s, Vector2i(4, 3), "chasm")
	var u := Fixtures.add(s, "scorpion", Vector2i(3, 3))
	var evs := Push.displace(s, Vector2i(3, 3), RIGHT)
	assert_false(u.alive)
	var died: Dictionary = evs.filter(func(e): return e["type"] == "unit_died")[0]
	assert_eq(died["cause"], "chasm")


func test_push_into_mountain_damages_both_mountain_breaks_after_two():
	var s := Fixtures.blank_state()
	Fixtures.set_terrain(s, Vector2i(4, 3), "mountain")
	var u := Fixtures.add(s, "scorpion", Vector2i(3, 3))
	Push.displace(s, Vector2i(3, 3), RIGHT)
	assert_eq(u.hp, 4)
	assert_eq(u.pos, Vector2i(3, 3))
	assert_eq(s.mountain_hp[Vector2i(4, 3)], 1)
	Push.displace(s, Vector2i(3, 3), RIGHT)
	assert_eq(s.terrain[Vector2i(4, 3)], "rubble")
	# now rubble is walkable: a third push moves the unit
	Push.displace(s, Vector2i(3, 3), RIGHT)
	assert_eq(u.pos, Vector2i(4, 3))


func test_push_into_building_damages_unit_and_building_and_grid():
	var s := Fixtures.blank_state()
	Fixtures.add_building(s, Vector2i(4, 3), 2)
	var u := Fixtures.add(s, "scorpion", Vector2i(3, 3))
	var evs := Push.displace(s, Vector2i(3, 3), RIGHT)
	assert_eq(u.hp, 4)
	assert_eq(u.pos, Vector2i(3, 3))
	assert_eq(s.buildings[Vector2i(4, 3)]["hp"], 1)
	assert_eq(s.grid_power, 6)
	assert_true("grid_power_changed" in evs.map(func(e): return e["type"]))


func test_push_off_edge_blocked_with_damage():
	var s := Fixtures.blank_state()
	var u := Fixtures.add(s, "scorpion", Vector2i(7, 3))
	Push.displace(s, Vector2i(7, 3), RIGHT)
	assert_eq(u.pos, Vector2i(7, 3))
	assert_eq(u.hp, 4)


func test_damage_tile_unit():
	var s := Fixtures.blank_state()
	var u := Fixtures.add(s, "scorpion", Vector2i(3, 3))
	var evs := Push.damage_tile(s, Vector2i(3, 3), 2)
	assert_eq(u.hp, 3)
	assert_eq(_types(evs), ["unit_damaged"])


func test_building_overkill_grid_loss_capped():
	var s := Fixtures.blank_state()
	Fixtures.add_building(s, Vector2i(4, 3), 1)
	var evs := Push.damage_tile(s, Vector2i(4, 3), 3)
	assert_eq(s.grid_power, 6)  # only 1 hp existed -> only 1 power lost
	assert_true("building_destroyed" in _types(evs))
	# destroyed building leaves rubble
	assert_eq(s.terrain[Vector2i(4, 3)], "rubble")
	assert_false(s.buildings[Vector2i(4, 3)]["hp"] > 0)


func test_damage_tile_mountain():
	var s := Fixtures.blank_state()
	Fixtures.set_terrain(s, Vector2i(4, 3), "mountain")
	Push.damage_tile(s, Vector2i(4, 3), 1)
	assert_eq(s.mountain_hp[Vector2i(4, 3)], 1)
	Push.damage_tile(s, Vector2i(4, 3), 1)
	assert_eq(s.terrain[Vector2i(4, 3)], "rubble")


func test_damage_tile_empty_no_events():
	var s := Fixtures.blank_state()
	assert_eq(Push.damage_tile(s, Vector2i(3, 3), 2).size(), 0)
