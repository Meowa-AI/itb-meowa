extends GutTest


func _mission_state(idx: int = 0) -> BattleState:
	return BattleState.from_mission(Defs.missions()[idx], 7, [])


func test_start_battle_sets_intents():
	var s := _mission_state()
	TurnEngine.start_battle(s)
	var with_intent := s.vek().filter(func(u): return not u.intent.is_empty())
	assert_gt(with_intent.size(), 0)


func test_spawn_emerges_when_clear():
	var s := Fixtures.blank_state()
	s.mission = Defs.missions()[0]
	Fixtures.add(s, "prime", Vector2i(0, 0))
	s.pending_spawns = [{"def_id": "hornet", "pos": Vector2i(5, 5)}]
	var evs := TurnEngine.end_player_turn(s)
	assert_true("vek_spawned" in evs.map(func(e): return e["type"]))
	# spawned vek joins the roster (it may immediately move during the same phase)
	assert_eq(s.vek().size(), 1)
	assert_eq(s.vek()[0].def_id, "hornet")
	assert_eq(s.pending_spawns.size(), 0)


func test_spawn_blocked_by_unit_damages_blocker_and_retries():
	var s := Fixtures.blank_state()
	s.mission = Defs.missions()[0]
	var blocker := Fixtures.add(s, "prime", Vector2i(5, 5))
	s.pending_spawns = [{"def_id": "hornet", "pos": Vector2i(5, 5)}]
	var evs := TurnEngine.end_player_turn(s)
	assert_true("spawn_blocked" in evs.map(func(e): return e["type"]))
	assert_eq(blocker.hp, 3)
	assert_eq(s.pending_spawns.size(), 1)  # retries next turn
	assert_eq(s.vek().size(), 0)


func test_schedule_telegraphs_then_spawns():
	var s := Fixtures.blank_state()
	s.mission = Defs.missions()[0]
	Fixtures.add(s, "prime", Vector2i(0, 0))
	Fixtures.add(s, "scorpion", Vector2i(7, 7))  # keep battle alive
	s.spawn_queue = [{"turn": 1, "id": "hornet", "pos": Vector2i(5, 5)}]
	var evs := TurnEngine.end_player_turn(s)  # turn 1 ends: telegraph
	assert_true("spawn_telegraphed" in evs.map(func(e): return e["type"]))
	assert_eq(s.pending_spawns.size(), 1)
	assert_null(s.unit_at(Vector2i(5, 5)))
	assert_eq(s.vek().size(), 1)  # only the scorpion so far
	evs = TurnEngine.end_player_turn(s)  # turn 2 ends: emerges
	assert_true("vek_spawned" in evs.map(func(e): return e["type"]))
	assert_eq(s.vek().size(), 2)


func test_kill_all_requires_no_pending_spawns():
	var s := Fixtures.blank_state()
	s.mission = Defs.missions()[0]  # kill_all
	Fixtures.add(s, "prime", Vector2i(0, 0))
	s.pending_spawns = [{"def_id": "hornet", "pos": Vector2i(5, 5)}]
	assert_eq(TurnEngine.check_outcome(s), "")
	s.pending_spawns = []
	s.spawn_queue = []
	assert_eq(TurnEngine.check_outcome(s), "won")


func test_survive_mission_won_after_n_turns():
	var s := Fixtures.blank_state()
	s.mission = Defs.missions()[2]  # survive 5
	Fixtures.add(s, "prime", Vector2i(0, 0))
	Fixtures.add(s, "scorpion", Vector2i(7, 7))
	s.turn = 5
	var evs := TurnEngine.end_player_turn(s)
	assert_true("mission_won" in evs.map(func(e): return e["type"]))
	assert_eq(TurnEngine.check_outcome(s), "won")


func test_protect_failure_costs_two_grid():
	var s := Fixtures.blank_state()
	s.mission = Defs.missions()[3]  # protect
	Fixtures.add(s, "prime", Vector2i(0, 0))
	Fixtures.add_building(s, Vector2i(3, 1), 1, true)
	var bug := Fixtures.add(s, "scorpion", Vector2i(3, 2))
	bug.intent = {"weapon_id": "scorpion_pincer", "target": Vector2i(3, 1), "dir": Vector2i(0, -1)}
	var evs := TurnEngine.end_player_turn(s)
	var types := evs.map(func(e): return e["type"])
	assert_true("mission_failed" in types)
	assert_eq(s.grid_power, 7 - 1 - 2)  # 1 building hp + 2 penalty
	assert_eq(TurnEngine.check_outcome(s), "failed_protect")


func test_grid_zero_is_loss():
	var s := Fixtures.blank_state()
	s.mission = Defs.missions()[0]
	Fixtures.add(s, "prime", Vector2i(0, 0))
	Fixtures.add(s, "scorpion", Vector2i(7, 7))
	s.grid_power = 0
	assert_eq(TurnEngine.check_outcome(s), "lost_grid")


func test_all_mechs_dead_is_loss():
	var s := Fixtures.blank_state()
	s.mission = Defs.missions()[0]
	Fixtures.add(s, "scorpion", Vector2i(7, 7))
	assert_eq(TurnEngine.check_outcome(s), "lost_mechs")


func test_vek_move_and_telegraph_after_attack():
	var s := _mission_state()
	TurnEngine.start_battle(s)
	var evs := TurnEngine.end_player_turn(s)
	# After a full enemy phase every living vek has a fresh intent
	for v in s.vek():
		assert_false(v.intent.is_empty(), v.def_id)
	assert_true("telegraph_set" in evs.map(func(e): return e["type"]))
	assert_eq(s.turn, 2)


func test_ai_is_deterministic_across_restore():
	var s := _mission_state()
	TurnEngine.start_battle(s)
	var snap := s.snapshot()
	var evs1 := TurnEngine.end_player_turn(s)
	s.restore(snap)
	var evs2 := TurnEngine.end_player_turn(s)
	assert_eq(evs1.size(), evs2.size())
	for i in evs1.size():
		assert_eq(str(evs1[i]), str(evs2[i]))


func test_ai_does_not_telegraph_friendly_fire_when_avoidable():
	# A lone vek next to a mech should aim at the mech, not at another vek.
	var s := Fixtures.blank_state()
	s.mission = Defs.missions()[0]
	var mech := Fixtures.add(s, "prime", Vector2i(4, 4))
	Fixtures.add(s, "scorpion", Vector2i(3, 4))
	TurnEngine.start_battle(s)
	var bug: BUnit = s.vek()[0]
	assert_false(bug.intent.is_empty())
	var threatened := Telegraph.threatened_tiles(s, bug)
	assert_true(mech.pos in threatened)
