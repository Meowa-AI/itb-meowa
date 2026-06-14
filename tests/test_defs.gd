extends GutTest


func test_registry_has_mechs_and_vek():
	assert_not_null(Defs.unit("prime"))
	assert_eq(Defs.unit("prime").weapon_id, "titan_fist")
	assert_eq(Defs.unit("hornet").flying, true)
	assert_eq(Defs.weapon("titan_fist").damage, 2)
	assert_eq(Defs.missions().size(), 7)


func test_mech_squad_complete():
	for id in ["prime", "artillery", "science"]:
		var u: UnitDef = Defs.unit(id)
		assert_eq(u.team, "mech", id)
		assert_gt(u.max_hp, 0, id)
		assert_ne(u.weapon_id, "", id)


func test_vek_roster_complete():
	for id in ["hornet", "firefly", "scorpion", "scarab", "hornet_leader"]:
		var u: UnitDef = Defs.unit(id)
		assert_eq(u.team, "vek", id)
		assert_ne(u.weapon_id, "", id)
	assert_true(Defs.unit("hornet_leader").is_boss)


func test_missions_well_formed():
	var objectives := []
	for m in Defs.missions():
		objectives.append(m.objective)
		assert_eq(m.map_rows.size(), 8, m.id)
		for row in m.map_rows:
			assert_eq(row.length(), 8, m.id)
		assert_eq(m.mech_spawns.size(), 3, m.id)
		# spawns must be on plain ground
		for p in m.mech_spawns:
			assert_eq(m.map_rows[p.y][p.x], ".", "%s mech spawn %s" % [m.id, p])
		for v in m.initial_vek:
			assert_not_null(Defs.unit(v["id"]), m.id)
			assert_eq(m.map_rows[v["pos"].y][v["pos"].x], ".", "%s vek %s" % [m.id, v["pos"]])
		for sp in m.spawn_schedule:
			assert_not_null(Defs.unit(sp["id"]), m.id)
			assert_eq(m.map_rows[sp["pos"].y][sp["pos"].x], ".", "%s spawn %s" % [m.id, sp["pos"]])
		if m.objective == "survive":
			assert_gt(m.survive_turns, 0, m.id)
		if m.objective == "protect":
			assert_true("O" in "".join(m.map_rows), m.id)
	assert_eq(objectives, ["kill_all", "kill_all", "survive", "protect", "kill_all", "survive", "kill_all"])


func test_no_overlapping_start_positions():
	for m in Defs.missions():
		var seen := {}
		for p in m.mech_spawns:
			assert_false(seen.has(p), "%s dup %s" % [m.id, p])
			seen[p] = true
		for v in m.initial_vek:
			assert_false(seen.has(v["pos"]), "%s dup %s" % [m.id, v["pos"]])
			seen[v["pos"]] = true


func test_weapon_kinds_valid():
	for id in ["titan_fist", "arc_shot", "force_beam", "grappling_hook", "cluster_shells", "stinger", "firefly_shot", "scorpion_pincer", "scarab_arc", "leader_sweep"]:
		var w: WeaponDef = Defs.weapon(id)
		assert_not_null(w, id)
		assert_true(w.kind in ["melee", "projectile", "artillery"], id)
