extends GutTest

const RIGHT := Vector2i(1, 0)
const LEFT := Vector2i(-1, 0)


func test_move_range_respects_blockers_and_terrain():
	var s := Fixtures.blank_state()
	var u := Fixtures.add(s, "prime", Vector2i(3, 3))  # move 3
	Fixtures.add(s, "scorpion", Vector2i(4, 3))        # blocks path
	Fixtures.set_terrain(s, Vector2i(3, 2), "mountain")
	var moves := Actions.legal_moves(s, u)
	assert_false(Vector2i(4, 3) in moves)  # occupied
	assert_false(Vector2i(3, 2) in moves)  # mountain
	assert_true(Vector2i(3, 4) in moves)
	assert_true(Vector2i(3, 6) in moves)   # 3 straight down
	assert_false(Vector2i(3, 7) in moves)  # 4 away
	assert_false(Vector2i(3, 3) in moves)  # own tile not a move


func test_ground_cannot_cross_water_flying_can():
	var s := Fixtures.blank_state()
	# wall of water across row 3 splits the board
	for x in BattleState.SIZE:
		Fixtures.set_terrain(s, Vector2i(x, 3), "water")
	var ground := Fixtures.add(s, "prime", Vector2i(3, 2))
	var flyer := Fixtures.add(s, "hornet", Vector2i(5, 2))
	assert_false(Vector2i(3, 4) in Actions.legal_moves(s, ground))
	assert_true(Vector2i(5, 4) in Actions.legal_moves(s, flyer))   # crosses water
	assert_true(Vector2i(5, 3) in Actions.legal_moves(s, flyer))   # may end on water


func test_move_once_per_turn():
	var s := Fixtures.blank_state()
	var u := Fixtures.add(s, "prime", Vector2i(3, 3))
	var r := Actions.do_move(s, u, Vector2i(3, 4))
	assert_true(r["ok"])
	assert_eq(u.pos, Vector2i(3, 4))
	r = Actions.do_move(s, u, Vector2i(3, 5))
	assert_false(r["ok"])


func test_titan_fist_damages_and_pushes():
	var s := Fixtures.blank_state()
	var prime := Fixtures.add(s, "prime", Vector2i(3, 3))
	var bug := Fixtures.add(s, "scorpion", Vector2i(4, 3))
	var r := Actions.do_attack(s, prime, Vector2i(4, 3))
	assert_true(r["ok"])
	assert_eq(bug.hp, 3)               # 2 dmg
	assert_eq(bug.pos, Vector2i(5, 3)) # pushed away
	assert_true(prime.acted)


func test_melee_targets_are_adjacent_only():
	var s := Fixtures.blank_state()
	var prime := Fixtures.add(s, "prime", Vector2i(3, 3))
	var targets := Actions.legal_targets(s, prime)
	var tiles: Array = targets.map(func(t): return t["target"])
	assert_eq(tiles.size(), 4)
	assert_true(Vector2i(4, 3) in tiles)
	assert_false(Vector2i(5, 3) in tiles)


func test_force_beam_pulls_first_unit_in_line():
	var s := Fixtures.blank_state()
	var sci := Fixtures.add(s, "science", Vector2i(0, 3))
	var near := Fixtures.add(s, "firefly", Vector2i(4, 3))
	var far := Fixtures.add(s, "scorpion", Vector2i(6, 3))
	var r := Actions.do_attack(s, sci, Vector2i(4, 3))
	assert_true(r["ok"])
	assert_eq(near.hp, 2)               # 1 dmg
	assert_eq(near.pos, Vector2i(3, 3)) # pulled toward shooter
	assert_eq(far.hp, 5)                # untouched


func test_projectile_cannot_target_past_blocker():
	var s := Fixtures.blank_state()
	var sci := Fixtures.add(s, "science", Vector2i(0, 3))
	Fixtures.set_terrain(s, Vector2i(3, 3), "mountain")
	Fixtures.add(s, "firefly", Vector2i(5, 3))
	var tiles: Array = Actions.legal_targets(s, sci).map(func(t): return t["target"])
	assert_true(Vector2i(3, 3) in tiles)   # the mountain itself is hittable
	assert_false(Vector2i(5, 3) in tiles)  # behind the mountain


func test_arc_shot_pushes_ring_outward():
	var s := Fixtures.blank_state()
	var arty := Fixtures.add(s, "artillery", Vector2i(3, 3))
	var center := Fixtures.add(s, "scorpion", Vector2i(3, 6))
	var north := Fixtures.add(s, "firefly", Vector2i(3, 5))
	var east := Fixtures.add(s, "hornet", Vector2i(4, 6))
	var r := Actions.do_attack(s, arty, Vector2i(3, 6))
	assert_true(r["ok"])
	assert_eq(center.hp, 4)               # 1 dmg, not pushed
	assert_eq(center.pos, Vector2i(3, 6))
	assert_eq(north.pos, Vector2i(3, 4))  # pushed away from impact
	assert_eq(east.pos, Vector2i(5, 6))
	assert_eq(north.hp, 3)                # ring takes no damage from arc shot
	assert_eq(east.hp, 2)


func test_artillery_targets_cardinal_min_range_2_over_mountains():
	var s := Fixtures.blank_state()
	var arty := Fixtures.add(s, "artillery", Vector2i(3, 3))
	Fixtures.set_terrain(s, Vector2i(3, 4), "mountain")
	var tiles: Array = Actions.legal_targets(s, arty).map(func(t): return t["target"])
	assert_false(Vector2i(4, 3) in tiles)  # range 1 not allowed
	assert_true(Vector2i(5, 3) in tiles)
	assert_true(Vector2i(3, 6) in tiles)   # arcs over the mountain
	assert_false(Vector2i(4, 4) in tiles)  # not cardinal


func test_cluster_shells_damages_ring_no_push():
	var s := Fixtures.blank_state()
	var arty := Fixtures.add(s, "artillery", Vector2i(3, 3))
	arty.weapon_id = "cluster_shells"
	var center := Fixtures.add(s, "scorpion", Vector2i(3, 6))
	var north := Fixtures.add(s, "firefly", Vector2i(3, 5))
	Actions.do_attack(s, arty, Vector2i(3, 6))
	assert_eq(center.hp, 4)
	assert_eq(north.hp, 2)                # ring damaged
	assert_eq(north.pos, Vector2i(3, 5))  # not pushed


func test_weapon_damage_bonus_applies():
	var s := Fixtures.blank_state()
	var prime := Fixtures.add(s, "prime", Vector2i(3, 3))
	prime.weapon_damage_bonus = 1
	var bug := Fixtures.add(s, "scorpion", Vector2i(4, 3))
	Actions.do_attack(s, prime, Vector2i(4, 3))
	assert_eq(bug.hp, 2)  # 3 dmg


func test_repair_heals_one_and_consumes_action():
	var s := Fixtures.blank_state()
	var u := Fixtures.add(s, "prime", Vector2i(3, 3))
	u.hp = 2
	var r := Actions.do_repair(s, u)
	assert_true(r["ok"])
	assert_eq(u.hp, 3)
	assert_true(u.acted)
	# at full hp repair is refused
	var v := Fixtures.add(s, "science", Vector2i(5, 5))
	assert_false(Actions.do_repair(s, v)["ok"])


func test_attack_consumes_action_and_blocks_second():
	var s := Fixtures.blank_state()
	var prime := Fixtures.add(s, "prime", Vector2i(3, 3))
	Fixtures.add(s, "scorpion", Vector2i(4, 3))
	Actions.do_attack(s, prime, Vector2i(4, 3))
	var r := Actions.do_attack(s, prime, Vector2i(5, 3))
	assert_false(r["ok"])


func test_acted_unit_cannot_move():
	## ItB rule: act ends the unit's turn — no move after attacking.
	var s := Fixtures.blank_state()
	var prime := Fixtures.add(s, "prime", Vector2i(3, 3))
	Fixtures.add(s, "scorpion", Vector2i(4, 3))
	Actions.do_attack(s, prime, Vector2i(4, 3))
	assert_false(Actions.do_move(s, prime, Vector2i(3, 4))["ok"])
