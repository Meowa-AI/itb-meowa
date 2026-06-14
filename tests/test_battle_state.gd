extends GutTest


func _state() -> BattleState:
	return BattleState.from_mission(Defs.missions()[0], 7, [])


func test_from_mission_loads_terrain_units_buildings():
	var s := _state()
	assert_eq(s.grid_power, 7)
	assert_eq(s.mechs().size(), 3)
	assert_eq(s.vek().size(), 3)
	assert_eq(s.buildings.size(), 3)  # m1 has 3 'B'
	assert_eq(s.terrain[Vector2i(4, 1)], "mountain")
	assert_eq(s.terrain[Vector2i(6, 2)], "water")
	assert_eq(s.terrain[Vector2i(0, 0)], "plain")
	# building tiles tracked separately, terrain under them is plain
	assert_true(s.buildings.has(Vector2i(2, 0)))
	assert_eq(s.buildings[Vector2i(2, 0)]["hp"], 2)


func test_unit_lookup_and_ids_unique():
	var s := _state()
	var ids := {}
	for u in s.units:
		assert_false(ids.has(u.id))
		ids[u.id] = true
		assert_eq(s.unit_at(u.pos), u)
	assert_null(s.unit_at(Vector2i(7, 7)))


func test_squad_overrides_apply():
	var squad := [
		{"def_id": "prime", "max_hp": 6, "move": 4, "weapon_id": "titan_fist", "weapon_damage_bonus": 1},
		{"def_id": "artillery", "max_hp": 3, "move": 2, "weapon_id": "cluster_shells", "weapon_damage_bonus": 0},
		{"def_id": "science", "max_hp": 2, "move": 4, "weapon_id": "force_beam", "weapon_damage_bonus": 0},
	]
	var s := BattleState.from_mission(Defs.missions()[0], 5, squad)
	assert_eq(s.grid_power, 5)
	var prime: BUnit = s.mechs()[0]
	assert_eq(prime.max_hp, 6)
	assert_eq(prime.hp, 6)
	assert_eq(prime.move, 4)
	assert_eq(prime.weapon_damage_bonus, 1)
	assert_eq(s.mechs()[1].weapon_id, "cluster_shells")


func test_snapshot_restore_roundtrip():
	var s := _state()
	var snap := s.snapshot()
	var u: BUnit = s.mechs()[0]
	u.hp = 1
	u.pos = Vector2i(7, 7)
	s.grid_power = 2
	s.terrain[Vector2i(0, 0)] = "rubble"
	s.buildings[Vector2i(2, 0)]["hp"] = 0
	s.turn = 5
	s.restore(snap)
	assert_eq(s.mechs()[0].hp, s.mechs()[0].max_hp)
	assert_ne(s.mechs()[0].pos, Vector2i(7, 7))
	assert_eq(s.grid_power, 7)
	assert_eq(s.terrain[Vector2i(0, 0)], "plain")
	assert_eq(s.buildings[Vector2i(2, 0)]["hp"], 2)
	assert_eq(s.turn, 1)


func test_clone_is_independent():
	var s := _state()
	var c := s.clone()
	c.mechs()[0].hp = 1
	c.grid_power = 0
	assert_eq(s.mechs()[0].hp, s.mechs()[0].max_hp)
	assert_eq(s.grid_power, 7)


func test_dead_units_not_found_at_tile():
	var s := _state()
	var u: BUnit = s.vek()[0]
	u.alive = false
	assert_null(s.unit_at(u.pos))
	assert_eq(s.vek().size(), 2)


func test_walkability():
	var s := _state()
	var ground: BUnit = s.mechs()[0]   # mechs are ground
	var flyer: BUnit = s.vek()[0]      # m1 vek[0] is hornet (flying)
	assert_true(flyer.flying)
	assert_false(s.in_bounds(Vector2i(8, 0)))
	assert_false(s.is_walkable(Vector2i(6, 2), ground))  # water blocks ground
	assert_true(s.is_walkable(Vector2i(6, 2), flyer))    # flying may end on water
	assert_false(s.is_walkable(Vector2i(4, 1), ground))  # mountain blocks all
	assert_false(s.is_walkable(Vector2i(4, 1), flyer))
	assert_false(s.is_walkable(Vector2i(2, 0), ground))  # building blocks all
